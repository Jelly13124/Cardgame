# Battle UI after STS2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the battle's select → aim → play → leave presentation after STS2 (segmented arrow, target reticle, always-on playable outline, play-queue zone, arcing discard flight, exhaust burn) without changing any combat rule.

**Architecture:** Presentation-only changes in `battle_scene/`: a rewritten `targeting_arrow.gd`, new `battle_scene/ui/selection_reticle.gd` and `battle_scene/ui/card_highlight.gd` (+ shader), and `card_animator.gd` owning play-zone layout and leave animations. `battle_scene.gd` only reports state changes (card queued / resolving / resolved / dropped, hover target, playability). Rules, pipeline and action queue from phase 1 stay untouched.

**Tech Stack:** Godot 4.6.3, GDScript, `canvas_item` shader, headless scene tests via `tools/run_tests.ps1`.

**Spec:** `docs/superpowers/specs/2026-10-23-battle-ui-sts2-design.md`

## Global Constraints

- Godot `C:\Users\Jerry\Tools\Godot_v4.6.3\Godot_v4.6.3-stable_win64_console.exe`; every run through `tools/run_tests.ps1` (isolated user data). A windowed visual capture sets `APPDATA` to a temp dir first.
- Gate per task: `powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_tests.ps1` exits 0 (all phase 1 tests keep passing).
- Script/scene references by `preload("uid://…")  # res://…` (run `python tools/godot_refs.py convert` after import, then `check`); new scenes get uids via `tools/assign_scene_uids.gd`. No new `class_name`.
- No rule changes: damage, effects, queue order, energy and pile contents behave exactly as on `cbef734`.
- No new image or audio files: arrow, head and reticle are drawn in code (flat fill + dark outline, UI07); sounds reuse `card_draw` (pitch up) and `card_play_power` (pitch down).
- Exact values from the spec: 19 arrow segments, scale 0.28 → 0.42; enemy red `#E61E1B`; hover head scale 1.05 (elastic); reticle 0.2 s fade, 0.9 → 1.0 expo-out in, → 1.05 out; outline 0.5 s show/hide (cubic out), flash ×2 width for 0.1 s then 0.35 s back; play slot scale 0.8, waiting i (from 1) offset `300 × i/(i+2)` left and scale `0.8 × (1 − i/(i+1))`, 0.35 s cubic out; discard arc control point 500 + rand(100, 400) above the midpoint, duration rand(1, 1.75) s, speed rand(1.1, 1.25) accelerating rand(2, 2.5); body darkens and shrinks to 0.1 over the first third; exhaust particles ~0.8 s, node frees after 2 s; drop = sink 30 px + fade 0.5 s; STR stat color `#ff7a5c`, CON `#8fb8ff`.
- Commits: Conventional Commits, `-c user.name=Jelly13124 -c user.email=ruizheyuan3487@gmail.com`, trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. No merge, no push.

## Review Focus

- The mouse cursor must come back after every way targeting ends: play, right-click/Esc cancel, tool targeting, victory/defeat mid-aim, scene change.
- A card queued behind others whose target dies, or that is dropped at combat end, must not stay floating in the play zone.
- Outline state after energy changes mid-turn (Afterburner gains energy, a card is discovered with cost 0, End Turn pressed, enemy turn, new turn draw).
- Hover state on an enemy that dies or is freed while the arrow points at it (reticle must not be shown on a freed node; arrow returns to white).
- Rapidly played Exhaust cards: each burns at its own position, no particle node outlives 2 s, no card leaks.

---

### Task 1: Readable stat colors and the outline rule

**Files:**
- Modify: `assets/translations/ui_battle.csv` (4 templates: `UI_BATTLE_DESC_DEAL_SCALING`, `UI_BATTLE_DESC_DEAL_ALL_SCALING`, `UI_BATTLE_DESC_STRENGTH_SCALING` → `#ff7a5c`; `UI_BATTLE_DESC_BLOCK_SCALING` → `#8fb8ff`; both columns), `AGENTS.md` (UI gate bullet on card outlines), `docs/project-rules.md` (UI screens sentence on card outlines)
- Test: `tests/card_text_pipeline_contract_test.gd`

- [ ] **Step 1:** Add assertions: `tr("UI_BATTLE_DESC_DEAL_SCALING")` contains `#ff7a5c` and not `#8b0000`; `tr("UI_BATTLE_DESC_BLOCK_SCALING")` contains `#8fb8ff` and not `#4444ff`.
- [ ] **Step 2:** Run `-Only card_text*` → FAIL.
- [ ] **Step 3:** Edit the CSV (both `en` and `zh`). Rewrite the outline rule to: hand cards that can be played show a constant shape-hugging outline as a state cue; every other card preview shows only the card normally, its outline appears only on hover/focus/selection; never a decorative frame or large empty holder.
- [ ] **Step 4:** Run `-Only card_text*` → PASS; full run → exit 0.
- [ ] **Step 5:** Commit `fix(cards): make the attribute part of card numbers readable` (docs change in the same commit, body notes the rule change).

### Task 2: Always-on playable outline

**Files:**
- Create: `battle_scene/ui/card_highlight.gd`, `battle_scene/ui/card_highlight.gdshader`, `tests/battle_ui_contract_test.gd` + `.tscn`
- Modify: `battle_scene/play_card.tscn` (remove `PlayableGlow` panel and its StyleBox), `battle_scene/play_card.gd` (`playable_glow` → highlight; hover no longer toggles it; `update_playable`), `battle_scene/battle_scene.gd` (`can_play_card`, refresh on End Turn / turn start / energy change)

**Interfaces (Produces):**
- `card_highlight.gd` (`extends TextureRect`): `set_source(texture: Texture2D, card_size: Vector2)` (draws the outline around that silhouette; the rect extends 12 px beyond the card on every side), `anim_show()`, `anim_hide()`, `anim_hide_instantly()`, `anim_flash()`, `is_shown() -> bool` (target width > 0), `const COLOR := Color(0.2, 0.92, 1.0, 0.98)`, `const WIDTH := 0.075` (shader `width` uniform in UV units of the extended rect).
- Shader: outline where the source alpha is < 0.5 but some sample within `width` (8 directions × 2 radii) has alpha ≥ 0.5; output `COLOR` with soft falloff; transparent elsewhere.
- `battle_scene.can_play_card(card: Control) -> bool`: card in `hand`, `_accepts_player_input()`, `can_afford([card])`, not curse / `unplayable`, and for attacks the double-fire allowance (`_attack_limit_per_turn <= 0 or _attacks_left_this_turn > 0`).
- `play_card.update_playable()` (no argument): cost-disc dim as now, plus highlight show/hide from `can_play_card(self)` when the scene has it and `suppress_playable_glow` is false; otherwise hide instantly.

- [ ] **Step 1: Failing tests** in new `battle_ui_contract_test` (real `battle_scene.tscn`, wait 4 frames, then add two `strike` cards via `deck_manager.add_card_to_hand`):
  - `test_outline_follows_playability`: with energy 3 both highlights `is_shown()`; set `player.energy = 0`, `battle.refresh_hand_ui()` → both hidden; energy back to 3 + refresh → shown; `battle._on_end_round_button_pressed()` then 1 frame → all hidden.
  - `test_outline_is_not_a_hover_toggle`: hovering (`_on_mouse_entered`) a card with energy 0 leaves `is_shown() == false`; the scene has no node named `PlayableGlow`.
- [ ] **Step 2:** Run `-Only battle_ui*` → FAIL.
- [ ] **Step 3: Implement.** Source silhouette: `GeneratedShell.texture` when the generated skin is active, else the legacy `FrontFace/TextureRect` texture. Highlight node sits behind `FrontFace` content (first child, `mouse_filter` ignore). `_handle_mouse_pressed` / drag start of a playable card calls `anim_flash()`. `battle_scene` calls `refresh_hand_ui()` when End Turn is pressed and in `_on_player_energy_changed` (already does via `_update_ui_labels`).
- [ ] **Step 4:** `-Only battle_ui*` → PASS; full run → exit 0 (discover modal still suppresses).
- [ ] **Step 5:** Commit `feat(cards): always-on outline for playable hand cards`.

### Task 3: Segmented targeting arrow

**Files:**
- Modify: `battle_scene/targeting_arrow.gd` (rewrite; keep `start(from_position)`, `stop()`, `set_target_valid(value)`), `battle_scene/battle_scene.gd` (restore cursor in `_clear_targeting_visuals`, `_victory`, `_game_over`, `_exit_tree`)
- Test: `tests/battle_ui_contract_test.gd`

**Interfaces (Produces):**
- `targeting_arrow.gd`: `const SEGMENT_COUNT := 19`, `const ENEMY_COLOR := Color("E61E1B")`, `segment_positions() -> PackedVector2Array` (19, last computed), `head_position() -> Vector2`, `current_color() -> Color` (white idle, `ENEMY_COLOR` when target valid), `head_scale() -> float` (0.95 idle, tweened to 1.05 elastic over 1.0 s when valid). `start` sets `Input.mouse_mode = Input.MOUSE_MODE_HIDDEN`; `stop` restores `MOUSE_MODE_VISIBLE`.
- Curve (STS2 `UpdateArrowPosition`): head at the mouse; control point `x = from.x − (head.x − from.x) × 0.25`; `y = head.y + (head.y − from.y) × 0.5` when `from.y > viewport_height / 2`, else `head.y × 0.75 + from.y × 0.25`; segment i at quadratic Bézier `t = i / 20`, scale `lerp(0.28, 0.42, i × 2 / 19)` (clamped to 0.42), each rotated toward the previous segment. Each segment drawn as a chevron (≈ 34 × 22 px at scale 1) with a 3 px dark outline; the head as a larger arrow (≈ 58 × 48 px at scale 1).

- [ ] **Step 1: Failing test** `test_arrow_is_segmented_and_hides_the_cursor`: `battle.start_spell_targeting(card)`, 1 frame → `arrow.segment_positions().size() == 19`, `arrow.current_color() == Color.WHITE`, `Input.mouse_mode == Input.MOUSE_MODE_HIDDEN`; `arrow.set_target_valid(true)` → `current_color() == arrow.ENEMY_COLOR`; `battle._cancel_spell_targeting()` → `Input.mouse_mode == Input.MOUSE_MODE_VISIBLE` and `battle.targeting_arrow == null`. Plus `test_cursor_returns_when_combat_ends_mid_aim`: start targeting, call `battle._victory()` → `Input.mouse_mode == Input.MOUSE_MODE_VISIBLE`.
- [ ] **Step 2:** Run → FAIL. (If headless ignores `mouse_mode`, record a ruling and assert the arrow's own `cursor_hidden` flag instead.)
- [ ] **Step 3: Implement** the rewrite; delete the flow dots, target ring, cubic curve and green idle color.
- [ ] **Step 4:** `-Only battle_ui*`, `-Only tool_use*` → PASS; full run → exit 0.
- [ ] **Step 5:** Commit `feat(battle): segmented STS2-style targeting arrow`.

### Task 4: Target reticle instead of enemy scale/tint

**Files:**
- Create: `battle_scene/ui/selection_reticle.gd`
- Modify: `battle_scene/enemy_entity.gd` (owns a reticle; `show_reticle()`, `hide_reticle()`, `reticle_shown() -> bool`), `battle_scene/battle_scene.gd` (`_set_hover_effect` → reticle + `targeting_arrow.set_target_valid`; never scale or tint the enemy)
- Test: `tests/battle_ui_contract_test.gd`

**Interfaces (Produces):**
- `selection_reticle.gd` (`extends Node2D`): `set_rect(local_rect: Rect2)`, `show_reticle()`, `hide_reticle()`, `is_shown() -> bool`; draws four corner brackets (bracket length 22 % of the shorter side, 4 px light line on a 7 px dark line); show = alpha 0→1 over 0.2 s and scale 0.9→1.0 over 0.5 s expo-out about the rect centre; hide = alpha →0 and scale →1.05 over 0.2 s sine-out.
- Enemy rect: from `get_targeting_rect()` converted to the enemy's local space, refreshed on show.

- [ ] **Step 1: Failing test** `test_hover_shows_reticle_without_changing_the_enemy`: while targeting, `battle._set_hover_effect(enemy, true)` → `enemy.reticle_shown()`, `enemy.scale == Vector2.ONE`, `enemy.modulate == Color.WHITE`; `_set_hover_effect(enemy, false)` → `not enemy.reticle_shown()`. Plus `test_freed_hover_target_resets_arrow`: hover an enemy, `queue_free()` it, 2 frames of `_process` → `battle.hovered_unit == null` and `arrow.current_color() == Color.WHITE`, no script error.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement**; `_process` drops a `hovered_unit` that is no longer live before using it.
- [ ] **Step 4:** `-Only battle_ui*` → PASS; full run → exit 0.
- [ ] **Step 5:** Commit `feat(battle): STS2-style target reticle replaces enemy hover tint`.

### Task 5: Play-queue zone

**Files:**
- Modify: `battle_scene/card_animator.gd` (replace `fly_to_play_area` / `_get_play_area_card_position`), `battle_scene/battle_scene.gd` (`play_spell` calls `card_animator.enqueue_card(card)`; `_resolve_played_card` awaits `card_animator.begin_resolving(card)` instead of the flight flag; remove `_fly_to_play_area`)
- Test: `tests/battle_ui_contract_test.gd`

**Interfaces (Produces):**
- `card_animator.gd`: `play_position(card: Control) -> Vector2` (card top-left so its centre is at `(viewport.x × 0.5, viewport.y × 0.40)`), `static func waiting_offset(i: int) -> float` (`300.0 * i / (i + 2)`), `static func waiting_scale(i: int) -> float` (`0.8 * (1.0 - float(i) / (i + 1))`), `enqueue_card(card: Control) -> void` (append to `_waiting`, re-layout), `begin_resolving(card: Control) -> void` (coroutine: remove from `_waiting`, tween to `play_position` at scale 0.8 over 0.2 s cubic out, re-layout the rest), `waiting_cards() -> Array`, `drop_waiting() -> Array` (returns and clears waiting cards; Task 6 animates them).
- Layout tween: every waiting card i (1-based) to `play_position − (waiting_offset(i), 0)`, scale `waiting_scale(i)`, rotation 0, 0.35 s cubic out.

- [ ] **Step 1: Failing tests** `test_waiting_layout_formula` (`waiting_offset(1) == 100.0`, `waiting_offset(2) == 150.0`, `waiting_scale(1) == 0.4`, `waiting_scale(2) ≈ 0.2667`) and `test_three_quick_plays_line_up`: three `strike` cards played back-to-back at one enemy with 999 HP; after 0.4 s the first is at `play_position` (±2 px) with scale 0.8 and the other two are at offsets 100 and 150 left with scales 0.4 and 0.2667 (±0.02); after the queue drains all three are in the discard pile.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** `-Only battle_ui*`, `-Only action_queue*`, `-Only combat_flow*` → PASS; full run → exit 0.
- [ ] **Step 5:** Commit `feat(battle): STS2-style play-queue zone for queued cards`.

### Task 6: Discard arc, exhaust burn, drop on combat end

**Files:**
- Modify: `battle_scene/card_animator.gd` (rewrite `fly_to_discard`; replace `fly_to_exhaust` with `burn_exhaust`; add `drop_card`), `battle_scene/battle_scene.gd` (`_route_played_card` uses them; `_victory` / `_game_over` animate `card_animator.drop_waiting()` with `drop_card` and park those cards in the discard pile)
- Test: `tests/battle_ui_contract_test.gd`

**Interfaces (Produces):**
- `fly_to_discard(card: Control) -> void` (coroutine): quadratic arc from the card's centre to the discard pile glyph centre with the spec's random control point, duration, speed and acceleration; card rotated along the path (lerp 12 × delta); a body-darkening `modulate` toward black and scale toward 0.1 over the first third; a `Line2D` trail (last 12 positions, width 18 → 0, alpha fades with the card) added to the battle scene and freed with the flight; `AudioManager.play_sfx("card_draw", -4.0, 1.35)` at start; on arrival resets scale/rotation/modulate/z_index/input exactly as today.
- `burn_exhaust(card: Control) -> void` (coroutine): spawns a one-shot `CPUParticles2D` (≈ 40 particles, lifetime 0.8 s, orange → ash grey color ramp, upward spread) at the card centre in the battle scene, fades the card out over 0.4 s, plays `card_play_power` at pitch 0.7; the particle node frees itself after 2.0 s. Caller frees the card afterwards (unchanged).
- `drop_card(card: Control) -> void` (coroutine): position.y +30 and alpha → 0 over 0.5 s cubic out.
- Scope note: a queued card whose target died still resolves (phase 1 rule: effects fizzle without a target, energy stays spent), so it flies to discard normally; only cards dropped by combat end use `drop_card`. Spec §4 "取消出牌" is read this way; returning to hand never applies under current rules.

- [ ] **Step 1: Failing tests** `test_discard_flight_lands_in_the_pile` (one `strike` resolved → card ends in `discard_pile`, `scale == Vector2.ONE`, `modulate.a == 1.0`, no `Line2D` left in the battle scene after the flight), `test_exhaust_burns_in_place` (an Exhaust card such as `reload` played → a `CPUParticles2D` appears in the battle scene, the card is freed, and 2.2 s later no `CPUParticles2D` remains), `test_combat_end_drops_waiting_cards` (queue three cards, force `_victory()` after the first starts → the two waiting cards end in the discard pile, not in the play zone).
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** (time-scale the flight with `Engine.time_scale`-aware process delta like other tweens).
- [ ] **Step 4:** `-Only battle_ui*` and full run → exit 0.
- [ ] **Step 5:** Commit `feat(battle): STS2-style discard arc, exhaust burn and dropped cards`.

### Task 7: Visual capture and branch verification

**Files:**
- Create: `tests/battle_ui_visual_capture.gd` + `.tscn` (not run by the runner): opens the battle, aims a card at an enemy (arrow red, reticle shown, outlines visible), saves `res://tmp/battle-ui-aim.png`; then plays an Exhaust card and a normal card mid-flight and saves `res://tmp/battle-ui-leave.png`.

- [ ] **Step 1:** Write the capture; run it windowed with `APPDATA`/`XDG_DATA_HOME` pointed at a temp dir; inspect both PNGs (arrow segments and colors, reticle corners, outline hugging the card shape, trail and particles visible).
- [ ] **Step 2:** Full `tools/run_tests.ps1` → exit 0; clean clone of the branch → exit 0; real profile untouched.
- [ ] **Step 3:** Commit `test(battle): visual capture for the STS2-style battle UI`; independent whole-branch review; fix Critical/Important with RED→GREEN.

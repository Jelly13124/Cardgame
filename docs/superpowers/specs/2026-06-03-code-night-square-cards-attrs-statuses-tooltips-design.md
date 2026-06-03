# Code Night — Square Cards · Attr Display · New Statuses · Tooltips · QoL — Design

> Overnight code batch run in parallel with Codex's art refactor. **Hard constraint:**
> touch only `.gd` / `.json` / `.gdshader` / translation `.csv`. Do **NOT** edit any
> PNG or the art-node layout of `play_card.tscn` — those are Codex's tonight.

**Goal:** Land six self-contained code improvements: remove the attack-card art-shape
mask (all square), fix the STR/CON breakdown in card descriptions, add four new status
effects (Regen / Thorns / Frail / Dodge) with supporting content, fill three tooltip
gaps, add an attack-damage preview, and clear one piece of dead code.

**Architecture:** All changes ride existing systems — the shader mask removal is pure
deletion; the description fix mirrors `combat_engine._apply_effect`'s global-attribute
rule; new statuses extend `status_effect_system.gd` + `combat_engine.gd` hooks and the
`data_validator` allow-list (the two-place rule); tooltips reuse the `Tooltip` autoload.

**Tech Stack:** Godot 4.6, GDScript, JSON content, CSV i18n.

---

## Units

### Unit 0 — Remove attack-card art-shape mask (all cards square)

Today attack cards clip their art into a downward-V via `card_art_mask.gdshader`
(`is_attack` uniform); skill/ability stay square. Remove the distinction entirely.

- Delete `battle_scene/card_art_mask.gdshader` (+ its `.uid` sidecar via `git rm`).
- `battle_scene/play_card.gd`:
  - Remove `const MASK_SHADER = preload(...)` (line ~20).
  - Remove `var _mask_material: ShaderMaterial = null` (line ~29).
  - Remove the mask block in `_set_card_data` (lines ~200–206: the `_mask_material`
    construction + `set_shader_parameter("is_attack", ...)`). Leave `art_texture`
    with no material override.
  - Keep the type-label text/color logic (lines ~208–218) untouched.

**Done when:** all cards render square art; no `card_art_mask` references remain; smoke green.

---

### Unit 1 — Card description STR/CON breakdown (regression fix)

`_build_description` in `play_card.gd` still reads the removed per-card `scaling`
field, so it never adds the global STR/CON and never shows the `(base+stat)` split.
`combat_engine._apply_effect` actually applies: `deal_damage`/`deal_damage_all` →
`amount += player.strength`; `gain_block` → `amount += player.constitution`; the
multiplier is applied to the base **before** the attribute is added.

Rewrite the per-effect numeric calc to mirror that exactly:

- For `deal_damage` / `deal_damage_all`: `base_after_mult = int(base * mult)`,
  `attr_val = stats.strength`, `total = base_after_mult + attr_val`. Then apply the
  display status multipliers already present (`outgoing_mult`, `double_damage`).
- For `gain_block`: `base_after_mult = int(base * mult)`, `attr_val = stats.constitution`,
  `total = base_after_mult + attr_val`.
- Show the `(base+stat)` split via the existing `UI_BATTLE_DESC_*_SCALING` strings
  **only when `attr_val > 0`** (format args `{val, base, stat}` where `base =
  base_after_mult`, `stat = attr_val`); otherwise the plain `UI_BATTLE_DESC_*` string.
- `deal_damage_str_mult` and `scale_damage_by_attacks` keep their own formulas and do
  **not** receive the global +STR (matching combat_engine).
- Drop the dead `scaling`/`stat_val`-from-`scaling` path.

**Done when:** with e.g. 3 STR, a "Deal 6" attack card reads "Deal 9 (6+3)"; a
"Gain 5" block card with 2 CON reads "Gain 7 (5+2)"; cards with 0 STR/CON read plain.

---

### Unit 5 — Dead-code cleanup (done early, low risk)

`relic_effect_system.gd` `_mark_used_once(entry)` is meaningful for `once_per_combat`
relics but is a no-op call on the Sharpened Scrap branch (relic is not
`once_per_combat`). Remove **only** the provably-dead call on that branch; leave every
`once_per_combat` call site intact. Verify by reading the surrounding `match`/`if`
before deleting. No behavior change.

**Done when:** the dead Sharpened Scrap call is gone, all real once-per-combat calls
remain, smoke green.

---

### Unit 2 — Four new status effects + supporting content

Add `regen`, `thorns`, `frail`, `dodge`. All four registered in **both** places
(`status_effect_system` handler + `data_validator.ALLOWED_STATUS_NAMES`).

**`status_effect_system.gd`:**
- `STATUS_COLORS` / `STATUS_LABELS` / `STATUS_DESCRIPTIONS`: add the four. Suggested
  labels: regen `+`, thorns `🜨`(or `T`), frail `F`, dodge `~`. Colors: regen green,
  thorns steel, frail purple-grey, dodge cyan-white.
- **Regen** — in `on_turn_start`: if `has_status("regen")`, `entity.heal(stacks)`
  then decay 1 (erase at 0). Player-friendly; heal via existing `heal()`.
- **Thorns** — persistent, no decay. Reflection handled in `combat_engine`
  (see hooks below), not here. Expose `get_stacks("thorns")`.
- **Frail** — decays 1/turn (add to `TURN_END_DECAY`). Add
  `get_block_multiplier() -> float` returning `0.75` when `has_status("frail")` else
  `1.0` (flat 25% reduction, mirroring weak's flat model — NOT per-stack, for
  consistency with the existing `get_outgoing_multiplier`).
- **Dodge** — persistent, consumed on hit. Add
  `try_consume_dodge(entity) -> bool`: if `has_status("dodge")`, consume 1 stack
  (erase at 0), refresh badges, return true; else false.

**`combat_engine.gd` hooks:**
- **Dodge (player→enemy):** in `deal_damage`, `deal_damage_all`,
  `scale_damage_by_attacks`, `deal_damage_str_mult` — before applying outgoing damage
  to a target, if `target.status_system.try_consume_dodge(target)` returns true, skip
  the damage for that target and show a "DODGE" notification (no damage dealt).
- **Frail (player block):** in `gain_block`, after the existing equipment
  `modify_card_block`, multiply by `player.status_system.get_block_multiplier()`
  (floor at int). So a frail player gains 25% less block.
- **Thorns (player→enemy):** add a shared helper
  `apply_thorns_reflection(attacker, defender)`: if `defender` alive and
  `defender.status_system.has_status("thorns")`, `attacker.take_damage(thorns_stacks)`.
  Call it after each successful player attack lands on a living enemy (in the four
  damage branches above).

**Enemy side (`enemy_ai.gd`):**
- **Thorns (enemy→player):** after an enemy attack lands on the player, call the same
  reflection (enemy takes player's thorns).
- **Dodge (enemy→player):** before the enemy's attack damages the player, if
  `player.status_system.try_consume_dodge(player)` → negate, show "DODGE". (Player
  dodge is rare but the hook must exist for symmetry.)
- **Frail (enemy block):** if an enemy gains block, multiply by its
  `get_block_multiplier()`.

**`data_validator.gd`:** add `"regen"`, `"thorns"`, `"frail"`, `"dodge"` to
`ALLOWED_STATUS_NAMES`.

**i18n** (`assets/translations/`, the combat status CSV): add EN + ZH rows
`UI_COMBAT_STATUS_REGEN[_DESC]`, `_THORNS[_DESC]`, `_FRAIL[_DESC]`, `_DODGE[_DESC]`
so badges/tooltips localize. Re-import via headless after editing the CSV.

**Supporting content (JSON, + draft-pool wiring):**
- `patch_kit` — skill, common, cost 1: `apply_status_self regen 3`.
- `spiked_guard` — skill, uncommon, cost 1: `gain_block 5` + `apply_status_self thorns 3`.
- `corrode` — skill, common, cost 1: `apply_status frail 2` (to target enemy).
- Add a `_plus` upgrade variant for each (bump the numbers: regen 5 / block 8+thorns 4 /
  frail 3) to match the project's upgrade convention.
- Card art: each new card needs a PNG, but **art is Codex's job** — reference the
  expected path and let the data_validator warn-not-fail for the missing-art window
  (per CLAUDE.md rule 5). Do not generate placeholder PNGs.
- **Wiring:** add `patch_kit`, `spiked_guard`, `corrode` to
  `MetaProgress.INITIAL_CARD_POOL` so they roll in loot drafts.
- Run the `content-balance` subagent on the three new cards before committing.
- **Dodge enemy:** give an agile enemy (`chrome_hound`) a `dodge`-granting action
  (`apply_status_self dodge 1`) somewhere in its action pattern, so dodge appears
  in play. No new player source of dodge (it stays rare/enemy-only by design).

**Done when:** all four statuses work in combat (regen heals, thorns reflects both
directions, frail cuts block, dodge negates + consumes), badges show with tooltips,
validator passes, new cards draftable, chrome_hound can dodge, smoke green.

---

### Unit 3 — Fill three tooltip gaps (reuse `Tooltip` autoload)

**3a — Enemy intent.** In `enemy_entity.gd` (`_build_intent_badge` ~295 /
`_update_intent_display` ~386), wire the intent badge's `mouse_entered` to
`Tooltip.show(text, badge_global_pos, badge_id)` and `mouse_exited`/`tree_exited` to
`Tooltip.hide_if_owner(badge_id)` (same stale-guard pattern as status badges). Build
the text from the current intent (type + value): e.g. "Attack — deals N", "Defend —
gains N block", "Buff — strengthening", "Charge / Summon". Localize via new
`UI_BATTLE_INTENT_*` rows (EN+ZH).

**3b — Card keyword glossary.** In `play_card.gd` `_on_mouse_entered`, scan the card's
description text for known keywords (the status names + any in `STATUS_DESCRIPTIONS`,
plus STR/CON terms). If any are present, `Tooltip.show(glossary, global_position)` with
one "[b]Keyword[/b]: desc" line per matched keyword; hide on `_on_mouse_exited`
(use owner-id guard). Pull descriptions from `StatusEffectSystem.STATUS_DESCRIPTIONS`
+ localized keys so there's a single source of truth. Additive — must not disturb the
existing hover-enlarge tween.

**3c — Misc UI audit.** Add tooltips where clearly missing and high-value, bounded to:
attribute icons (STR/CON/INT/LUCK/CHARM) in the CharacterHUD and the map character-info
panel → short "what it does" text. Skip backpack/safe-cell unless trivial. Reuse the
`Tooltip` autoload; localize new strings.

**Done when:** hovering an enemy intent, a card with keywords, and an attribute icon
each shows an explanatory tooltip; no stale-tooltip leaks; smoke green.

---

### Unit 4 — Attack-damage preview

When the player is dragging an attack card to target, show the predicted post-mitigation
damage above the prospective target, computed via the existing
`combat_engine.calculate_attack_damage(base+STR, player, enemy)` (include weak /
vulnerable / equipment as that function already does). **If exactly one enemy is on the
field, show the corrected actual number directly** (no hover needed — display it as soon
as an attack card is picked up / hovered). Find the drag-target/arrow code (in
`play_card.gd` and/or `battle_scene.gd`) and attach a small floating Label above the
enemy; clear it on drop/cancel. Logic only — no new art.

**Done when:** dragging an attack card shows the real number it will deal; with a single
enemy the number shows immediately; clears on release; smoke green.

---

## Execution order & gating

`0 → 1 → 5 → 2 → 3 → 4`. Run `bash scripts/smoke_test.sh` (GODOT_BIN set) after each
unit; expected tail `[OK] DataValidator: all schemas passed.` Commit per unit. **Do not
push** (Codex shares the working tree; owner reviews + pushes). New-content units
(Unit 2) additionally run the `content-balance` and `gdscript-reviewer` subagents
before their commit.

## Out of scope

Boss/elite bespoke mechanics (deferred by owner); any PNG / `play_card.tscn` art-node
edits (Codex); pushing to remote.

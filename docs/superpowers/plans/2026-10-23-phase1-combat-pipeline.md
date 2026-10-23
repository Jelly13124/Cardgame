# Phase 1 Combat Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One damage/block/status pipeline with preview mode, one effect registry shared by cards, tools, relics, sets, enemies, curses and events, combat hooks, and a top-level action queue — so preview, intent, card text and resolution can no longer disagree.

**Architecture:** Pure rule code in `core/combat/` (value types, pipeline stages, hook dispatcher, rule listeners, action queue) and `core/effects/` (registry, run-context effects). Battle-side presentation code in `battle_scene/combat/` (commands that animate and apply, combat effect handlers). Existing `RelicEffectSystem` / `EquipmentSetSystem` become hook listeners; `combat_engine.gd` shrinks to card-play orchestration.

**Tech Stack:** Godot 4.6.3, GDScript, headless scene tests (`tools/run_tests.ps1`).

**Spec:** `docs/superpowers/specs/2026-10-23-phase1-combat-pipeline-design.md`

## Global Constraints

- Godot binary: `GODOT_BIN=C:\Users\Jerry\Tools\Godot_v4.6.3\Godot_v4.6.3-stable_win64_console.exe`; every Godot run goes through `tools/run_tests.ps1` (isolated user data). Never run Godot unisolated.
- Gate after every task: `powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_tests.ps1` exits 0 (or `-Only <pattern>` while iterating, full run before commit).
- `core/` files: no scene tree (`get_tree()`, `current_scene`, `get_node(`, `$`), no UI paths; reference scripts by `preload("uid://…")  # res://…`; new scripts get uids from Godot import (run `python tools/godot_refs.py convert` after the first import, then `check`).
- No new `class_name`; use preloaded script constants.
- Card / enemy / relic / set / event JSON schemas stay the same except `dodge` → `intangible` (smoke_step, chrome_hound).
- Commits: Conventional Commits, author `-c user.name=Jelly13124 -c user.email=ruizheyuan3487@gmail.com`, trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Do not merge or push.
- Floor once after the multiplicative stage; act damage scaling stays `round` inside the enemy base value (`RunManager.scale_enemy_damage`).
- Hook dispatch depth limit: 16.

## Review Focus

- A target that dies mid multi-target effect (AoE, Overload) or between replay passes: remaining hits skip it, hooks never receive a freed node, victory fires once.
- Preview called every frame must never mutate state (Loaded, Deadeye, once-per-combat relics, crit RNG) — pinned by the parity tests running preview twice before actual.
- Rapid input: two cards dropped while one resolves, End Turn clicked while cards are queued, a tool confirmed while a card resolves — all serialize in enqueue order.
- Intangible on the player while an enemy attack ramps / attacks all / applies a status: each hit deals ≤1 and the status rider still applies.
- Combat ends while actions are queued: pending actions are dropped, no effect runs on a freed scene.

---

### Task 1: Core value types, pipeline, hooks and rule listeners

**Files:**
- Create: `core/combat/value_props.gd`, `core/combat/combat_source.gd`, `core/combat/value_calc.gd`, `core/combat/damage_result.gd`, `core/combat/card_play.gd`, `core/combat/combat_hooks.gd`, `core/combat/rules/attribute_rules.gd`, `core/combat/rules/status_rules.gd`, `core/combat/rules/crit_rules.gd`
- Test: `tests/combat_pipeline_contract_test.gd` + `.tscn`

**Interfaces (Produces):**
- `value_props.gd`: `const POWERED := 1`, `UNBLOCKABLE := 2`, `NO_STRENGTH := 4`, `NO_CONSTITUTION := 8`.
- `combat_source.gd`: fields `kind: String`, `side: String` ("player"|"enemy"|"neutral"), `card: Object`, `id: String`, `dealer: Object`; `static func make(kind, side, dealer = null, card = null, id = "")`; `is_card() -> bool`; `card_type() -> String` (lower-case `card.card_info.type` or "").
- `value_calc.gd`: `static func damage(source, target, base: int, props: int, preview: bool, play = null)`, `static func block(source, creature, base, props, preview)`, `static func status(source, target, status: String, stacks: int, effect_type: String, preview: bool)`; fields `kind, value: float, base, dealer (=source.dealer), target, props, source, preview, play, flat_bonus: int, critical: bool, tags: Dictionary, status, effect_type, commits: Array[Callable]`; `has(flag) -> bool`; `on_commit(c: Callable)`; `commit()` runs and clears commits.
- `damage_result.gd`: `source, props, dealer, target, amount, blocked, hp_lost, killed, critical, block_broken`.
- `card_play.gd`: `card, target, dealer, preview: bool, loaded_taken: bool, simulated: Dictionary`; `take_loaded(dealer) -> int` (first call returns dealer `loaded` stacks and, when not preview, spends them; later calls return 0); `simulate_spend(key) -> bool` (preview-only bookkeeping: returns true the first time a key is spent in this preview).
- `combat_hooks.gd`: `add_listener(l)`, `clear()`, `compute_damage(calc) -> int`, `compute_block(calc) -> int`, `compute_status_stacks(calc) -> int`; coroutine dispatch `after_damage_given(result)`, `after_damage_received(result)`, `after_attack(attack: Dictionary)`, `after_block_gained(result: Dictionary)`; `const MAX_DEPTH := 16`; `var commands` (set by battle; passed to listeners through `calc`/results as `hooks.commands`).
  Damage stages call, in listener order, `modify_damage_additive`, `modify_damage_multiplicative`, then `floor`, `modify_damage_reduction`, `modify_damage_cap`; `flat_bonus` is added in the additive stage only when `POWERED`. Block: `modify_block_additive`, `modify_block_multiplicative`, floor, min 0. Status: `modify_status_stacks`, min 0.
- `attribute_rules.gd`: STR (POWERED, player side, no NO_STRENGTH), CON (POWERED, no NO_CONSTITUTION), INT (source kind card|tool, target not dealer-side, effect_type apply_status|apply_status_all, status != "stun").
- `status_rules.gd`: weak ×0.5 on dealer (POWERED), vulnerable ×1.5 on target (POWERED), frail ×0.75 on block (POWERED), intangible cap 1; `after_damage_received`: thorns reflection (POWERED, dealer alive) via `hooks.commands.damage(thorns source, [dealer], thorns, 0)`, spend 1 thorns, Serrated Barbs via `relics.thorns_apply_short_circuit()` → `hooks.commands.apply_status(...)`.
- `crit_rules.gd`: `var relics` (RelicEffectSystem or null), `reset_turn()`; multiplicative stage per spec §3 (overload tag `calc.tags.overload`: random roll only, ×`RunManager.CRIT_MULT`); preview uses only forced crits and `play.simulate_spend` so one forced crit shows once per preview; commits spend Deadeye / mark first-attack used / Hot Streak / All In loaded / `relics.on_player_crit(player)`.

- [ ] **Step 1: Write failing contract test** `combat_pipeline_contract_test` with fake creatures (Node2D with `status_system`, `strength`, `constitution`, `intelligence`, `block`, `health`). Assertions (exact values):
  - STR 3, base 4 powered → 7; same with `NO_STRENGTH` → 4; source kind tool (not powered) with STR 3 and vulnerable target → 4.
  - base 7 powered, target vulnerable → 10 (floor of 10.5); dealer weak + target vulnerable, base 7 → 5.
  - intangible target, base 30 powered vulnerable → 1; intangible applies to unpowered base 6 → 1.
  - block: CON 3, base 5, frail → 6 (floor((5+3)×0.75)); relic source block 5 with frail → 5.
  - status: card source apply_status weak 1 to enemy with INT 2 → 3; apply_status_self → 1; stun → 1; tool source apply_status → 1+INT.
  - Deadeye 1 on player: preview twice → critical both times, stacks still 1; real calc + `commit()` → stacks 0 and value ×1.5.
  - `card_play.take_loaded`: loaded 2 → preview play returns 2 then 0 and stacks unchanged; real play returns 2, stacks 0.
  - Hook depth: a listener whose `after_damage_given` re-dispatches itself stops at depth 16 with no crash (count == 16).
- [ ] **Step 2: Run** `tools/run_tests.ps1 -Only combat_pipeline*` → FAIL (scripts missing).
- [ ] **Step 3: Implement the files above.**
- [ ] **Step 4: Import, convert refs, run** `python tools/godot_refs.py convert` then `tools/run_tests.ps1 -Only combat_pipeline*` → PASS; `python tools/check_layers.py` → `layers: ok`.
- [ ] **Step 5: Commit** `feat(combat): add value pipeline, combat hooks and rule listeners`.

### Task 2: Effect registry and run-context effects

**Files:**
- Create: `core/effects/effect_registry.gd`, `core/effects/effect_context.gd`, `core/effects/run_effects.gd`
- Modify: `run_system/core/run_manager.gd` (`apply_event_effects` delegates)
- Test: `tests/effect_registry_contract_test.gd` + `.tscn`

**Interfaces (Produces):**
- `effect_registry.gd`: `register(type: String, handler: Callable, contexts: PackedStringArray)`, `has_type(type, context) -> bool`, `types(context) -> PackedStringArray`, coroutine `execute(ctx, effect: Dictionary)` (unknown type/context → `push_error` + `assert(false)`).
- `effect_context.gd`: fields `kind` ("combat"|"enemy"|"run"), `source` (CombatSource), `actor`, `target`, `play` (CardPlay or null), `services` (battle-side services object or null), `pace: bool` (wait the old notification timers only for card/tool sources).
- `run_effects.gd`: `static func register_into(registry)`; handlers for the 8 event types with the exact RunManager calls now in `apply_event_effects` (`heal` and `lose_hp` registered for context "run" here; combat versions come in Task 3).

- [ ] **Step 1: Failing test**: run registry executes `gain_gold` 7 → `RunManager.gold` +7 (restore after); `has_type("overload","run") == false`; every `DataValidator.ALLOWED_EVENT_EFFECT_TYPES` entry `has_type(_, "run")`.
- [ ] **Step 2: Run** `-Only effect_registry*` → FAIL.
- [ ] **Step 3: Implement**; `RunManager.apply_event_effects(effects)` builds one shared static run registry lazily and awaits nothing (run handlers are synchronous).
- [ ] **Step 4: Run** `-Only effect_registry*`, `-Only card_event*` → PASS.
- [ ] **Step 5: Commit** `refactor(events): run event effects through the shared effect registry`.

### Task 3: Combat commands, card/tool effects, listeners, preview parity

**Files:**
- Create: `battle_scene/combat/combat_commands.gd`, `battle_scene/combat/combat_effects.gd`, `tests/support/combat_harness.gd`, `tests/combat_hooks_contract_test.gd` + `.tscn`
- Modify: `battle_scene/combat_engine.gd` (remove `_apply_effect`, `calculate_attack_damage`, `_apply_player_crit`, `_check_dodge`, `apply_thorns_reflection`, `_consume_loaded_bonus`, `_grant_card_block`, `_register_player_attack`; keep `resolve_card_effect`, gunshot animation, `declare_victory`, add `execute_effect(effect, target, source)`), `battle_scene/battle_scene.gd` (create services in `_start_new_game`; tools and curses call `execute_effect`; `preview_card_damage(card, target) -> int` replaces `_card_preview_damage`), `battle_scene/relic_effect_system.gd`, `battle_scene/equipment_set_system.gd` (listener methods), `battle_scene/status_effect_system.gd` (remove multipliers and dodge helpers; add `damage_router: Callable` used for Burn), `battle_scene/player.gd` (`gain_energy`, drop multiplier helpers), `tests/combat_preview_parity_test.gd`, `tests/short_circuit_contract_test.gd`, `tests/gunslinger_contract_test.gd`, `tests/combat_feedback_runtime_test.gd`, `tests/expected_failures.txt`

**Interfaces:**
- Consumes Task 1 and Task 2 interfaces.
- `combat_commands.gd` (`extends RefCounted`, `var battle`, `var hooks`): coroutines `damage(source, targets: Array, base: int, props: int, play = null, flat_bonus := 0, tags := {}) -> Array` (DamageResults; skips dead targets; feedback `source` tag: card/tool → "player", enemy → "enemy", relic/set → "relic", status → "status", thorns → "thorns"), `gain_block(source, creature, base: int, props: int) -> int`, `apply_status(source, target, status: String, stacks: int, effect_type := "") -> int`, `lose_hp(source, creature, amount: int) -> int` (intangible caps to 1); `preview_damage(source, target, base, props, play, flat_bonus := 0) -> int`.
- `combat_effects.gd`: `static func register_into(registry)` registering every type in `DataValidator.ALLOWED_EFFECT_TYPES` for "combat" plus relic-only `gain_temp_strength`; `static func damage_base(ctx, effect) -> int`, `static func damage_props(effect) -> int` (table in spec §5); `static func preview_card_damage(services, card, target) -> int` (sum of per-effect previews over a preview `CardPlay`, `-1` when the card has no damage effect).
- `combat_engine.gd`: `execute_effect(effect: Dictionary, target, source) -> void` (coroutine), `resolve_card_effect(card, target, player)` (builds `CardPlay`, runs passes, fires `hooks.after_attack({"source", "dealer", "target"})` per pass for attack cards with a live target, increments `turn_manager.attacks_played_this_turn/_combat` once after all passes for attack cards).
- Battle services surface used by commands/effects (duck-typed on `battle_scene`): `player`, `enemy_container`, `deck_manager`, `turn_manager`, `relic_effect_system`, `equipment_set_system`, `combat_hooks`, `combat_commands`, `effect_registry`, `show_notification`, `is_game_over`, plus existing helpers (`open_discover`, `try_gain_gold`, `add_attack_allowance`, `restore_attack_allowance`, `update_polarity_hud`).
- `tests/support/combat_harness.gd`: `static func install(battle_like: Node) -> void` wiring hooks/commands/registry/rules onto a fake battle node.

- [ ] **Step 1: Failing tests**:
  - `combat_hooks_contract_test`: with set `attack_damage_bonus` 2 and `attack_apply_status weak 1` active: Final Salvo (attacks this combat 3) deals 5+3+2 = 10 and applies Weak 1; Kinetic Rebound with Block 6 deals 8 and applies Weak 1; a relic `deal_damage_all` 1 applies no Weak; a tool `deal_damage` 10 vs Vulnerable enemy with STR 3 deals 10; attack counter after one play of a Replay-1 attack card == 1; Overload discharge triggers the set Weak on each struck enemy (card source).
  - `combat_preview_parity_test` rewritten against `combat_effects.preview_card_damage` vs actual executed damage effects (shared real `CardPlay`), adding dimensions `intangible` (target) and `deadeye` (player, Deadeye 1); preview is called twice before actual.
- [ ] **Step 2: Run** `-Only combat_hooks*` → FAIL; `-Only combat_preview*` → FAIL to compile/run.
- [ ] **Step 3: Implement** commands, effects (move every `_apply_effect` branch, keeping notifications/sfx/timers when `ctx.pace`), engine thin layer, battle wiring, relic/set listener methods (spec §6 table: relic `modify_damage_additive` add_damage, `modify_damage_reduction` reduce_damage, `modify_block_additive` gain_block, `modify_block_multiplicative` gain_block_crit, `modify_status_stacks` Brutal Servo, `after_block_gained` Scavenger Lens, `after_attack` player_attack statuses, `after_damage_received` Medkit Drone; set `modify_damage_additive` attack_damage_bonus, `modify_block_additive` skill_block_bonus, `after_damage_given` attack_apply_status); once-per-combat marks go through `calc.on_commit`.
- [ ] **Step 4: Migrate** short_circuit / gunslinger / combat_feedback_runtime tests to the harness + public API (same assertions); delete the `combat_preview_parity_test` line from `tests/expected_failures.txt`. Run full `tools/run_tests.ps1` → exit 0 (intent parity still XFAIL).
- [ ] **Step 5: Commit** `refactor(combat): route card and tool effects through one pipeline and command layer`.

### Task 4: Relic/set actions, Burn, Intangible

**Files:**
- Modify: `battle_scene/relic_effect_system.gd` (turn-start/victory actions → `effect_registry.execute` with relic source, `pace = false`), `battle_scene/equipment_set_system.gd` (start-turn/battle actions), `battle_scene/battle_scene.gd` (`_on_turn_ended`: intangible decrement per spec §7), `battle_scene/status_effect_system.gd` (`intangible` replaces `dodge` in colors/labels/descriptions), `battle_scene/data_validator.gd`, `battle_scene/card_info/player/smoke_step.json`, `battle_scene/card_info/enemy/chrome_hound.json`, `assets/translations/ui_combat.csv`, `assets/translations/content_cards.csv`, `battle_scene/assets/images/ui/status/dodge.png` → `intangible.png` (`git mv` with `.import`), `docs/PRD.md` status table
- Test: extend `tests/combat_pipeline_contract_test.gd`

- [ ] **Step 1: Failing tests**: Burn 6 on an intangible enemy deals 1 through `damage_router`; player Intangible 1 survives the end of the player turn and is gone after the enemy turn ends; enemy Intangible 1 is gone after the player turn ends; relic `player_turn_start gain_block 5` with Frail → +5 Block; validator rejects status `dodge`.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement**; translation keys `UI_COMBAT_STATUS_INTANGIBLE` (Intangible / 无实体), `_DESC` ("Each hit deals at most 1 damage. Lasts until the end of the opponent's turn; loses 1 stack then." / "每段伤害最多 1 点。持续到对手回合结束，届时减 1 层。"), `UI_COMBAT_SHORT_INTANGIBLE`; `CARD_smoke_step_DESC` "Gain [b]1 Intangible[/b]. Exhaust." / "获得 [b]1 层无实体[/b]。消耗。"; remove `UI_COMBAT_DODGE*` rows.
- [ ] **Step 4: Run** full → exit 0.
- [ ] **Step 5: Commit** `feat(combat): replace Dodge with turn-based Intangible and route relic/set actions through the registry`.

### Task 5: Enemy actions and intent through the pipeline

**Files:**
- Modify: `battle_scene/combat/combat_effects.gd` (enemy handlers, context "enemy"; `static func preview_enemy_attack(services, enemy, action) -> int`), `battle_scene/enemy_ai.gd` (`_execute_action` → interrupt check + `registry.execute`; `execute_enemy_turn` awaits), `battle_scene/enemy_entity.gd` (`intent_attack_damage(action) -> int` replaces `_compute_display_attack`; drop multiplier helpers), `battle_scene/battle_scene.gd` (remove `modify_player_attack_damage` / `modify_enemy_attack_damage`), `tests/enemy_intent_parity_test.gd`, `tests/expected_failures.txt`

- [ ] **Step 1: Rewrite** `enemy_intent_parity_test` to compare `enemy.intent_attack_damage(action)` with damage actually passed to the player by `enemy_ai.execute_action(enemy, action)` (public), adding `signal_jammer` (once-per-combat, checked on a second attack too) and player `intangible` dimensions.
- [ ] **Step 2: Run** `-Only enemy_intent*` → FAIL.
- [ ] **Step 3: Implement** (attack_status rider applies through `commands.apply_status` after the hit, regardless of block, as now).
- [ ] **Step 4: Remove** the intent line from `expected_failures.txt` (file keeps its header comment); full run → exit 0 with `xfail=0`.
- [ ] **Step 5: Commit** `fix(combat): compute enemy intents with the shared damage pipeline`.

### Task 6: Top-level action queue

**Files:**
- Create: `core/combat/action_queue.gd`, `tests/action_queue_contract_test.gd` + `.tscn`
- Modify: `battle_scene/battle_scene.gd` (`play_spell` validates/spends then enqueues; tools enqueue; End Turn enqueues; `_victory`/`_game_over` call `action_queue.clear_pending()`), `battle_scene/enemy_ai.gd`

**Interfaces:**
- `action_queue.gd`: `enqueue(label: String, action: Callable)`, `is_busy() -> bool`, `clear_pending()`, `signal drained`; executes one at a time with `await action.call()`.

- [ ] **Step 1: Failing test** (real `battle_scene.tscn`, isolated): drop two zero-cost attacks back to back → resolution log order matches enqueue order and the second starts only after the first's damage; End Turn pressed with a card queued → enemy turn starts after that card resolved; `clear_pending()` after victory leaves queued actions unexecuted.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement**; reject play input when not player turn or an end-turn is queued.
- [ ] **Step 4: Run** full → exit 0 (tool_use_confirm and ui hud tests unchanged).
- [ ] **Step 5: Commit** `feat(combat): serialize card plays, tools and end turn through an action queue`.

### Task 7: Card text from the pipeline, docs, cleanup

**Files:**
- Modify: `battle_scene/play_card.gd` (`deal_damage`/`deal_damage_all`/`gain_block` numbers from `combat_effects.preview_effect_value(services, card_data, effect) -> int` when a battle is running; current formula otherwise), `docs/conventions/gameplay-code.md` (rule 6 → registry + validator), `docs/PRD.md` (combat rules: props, stages, Intangible), `docs/reviews/…/10-roadmap.md` is untracked in main — add the wounds/assassin and queue notes to `docs/superpowers/specs/2026-10-23-phase1-combat-pipeline-design.md` follow-up section instead
- Test: extend `combat_hooks_contract_test` (card text number for Shoot with STR 3 and Weak == preview against a target without modifiers)

- [ ] **Step 1–4:** failing assertion → implement → full run exit 0.
- [ ] **Step 5: Commit** `refactor(cards): show card numbers from the shared pipeline` and `docs: describe the phase 1 combat rules`.

### Task 8: Whole-branch verification and review

- [ ] Full `tools/run_tests.ps1` exit 0, `xfail=0`; real profile untouched (`%APPDATA%\Godot\app_userdata\CardFramework` mtime unchanged).
- [ ] Merge simulation onto phase 0 head in `%TEMP%` (clean clone, import, full run).
- [ ] Independent review agent over `17d4e6c..HEAD`; fix findings with RED→GREEN; record rulings in the ledger.

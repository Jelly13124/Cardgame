# Phase 3 Listener Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Statuses, relics, equipment sets, ascension and bounties are listeners on the combat/run state; the core broadcasts phases and never names content.

**Architecture:** `core/listeners/listener.gd` base; `combat_hooks.gd` gains value hooks, phase reactions and a listener provider; status definitions in `content/statuses/` with per-creature listener instances; `data_relic.gd` instances per held relic; ascension levels in `content/ascension/`; bounty tracker as a run listener.

**Tech Stack:** Godot 4.6.3 GDScript, `tools/run_tests.ps1`.

**Spec:** `docs/superpowers/specs/2026-10-24-phase3-listeners-design.md`

## Global Constraints

- Gameplay unchanged: every number, trigger, order and preview result stays as on main.
- `core/` has no scene tree access except through the objects passed in (creatures, battle services); no new `class_name`; preload by uid with path comment; `addons/` untouched.
- Runtime status keys = `MODEL_ID.key_entry(status id)` (base: bare names).
- Listener order: rules → statuses (player first, then enemies; per creature in application order) → relics (RunManager.relics order) → equipment sets → ascension.

## Review Focus

- Crit preview semantics: a forced crit (relic first attack, Deadeye) shows once per preview play, never a random crit; real hits spend once.
- Reaction order changes (thorns before relic heal; set status after relic status) would change outcomes; the provider order must match the old list.
- Status listener lifetime: stacks spent to 0 mid-dispatch, re-applied, or applied to a dying enemy.
- A relic with `once_per_combat` must still be spent only by the real calculation, and reset each combat.
- Bounty progress must still count each event exactly once (no double count from both the old call and the new emitter).

---

### Task 1: Listener base, hook values, provider

**Files:** Create `core/listeners/listener.gd`, `core/combat/hook_value.gd`; Modify `core/combat/combat_hooks.gd`; Test `tests/listener_hooks_contract_test.gd` + `.tscn`.

**Produces:** `LISTENER` base (`owner`, `hooks`, `id`, `commands()`, `alive(c)`, `stacks(c, status)`); `HOOK_VALUE.make(value, fields: Dictionary)` → object with `value` + fields as properties via `get(key)`/dictionary `ctx`; `combat_hooks.provider: Callable` (returns Array of listeners; when unset, `listeners` is used); `combat_hooks.compute(hook_name: String, calc) -> Variant` (runs `hook_name` on every listener, returns `calc.value`); `combat_hooks.query_any(hook_name: String, arg) -> bool` (true at the first listener returning true; stops there); `combat_hooks.react(hook_name: String, ...args)` (coroutine dispatch with the existing depth guard; up to 2 args).

- [ ] Step 1 failing test: provider is read on every dispatch (add a listener between two `compute` calls → second sees it); `compute("modify_hand_draw", HOOK_VALUE.make(3, {}))` returns 5 with a +2 listener; `query_any` stops at first true (second listener not called); `react("after_turn_start", "player", 1)` passes both args; listener without the method is skipped.
- [ ] Step 2 run → FAIL. Step 3 implement. Step 4 run → PASS + full suite.
- [ ] Step 5 commit `feat(combat): listener base and generic hook dispatch`.

### Task 2: Status definitions and status listeners

**Files:** Create `content/statuses/*.json` (19), `core/listeners/statuses/*.gd` (weak, vulnerable, frail, intangible, thorns, reactive_plating, burn, regen, metallicize, feel_no_pain, covering_reload, hot_streak, all_in, deadeye, overload_protocol); Modify `core/content/model_db.gd` (category `status`), `battle_scene/status_effect_system.gd`, `core/combat/rules/crit_rules.gd`, `battle_scene/battle_scene.gd`, `battle_scene/player.gd`, `battle_scene/deck_manager.gd`, `battle_scene/data_validator.gd`; Delete `core/combat/rules/status_rules.gd`; Test `tests/status_definitions_test.gd` + `.tscn`.

- [ ] Step 1 failing test: ModelDb has 19 statuses; `DataValidator.ALLOWED_STATUS_NAMES` equals their key entries; weak def has `kind == "debuff"`, `decay == "turn_end"`; intangible `decay == "opponent_turn_end"`; adding 2 Weak to a bare test creature creates exactly one weak listener with `owner` = creature, and spending it to 0 removes it; StatusEffectSystem colour for `weak` equals the def colour.
- [ ] Step 2 run → FAIL. Step 3 implement (defs from the current constant tables verbatim; listeners reproduce `status_rules`, the crit-status parts of `crit_rules`, Metallicize from `player.start_turn`, Feel No Pain from `_trigger_exhaust_powers`, Covering Reload from `restore_attack_allowance`, burn/regen from `on_turn_start`; battle wiring broadcasts `after_turn_start`, `after_card_exhausted`, `after_reload`, `after_crit`, `after_non_crit`; crit forced/multiplier/overload through `should_force_crit`, `modify_crit_multiplier`, `can_crit_overload`). Step 4 run → PASS + full suite.
- [ ] Step 5 commit `refactor(combat): statuses are content definitions with listeners`.

### Task 3: Relic listeners

**Files:** Create `core/listeners/data_relic.gd`, `tests/fixtures/relic_mod/relics/third_attack_block.json`, `tests/fixtures/relic_mod/third_attack_block.gd`; Modify `battle_scene/relic_effect_system.gd` (builder only), `battle_scene/battle_scene.gd`, `battle_scene/combat_engine.gd`, `battle_scene/play_card.gd`, `core/combat/rules/crit_rules.gd`, `battle_scene/data_validator.gd` (`script` exists); Test `tests/relic_listener_test.gd` + `.tscn`.

- [ ] Step 1 failing test: in a real battle with the fixture relic injected and held, playing 6 attack cards grants 3 Block twice (after the 3rd and 6th); a `once_per_combat` relic effect is spent by the real hit only (preview does not spend) and resets next combat; relic listeners are built once per battle (count constructions).
- [ ] Step 2 run → FAIL. Step 3 implement (value hooks `modify_attack_limit`, `modify_attack_replays`, `modify_crit_multiplier`, `should_force_crit`, `thorns_apply_short_circuit`; reactions as in the spec). Step 4 → PASS + full suite.
- [ ] Step 5 commit `refactor(relics): relics are per-battle listener instances`.

### Task 4: Equipment-set listener

Move `battle_scene/equipment_set_system.gd` → `core/listeners/equipment_set.gd` using `before_combat_start` / `after_turn_start`; update preload sites. Test: existing set tests + full suite. Commit `refactor(sets): equipment sets are a combat listener`.

### Task 5: Ascension definitions

**Files:** Create `content/ascension/*.json` (a1_tough_enemies level 1 `hp_pct_per_level: 10`; a2_frail_start level 2 with current penalty param; a3_cold_start level 3 `energy: 1` + `cursed_drops: true`; a4 level 4 shop param; a5 level 5 elite bias), `core/listeners/ascension.gd`; Modify ModelDb category `ascension`, RunManager (`has_ascension`, `ascension_param`), the six threshold sites. Test `tests/ascension_contract_test.gd`: at asc 2 `has_ascension("base:a3_cold_start") == false`, at 3 true; enemy HP at asc 2 equals old formula; first-turn energy at asc 3 is max−1.
Commit `refactor(ascension): named ascension levels as content`.

### Task 6: Bounty tracker as a run listener

**Files:** Create `core/listeners/bounty_tracker.gd`; Modify RunManager (typed emitters + tracker registration), battle_scene, enemy_entity, card_upgrade_modal, data_validator (objectives from tracker). Test `tests/bounty_events_test.gd`: each emitter advances matching objectives once; no `bounty_event(` call remains outside RunManager.
Commit `refactor(bounty): bounty progress listens to run events`.

### Task 7: Acceptance scan and docs

Test `tests/core_names_no_content_test.gd`: `battle_scene.gd`, `combat_engine.gd`, `player.gd` contain no status key (except `bullet`) or relic entry as a string literal. Update `docs/conventions/*` (listeners, hooks, status defs, relic scripts). Full suite. Commit `docs: listener model conventions`.

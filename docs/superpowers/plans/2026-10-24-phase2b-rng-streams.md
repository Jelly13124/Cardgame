# Phase 2b Seeded RNG Streams Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every gameplay roll in a run comes from a named, seeded, saved stream (STS2 RunRngSet), and the player can see and enter the run seed.

**Architecture:** `core/rng/rng.gd` (seed + counter, one `randi()` per draw) and `core/rng/run_rng_set.gd` (named streams derived from a seed string). RunManager owns the set, saves it in the run save (v3), and exposes `rng(name)`. Gameplay call sites switch from global RNG to their stream; a source scan keeps them there.

**Tech Stack:** Godot 4.6.3 GDScript, `tools/run_tests.ps1`.

**Spec:** `docs/superpowers/specs/2026-10-24-phase2b-rng-streams-design.md`

## Global Constraints

- `core/` has no scene tree, autoloads or UI paths; no new `class_name`; preload by uid with path comment; `addons/` untouched.
- Stream names exactly: `up_front, shuffle, unknown_map_point, combat_card_generation, combat_targets, combat_crits, monster_ai, rewards, shops, events, niche`.
- Seed alphabet `0123456789ABCDEFGHJKLMNPQRSTUVWXYZ`, length 10; canonicalize = upper, `O`→`0`, `I`→`1`, trim.
- Hash = FNV-1a 32-bit over UTF-8 bytes; stream seed = `(set_seed + fnv1a32(name)) & 0xFFFFFFFF`.
- Cosmetic randomness (`card_animator.gd`, `audio_manager.gd`) and deck-entry uid generation stay on the global RNG.
- Gameplay distributions unchanged (same probabilities and pools); only the source of randomness changes.

## Review Focus

- A gameplay roll still on the global RNG (missed site, or inside an addon call such as `CardContainer.shuffle()`) breaks reproducibility silently — the scan test plus the same-seed reproducibility test must catch it.
- Loading a v2 save (no `rng` key) must keep the run going with a fresh random seed, not crash.
- Save → load → next draws equal an uninterrupted copy for every stream (counter fast-forward).
- Calls outside a run (market, forge at home base; tests) must not crash and must not touch the saved set.
- The seed field: empty = random; a typed seed with invalid characters must not start a run.

---

### Task 1: Rng and RunRngSet

**Files:** Create `core/rng/rng.gd`, `core/rng/run_rng_set.gd`; Test `tests/rng_contract_test.gd` + `.tscn`.

**Interfaces — Produces:**
- `RNG.new(seed: int, counter := 0)`; `seed`, `counter`; `next_int(max_exclusive: int) -> int`, `next_range(min: int, max_inclusive: int) -> int`, `next_float() -> float`, `next_bool() -> bool`, `chance(p: float) -> bool`, `pick(items: Array) -> Variant`, `shuffle(items: Array) -> void`, `fast_forward(target: int)`, `to_dict()`, `static from_dict(d) -> Rng`.
- `RUN_RNG_SET.new(seed_string: String)`; `seed_string`, `seed`; `STREAMS: Array[String]`; `stream(name) -> Rng` (push_error + return a throwaway Rng for unknown); `to_dict() -> {seed_string, counters}`; `static from_dict(d)`; `static random_seed_string() -> String`; `static canonicalize(s) -> String`; `static is_valid_seed(s) -> bool` (non-empty, alphabet only after canonicalize); `static fnv1a32(s) -> int`.

- [ ] **Step 1: Failing test** `rng_contract_test.gd`: two `RNG.new(42)` give equal 20-draw sequences of mixed calls; `counter` counts draws (shuffle of 5 items adds 4); `from_dict(a.to_dict())` continues identically; `fast_forward` lower than counter push_errors and leaves state; `RUN_RNG_SET.new("ABC")` vs `new("abc")` equal seeds (canonicalize); `canonicalize(" o1i ") == "011"`; `is_valid_seed("A-B") == false`; `random_seed_string()` length 10 and alphabet-only; independence: set A draws 50 from `combat_crits` then `rewards.next_int(1000)` equals set B's first `rewards.next_int(1000)`; set round-trip through `to_dict`/`from_dict` continues every stream identically; `fnv1a32("") == 2166136261`.
- [ ] **Step 2: Run** `tools/run_tests.ps1 -Only "rng_contract*"` — Expected: FAIL (missing scripts).
- [ ] **Step 3: Implement** both scripts.
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Commit** `feat(rng): add seeded Rng and RunRngSet streams`.

### Task 2: RunManager ownership, save v3, call-site migration

**Files:** Modify `run_system/core/run_manager.gd`, `core/content/save_migration.gd` (RUN_VERSION 3), `battle_scene/{battle_scene,deck_manager,relic_effect_system}.gd`, `core/combat/rules/crit_rules.gd`, `run_system/core/{affix_pool,discover_pool}.gd`, `run_system/ui/{loot_reward,map_scene,shop_scene,event_modal}.gd`, `run_system/ui/buildings/market_screen.gd`. Test `tests/run_rng_contract_test.gd` + `.tscn`.

**Interfaces — Consumes:** Task 1. **Produces:** `RunManager.run_rng` (RunRngSet or null), `RunManager.rng(name: String) -> Rng`, `RunManager.start_new_run(hero_id, starter_deck := [], asc := -1, seed_string := "")`, `RunManager.run_seed() -> String`.

Stream mapping: map gen, `_roll_node_type`, `select_encounter`, event deal, demo featured set → `up_front`; deck shuffles (via `deck_manager._shuffle_pile`) and the fallback list → `shuffle`; map "?" rolls and amounts → `unknown_map_point`; discover → `combat_card_generation`; relic random enemy → `combat_targets`; crit rolls (crit_rules, relic block crit) → `combat_crits`; loot rows, draft, equipment drops (`roll_shell_drop`, `_random_set_piece`), affix rolls, elite scrap, tool drop picks → `rewards`; shop / market stock → `shops`; event luck check → `events`; anything else gameplay → `niche`.

- [ ] **Step 1: Failing test** `run_rng_contract_test.gd`: (a) `start_new_run("base:cowboy_bill", [], 0, "TESTSEED01")` twice → identical `map_data`, identical `select_encounter("enemy", 2)` sequence of 5 calls, identical `roll_shell_drop("common")` ×3 (ignoring nothing), identical first 5 draft ids from loot's roll function; (b) `run_seed() == "TESTSEED01"`; empty seed → valid random 10-char seed; (c) save round-trip: draw from `rewards`, `shuffle`, `combat_crits`, `save_run()`, record next draws, `load_run()`, next draws equal; (d) a v2 run save fixture (no `rng`) loads, `run_seed()` is a valid seed; (e) with `is_run_active == false`, `rng("shops").next_int(10)` works and `run_rng` stays null; (f) source scan: no `randi(`, `randf(`, `randi_range(`, `randf_range(`, `.shuffle()`, `pick_random(` or `randomize(` in `.gd` under `battle_scene/`, `run_system/`, `core/` except `card_animator.gd`, `audio_manager.gd`, `core/rng/`, and lines marked `# rng-ok: <reason>`.
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** ownership, save (`"rng": run_rng.to_dict()`, `"v": 3`; load rebuilds or seeds fresh), `SAVE_MIGRATION.RUN_VERSION = 3` (migration from 1 still applies ID rewrite; 2→3 adds nothing), then migrate every call site per the mapping. Deck-entry uid and the meta bounty shelf keep their RNG with `# rng-ok:` markers.
- [ ] **Step 4: Run** test + full suite — Expected: PASS (update save_migration_test's version expectation to 3).
- [ ] **Step 5: Commit** `feat(rng)!: draw run randomness from seeded streams` with `BREAKING CHANGE:` (run save v3).

### Task 3: Seed UI

**Files:** Modify `run_system/ui/home_base_scene.gd` (seed `LineEdit` named `SeedField` right of the Depart button; `_on_start_pressed` passes its canonicalized text; invalid → red outline + no start), `run_system/ui/result_screen.gd` (label `SeedLabel` text `tr("UI_RESULT_SEED").format({"seed": RunManager.run_seed()})`), `assets/translations/ui_home.csv` (`UI_HOME_SEED_PLACEHOLDER` "Seed (optional)"/"种子（可选）", `UI_HOME_SEED_INVALID` "Invalid seed"/"种子无效"), `assets/translations/ui_common.csv` (`UI_RESULT_SEED` "Seed: {seed}"/"种子：{seed}"). Test `tests/seed_ui_contract_test.gd` + `.tscn`.

- [ ] **Step 1: Failing test:** home scene has `SeedField`; set text `"abc o1"`→ invalid (space) → pressing start does not start a run and field shows invalid state; text `"testseedo1"` → start begins a run with `run_seed() == "TESTSEED01"` (stop before the scene change by calling the handler that resolves the seed, `_resolve_seed_input() -> String` returning `""` for empty and `"!"`-free canonical or `null` for invalid — exact: returns `{"ok": bool, "seed": String}`); result screen instantiated after a run contains `SeedLabel` whose text contains the seed.
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** test + full suite — Expected: PASS.
- [ ] **Step 5: Commit** `feat(ui): show the run seed and accept a seed at depart`.

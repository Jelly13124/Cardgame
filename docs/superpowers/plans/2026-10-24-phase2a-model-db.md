# Phase 2a ModelDb Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** All content is read through one static ModelDb keyed by namespaced IDs, loaded from `content/<type>/`, with pools owned by the character and saves migrated.

**Architecture:** `core/content/` holds `model_id.gd`, `content_model.gd`, `model_db.gd`, `save_migration.gd` (pure, no scene tree). JSON moves to `content/`; consumers drop their own loaders and caches. Runtime state and code literals use full IDs (`base:x`); translation keys and asset paths go through `MODEL_ID.key_entry`.

**Tech Stack:** Godot 4.6.3 GDScript, scene tests run by `tools/run_tests.ps1`, Python tools.

**Spec:** `docs/superpowers/specs/2026-10-24-phase2a-model-db-design.md`

## Global Constraints

- `core/` must not use the scene tree, autoloads or UI paths.
- Preload scripts by uid with a `# res://...` path comment; no new `class_name`; `addons/` untouched.
- New scenes get uids via `tools/assign_scene_uids.gd`; run `python tools/godot_refs.py check`.
- Base translation keys and asset paths are unchanged (`key_entry("base:x") == "x"`).
- Gameplay unchanged: same offers, same numbers, same encounter tables.
- Every Godot run isolates APPDATA (use `tools/run_tests.ps1`).

## Review Focus

- A bare literal left in code (`relics.has("crit_clip")`) compares unequal to a full ID and silently disables a rule — content_integrity_test's bare-literal scan must catch it.
- An old v1 save with a deck, backpack instances and relics loads, keeps every item, and the backup file is written once.
- Translation keys built from IDs (`"RELIC_%s_NAME" % id.to_upper()`) still find base text — any `:` in a key is a bug.
- Card nodes from the factory carry the full ID in both `card_name` and `card_info.id`; upgrade/exhaust/viewer paths that read `card_info.name` are gone.
- `ModelDb.data()` returns read-only dicts; a consumer that mutated the old cached dict now errors — every mutating consumer must use `mutable()`.

---

### Task 1: ModelId, ContentModel, ModelDb core

**Files:**
- Create: `core/content/model_id.gd`, `core/content/content_model.gd`, `core/content/model_db.gd`
- Create: `tests/fixtures/content_mod/cards/zap.json`, `tests/fixtures/content_mod/relics/reload.json`, `tests/fixtures/content_mod/card_pools/modpool.json`
- Test: `tests/model_db_test.gd` + `.tscn`

**Interfaces:**
- Produces: `MODEL_ID.make(ns, entry)`, `namespace_of(id)`, `entry_of(id)`, `is_full(id)`, `key_entry(id)`.
- Produces: `MODEL_DB.ensure_loaded()`, `get_model(cat, id)`, `data(cat, id)`, `mutable(cat, id)`, `ids(cat)`, `models(cat)`, `has(cat, id)`, `resolve(cat, ref, ctx := "base")`, `inject_dir(path, ns)`, `inject(cat, ns, entry, data)`, `remove(cat, id)`, `reset()`, `load_errors()`, `CATEGORY_DIRS` (category → dir name per spec table), `CONTENT_ROOT := "res://content/"`.
- Produces: content_model fields `id, category, namespace, entry, data`, `to_mutable()`.

- [ ] **Step 1: Write failing tests** in `tests/model_db_test.gd` (pattern of `intangible_contract_test.gd`):
  - `key_entry("base:reload") == "reload"`, `key_entry("mymod:zap") == "mymod_zap"`, `entry_of("base:reload") == "reload"`, `is_full("reload") == false`.
  - After `reset()` + `inject_dir("res://tests/fixtures/content_mod/", "mymod")`: `has("card", "mymod:zap")`; fixture relic `mymod:reload` exists while `resolve("card", "reload")` returns `"base:reload"` (same entry, two categories).
  - `resolve("card", "zap", "mymod") == "mymod:zap"`; `resolve("card", "zap") == ""` (base context, no fallback into mods); `resolve("card", "nope") == ""`.
  - Fixture card's effect `{"type":"add_card_to_hand","card":"reload"}` is stored as `"base:reload"` (ref normalized at load).
  - `data("card","mymod:zap").is_read_only()` and nested `effects[0]` read-only; `mutable()` copy is writable and editing it leaves `data()` unchanged.
  - `remove("card","mymod:zap")` then `has` false; `reset()` drops mymod content.
  - A fixture with a bad ref (`"card": "missing_card"` in the modpool) adds one entry to `load_errors()`.
- [ ] **Step 2: Run** `tools/run_tests.ps1 -Only "model_db*"` — Expected: FAIL (scripts missing).
- [ ] **Step 3: Implement** the three scripts. Loader reads `<root>/<dir>/*.json`, entry = file basename, checks local `id` equals entry (error otherwise), sets `data.id` to the full ID, normalizes references by the spec's reference table, makes data deep read-only. Ref normalization of injected dirs resolves after the whole dir is registered (two passes) so intra-mod refs work. Base load is lazy in `ensure_loaded()`.
- [ ] **Step 4: Run** the test — Expected: PASS. Note: base content does not exist under `content/` yet; tests that need `base:reload` call `inject(...)` for it in this task.
- [ ] **Step 5: Commit** `feat(content): add ModelDb registry with namespaced ids`.

### Task 2: Move content, pools, switch every consumer to ModelDb and full IDs

**Files:**
- Move: the ten content dirs per the spec table to `content/` (`git mv`); delete emptied dirs.
- Create: `content/card_pools/cowboy.json`, `content/relic_pools/cowboy.json`; modify `content/characters/cowboy_bill.json` (`card_pool`, `relic_pool`).
- Modify: every card JSON `name` → `id`.
- Modify consumers: `battle_scene/{cached_card_factory,play_card,enemy_entity,discover_modal,deck_manager,battle_ui_manager,battle_scene,data_validator,enemy_ai,equipment_set_system,status_effect_system}.gd`, `battle_scene/combat/combat_effects.gd`, `core/effects/run_effects.gd`, `run_system/core/{run_manager,meta_progress,discover_pool,deck_manager?}.gd`, `run_system/ui/**` files listed by `grep -rn "card_info/\|run_system/data/"` and by the key-format grep `"[A-Z_]*%s[A-Z_]*" *%`.
- Modify tests that read content dirs (10 files listed by the same grep under `tests/`).
- Test: `tests/content_integrity_test.gd` + `.tscn`

**Interfaces:**
- Consumes: Task 1 API.
- Produces: `RunManager.current_card_pool() -> Array[String]`, `RunManager.current_relic_pool() -> Array[String]` (full IDs from the current character's pools); all runtime ID state full.

- [ ] **Step 1: Write failing** `tests/content_integrity_test.gd`:
  - `MODEL_DB.load_errors().is_empty()`; `ids("card").size() == 45`, `ids("monster").size() == 20`, `ids("relic").size() == 30`, `ids("event").size() == 12`, `ids("tool").size() == 11`.
  - `has("event","base:adrenaline_shot") and has("tool","base:adrenaline_shot")`.
  - Every card ID is in some card_pool's `cards`; every relic in some relic_pool.
  - `data("character","base:cowboy_bill").starter_deck` all start with `base:`.
  - Source scan over `res://` `.gd` files (skip `addons/`, `tests/fixtures/`): every literal matching `"base:[a-z0-9_]+"` resolves in some category; no file outside `core/content/` contains `res://content/`; no file contains `card_info/` or `run_system/data/`.
  - Bare-literal scan: a string literal equal to the entry of a registered card, relic, equipment, equipment_set, event, tool, bounty, character or monster, used as an argument of `has(`, `==`, `!=`, ` in `, `erase(`, `append(`, `get(` or as an element of a `const` array/dict, fails — except an allowlist kept in the test for status/rule keys that share a name with content (fill it from the first failing run, each entry with a one-line reason).
  - Factory: `card_factory.create_card("base:reload", null)` returns a card whose `card_name` and `card_info.id` are `"base:reload"`; title resolves via `CARD_reload_TITLE`.
- [ ] **Step 2: Run** — Expected: FAIL (no `content/` yet).
- [ ] **Step 3: Move data** with `git mv`, rename card `name`→`id` (script), add pools and character pool refs; update `generate_cards.sh` output dir.
- [ ] **Step 4: Switch readers.** Replace each dir loop/cache with `MODEL_DB.data/mutable/ids`; mutating consumers use `mutable`. Delete `_card_info_cache`, relic/tool/equipment caches, `*_DATA_DIR`, `ENEMY_DATA_DIR`, `CARD_DIR` constants. Offers (loot draft, discover, shop, market, relic reward) take candidates from `current_card_pool()`/`current_relic_pool()`.
- [ ] **Step 5: Full IDs.** Rewrite content literals in code to `base:` form (script over the 72 known IDs, then hand-review each hit; status names such as `hot_streak` stay). Card `info.get("name")` reads become `info.get("id")`. Every key/path format site wraps the ID: `"CARD_%s_TITLE" % MODEL_ID.key_entry(card_id)`.
- [ ] **Step 6: Run** content_integrity_test, then the full suite `tools/run_tests.ps1` — Expected: all PASS (expected failures unchanged). Read the full log of any failure.
- [ ] **Step 7: Commit** `refactor(content)!: load content through ModelDb with namespaced ids` with a `BREAKING CHANGE:` footer (content paths and save IDs).

### Task 3: Save migration

**Files:**
- Create: `core/content/save_migration.gd`
- Modify: `run_system/core/run_manager.gd` (`save_run` writes `"v": 2`; load migrates), `run_system/core/meta_progress.gd` (`content_v`; load migrates)
- Test: `tests/save_migration_test.gd` + `.tscn`, fixtures `tests/fixtures/saves/run_v1.json`, `tests/fixtures/saves/meta_v1.json`

**Interfaces:**
- Produces: `SAVE_MIGRATION.migrate_run(d: Dictionary) -> Dictionary`, `SAVE_MIGRATION.migrate_meta(d: Dictionary) -> Dictionary`, `SAVE_MIGRATION.RUN_VERSION := 2`, `SAVE_MIGRATION.META_CONTENT_VERSION := 2`, `SAVE_MIGRATION.backup_once(path: String) -> bool`.

- [ ] **Step 1: Write failing tests:** v1 run fixture (deck `[{uid:1,card_id:"reload"}]`, relics `["bounty_tags"]`, backpack instance `{base:"warden_axe", set_id:"warden", affixes:[...]}`, tools, encounter, seen events, hero id) migrates every field listed in the spec to `base:`; an unknown `"ghost_card"` stays `"ghost_card"`; affixes unchanged; result `v == 2`. Meta fixture: upgrades keys, stash, loadout, bounties, cards_seen keys, run_history migrated. `migrate_run` on a v2 dict is identity. `backup_once` writes `<path>.v1.bak` and a second call does not overwrite it (user:// in the isolated test dir). End-to-end: write the v1 fixture to the run save path, call `RunManager.load_run()`, check `RunManager.relics` starts with `"base:bounty_tags"` and backup exists.
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** migration (each field via `MODEL_DB.resolve(category, ref)`, keep verbatim when `""`); hook into load before parsing; `current_hero_data` re-read from ModelDb.
- [ ] **Step 4: Run** test and full suite — Expected: PASS.
- [ ] **Step 5: Commit** `feat(save): migrate v1 saves to namespaced content ids`.

### Task 4: Tools and docs

**Files:**
- Modify: `tools/gen_catalog_html.py`, `tools/check_missing_art.py`, `tools/i18n_audit.py` (if it scans content), `tools/tests/*` affected; docs listed by `grep -rln "card_info/\|run_system/data/" docs` (not `docs/superpowers/`).

- [ ] **Step 1:** Update paths and the card `id` field; run `python -m unittest discover -s tools/tests` — Expected: OK. Run `python tools/gen_catalog_html.py` to a temp output — Expected: same card/relic counts as before.
- [ ] **Step 2:** Update docs (data-files convention: content layout, namespaced IDs, `key_entry`, pools, inject for tests).
- [ ] **Step 3:** Full suite `tools/run_tests.ps1` and `python tools/godot_refs.py check` — Expected: PASS.
- [ ] **Step 4: Commit** `docs: describe content registry layout and ids`.

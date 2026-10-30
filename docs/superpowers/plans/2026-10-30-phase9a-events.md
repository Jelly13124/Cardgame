# Phase 9a Events as Models Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace JSON option lists with one GDScript `EventModel` per event: multi-page
state, `EventOption` objects, per-act decks with `is_allowed`, and run save v5 that resumes
an event without paying it out twice.

**Architecture:**
- `core/run/events/` owns the rules: model, option and pool. The map drives a lifecycle
  through four `RunManager` facade calls, and `ui/events/` renders the model and reacts to
  `state_changed`.
- Effects still run through the one run effect registry (`core/effects/run_effects.gd`).
- Content stays registered by ModelDb: each event JSON names its script.

**Tech Stack:** Godot 4.6.3 GDScript. Tests are scene tests run by `tools/run_tests.ps1`.

**Spec:** `docs/superpowers/specs/2026-10-30-phase9a-events-design.md`

## Global Constraints

- Godot binary: `C:\Users\Jerry\Tools\Godot_v4.6.3\Godot_v4.6.3-stable_win64_console.exe`.
- Run every test through `powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_tests.ps1 [-Only "<glob>"]`
  with `$env:GODOT_BIN` set. This isolates APPDATA. Never touch
  `%APPDATA%\Godot\app_userdata\CardFramework`.
- New scripts and scenes:
  - Reference them by uid (`preload("uid://…")  # res://path`).
  - Assign uids with `tools/assign_scene_uids.gd`, then run `--import`.
  - Run `python tools/godot_refs.py convert` and then `check`, and fix doubled comments with
    `sed -E 's@# (res://[^ ]+) \(\1\)@# \1@'`.
  - Run `python tools/check_layers.py`: `core/` must not depend on `ui/`.
- Each test is `tests/<name>_test.gd` plus `tests/<name>_test.tscn`, following the
  `_expect` / `failures` pattern of `tests/model_db_test.gd`.
- Content ids are full ids (`base:lucky_cog`). Text keys use
  `EVENT_<ID>_TITLE`, `EVENT_<ID>_PAGE_<PAGE>` and `EVENT_<ID>_OPT_<KEY>`, where `<ID>` is
  the uppercased entry without its namespace. Every key has en and zh in
  `assets/translations/ui_events.csv`.
- Effects and numbers of the 12 existing events do not change, except for the two multi-page
  redesigns the spec names.
- Commits:
  - Author flags: `git -c user.name=Jelly13124 -c user.email=ruizheyuan3487@gmail.com commit`.
  - Conventional subjects.
  - End every message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- No merge or push. The user playtests and decides.
- Do not touch the main checkout (`Desktop/Cardgame`), which has uncommitted art.

## Review Focus

1. **Quit right after entering a `?` node, before choosing.** The reload must reopen the same
   event, not deal a new one or lose the node. The pin is the Task 4 test
   `map_reopens_unfinished_event`.
2. **A lethal option inside an event.** If `lose_hp` kills the player mid-page, the run-loss
   flow must win: no proceed button and no save of `current_event`. The pin is the Task 5 test
   `rad_storm_lethal_dig_ends_run`.
3. **Double click on an option.** It must run once. The pin is the Task 3 test
   `option_click_runs_once`.
4. **An event script that a mod injects with a bad path.** This must be a load error, not a
   crash when the pool reaches it. The pin is the Task 1 test `missing_script_is_load_error`.
5. **An act whose deck empties early,** for example in the one-act demo. `next` must return
   null and the `?` fallback must run, with no repeat. The pin is the Task 2 test
   `empty_deck_returns_null`.

---

### Task 1: EventModel, EventOption and event registration

**Files:**
- Create:
  - `core/run/events/event_model.gd`
  - `core/run/events/event_option.gd`
- Modify:
  - `core/content/model_db.gd`, the `"event"` branch of `_normalize_refs` and `_finalize`
  - `core/content/data_validator.gd`, `validate_event`
- Test:
  - `tests/event_model_test.gd` / `.tscn`
  - `tests/fixtures/content_mod/events/probe.json` and `probe.gd`
  - `tests/model_db_test.gd`

**Interfaces:**
- Produces (`event_option.gd`, `extends RefCounted`):
  - Fields: `key: String`, `text_key: String`, `on_chosen: Callable`, `lock_reason: String`,
    `chance: float = -1.0`, `relic_id: String`, `card_id: String`,
    `will_kill_player: bool`, `is_proceed: bool`.
  - `is_locked() -> bool`: true when `on_chosen` is invalid or `lock_reason != ""`.
  - `requires(attrs: Dictionary) -> EventOption`: chainable. Reads `RunManager._attr(name)`.
    Below a threshold it sets `lock_reason` to `"<Attr> <n>"` (for example `"Charm 5"`).
- Produces (`event_model.gd`, `extends RefCounted`):
  - Fields: `id: String`, `owner` (set to `RunManager`), `rng` (`RunManager.rng("events")`),
    `dynamic_vars: Dictionary`, `page: String = "INITIAL"`, `current_options: Array`,
    `is_finished: bool`.
  - `signal state_changed`.
  - Overridable: `generate_initial_options() -> Array`, `is_allowed(run_state) -> bool`
    (returns `true`), `calculate_vars() -> void` (does nothing), `page_art(page: String) -> String`
    (returns `""`, meaning the event's own art).
  - `begin() -> void`: calls `calculate_vars()`, then `generate_initial_options()`, and sets
    `current_options`.
  - `option(key: String, on_chosen: Callable) -> EventOption`
  - `luck_option(key: String, on_success: Callable, on_fail: Callable) -> EventOption`: sets
    `chance` to `owner.luck_check_chance()`. Its callable rolls `rng.chance(chance)`.
  - `set_event_state(page: String, options: Array) -> void`
  - `set_event_finished(page: String) -> void`: one option with `is_proceed`, key `PROCEED`
    and text key `UI_EVENT_CONTINUE`.
  - `choose(index: int) -> bool`: false when out of range, locked, already choosing, or
    already finished. Otherwise it runs `on_chosen` once.
  - `apply(effects: Array) -> void`: the body of today's `RunManager.apply_event_effects`.
  - `will_kill(damage: int) -> bool`: `owner.current_health <= damage`.
  - `text_key(suffix: String) -> String`: `"EVENT_%s_%s" % [entry upper, suffix]`.
  - `format(text: String) -> String`: substitutes `{name}` from `dynamic_vars`.
- Produces (`model_db.gd`):
  - Event data gains `script_path` (an absolute `res://` path, resolved next to the JSON) and
    `acts: Array[int]` (absent means shared).
  - `static func event_script(id: String) -> Script`: the loaded script, or null.
  - A missing script, or one that does not extend `event_model.gd`, appends to
    `load_errors()`.

- [ ] **Step 1: Write the tests.**

  `tests/event_model_test.gd` uses an inline subclass built with `GDScript.new()`, or the
  fixture `probe.gd` loaded from its path. The fixture has these pages:
  - INITIAL: `GO`, which goes to page `TWO` with option `END`; and `NOPE`, which has no
    callable.
  - `END` finishes on page `DONE`.

  Assertions:
  - `begin()` gives two options, and `NOPE.is_locked()`.
  - `choose(0)`:
    - emits `state_changed` once;
    - leaves `page == "TWO"` with one option `END`.
  - `choose(0)` again (now `END`):
    - sets `is_finished`;
    - leaves the single option `is_proceed`.
  - `choose(1)` on a locked option returns false.
  - `requires({"charm": 99}).lock_reason == "Charm 99"`.
  - `requires({"charm": 0})` is unlocked.
  - Luck determinism: two models whose rng is seeded the same way pick the same branch.
  - `will_kill(owner.current_health)` is true, and `will_kill(owner.current_health - 1)` is
    false.
  - `format("take {rad}")` with `dynamic_vars = {"rad": 3}` gives `"take 3"`.

  `tests/model_db_test.gd`:
  - After `inject_dir(MOD_DIR, "mymod")`, `event_script("mymod:probe")` is a Script, and
    `data("event", "mymod:probe")["acts"] == [1]`.
  - **missing_script_is_load_error**: `inject("event", "mymod", "ghost", {"id": "ghost", "script": "ghost.gd"})`
    makes `load_errors()` contain `"ghost"`.

- [ ] **Step 2: Run the tests and confirm they fail.**

  Run `tools/run_tests.ps1 -Only "event_model*"`, then `-Only "model_db*"`.

  Expected: both fail, on a missing preload or script and on missing `acts`.

- [ ] **Step 3: Implement both classes and the registration.**

  - Resolve `script` relative to the JSON's directory. For `inject` (no file), resolve it
    relative to `res://content/events/`.
  - The validator accepts `{id, script, acts?, art?}`. A JSON that still has `options` and no
    `script` stays valid until Task 4 removes it.

- [ ] **Step 4: Run both tests, then the full suite.**

  Expected: PASS, and the full suite is still green.

- [ ] **Step 5: Commit.**

  `feat(events): EventModel, EventOption and scripted event registration`

### Task 2: EventPool, run state, the lifecycle facade and run save v5

**Files:**
- Create: `core/run/events/event_pool.gd`
- Modify:
  - `core/run/run_state.gd`
  - `core/save/run_save.gd` (`CURRENT = 5`, `_v4_to_v5`, `to_dict`/`from_dict`)
  - `core/save/content_id_migration.gd` (key name)
  - `autoload/run_manager.gd`, at `start_new_run` and `advance_act`, plus the new facade
- Test:
  - `tests/event_pool_test.gd` / `.tscn`
  - `tests/save_migration_test.gd`
  - `tests/run_rng_contract_test.gd`
  - `tests/demo_content_contract_test.gd`

**Interfaces:**
- Consumes (Task 1): `ModelDb.event_script`, data `acts`, `EventModel.is_allowed` and `begin`.
- Produces (`event_pool.gd`, static):
  - `build_deck(act_number: int, exclude: Array, rng) -> Array[String]`: events whose `acts`
    contains `act_number`, plus the shared ones, minus `exclude`, shuffled with
    `rng.shuffle`.
  - `instantiate(id: String) -> EventModel`: a fresh instance with `id`, `owner` and `rng` set.
    It returns null when the event has no script.
  - `next(run_state) -> EventModel`: walks `run_state.event_deck` in order and takes the first
    instance whose `is_allowed(run_state)` holds. That id is removed from the deck and
    appended to `seen_event_ids`. It returns null when nothing fits.
- Produces (`run_state.gd`): `event_deck: Array[String]` and `current_event: Dictionary`.
- Produces (`RunManager`), replacing `load_random_events`, `pick_random_event`,
  `option_unlocked`, `apply_event_effects`, `_random_events` and `_seen_random_event_ids`:
  - `enter_event(node_id: String) -> EventModel`: calls `next`. On a hit it sets
    `current_event = {node_id, event_id, finished: false}` and calls `save_run()`. It returns
    the model, or null.
  - `resume_event() -> EventModel`:
    - when `current_event` is empty, returns null;
    - when the event is unfinished, instantiates `current_event.event_id` and calls `begin()`;
    - when it is finished, calls `set_event_finished("RESUMED")`. The page text key is
      `UI_EVENT_RESUMED_DONE`, with en "This encounter is behind you." and zh "这件事已经过去了。".
  - `event_option_resolved() -> void`: when `current_event` is not empty and the run is
    active, sets `finished = true` and calls `save_run()`.
  - `finish_event() -> void`: clears `current_event`, calls
    `_emit_run_event("after_event_finished", event_id)` and `save_run()`.
  - `start_new_run`: after the RNG is set, `state.event_deck = EventPool.build_deck(1, [], rng("up_front"))`,
    `current_event = {}`, and `seen_event_ids` cleared.
  - `advance_act`: `event_deck = build_deck(current_act, seen_event_ids, rng("up_front"))` and
    `current_event = {}`.
- Produces (save v5):
  - Keys: `seen_event_ids`, `event_deck`, `current_event`.
  - `_v4_to_v5`:
    - renames `seen_random_event_ids` to `seen_event_ids`;
    - builds `event_deck` from a `RUN_RNG_SET.from_dict(d["rng"])` stream `up_front` (the
      loader's own default when `rng` is empty), excluding the seen ids, and writes the
      advanced `rng` back;
    - sets `current_event` to `{}`.

- [ ] **Step 1: Write the tests.**

  `tests/event_pool_test.gd` injects fixture events with `ModelDb.inject` and the probe
  script:
  - `a1` with `acts [1]`, `a23` with `acts [2, 3]`, and `shared` with no acts.
  - `picky`, whose `is_allowed` returns false. Use a fixture `picky.gd`.

  Assertions:
  - `build_deck(1, …)` contains `a1` and `shared`, and not `a23`.
  - `build_deck(3, …)` contains `a23` and `shared`.
  - The same seed gives an equal deck.
  - Excluded ids are absent.
  - `next` skips `picky`, which stays in the deck.
  - An id leaves the deck and joins `seen_event_ids`.
  - **empty_deck_returns_null**: a deck of only `picky` returns null, and a repeat call also
    returns null.

  Lifecycle assertions (real `start_new_run("base:cowboy_bill", [], 0, "EVTSEED01")`):
  - `enter_event("n1")` sets `current_event.finished == false`.
  - `event_option_resolved()` makes it true.
  - `RUN_SAVE.to_dict` → `from_dict` round-trips `event_deck` and `current_event`.
  - `finish_event()` empties `current_event`.

  `tests/save_migration_test.gd`:
  - A v4 fixture with `seen_random_event_ids: ["base:adrenaline_shot"]` migrates to
    `seen_event_ids` with the same value.
  - `event_deck` lacks `base:adrenaline_shot`.
  - Migrating the same input twice gives equal decks.
  - `current_event == {}`.
  - Update the existing assertion at line 92 to the new key.

  Rewrite the existing consumers:
  - `run_rng_contract_test` `_snapshot`: `"event": state.event_deck.duplicate()`.
  - The detour loop: `RunManager.enter_event("x")` then `finish_event()`.
  - `demo_content_contract_test._test_event_deck`: inject three probe events, then deal them
    through `enter_event` / `finish_event` three times. Expect three distinct ids and then
    null.

- [ ] **Step 2: Run the tests and confirm they fail.**

  Run `-Only "event_pool*"`, `"save_migration*"`, `"run_rng*"` and `"demo_content*"`.

  Expected: failures on the missing pool, facade and keys.

- [ ] **Step 3: Implement the pool, the state fields, v5 and the facade.**

  - Remove the six replaced RunManager members.
  - Keep `luck_check_chance`.

- [ ] **Step 4: Run the full suite.**

  Expected: green. The map still calls `pick_random_event` until Task 4, so the parse check
  must be updated in this task: change `_open_event_node` to call `enter_event`, but keep the
  old modal path by passing `model` to it. Task 4 replaces the modal itself.

  Ruling for the executor: if that interim adaptation is not small, make `_open_event_node`
  fall straight through to `_resolve_unknown_node` until Task 4.

- [ ] **Step 5: Commit.**

  `feat(events): per-act event decks, event lifecycle and run save v5`

### Task 3: Event room UI

**Files:**
- Create:
  - `ui/events/event_room.gd`
  - `ui/events/event_layout.gd`
  - `ui/events/event_option_button.gd`
- Delete: `ui/events/event_modal.gd` (and `.uid`)
- Modify: `tests/card_event_ui_contract_test.gd`
- Test: `tests/event_room_test.gd` / `.tscn`

**Interfaces:**
- Consumes: `EventModel` (Task 1); `RunManager.event_option_resolved` and `finish_event`
  (Task 2).
- Produces (`event_room.gd`, `extends Control`):
  - `var model: EventModel`, set before `_ready`.
  - `signal resolved`.
  - It moves into `event_room.gd` the full-screen fit, the art background, the vignette, the
    music swap and `_finalize` from `event_modal.gd`, keeping the node names
    `EventBackground`, `EventContent` and `EventTextVignette`.
  - The art path is `events/<page_art or art or entry>.png`.
  - On option press it calls `model.choose(i)`:
    - When the call returns true and this is the first resolved option of the room, it
      calls `RunManager.event_option_resolved()`.
    - When `is_proceed` is pressed, it calls `RunManager.finish_event()`, then
      `resolved.emit()` and `queue_free()`.
    - When `RunManager.is_run_active` is false after `choose` (run lost), it does nothing
      more. The loss flow owns the screen.
- Produces (`event_layout.gd`, `extends VBoxContainer`):
  - `bind(model)` renders the title, then `model.format(Settings.t(text_key("PAGE_" + page)))`,
    then one button per option.
  - It rebuilds on `state_changed`.
  - `signal option_pressed(index: int)`.
- Produces (`event_option_button.gd`, `extends Button`):
  - `setup(option, model)` sets the text to `model.format(Settings.t(option.text_key))`.
  - Suffixes:
    - locked: `"  [" + lock_reason + "]"`, and the button is disabled;
    - luck: `"  (" + str(roundi(chance * 100)) + "%)"`;
    - `will_kill_player`: the label colour turns red and the suffix `"  ☠"` is added.
  - A relic or card hover tip uses the existing tooltip used by the relic shelf. Find it with
    `grep -rn "tooltip" ui/common ui/map`.
  - Clicking disables every button in the layout until the next rebuild.

- [ ] **Step 1: Write the tests.**

  `tests/event_room_test.gd`:
  - Start a real run, instantiate the probe model through `EventPool.instantiate("mymod:probe")`
    after `inject_dir`, and add an `event_room` with the model.
  - Assert two buttons, the second disabled with `[`.
  - Pressing the first:
    - rebuilds to one button;
    - leaves `RunManager.state.current_event.finished == true`, after first setting
      `current_event` with `enter`-shaped data.
  - Pressing proceed emits `resolved` and empties `current_event`.
  - **option_click_runs_once**: two `pressed.emit()` calls in the same frame on `GO` leave
    `page == "TWO"`, and the probe's counter of `GO` runs equals 1.

  `card_event_ui_contract_test`: build the room from the probe model instead of
  `event_data`, and keep the three layout assertions.

- [ ] **Step 2: Run the tests and confirm they fail.**

  Run `-Only "event_room*"` and `-Only "card_event_ui*"`.

  Expected: both fail.

- [ ] **Step 3: Implement the three files and delete the modal.**

  Update `ui/map/map_scene.gd`'s preload to `event_room.gd`. The full map wiring is Task 4.

- [ ] **Step 4: Run the full suite plus the parse check and `check_layers.py`.**

  Expected: green.

- [ ] **Step 5: Commit.**

  `feat(events): event room, layout and option button replace the modal`

### Task 4: Convert the 12 events and wire the map

**Files:**
- Create: `content/events/<id>.gd` for the 12 ids.
- Modify:
  - `content/events/<id>.json`, reduced to `{id, script, acts?}`
  - `assets/translations/ui_events.csv` (key renames)
  - `core/content/data_validator.gd` (`script` required, `options` rejected)
  - `ui/map/map_scene.gd` (`_open_event_node`, `_ready`)
  - `tools/gen_catalog_html.py` (`build_events`)
- Test:
  - `tests/event_content_test.gd` / `.tscn`
  - `tests/event_room_test.gd`

**Interfaces:**
- Consumes: Tasks 1–3.
- Each script:
  - `extends "uid://<event_model uid>"`.
  - Single-page shape: an `option(...)` (with `.requires(...)` where the JSON had `requires`)
    whose callable does `apply([...])` and then `set_event_finished("<KEY>")`.
  - `luck_check` options use `luck_option(key, ok, fail)`. Each branch applies its effects and
    finishes on pages `<KEY>_OK` and `<KEY>_FAIL`.
- Option keys: an uppercase slug of the option's intent (`SHARE`, `READ`, `CUT`, …). The
  result page of a plain option is the option key itself.
- CSV renames:
  - `EVENT_<ID>_DESC` → `EVENT_<ID>_PAGE_INITIAL`
  - `EVENT_<ID>_OPT<n>_TEXT` → `EVENT_<ID>_OPT_<KEY>`
  - `EVENT_<ID>_OPT<n>_RESULT` → `EVENT_<ID>_PAGE_<KEY>`
  - `_RESULT_OK` / `_RESULT_FAIL` → `EVENT_<ID>_PAGE_<KEY>_OK` / `_FAIL`
  - Every en and zh text is moved, not rewritten. Do the rename with a script in the
    scratchpad that reads each old JSON before it is reduced.
- The `acts` field follows the spec's table:
  - shared: hooded_stranger, deserter_charm, fortune_shrine, torn_coin_pouch, buried_cache,
    cursed_safe;
  - `[1, 2]`: adrenaline_shot, stranded_trader, caravan_checkpoint;
  - `[2, 3]`: collapsed_overpass, mutant_bazaar, rad_storm.
- Map:
  - `_open_event_node(floor_idx)`: `var model := rm.enter_event(rm.current_node_id)`. If it is
    null, use `_resolve_unknown_node`. Otherwise open an `event_room` on the same
    CanvasLayer 120 with the same `resolved` handler.
  - In `_ready`, after the save checkpoint: when
    `rm.state.current_event.get("node_id") == rm.current_node_id`, open
    `rm.resume_event()` the same way.

- [ ] **Step 1: Write the tests.**

  `tests/event_content_test.gd` covers every id in `ModelDb.ids("event")`:
  - `event_script(id)` is not null.
  - For every INITIAL option index `i`, and for luck options with the rng forced to both
    branches (set `chance` to 1.0, then to 0.0, before `choose`), start a fresh run, then:
    - `instantiate`, `begin`, `choose(i)`;
    - keep choosing option 0 until `is_finished`, with a guard of 20 choices;
    - expect no errors and the event finished.
  - For every page reached and every option: `Settings.t(key, "")` is not empty in `en` and
    in `zh`. Switch the locale through the existing Settings setter.
  - Single-page parity: hooded_stranger `SHARE` heals 8 and adds 1 Charm, and stranded_trader
    `DIG` gives +40 gold. Use before/after values.

  `tests/event_room_test.gd`, **map_reopens_unfinished_event**:
  - Set `current_event = {node_id: current_node_id, event_id: "base:hooded_stranger", finished: false}`,
    instance the map scene, and expect an `EventContent` node whose page is INITIAL.
  - With `finished: true`, the room shows the single proceed button.

- [ ] **Step 2: Run the tests and confirm they fail.**

  Run `-Only "event_content*"` and `"event_room*"`.

  Expected: both fail.

- [ ] **Step 3: Write the 12 scripts, reduce the JSONs, rename the CSV keys, tighten the
  validator, wire the map and update the catalog.**

  The catalog lists `EVENT_<ID>_PAGE_*` texts in place of options.

- [ ] **Step 4: Run the full suite, `python tools/gen_catalog_html.py`, the parse check,
  `godot_refs.py check` and `check_layers.py`.**

  Expected: all clean.

- [ ] **Step 5: Commit.**

  `refactor(events): the 12 events are EventModel scripts; map resumes events`

### Task 5: Multi-page rad_storm and cursed_safe, and is_allowed

**Files:**
- Modify:
  - `content/events/rad_storm.gd`
  - `content/events/cursed_safe.gd`
  - `assets/translations/ui_events.csv`
- Test: `tests/event_content_test.gd`

**Interfaces:**
- rad_storm:
  - `dynamic_vars = {"rad": 3}`.
  - INITIAL:
    - `HUNKER`: lose 4 HP, then finish.
    - `CONVOY`: requires Charm 5; heal 6 and gain 15 gold, then finish.
    - `SPRINT`: a luck option. On failure, lose 10 HP and finish on `SPRINT_FAIL`. On
      success, gain 20 scrap and go to `BUNKER`.
  - `BUNKER` and `DEATH_WARNING` both offer:
    - `DIG`: gain 10 scrap, lose `{rad}` HP, then `rad += 2`. The next page is
      `DEATH_WARNING` when `will_kill(rad)`, otherwise `BUNKER`. `will_kill_player` is set on
      `DIG` whenever `will_kill(rad)` holds.
    - `LEAVE`: finish.
  - `is_allowed`: `owner.current_health > 4`.
  - `page_art("BUNKER")` and `page_art("DEATH_WARNING")` return `"rad_storm_bunker"`.
- cursed_safe:
  - INITIAL:
    - `CRACK` goes to `OPEN`.
    - `LEAVE` finishes.
  - OPEN:
    - `POCKET`: gain 40 gold and the `rust` curse, then finish.
    - `PRY`: a luck option. On success, gain 40 gold, 20 scrap and `rust`. On failure, gain
      40 gold, `rust` and `panic`. It finishes on `PRY_OK` or `PRY_FAIL`.
  - `is_allowed`: fewer than 2 curse cards in `owner.player_deck`. A curse is a card whose
    data `type == "curse"`; check `content/cards/rust.json` for the field.
  - `page_art("OPEN")` returns `"cursed_safe_open"`.
- Copy: write en and zh for every new page and option, in the existing voice. The user reviews
  it at playtest.

- [ ] **Step 1: Write the tests in `event_content_test.gd`.**
  - rad_storm forced to success reaches `BUNKER` with +20 scrap.
  - Three digs give +30 scrap and HP lost of 3 + 5 + 7.
  - With HP set to 9 after one dig, the page is `DEATH_WARNING` and `DIG.will_kill_player`.
  - **rad_storm_lethal_dig_ends_run**: from `DEATH_WARNING` with HP at most `rad`, `choose` on
    `DIG` leaves `RunManager.is_run_active == false`, and no save file is written afterwards
    by `event_option_resolved`.
  - `is_allowed` is false at HP 4.
  - cursed_safe `CRACK` reaches `OPEN` with no gold change.
  - `POCKET` gives +40 gold and one more `rust`.
  - `is_allowed` is false with two curses.

- [ ] **Step 2: Run `-Only "event_content*"` and confirm it fails.**

- [ ] **Step 3: Implement both scripts and the copy.**

- [ ] **Step 4: Run the full suite.**

  Expected: green.

- [ ] **Step 5: Commit.**

  `feat(events): multi-page Rad Storm and Humming Strongbox`

### Task 6: Art requests and playtest build

**Files:**
- Modify: `docs/art/codex-art-requests.md`
- Test: none (docs). Then a windowed playtest for the user.

- [ ] **Step 1: Update `docs/art/codex-art-requests.md`.** Under "Event illustrations", add:

  | File | Event / page |
  |---|---|
  | `rad_storm_bunker.png` | Rad Storm, inside the bunker: a glowing core in a dark concrete room, dust in the hatch light |
  | `cursed_safe_open.png` | Humming Strongbox, open: coins and a pulsing green core inside the box |

  Add a new section, "Event option icons": folder `ui/events/icons/`, 32×32 RGBA PNG with a
  transparent background, readable on the dark vignette. The button falls back to its text
  suffix when an icon is missing.

  | File | Meaning |
  |---|---|
  | `lock.png` | Option locked by an attribute |
  | `luck.png` | Luck check (dice) |
  | `lethal.png` | This option can kill you |

  Keep the three existing missing illustrations (adrenaline_shot, deserter_charm,
  torn_coin_pouch). Add any replacement entries the user names under a "Redo (looks wrong)"
  section with the user's reason.

- [ ] **Step 2: Commit.**

  `docs(art): event page art and option icons for Codex`

- [ ] **Step 3: Run the full suite one last time, then open the windowed playtest.**

  Use `.superpowers/playtest/` in the worktree. The user plays a `?` node, quits mid-event,
  resumes, and plays both multi-page events.

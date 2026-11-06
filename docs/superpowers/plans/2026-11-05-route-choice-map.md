# Route Choice Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the branching node map with a route of 2–3 choice cards per floor, each
printing its rewards and previewing the next floor.

**Architecture:** `core/run/map_generator.gd` stops building a whole act and instead grows
`map_data` one floor at a time from per-node derived RNG streams, pruning unchosen branches.
Rewards are rolled into each node and paid by `combat_rewards.gd`. `ui/map/map_scene.gd`
drops graph drawing for a row of `route_choice_card` scenes and a floor track.

**Tech Stack:** Godot 4.6.3, GDScript, scene tests run by `tools/run_tests.ps1`.

**Spec:** `docs/superpowers/specs/2026-11-05-route-choice-map-design.md`

## Global Constraints

- Work only in `C:\Users\Jerry\Desktop\Cardgame-map` (branch `feat/route-choice-map`). Never touch `C:\Users\Jerry\Desktop\Cardgame` or `%APPDATA%\Godot\app_userdata\CardFramework`. Do not merge or push.
- Run tests with `$env:GODOT_BIN = "C:\Users\Jerry\Tools\Godot_v4.6.3\Godot_v4.6.3-stable_win64_console.exe"; powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Only "<glob>"` from the worktree root (it isolates APPDATA).
- Edit `.gd` files with the Edit tool or Python, never PowerShell `Get-Content`/`WriteAllText` (they corrupt UTF-8).
- Preloads use `uid://` with a trailing `# res://…` comment. New `.tscn` files get uids via `"$GODOT_BIN" --headless --path . --script res://tools/assign_scene_uids.gd`; then `python tools/godot_refs.py convert --dirs <dirs>`; revert unrelated files it rewrites.
- Commits: `git -c user.name=Jelly13124 -c user.email=ruizheyuan3487@gmail.com commit`, Conventional Commit subject, body ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Floors are 0-based. Fixed floors: 0 `relic`, `guaranteed_treasure_floor` (6) `treasure`, `floors-2` (10) `rest`, `floors-1` (11) `boss`; each holds one card. Other floors hold 2 or 3 cards.
- Node shape: `{id, floor, slot, type, children: Array[String], rewards: Dictionary}`. Child id = `"%s.%d" % [parent_id, index]`; the floor-0 id is `"f0"`.
- Child stream: `run_rng.derived("map_act_%d_%s" % [act_number, parent_id])`. Rewards stream: `run_rng.derived("map_act_%d_%s_rewards" % [act_number, node_id])`.
- Rewards: `enemy` → `{caps: RunManager.CAPS_PER_COMBAT}`; `elite` → `{caps: RunManager.CAPS_PER_ELITE, scrap: rng.next_range(lo, hi)}` with `[lo, hi]` = `loot_economy.elite_scrap` (default `[8, 16]`); other types → `{}`.
- On one floor at most one each of `merchant`, `rest`, `unknown`, `treasure`; `enemy` and `elite` may repeat. A repeat re-rolls (max 8 tries per card); if the floor would hold fewer than 2 cards, it adds `enemy`.
- XP is never printed on a card. Treasure prints "relic choice". Rest prints the heal from `ROOMS.rest_heal_amount`.

## Review Focus

1. An old (v6) save whose current node sits in the old full graph: after pruning, a grandchild whose children were removed must get fresh children, not dangling ids — Task 4 test `old graph walks to the boss`.
2. Pressing `1` then `2` quickly (or double-clicking) must enter one room only — Task 6 test `a second choice while one is pending is ignored`.
3. A save made inside an event on the new map must still reopen the event — Task 6 keeps `tests/event_room_test.gd` green.
4. Act 2+ in the full config: `advance_act` regenerates a fresh route whose cards differ from act 1's — Task 2 test `act 2 route differs from act 1`.
5. Peek mode over a battle must not travel — Task 6 test `peek cards ignore input`.

---

### Task 1: Route generator

**Files:**
- Rewrite: `core/run/map_generator.gd` (keep `_pick_node_type` logic for the per-floor table roll; delete the slot/edge/orphan helpers)
- Create: `tests/route_map_generator_test.gd`, `tests/route_map_generator_test.tscn`

**Interfaces:**
- Produces:
  - `static func start(act: Dictionary, act_number: int, run_rng, elite_bias_floor := 0.0) -> Array` — floor-0 node, its children, and their children.
  - `static func grow(map_data: Array, entered_id: String, act: Dictionary, act_number: int, run_rng, elite_bias_floor := 0.0) -> Array` — returns the new `map_data`: for each child `c` of the entered node, if `c.children` is empty or names an id not in `map_data`, roll fresh children for `c` (unless `c` is on the top floor); then keep only the walked path (the entered node and its ancestors, i.e. ids that are prefixes of it), the entered node's children, and their children.
  - `static func node_rewards(type: String, rng) -> Dictionary`.
  - `static func roll_children(parent: Dictionary, map_data: Array, act: Dictionary, act_number: int, run_rng, elite_bias_floor: float) -> Array` — the parent's new child nodes with `rewards` filled (also sets `parent.children`). Extra-treasure cap counts treasures off the guaranteed floor among the parent and its ancestors.

- [ ] **Step 1: Write the failing test** (`tests/route_map_generator_test.gd`, same `_expect`/`failures`/`quit` shape as `tests/combat_rewards_route_test.gd`). Use `RUN_RNG_SET.new("ROUTEMAP01")` and `ACTS.act(1)`. Assertions:
  - `start(...)`: floor 0 is one node `{id: "f0", type: "relic"}`; floor-1 nodes are its children; every floor-1 node has 1–3 children on floor 2.
  - Walking 200 random routes (pick a random child each step via `grow`) from `start` to floor 11: floors 6, 10, 11 always hold exactly one choice of type `treasure`, `rest`, `boss`; every other floor's choice set has 2–3 nodes; no choice set repeats `merchant`, `rest`, `unknown` or `treasure`; no `merchant`, `rest` or `elite` on floors 1–4.
  - `start` twice with the same seed, then the same `grow` sequence: identical `[id, type, children, rewards]` lists.
  - Preview is binding: before `grow(map, c.id, …)`, record `c.children` ids and their types; after it, the children of `c` have the same ids and types.
  - After `grow`, no node remains whose id is neither a prefix of the entered id, a child of it, nor a grandchild of it; ids are unique.
  - Rewards: every `enemy` has `{caps: 6}`; every `elite` has `caps == 18` and `8 <= scrap <= 16`; other types have `{}`.
  - Elite bias: with `elite_bias_floor = 0.99`, every rolled choice on floors 5–9 is `elite`.
  - `act 2 route differs from act 1`: `start(ACTS.act(2), 2, …)` children types or ids-with-rewards differ from act 1's for the same seed (compare the flattened `[type, rewards]` lists of floors 1–2).

- [ ] **Step 2: Run it** — `-Only "route_map_generator*"`. Expected: FAIL (`start` not found).

- [ ] **Step 3: Implement** the four functions above in `core/run/map_generator.gd`. Card count on rolled floors: `rng.next_range(2, 3)`. `slot` = index within the parent's children. Update the file header comment to describe the route.

- [ ] **Step 4: Run it** — Expected: `[OK]`, exit 0.

- [ ] **Step 5: Commit** — `feat(map): route generator grows one floor at a time`.

### Task 2: Run wiring and goldens

**Files:**
- Modify: `autoload/run_manager.gd` (`generate_map`, new `enter_map_node`)
- Modify: `tests/run_structure_golden_test.gd`, `tests/fixtures/run_structure_golden.json`, `tests/fixtures/run_structure_golden2.json`
- Create: `tests/route_map_run_test.gd`, `.tscn`

**Interfaces:**
- Consumes: Task 1 `start`, `grow`.
- Produces: `RunManager.enter_map_node(node_id: String) -> Dictionary` — `MAP_TRAVEL.enter`; on `{ok: true}` replaces `map_data` with `grow(...)` and calls `_reindex_map()`; returns the travel result. `generate_map()` now calls `start(ACTS.act(current_act), current_act, run_rng, elite_bias)` (fall back to `rng_for_act_map` behaviour only through `run_rng` being set; when `run_rng == null` use `RUN_RNG_SET.new(RUN_RNG_SET.random_seed_string())`).

- [ ] **Step 1: Write the failing test** `tests/route_map_run_test.gd`: `start_new_run("base:cowboy_bill", [], 0, "ROUTERUN01")`, `generate_map()`; walk to the boss by always entering the first child through `RunManager.enter_map_node`; assert each call returns `{ok: true}`, `current_floor` ends at 11, `map_data.size() <= 1 + 11 + 3 + 9` at every step, and `enter_map_node` of a pruned sibling id returns `ok == false`. Save/reload: after entering floor 3, `save_run()`, record `map_data`, load it back with `RunManager.load_run()` (returns `true`), assert `map_data` equal and the current node's children unchanged.

- [ ] **Step 2: Run it** — Expected: FAIL (`enter_map_node` missing).

- [ ] **Step 3: Implement** `enter_map_node` and the `generate_map` change. Remove `_map_rng` if nothing else reads it.

- [ ] **Step 4: Goldens.** In `tests/run_structure_golden_test.gd` delete the `"map unchanged"` check and the `a5_map` check (the encounter, HP and damage checks stay). Delete the `"map"` key from every act entry of `run_structure_golden.json` and `a5_map` from `run_structure_golden2.json` with a short Python script. The rules those checks guarded (fixed floors, merchant floors, A5 elite bias, treasure cap) are asserted in Task 1.

- [ ] **Step 5: Run** `-Only "route_map_*"` then `-Only "run_structure_golden*"` — Expected: both `[OK]`.

- [ ] **Step 6: Commit** — `feat(map): the run enters route nodes and grows the route`.

### Task 3: Printed rewards are paid

**Files:**
- Modify: `core/run/combat_rewards.gd` (`settle_victory`, header comment, line 19 stale comment)
- Modify: `ui/battle/battle_screen.gd:888`
- Modify: `core/run/rooms.gd` (new `rest_heal_amount`)
- Modify: `tests/combat_rewards_route_test.gd`

**Interfaces:**
- Produces: `static func settle_victory(node_type: String, act: int, rewards: Dictionary) -> Dictionary` — for `enemy`/`elite` pays `award_run_caps(int(rewards.get("caps", 0)))` and, for elites, `add_scrap_to_backpack(int(rewards.get("scrap", 0)))`; boss path unchanged (still `award_caps_for_combat("boss")`). `static func rest_heal_amount(max_health: int) -> int` in `core/run/rooms.gd` returning `int(max_health * 0.25)`.

- [ ] **Step 1: Write the failing test.** In `tests/combat_rewards_route_test.gd`, replace the 8–16 range check: `settle_victory("enemy", 1, {"caps": 6})` raises run caps by exactly 6 and Scrap by 0; `settle_victory("elite", 1, {"caps": 18, "scrap": 11})` raises caps by 18 and Scrap by exactly 11. Add `ROOMS.rest_heal_amount(80) == 20`.
- [ ] **Step 2: Run** `-Only "combat_rewards_route*"` — Expected: FAIL (argument count).
- [ ] **Step 3: Implement.** `battle_screen.gd` passes `RunManager.get_node_by_id(RunManager.current_node_id).get("rewards", {})`. Replace the comment "A card draft per level gained (the loot screen consumes them)" with "XP; each level gained queues an attribute pick (the loot screen consumes them)". Both heal sites in `ui/map/map_scene.gd` call `ROOMS.rest_heal_amount(rm.max_health)`.
- [ ] **Step 4: Run** `-Only "combat_rewards_route*"` — Expected: `[OK]`.
- [ ] **Step 5: Commit** — `feat(map): fights pay the rewards printed on their node`.

### Task 4: Save migration v6 → v7

**Files:**
- Modify: `core/save/run_save.gd` (`CURRENT := 7`, `.add(6, _v6_to_v7)`)
- Create: `tests/route_map_save_test.gd`, `.tscn`

**Interfaces:**
- Consumes: Task 1 `node_rewards`, `grow`; Task 2 `enter_map_node`.
- Produces: `static func _v6_to_v7(d: Dictionary) -> Dictionary` — builds `RUN_RNG_SET.new(str(d.rng.seed_string))` (random seed when missing) and gives every `map_data` node lacking `rewards` `MAP_GENERATOR.node_rewards(type, rng_set.derived("map_act_%d_%s_rewards" % [current_act, id]))`.

- [ ] **Step 1: Write the failing test** `tests/route_map_save_test.gd`: build a v6 save dict by running a run with seed `"OLDMAP0001"`, generating an old-shape map by hand (a 12-floor graph with ids `f<floor>_s<slot>`, two nodes per floor, each linked to both nodes of the next, floor 0 and 11 single, types as the spec's fixed floors plus `enemy`/`elite` elsewhere, no `rewards`), `current_node_id = "f3_s0"`, `schema_version = 6`. Migrate with `RUN_SAVE.migrate(d)`, apply with `RUN_SAVE.apply(RunManager.state, migrated)` and `RunManager._reindex_map()`, then assert: every node has `rewards`; `enemy` nodes have `{caps: 6}`; then `old graph walks to the boss`: repeatedly `enter_map_node` on the current node's first child until floor 11, each returning `ok == true`.
- [ ] **Step 2: Run** `-Only "route_map_save*"` — Expected: FAIL (nodes lack `rewards`).
- [ ] **Step 3: Implement** `_v6_to_v7` and bump `CURRENT`.
- [ ] **Step 4: Run** `-Only "route_map_*"` and `-Only "*save*"` — Expected: all `[OK]`.
- [ ] **Step 5: Commit** — `feat(save): run save v7 gives old map nodes their rewards`.

### Task 5: Route choice card

**Files:**
- Create: `ui/map/route_choice_card.gd`, `ui/map/route_choice_card.tscn`
- Modify: `assets/translations/ui_map.csv`
- Create: `tests/route_choice_card_test.gd`, `.tscn`

**Interfaces:**
- Produces: `extends Control`; `signal chosen(node_id: String)`; `func setup(node: Dictionary, next_types: Array, heal_amount: int, interactive: bool) -> void`; card size `Vector2(300, 420)`. Children named `TypeIcon` (TextureRect), `TypeName` (Label), `Rewards` (VBoxContainer, one HBox row per reward), `NextRow` (HBoxContainer of TextureRects, one per next type).
- New translation keys (en, zh): `UI_ROUTE_CARD_DRAFT` (Card draft, 选卡), `UI_ROUTE_RELIC_CHOICE` (Choose 1 of 3 relics, 遗物三选一), `UI_ROUTE_HEAL` (Heal {n}, 回复 {n}), `UI_ROUTE_NEXT` (Next, 下一层). Type names reuse `UI_MAP_LEGEND_<TYPE>`.
- Icons: node icons `res://run_system/assets/images/map/nodes/<type>.png`; caps `res://run_system/assets/images/home/currency/caps.png`; Scrap `…/currency/scrap.png`.

- [ ] **Step 1: Write the failing test**: instantiate the card; `setup({id: "f0.1", type: "elite", rewards: {caps: 18, scrap: 11}}, ["rest", "enemy"], 20, true)`; assert `TypeName.text == tr("UI_MAP_LEGEND_ELITE")`, `Rewards` has 3 rows whose text contains `"18"`, `"11"` and `tr("UI_ROUTE_CARD_DRAFT")`, `NextRow.get_child_count() == 2`. `setup` of a `rest` node with heal 20 shows one row containing `"20"`; `unknown` and `merchant` show 0 rows; `treasure` shows one row `tr("UI_ROUTE_RELIC_CHOICE")`. A simulated left click emits `chosen("f0.1")` once; with `interactive = false` it emits nothing.
- [ ] **Step 2: Run** `-Only "route_choice_card*"` — Expected: FAIL (scene missing).
- [ ] **Step 3: Implement** the card: dark panel with the wasteland theme (`ui/common/theme/wasteland_theme.gd`), icon 96 px, rows of 32 px icon + label, a divider, `UI_ROUTE_NEXT` label and 28 px icons. Hover: scale 1.05 and outline via the theme accent; no hover when not interactive. Assign uids and convert preloads.
- [ ] **Step 4: Run** — Expected: `[OK]`.
- [ ] **Step 5: Commit** — `feat(map): route choice card`.

### Task 6: Map scene shows the route

**Files:**
- Modify: `ui/map/map_scene.gd`, `ui/map/map_scene.tscn` if it holds graph nodes
- Delete: `ui/map/map_renderer.gd`, `ui/map/map_renderer.gd.uid`
- Create: `tests/map_route_scene_test.gd`, `.tscn`

**Interfaces:**
- Consumes: Task 2 `enter_map_node`, Task 3 `ROOMS.rest_heal_amount`, Task 5 card.
- Produces: `map_scene` children `FloorTrack` (HBoxContainer of 12 pips) and `ChoiceRow` (HBoxContainer of cards). `func _choose(node_id: String) -> void` replaces `_on_node_clicked`'s travel call with `rm.enter_map_node(node_id)` and keeps the existing `_node_click_pending` guard and room `match`.

- [ ] **Step 1: Write the failing test** `tests/map_route_scene_test.gd`: start a run (seed `"ROUTEUI001"`), instantiate the map scene, wait two frames; assert `ChoiceRow.get_child_count()` equals the current choices (1 on a fresh run: the relic card); set the run to a floor-2 node via `enter_map_node`, re-instantiate, assert the count equals that node's children count and each card's `NextRow` count equals its node's children count; `FloorTrack.get_child_count() == 12`. `a second choice while one is pending is ignored`: call `_choose` on two different cards in the same frame; only the first changes `current_node_id`. `peek cards ignore input`: with `peek_mode = true` set before adding to the tree, `_choose` leaves `current_node_id` unchanged.
- [ ] **Step 2: Run** `-Only "map_route_scene*"` — Expected: FAIL.
- [ ] **Step 3: Implement.** Delete `MAP_RENDERER_SCRIPT`, `_renderer`, `_node_positions`, scroll/drag fields, `_compute_positions`, `_get_max_floor`, `_get_max_slot`, `_get_total_width`, `_scroll_to_current`, `_get_screen_pos`, `_draw` graph code, `_get_node_at`, hover/drag/click handling in `_input`, and the dead `_open_rest_choice_legacy`. Keep the background drawn full-rect, the top bar, pause, `I` key, event resume, relic/rest/treasure/event paths. Build `FloorTrack` under the top bar and `ChoiceRow` centred with 48 px separation; the choices are `rm.map_data` nodes whose id is in the current node's `children` (on a fresh run, the `f0` node). Keys `1`/`2`/`3` choose the card at that index when no page or modal is open. Motion: cards tween in from 40 px below with 0.06 s stagger; on choose, the chosen card scales to 1.1 and the others fade over 0.25 s, then the room opens. Node icons load from `NODE_ICON_DIR` by type list `["relic","unknown","merchant","treasure","rest","enemy","elite","boss"]`.
- [ ] **Step 4: Run** `-Only "map_route_scene*"`, `-Only "event_room*"`, `-Only "ui_sts2_hud*"`, `-Only "card_event_ui*"` — Expected: all `[OK]`.
- [ ] **Step 5: Commit** — `feat(map): the map screen shows route choice cards`.

### Task 7: Docs and full suite

**Files:**
- Modify: `docs/PRD.md` (Core Gameplay Loop item 2), `docs/PROJECT_STRUCTURE.md` (map files)

- [ ] **Step 1:** PRD item 2 becomes: "**Route** - Each floor offers 2–3 cards showing the room, its rewards and the next floor's rooms; floors 0, 6, 10 and 11 are fixed (relic, treasure, rest, boss)". Remove `map_renderer.gd` and add `route_choice_card` in PROJECT_STRUCTURE.
- [ ] **Step 2:** Run the full suite `tools/run_tests.ps1` — Expected: exit 0.
- [ ] **Step 3: Commit** — `docs(map): describe the route choice map`.
- [ ] **Step 4:** Open a windowed playtest for the user (`APPDATA` = `<scratchpad>\playtest_appdata`, GUI Godot binary, `--path C:\Users\Jerry\Desktop\Cardgame-map`).

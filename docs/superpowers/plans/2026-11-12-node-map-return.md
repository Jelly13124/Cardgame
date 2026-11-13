# Node Map Return Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the route of choice cards with the full branching act map, keep one run currency, and draw the map as a scrollable parchment chart of octagonal nodes.

**Architecture:** The data layer (generator, travel, act tables, golden fixtures) is restored from `c508d9b`, so a move no longer changes the map. Fight rewards become a lookup by room type. Run save v9 turns route saves into act maps. The map screen gets a new presentation: a scroll view holding a path layer drawn in code and one node control per node. Room opening in `map_scene.gd` stays.

**Tech Stack:** Godot 4.6.3, GDScript, scene tests via `tools/run_tests.ps1`.

**Spec:** `docs/superpowers/specs/2026-11-12-node-map-return-design.md`

## Global Constraints

- Work only in `C:\Users\Jerry\Desktop\Cardgame-nodemap` (branch `feat/node-map`). Never touch `C:\Users\Jerry\Desktop\Cardgame`, Codex's worktrees, or `%APPDATA%\Godot\app_userdata\CardFramework`. No merge, no push.
- Tests: `$env:GODOT_BIN = "C:\Users\Jerry\Tools\Godot_v4.6.3\Godot_v4.6.3-stable_win64_console.exe"; powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Only "<glob>" -TimeoutSeconds 120`. Import once first.
- Edit `.gd` files with the Edit tool or Python, never with PowerShell content cmdlets. Preloads use `uid://` with a `# res://…` comment. New `.tscn` files go through `tools/assign_scene_uids.gd`. Test-only content ids use `test_only:`.
- Commits use `git -c user.name=Jelly13124 -c user.email=ruizheyuan3487@gmail.com commit` and Conventional subjects; the body ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Map rules come from `c508d9b` unchanged: 12 floors; floor 0 a single `relic`; middle floors 2–4 nodes (width 4, floor 1 at most 3); floor 6 all `treasure`; floor 10 all `rest`; floor 11 a single `boss`; at most 3 children per node; `early_rolls` through floor 4.
- Gold: `enemy` 8, `elite` 18, `?` fight 8, boss 45 into the backpack. Elite Scrap is rolled at settlement from `loot_economy.elite_scrap` on the `rewards` stream.
- Nodes show room type only. There is no player token; the current node gets an orange ring.

## Review Focus

1. A save made inside an event on a route map must resume that event once after migration. Task 3 test `route save inside an event resumes`.
2. Clicking two available nodes in the same frame, or one node twice, moves the player once. Task 4 test `a second choice while one resolves is ignored`.
3. Long acts must scroll so the current node is visible on open, including on the boss floor. Task 4 test `current node is in view`.
4. Peek over a battle never travels and never saves. Task 4 test `peek never travels`.
5. Act 2+ in the full config regenerates a whole map that differs from act 1. Task 1 test `act 2 map differs`.

---

### Task 1: Data layer back to the act map

**Files:**
- Restore from `c508d9b`: `core/run/map_generator.gd` (fix its header and `generate_map` comment: 2–4 nodes, merchants from floor 5), the `early_rolls` of `content/acts/act1..3.json`, the `map` keys of `tests/fixtures/run_structure_golden.json`, and `a5_map` of `tests/fixtures/run_structure_golden2.json` (with their checks in `tests/run_structure_golden_test.gd`).
- Modify: `autoload/run_manager.gd`: restore `rng_for_act_map`; `generate_map` uses `MAP_GENERATOR.generate(...)` then `_reindex_map()`; delete `_route_rng`, `enter_map_node`, `encounter_for`. Modify `core/run/encounters.gd`: delete `strength` and `_total_hp`; keep `monsters_of` only if `select` uses it. Modify `ui/map/map_scene.gd` to stay playable: `_choose` calls `MAP_TRAVEL.enter(rm.state, rm._node_index, node)`, and the fight branch calls `rm.select_encounter(node.type, node.floor)`.
- Delete: `tests/route_map_generator_test.*`, `tests/route_map_run_test.*`, `tests/encounter_strength_test.*`.
- Create: `tests/map_generator_rules_test.gd` + `.tscn`.
- Modify: `tests/fourth_act_test.gd` (walk with `MAP_TRAVEL.enter`).

**Interfaces:**
- Produces: `MapGenerator.generate(act: Dictionary, rng, elite_bias_floor := 0.0) -> Array` of `{id: "f<floor>_s<slot>", floor, slot, type, children: Array[String]}`. `RunManager.rng_for_act_map(act: int)`. `RunManager.generate_map()`.

- [ ] **Step 1: Write the failing test** `map_generator_rules_test.gd`. Over 200 seeds of `RUN_RNG_SET.new("MAPRULE%03d" % i).derived("map_act_1")` with `ACTS.act(1)`: floor 0 is one `relic`; floor 11 is one `boss`; every node on floor 6 is `treasure` and on floor 10 is `rest`; floors 1–9 hold 2–4 nodes and floor 1 at most 3; every non-boss node has 1–3 children on the next floor; every node after floor 0 is some node's child; there is no `merchant` before floor 5. With `elite_bias_floor = 0.99`, the share of `elite` on floors 5–9 is above 0.5. `act 2 map differs`: under `ACTS.active_run = "base:full"`, act 2 differs from act 1 for the same seed. Every id matches `^f\d+_s\d+$`.
- [ ] **Step 2: Run** `-Only "map_generator_rules*"`. Expected: FAIL (`generate` missing).
- [ ] **Step 3: Implement** the restores and changes in Files. Delete the three route test sets.
- [ ] **Step 4: Run** `-Only "map_*"`, `-Only "run_structure_golden*"`, `-Only "fourth_act*"`, `-Only "event_room*"`. Expected: `[OK]` for each.
- [ ] **Step 5: Commit**: `feat(map): restore the act map data layer`.

### Task 2: Gold by room type

**Files:**
- Modify: `autoload/run_manager.gd` `battle_rewards()`; `core/run/combat_rewards.gd` (the elite Scrap roll); `content/economy/loot_economy.json` (`combat_gold: 8` replaces `combat_gold_by_strength`; keep `elite_gold`, `boss_gold`, `elite_scrap`); `tests/combat_rewards_route_test.gd`.

**Interfaces:**
- Produces: `RunManager.battle_rewards() -> Dictionary` returning `{gold: combat_gold}` for `enemy` and `unknown`, `{gold: elite_gold}` for `elite`, and `{}` for `boss`, keyed on `last_battle_node_type`. `settle_victory(node_type, act, rewards)` keeps its signature but ignores `rewards.scrap`: an elite rolls Scrap itself.

- [ ] **Step 1: Failing test.** In `combat_rewards_route_test.gd`, with `last_battle_node_type` set to `enemy`, `elite`, `unknown` and `boss`, `battle_rewards()` gives `{gold: 8}`, `{gold: 18}`, `{gold: 8}` and `{}`, with no map node needed. `settle_victory("elite", 1, {})` adds 8–16 Scrap. Remove the node-reward assertions.
- [ ] **Step 2: Run** `-Only "combat_rewards_route*"`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `-Only "c*"` and `-Only "base_inventory*"`. Expected: `[OK]`.
- [ ] **Step 5: Commit**: `feat(economy): fight gold by room type`.

### Task 3: Run save v9

**Files:**
- Modify: `core/save/run_save.gd`: `CURRENT := 9`, `.add(8, _v8_to_v9)`. The v6→v7 step's node work becomes a no-op. The v7→v8 step keeps the `run_caps` → `legacy_caps` move and drops `fill_fight`.
- Rewrite: `tests/route_map_save_test.gd` → `tests/map_save_migration_test.gd`. Update `tests/save_migration_test.gd` to expect v9.

**Interfaces:**
- Consumes: `MapGenerator.generate`, `rng_for_act_map` naming (`map_act_<act>` from the save's seed).
- Produces: `static func _v8_to_v9(d: Dictionary) -> Dictionary`, following spec §3: route detection by id shape; a fresh map from `RUN_RNG_SET.new(seed).derived("map_act_%d" % act)`; the lowest-slot node on `current_floor`, or `""` when the save is at the start; `current_event` re-keyed; `shop_stock` dropped; `rewards`/`encounter`/`strength` erased from all nodes.

- [ ] **Step 1: Failing tests.**
  - A v8 dict with route ids (`f0`, `f0.1`, …), `current_floor = 3` and current `f0.1.0.2` migrates to `schema_version 9`. Its map is the act map for its seed, `current_node_id` is the lowest-slot node of floor 3, and `visited_node_ids` holds only that node.
  - `route save inside an event resumes`: the same save with `current_event = {node_id: "f0.1.0.2", event_id: "base:hooded_stranger", finished: false}` keeps the event with `node_id` set to the new current node.
  - A route save with `current_node_id ""` stays at `""`.
  - A v6-shaped graph keeps its ids and children, with no `rewards`, `encounter` or `strength` on any node.
  - Loading the migrated save through `RunManager.load_run()` lets `MAP_TRAVEL.enter` walk to the boss.
- [ ] **Step 2: Run** `-Only "map_save_migration*"`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `-Only "*save*"`. Expected: `[OK]`.
- [ ] **Step 5: Commit**: `feat(save): run save v9 turns route saves into act maps`.

### Task 4: The node map screen

**Files:**
- Create: `ui/map/node_map_view.gd` (scroll canvas, layout, path layer, legend, start flag); `ui/map/map_node_button.gd` + `.tscn` (one node: octagon, icon, state, pulse and hover, `chosen(node_id)`).
- Modify: `ui/map/map_scene.gd`: replace the floor track and card row with a `NodeMapView`; `_choose(node_id)` keeps its guards (peek, pending, page, relic modal); the choose motion is a 0.2 s pop, then the room opens after 0.3 s.
- Delete: `ui/map/route_choice_card.*`, `tests/route_choice_card_test.*`, the `UI_ROUTE_*` keys in `assets/translations/ui_map.csv`.
- Rewrite: `tests/map_route_scene_test.gd` → `tests/node_map_scene_test.gd`.

**Interfaces:**
- `NodeMapView`: `func setup(map_data: Array, current_id: String, visited: Array[String], interactive: bool) -> void`, `signal node_chosen(node_id: String)`, `func node_button(id: String) -> Control`, and `func scroll_to_node(id: String) -> void`. Layout is deterministic: x = `LEFT + floor * FLOOR_SPACING`. A floor's nodes spread evenly over the band from y 180 to the viewport bottom minus 160, plus a seeded jitter of ±18 px in both x and y from `hash(id)`.
- `MapNodeButton`: `func setup(node: Dictionary, state: String) -> void`, where state is one of `available`, `current`, `visited` and `unreachable`; `signal chosen(node_id: String)`.
  - Octagons and dashed paths are drawn in code until the art arrives; the art paths are taken from spec §5 when the files exist.
  - The node icons come from `run_system/assets/images/map/nodes/<type>.png`.

- [ ] **Step 1: Failing test** `node_map_scene_test.gd`.
  - A fresh run shows one `MapNodeButton` per `map_data` node. Exactly the floor-0 node is `available`.
  - After `MAP_TRAVEL.enter` to floor 0 and reopening, the `available` set equals the current node's children, and the current node is `current`.
  - `a second choice while one resolves is ignored`: two `_choose` calls in one frame move the player once.
  - `peek never travels`: `peek_mode` cards are not interactive, and `_choose` leaves `current_node_id` unchanged.
  - `current node is in view`: after entering a floor-9 node and reopening, the current node's global x lies inside the viewport.
  - The legend lists 8 entries.
- [ ] **Step 2: Run** `-Only "node_map_scene*"`. Expected: FAIL.
- [ ] **Step 3: Implement** to spec §4. Scrolling uses the mouse wheel and a drag on empty map, clamped at both ends. The view opens with the current node at about one third of the width.
- [ ] **Step 4: Run** `-Only "node_map_scene*"`, `-Only "event_room*"`, `-Only "ui_sts2_hud*"`, `-Only "card_event_ui*"`. Expected: `[OK]`. Then take a windowed screenshot of the map at the start and at floor 5, and look at both.
- [ ] **Step 5: Commit**: `feat(map): parchment node map screen`.

### Task 5: Docs, art brief, full suite

- [ ] **Step 1:** In `docs/PRD.md`, replace the Route line with the node map rules. Update `docs/PROJECT_STRUCTURE.md` (map files) and `docs/conventions/ui-code.md`.
- [ ] **Step 2:** Write `docs/art/node-map-art-brief.md` for GPT from spec §5. For each file give the path, size, layers, what it shows and the style anchor (the user's parchment reference, translated to our wasteland). State that no player token is drawn.
- [ ] **Step 3:** Run the full suite with `tools/run_tests.ps1`. Expected: exit 0.
- [ ] **Step 4: Commit**: `docs(map): node map docs and art brief`.

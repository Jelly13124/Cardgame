# One Run Currency and Route Encounter Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make backpack gold the only in-run currency (banked 1:1), pre-roll fight encounters onto route nodes with a strength tag and gold by strength, and widen early-floor room types.

**Architecture:** Hidden run caps are deleted from RunState/RunManager/save; settlement banks `total_gold()`. `core/run/map_generator.gd` rolls `encounter`, `strength` and `rewards.gold` per fight node; `core/run/encounters.gd` owns the strength rule; the loot screen and battle entry read the entered node. Run save v8 migrates old runs. The route card shows portraits and a tag.

**Tech Stack:** Godot 4.6.3, GDScript, scene tests via `tools/run_tests.ps1`.

**Spec:** `docs/superpowers/specs/2026-11-09-economy-route-preview-design.md`

## Global Constraints

- Work only in `C:\Users\Jerry\Desktop\Cardgame-econ` (branch `feat/economy-route-preview`). Never touch `C:\Users\Jerry\Desktop\Cardgame` or `%APPDATA%\Godot\app_userdata\CardFramework`. Do not merge or push.
- Tests: `$env:GODOT_BIN = "C:\Users\Jerry\Tools\Godot_v4.6.3\Godot_v4.6.3-stable_win64_console.exe"; powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Only "<glob>"` from the worktree root. Import once first: `& $env:GODOT_BIN --headless --path . --import`.
- Edit `.gd` with the Edit tool or Python, never PowerShell content cmdlets. Preloads use `uid://` plus `# res://…`; new `.tscn` get uids via `tools/assign_scene_uids.gd`, then `python tools/godot_refs.py convert --dirs <dirs>`, reverting unrelated rewrites.
- Commits: `git -c user.name=Jelly13124 -c user.email=ruizheyuan3487@gmail.com commit`, Conventional subject, body ends `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Economy values (`content/economy/loot_economy.json`): `combat_gold_by_strength` `{"weak": 6, "normal": 8, "strong": 11}`, `elite_gold` `18`, `boss_gold` `45`.
- Strength: summed `max_health` of an encounter's monsters vs the mean over `Encounters.band_pool(act, floor)`; `< 0.85 × mean` → `weak`, `> 1.15 × mean` → `strong`, else `normal`.
- Encounter and rewards for a node roll from `run_rng.derived("map_act_%d_%s_rewards" % [act, id])`, encounter first, then Scrap.
- Early rolls for acts 1–3 (floors 2–4): `[{"below":0.55,"type":"enemy"},{"below":0.80,"type":"unknown"},{"below":0.88,"type":"merchant"},{"below":0.95,"type":"rest"},{"below":1.0,"type":"treasure","capped":true},{"type":"enemy"}]`. Floor 1 is `enemy` only.

## Review Focus

1. Backpack full when claiming fight gold — the gold row stays claimable and warns (existing behaviour); Task 1 keeps `tests/` that cover it green.
2. A boss win with a full backpack — the 45 boss gold that does not fit must not vanish silently; Task 1 test `boss gold overflow is banked`: overflow is added to `MetaProgress` caps at settlement via the same `legacy_caps` carry as Task 4.
3. An encounter whose monsters are missing from ModelDb — strength must fall back to `normal`, not crash; Task 2 test `unknown encounter is normal`.
4. Elites with no `elites` list in an act — node keeps `encounter = ""` and battle falls back to `select_encounter`; Task 2 test `empty elite list falls back`.
5. Old v7 save mid-route with `run_caps` > backpack room — remainder banked at settlement; Task 4 test `legacy caps that do not fit are banked`.

---

### Task 1: One currency

**Files:**
- Modify: `core/run/run_state.gd` (drop `run_caps`; add `legacy_caps: int = 0`), `autoload/run_manager.gd` (drop `_run_caps`, `award_run_caps`, `CAPS_PER_*`, `GOLD_PER_CAP`; `_settle_backpack` banks `total_gold() + legacy_caps`; reset `legacy_caps` with the run), `core/save/run_save.gd` (save/load `legacy_caps` instead of `run_caps`; no version bump here), `core/run/combat_rewards.gd` (no caps; boss adds `boss_gold` via `add_gold`, overflow to `state.legacy_caps`), `core/run/rewards.gd` (`combat_loot(node_type: String, gold: int) -> Array`), `ui/rewards/loot_reward.gd:108` (pass `int(RunManager.battle_rewards().get("gold", 0))`), `core/run/map_generator.gd` (`node_rewards` emits `gold`), `autoload/run_manager.gd` `battle_rewards()`, `ui/map/route_choice_card.gd:98` (read `gold`), `content/economy/loot_economy.json` (new keys; delete `combat_gold`)
- Test: `tests/combat_rewards_route_test.gd`, `tests/base_inventory_ownership_contract_test.gd:197-205`, `tests/run_structure_golden_test.gd:79`, `tests/route_map_generator_test.gd` (`_check_rewards`), `tests/route_choice_card_test.gd`

**Interfaces:**
- Produces: `static func node_rewards(type: String, rng, strength := "normal") -> Dictionary` — `enemy` → `{gold: combat_gold_by_strength[strength]}`; `elite` → `{gold: elite_gold, scrap: rng.next_range(lo, hi)}`; else `{}`. `static func combat_loot(node_type: String, gold: int) -> Array` (first row `{type: "gold", amount: gold}`). `RunManager.battle_rewards()` returns node rewards when the node type matches the fight, else `MAP_GENERATOR.node_rewards(last_battle_node_type, rng("rewards"))`. `RunState.legacy_caps: int`.

- [ ] **Step 1: Failing tests.** In `combat_rewards_route_test.gd`: settle `enemy` with `{"gold": 8}` changes neither MetaProgress caps nor any hidden counter (assert `not "run_caps" in RunManager.state` via `RunManager.state.get("run_caps") == null`); `REWARDS.combat_loot("enemy", 8)[0] == {"type": "gold", "amount": 8}`; boss: backpack gold rises by 45; `boss gold overflow is banked`: fill every usable backpack cell, settle boss, assert `RunManager.state.legacy_caps == 45`. `battle_rewards()` for a `?` node with `last_battle_node_type = "enemy"` returns `{"gold": 8}`. In the base inventory test replace `_run_caps` with backpack gold 25 only and assert `MetaProgress.caps == 25` ("banks backpack gold 1:1"). Generator `_check_rewards`: enemy `{"gold": 8}`, elite `gold == 18` and scrap 8–16. Card test: elite rewards `{"gold": 18, "scrap": 11}` shows `"18"`.
- [ ] **Step 2: Run** `-Only "combat_rewards_route*"` — Expected: FAIL.
- [ ] **Step 3: Implement** the removals and changes listed in Files. `_settle_backpack` on extract/victory: `MetaProgress.add_caps(total_gold() + state.legacy_caps)`, then `legacy_caps = 0`.
- [ ] **Step 4: Run** `-Only "combat*"`, `-Only "base_inventory*"`, `-Only "r*"` — Expected: all `[OK]`.
- [ ] **Step 5: Commit** — `feat(economy): backpack Caps are the only run currency`.

### Task 2: Encounters and strength on fight nodes

**Files:**
- Modify: `core/run/encounters.gd` (new `strength`), `core/run/map_generator.gd` (`roll_children` fills `encounter`/`strength`), `ui/map/map_scene.gd:318` (use `node.encounter` when not empty)
- Test: `tests/route_map_generator_test.gd`, create `tests/encounter_strength_test.gd` + `.tscn`

**Interfaces:**
- Consumes: Task 1 `node_rewards(type, rng, strength)`.
- Produces: `static func strength(act: Dictionary, floor_idx: int, encounter_id: String) -> String` in `core/run/encounters.gd` (`"weak"|"normal"|"strong"`; `"normal"` when the encounter or band is unknown). `static func monsters_of(encounter_id: String) -> Array[String]` (the existing lookup in `select`, factored out). Node fields `encounter: String`, `strength: String` (`""` for non-fights; elites have `strength = ""`).

- [ ] **Step 1: Failing tests.** `encounter_strength_test.gd`, using act 1 floor 1: compute each pool encounter's HP sum and mean in the test, then assert `strength()` returns `weak` for one below 0.85×mean, `strong` above 1.15×mean, `normal` otherwise (skip a class the real pool lacks, but assert at least two classes appear); `unknown encounter is normal`: `strength(act, 1, "base:no_such") == "normal"`. Generator test: every `enemy` node has a non-empty `encounter` in its floor's band pool, `strength` in the three values, and `rewards.gold == {weak:6, normal:8, strong:11}[strength]`; every `elite` has `encounter` in `act.elites`; `empty elite list falls back`: `roll_children` with an act copy whose `elites` is `[]` gives elites `encounter == ""`. Map scene: in `tests/map_route_scene_test.gd`, after `_choose` on an enemy card, `RunManager.current_encounter == ENCOUNTERS.monsters_of(node.encounter)` (free the map right after the assertion, before the scene change fires).
- [ ] **Step 2: Run** `-Only "encounter_strength*"` — Expected: FAIL (`strength` missing).
- [ ] **Step 3: Implement.** In `map_scene.gd` the fight branch uses `ENCOUNTERS.monsters_of(node.encounter)` when `node.get("encounter", "") != ""`, else `select_encounter` as today.
- [ ] **Step 4: Run** `-Only "encounter_strength*"`, `-Only "route_map_*"`, `-Only "map_route_scene*"`, `-Only "run_structure_golden*"` — Expected: `[OK]`.
- [ ] **Step 5: Commit** — `feat(map): fight nodes carry their encounter and strength`.

### Task 3: Early floors

**Files:**
- Modify: `content/acts/act1.json`, `act2.json`, `act3.json` (`map.early_rolls` per Global Constraints), `core/run/map_generator.gd` (floor 1 forced `enemy`)
- Test: `tests/route_map_generator_test.gd`

- [ ] **Step 1: Failing test.** Over the existing 200 walks: floor 1 types are all `enemy`; across all walks, floors 2–4 include at least one `merchant`, one `rest` and one `treasure`; the "no merchant/rest/elite on floors 1–4" assertion becomes "no elite on floors 1–4".
- [ ] **Step 2: Run** `-Only "route_map_generator*"` — Expected: FAIL.
- [ ] **Step 3: Implement.** In `_pick_node_type`, `floor_idx == 1` returns `"enemy"`. Edit the three act files.
- [ ] **Step 4: Run** `-Only "route_map_*"` and `-Only "*content*"` — Expected: `[OK]`.
- [ ] **Step 5: Commit** — `feat(map): early floors offer shops, rests and treasure`.

### Task 4: Run save v8

**Files:**
- Modify: `core/save/run_save.gd` (`CURRENT := 7` → `8`, `.add(7, _v7_to_v8)`)
- Test: `tests/route_map_save_test.gd`, `tests/save_migration_test.gd` (v7 → v8 expectations)

**Interfaces:**
- Consumes: Task 1 `node_rewards`, Task 2 `strength`/`monsters_of`, rewards stream name.
- Produces: `static func _v7_to_v8(d: Dictionary) -> Dictionary` — `d.legacy_caps = int(d.run_caps)` then erase `run_caps`; every `enemy`/`elite` node lacking `encounter` gets one rolled from its rewards stream exactly as Task 2; `rewards` recomputed with `node_rewards(type, stream, strength)` after the encounter roll. On load, `RunManager.load_run()` moves `legacy_caps` into the backpack with `add_gold` and keeps any remainder in `state.legacy_caps`.

- [ ] **Step 1: Failing tests.** In `route_map_save_test.gd`: build a v7 dict (from `RUN_SAVE.to_dict`, `schema_version = 7`, `run_caps = 30`, nodes with `rewards: {caps: 6}` and no `encounter`); migrate → `schema_version == 8`, no `run_caps`, `legacy_caps == 30`, every enemy node has `encounter` and `rewards.gold`; write it with `SAVE_IO.write_json(RunManager._run_save_path(), d)` and `load_run()` → backpack gold rose by 30 and `state.legacy_caps == 0`. `legacy caps that do not fit are banked`: same with every usable backpack cell full → `state.legacy_caps == 30` after load. Update `save_migration_test.gd` version assertions to 8.
- [ ] **Step 2: Run** `-Only "route_map_save*"` — Expected: FAIL.
- [ ] **Step 3: Implement** `_v7_to_v8` and the load step.
- [ ] **Step 4: Run** `-Only "*save*"` — Expected: `[OK]`.
- [ ] **Step 5: Commit** — `feat(save): run save v8 folds hidden caps into backpack gold`.

### Task 5: Card shows the encounter

**Files:**
- Modify: `ui/map/route_choice_card.gd`, `assets/translations/ui_map.csv`
- Test: `tests/route_choice_card_test.gd`

**Interfaces:**
- Consumes: node fields `encounter`, `strength`; `ENCOUNTERS.monsters_of`.
- Produces: card child `%Portraits` (HBoxContainer, one 56 px TextureRect per monster, max 3) and `%StrengthTag` (Label, hidden when `strength == ""`). Keys: `UI_ROUTE_STRENGTH_WEAK` (Weak, 弱), `UI_ROUTE_STRENGTH_NORMAL` (Normal, 中), `UI_ROUTE_STRENGTH_STRONG` (Strong, 强). Tag colours: weak `T.ACCENT_NEON_GREEN`, normal `T.UI_HEADER_GOLD`, strong `T.ACCENT_DANGER`.

- [ ] **Step 1: Failing test.** A card for `{type: "enemy", encounter: <a real two-monster encounter id from act 1>, strength: "strong", rewards: {gold: 11}}` has 2 portraits, a visible tag with `tr("UI_ROUTE_STRENGTH_STRONG")`, and a row containing `"11"`. An elite card has 1 portrait and a hidden tag. A `rest` card has 0 portraits.
- [ ] **Step 2: Run** `-Only "route_choice_card*"` — Expected: FAIL.
- [ ] **Step 3: Implement.** Portrait path: `battle_scene/assets/images/enemies/<sprite_id>/attack/<sprite_id>_attack_0.png`, `sprite_id` from the monster's data (`MODEL_DB.data("monster", id).sprite_id`, falling back to the bare id); missing texture leaves the slot out. Portraits sit between `TypeName` and `Rewards`; the tag sits in the same row after the portraits.
- [ ] **Step 4: Run** `-Only "route_choice_card*"`, `-Only "map_route_scene*"` — Expected: `[OK]`.
- [ ] **Step 5: Commit** — `feat(map): route cards show the encounter and its strength`.

### Task 6: Docs, full suite, review, playtest

- [ ] **Step 1:** In `docs/PRD.md` replace the GOLD_PER_CAP / per-fight caps wording with: in-run Caps are backpack gold, banked 1:1 on extract or victory. Update the route line to mention encounter portraits and strength.
- [ ] **Step 2:** Full suite `tools/run_tests.ps1` — Expected: exit 0.
- [ ] **Step 3: Commit** — `docs(economy): one run currency`.
- [ ] **Step 4:** Whole-branch review by a fresh reviewer (sonnet), fix Critical/Important test-first, then a windowed playtest with `APPDATA` in the session scratchpad.

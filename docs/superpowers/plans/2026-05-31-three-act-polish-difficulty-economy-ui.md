# Three-Act Polish (A+B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make later acts meaningfully harder (per-act enemy stat + pool scaling), sharpen the extract-vs-push Core economy, and surface the act everywhere the player reads run state.

**Architecture:** All per-act scaling math lives as pure, testable helpers on the `RunManager` autoload (`scale_enemy_hp`, `scale_enemy_damage`, `act_hp_mult`, `act_dmg_mult`) plus a pool offset inside `select_encounter`. Consumers call those helpers at exactly one site each (`enemy_entity.create()` for HP, `battle_scene.modify_enemy_attack_damage()` for damage). Economy is constant-only edits in `battle_scene.gd`. UI is translation-string + format-dict edits at three existing render sites. Bosses (`ids in ACT_BOSSES`) are exempt from all scaling — tuned later in sub-project C.

**Tech Stack:** Godot 4.6 / GDScript. No unit-test framework — logic is verified by temporary headless boot scenes (`_test_*.tscn` + `.gd`, deleted after the task), and every task ends with the project smoke gate.

**Spec:** `docs/superpowers/specs/2026-05-31-three-act-polish-difficulty-economy-ui-design.md`

---

## Test harness pattern (used by every logic task)

Autoloads (`RunManager`, `MetaProgress`, `Settings`) load for **scene** runs but NOT for `--script` runs, so logic tests boot a tiny scene. The `.tscn` scaffold is identical every time except the script path:

```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://_test_NAME.gd" id="1"]
[node name="T" type="Node"]
script = ExtResource("1")
```

The `.gd` does its asserts in `_ready()`, prints `[tag] PASS ...` / `[tag] FAIL ...`, then `get_tree().quit()`.

**Run:** `"C:/Program Files/Godot/Godot.exe" --headless --path . res://_test_NAME.tscn 2>&1 | grep -iE "\[tag\]|SCRIPT ERROR"`

**Important:** autoload constants accessed dynamically are `Variant` — declare typed locals explicitly (`var x: int = int(rm.SOME_CONST)`), never `:=` inference off an autoload member, or you get a parse error.

**Smoke gate (every task):** `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh` — expect tail `[OK] DataValidator: all schemas passed.` + `[OK] Headless boot clean.`

**Cleanup:** after a logic task's test passes, `rm -f _test_NAME.gd _test_NAME.tscn _test_NAME.gd.uid` and `rm -rf .godot/imported/_test_NAME*` before committing, so no temp files are committed.

---

## Task 1: RunManager — per-act scaling helpers + pool offset

**Files:**
- Modify: `run_system/core/run_manager.gd` (add consts + 4 funcs near the act block ~line 147; edit `select_encounter` enemy/unknown branch ~line 453-460)
- Test: `_test_scale.gd` + `_test_scale.tscn` (temp)

- [ ] **Step 1: Write the failing test**

`_test_scale.gd`:
```gdscript
extends Node


func _ready() -> void:
	var rm = RunManager
	var ok := true
	rm.start_new_run("cowboy_bill")

	# act 1 multipliers are identity
	rm.current_act = 1
	if not (is_equal_approx(rm.act_hp_mult(), 1.0) and is_equal_approx(rm.act_dmg_mult(), 1.0)):
		ok = false
		print("[scale] FAIL act1 mults hp=%f dmg=%f" % [rm.act_hp_mult(), rm.act_dmg_mult()])

	# act 2 / act 3 multipliers
	rm.current_act = 2
	if rm.scale_enemy_hp(100, "trash_robot") != 125:
		ok = false
		print("[scale] FAIL act2 hp100 -> %d (want 125)" % rm.scale_enemy_hp(100, "trash_robot"))
	if rm.scale_enemy_damage(20, "trash_robot") != 23:  # round(20*1.15)=23
		ok = false
		print("[scale] FAIL act2 dmg20 -> %d (want 23)" % rm.scale_enemy_damage(20, "trash_robot"))
	rm.current_act = 3
	if rm.scale_enemy_hp(100, "trash_robot") != 150:
		ok = false
		print("[scale] FAIL act3 hp100 -> %d (want 150)" % rm.scale_enemy_hp(100, "trash_robot"))
	if rm.scale_enemy_damage(10, "trash_robot") != 13:  # round(10*1.3)=13
		ok = false
		print("[scale] FAIL act3 dmg10 -> %d (want 13)" % rm.scale_enemy_damage(10, "trash_robot"))

	# bosses are exempt at every act
	rm.current_act = 3
	if rm.scale_enemy_hp(100, "rust_titan") != 100:
		ok = false
		print("[scale] FAIL boss hp scaled -> %d (want 100)" % rm.scale_enemy_hp(100, "rust_titan"))
	if rm.scale_enemy_damage(10, "junkyard_tyrant") != 10:
		ok = false
		print("[scale] FAIL boss dmg scaled -> %d (want 10)" % rm.scale_enemy_damage(10, "junkyard_tyrant"))

	# pool offset: act 2 floor 0 -> MID, act 3 floor 0 -> LATE
	var mid_ids := {}
	for pool in rm.ENCOUNTER_POOLS_MID:
		for id in pool:
			mid_ids[str(id)] = true
	var late_ids := {}
	for pool in rm.ENCOUNTER_POOLS_LATE:
		for id in pool:
			late_ids[str(id)] = true
	rm.current_act = 2
	for i in range(12):
		var e2: Array = rm.select_encounter("enemy", 0)
		if not mid_ids.has(e2[0]):
			ok = false
			print("[scale] FAIL act2 f0 enemy '%s' not in MID pool" % e2[0])
			break
	rm.current_act = 3
	for i in range(12):
		var e3: Array = rm.select_encounter("enemy", 0)
		if not late_ids.has(e3[0]):
			ok = false
			print("[scale] FAIL act3 f0 enemy '%s' not in LATE pool" % e3[0])
			break

	if ok:
		print("[scale] PASS hp/dmg mults, boss-exempt, pool offset")
	get_tree().quit()
```

`_test_scale.tscn` — use the scaffold from the harness pattern with script `res://_test_scale.gd`.

- [ ] **Step 2: Run test to verify it fails**

Run: `"C:/Program Files/Godot/Godot.exe" --headless --path . res://_test_scale.tscn 2>&1 | grep -iE "\[scale\]|SCRIPT ERROR"`
Expected: SCRIPT ERROR / parse failure (functions `act_hp_mult` etc. not defined yet).

- [ ] **Step 3: Add the helpers to `run_system/core/run_manager.gd`**

Immediately AFTER the `func advance_act()` block (added in the prior commit, ~line 187), insert:
```gdscript
## Per-act enemy stat multipliers (index = act-1). Bosses (ids in ACT_BOSSES)
## are exempt — their power is tuned per-boss in sub-project C, not this curve.
const ACT_HP_MULT: Array[float] = [1.0, 1.25, 1.5]
const ACT_DMG_MULT: Array[float] = [1.0, 1.15, 1.30]
## Enemy-pool tier offset per act: act N draws from a tier `(N-1)*offset` floors
## deeper, so act 2 opens at the MID pool and act 3 at the LATE pool.
const ACT_POOL_OFFSET: int = 4


func act_hp_mult() -> float:
	return ACT_HP_MULT[clampi(current_act - 1, 0, ACT_HP_MULT.size() - 1)]


func act_dmg_mult() -> float:
	return ACT_DMG_MULT[clampi(current_act - 1, 0, ACT_DMG_MULT.size() - 1)]


## Scale a non-boss enemy's base HP by the current act multiplier. Bosses pass
## through unchanged. Stacks multiplicatively with ascension scaling, which is
## applied separately at the enemy_entity spawn site.
func scale_enemy_hp(base_hp: int, enemy_id: String) -> int:
	if enemy_id in ACT_BOSSES:
		return base_hp
	return int(round(base_hp * act_hp_mult()))


## Scale a non-boss enemy's outgoing attack damage by the current act
## multiplier. Bosses pass through unchanged.
func scale_enemy_damage(amount: int, enemy_id: String) -> int:
	if enemy_id in ACT_BOSSES:
		return amount
	return int(round(amount * act_dmg_mult()))
```

- [ ] **Step 4: Apply the pool offset in `select_encounter`**

In `run_system/core/run_manager.gd`, the `"enemy", "unknown"` branch currently reads:
```gdscript
			var pool: Array
			if floor_idx <= 3:
				pool = ENCOUNTER_POOLS_EARLY
			elif floor_idx <= 7:
				pool = ENCOUNTER_POOLS_MID
			else:
				pool = ENCOUNTER_POOLS_LATE
```
Replace with:
```gdscript
			var pool: Array
			var tier_floor: int = floor_idx + (current_act - 1) * ACT_POOL_OFFSET
			if tier_floor <= 3:
				pool = ENCOUNTER_POOLS_EARLY
			elif tier_floor <= 7:
				pool = ENCOUNTER_POOLS_MID
			else:
				pool = ENCOUNTER_POOLS_LATE
```

- [ ] **Step 5: Run test to verify it passes**

Run: `"C:/Program Files/Godot/Godot.exe" --headless --path . res://_test_scale.tscn 2>&1 | grep -iE "\[scale\]|SCRIPT ERROR"`
Expected: `[scale] PASS hp/dmg mults, boss-exempt, pool offset`

- [ ] **Step 6: Smoke gate**

Run: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh 2>&1 | tail -3`
Expected: `[OK] DataValidator: all schemas passed.` + `[OK] Headless boot clean.`

- [ ] **Step 7: Clean up temp test + commit**

```bash
rm -f _test_scale.gd _test_scale.tscn _test_scale.gd.uid && rm -rf .godot/imported/_test_scale*
git add run_system/core/run_manager.gd
git commit -m "feat(difficulty): per-act enemy hp/damage scaling helpers + pool offset"
```

---

## Task 2: Wire HP scaling into enemy spawn

**Files:**
- Modify: `battle_scene/enemy_entity.gd` (create(), the HP block at ~line 88-94)
- Test: `_test_hp.gd` + `_test_hp.tscn` (temp)

- [ ] **Step 1: Write the failing test**

`_test_hp.gd`:
```gdscript
extends Node

const ENEMY_ENTITY = preload("res://battle_scene/enemy_entity.gd")


func _ready() -> void:
	var rm = RunManager
	var ok := true
	rm.start_new_run("cowboy_bill")
	rm.ascension = 0  # isolate act scaling from ascension scaling

	# trash_robot base HP from JSON (read it so the test isn't brittle to retunes)
	var base := _json_hp("trash_robot")

	rm.current_act = 1
	var e1 = ENEMY_ENTITY.create("trash_robot")
	if e1.max_health != base:
		ok = false
		print("[hp] FAIL act1 hp=%d (want %d)" % [e1.max_health, base])
	e1.free()

	rm.current_act = 3
	var e3 = ENEMY_ENTITY.create("trash_robot")
	if e3.max_health != int(round(base * 1.5)):
		ok = false
		print("[hp] FAIL act3 hp=%d (want %d)" % [e3.max_health, int(round(base * 1.5))])
	e3.free()

	# boss exempt
	var boss_base := _json_hp("rust_titan")
	rm.current_act = 3
	var b = ENEMY_ENTITY.create("rust_titan")
	if b.max_health != boss_base:
		ok = false
		print("[hp] FAIL boss hp=%d (want %d, unscaled)" % [b.max_health, boss_base])
	b.free()

	if ok:
		print("[hp] PASS act hp scaling + boss exempt")
	get_tree().quit()


func _json_hp(id: String) -> int:
	var f = FileAccess.open("res://battle_scene/card_info/enemy/%s.json" % id, FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	return int(d.get("max_health", 30))
```

`_test_hp.tscn` — scaffold with script `res://_test_hp.gd`.

- [ ] **Step 2: Run test to verify it fails**

Run: `"C:/Program Files/Godot/Godot.exe" --headless --path . res://_test_hp.tscn 2>&1 | grep -iE "\[hp\]|SCRIPT ERROR"`
Expected: `[hp] FAIL act3 hp=...` (HP not yet scaled by act).

- [ ] **Step 3: Apply scaling in `enemy_entity.gd`**

The current block in `create()`:
```gdscript
				entity.max_health = int(data.get("max_health", 30))
				# Ascension A1+: enemy HP scales +10% per level.
				if RunManager.ascension > 0:
					entity.max_health = int(
						round(entity.max_health * (1.0 + 0.1 * RunManager.ascension))
					)
				entity.health = entity.max_health
```
Replace with (add the act scaling AFTER ascension, before setting `health`):
```gdscript
				entity.max_health = int(data.get("max_health", 30))
				# Ascension A1+: enemy HP scales +10% per level.
				if RunManager.ascension > 0:
					entity.max_health = int(
						round(entity.max_health * (1.0 + 0.1 * RunManager.ascension))
					)
				# Per-act scaling (bosses exempt — see RunManager.scale_enemy_hp).
				entity.max_health = RunManager.scale_enemy_hp(entity.max_health, id)
				entity.health = entity.max_health
```

- [ ] **Step 4: Run test to verify it passes**

Run: `"C:/Program Files/Godot/Godot.exe" --headless --path . res://_test_hp.tscn 2>&1 | grep -iE "\[hp\]|SCRIPT ERROR"`
Expected: `[hp] PASS act hp scaling + boss exempt`

- [ ] **Step 5: Smoke gate**

Run: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh 2>&1 | tail -3`
Expected: both `[OK]` lines.

- [ ] **Step 6: Clean up temp test + commit**

```bash
rm -f _test_hp.gd _test_hp.tscn _test_hp.gd.uid && rm -rf .godot/imported/_test_hp*
git add battle_scene/enemy_entity.gd
git commit -m "feat(difficulty): scale non-boss enemy HP by act at spawn"
```

---

## Task 3: Wire damage scaling into the enemy-damage hook

**Files:**
- Modify: `battle_scene/battle_scene.gd` (`modify_enemy_attack_damage`, ~line 502-505)
- Test: `_test_dmg.gd` + `_test_dmg.tscn` (temp) — verifies the helper drives a constructed attacker

- [ ] **Step 1: Write the failing test**

The damage path runs through `RunManager.scale_enemy_damage` (already tested in Task 1). This task only wires it in. The integration test confirms the hook multiplies a constructed enemy's damage and leaves bosses alone, using the helper directly on an entity's `enemy_id`:

`_test_dmg.gd`:
```gdscript
extends Node

const ENEMY_ENTITY = preload("res://battle_scene/enemy_entity.gd")


func _ready() -> void:
	var rm = RunManager
	var ok := true
	rm.start_new_run("cowboy_bill")
	rm.current_act = 2

	var e = ENEMY_ENTITY.create("trash_robot")
	# The hook scales by the acting enemy's id; mirror that call.
	if rm.scale_enemy_damage(20, e.enemy_id) != 23:
		ok = false
		print("[dmg] FAIL act2 trash 20 -> %d (want 23)" % rm.scale_enemy_damage(20, e.enemy_id))
	e.free()

	var b = ENEMY_ENTITY.create("rust_titan")
	if rm.scale_enemy_damage(20, b.enemy_id) != 20:
		ok = false
		print("[dmg] FAIL boss 20 -> %d (want 20)" % rm.scale_enemy_damage(20, b.enemy_id))
	b.free()

	if ok:
		print("[dmg] PASS enemy_id-driven damage scaling")
	get_tree().quit()
```

`_test_dmg.tscn` — scaffold with script `res://_test_dmg.gd`.

- [ ] **Step 2: Run test to verify it passes against Task 1 helper, then confirm wiring is absent**

Run: `"C:/Program Files/Godot/Godot.exe" --headless --path . res://_test_dmg.tscn 2>&1 | grep -iE "\[dmg\]|SCRIPT ERROR"`
Expected: `[dmg] PASS` (the helper already exists from Task 1). The wiring itself (Step 3) has no automated assertion because it requires a live battle; it is covered by smoke + manual playtest. This is acceptable — the scaling math is the tested unit; the hook is a one-line delegation.

- [ ] **Step 3: Wire the helper into `modify_enemy_attack_damage`**

Current:
```gdscript
func modify_enemy_attack_damage(amount: int, attacker: Node, defender: Node) -> int:
	if relic_effect_system:
		return relic_effect_system.modify_enemy_attack_damage(amount, attacker, defender)
	return amount
```
Replace with:
```gdscript
func modify_enemy_attack_damage(amount: int, attacker: Node, defender: Node) -> int:
	var result := amount
	if relic_effect_system:
		result = relic_effect_system.modify_enemy_attack_damage(result, attacker, defender)
	# Per-act enemy damage scaling (bosses exempt). Applied after relic
	# modifiers so relic flat-reductions read against the pre-act number.
	if attacker and "enemy_id" in attacker:
		result = RunManager.scale_enemy_damage(result, str(attacker.enemy_id))
	return result
```

- [ ] **Step 4: Smoke gate**

Run: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh 2>&1 | tail -3`
Expected: both `[OK]` lines.

- [ ] **Step 5: Clean up temp test + commit**

```bash
rm -f _test_dmg.gd _test_dmg.tscn _test_dmg.gd.uid && rm -rf .godot/imported/_test_dmg*
git add battle_scene/battle_scene.gd
git commit -m "feat(difficulty): scale non-boss enemy damage by act via damage hook"
```

---

## Task 4: Economy — extract/push/victory Core values

**Files:**
- Modify: `battle_scene/battle_scene.gd` (`BOSS_VICTORY_CORE` ~line 46, `EXTRACT_REWARDS` ~line 51-54)
- Test: `_test_econ.gd` + `_test_econ.tscn` (temp)

- [ ] **Step 1: Write the failing test**

`_test_econ.gd` (the constants live on the battle scene script; load it and read them):
```gdscript
extends Node

const BATTLE = preload("res://battle_scene/battle_scene.gd")


func _ready() -> void:
	var ok := true
	if BATTLE.BOSS_VICTORY_CORE != 200:
		ok = false
		print("[econ] FAIL victory core=%d (want 200)" % BATTLE.BOSS_VICTORY_CORE)
	var r1: Dictionary = BATTLE.EXTRACT_REWARDS.get(1, {})
	var r2: Dictionary = BATTLE.EXTRACT_REWARDS.get(2, {})
	if int(r1.get("extract", -1)) != 60 or int(r1.get("continue", -1)) != 40:
		ok = false
		print("[econ] FAIL act1 rewards %s" % str(r1))
	if int(r2.get("extract", -1)) != 130 or int(r2.get("continue", -1)) != 80:
		ok = false
		print("[econ] FAIL act2 rewards %s" % str(r2))
	if ok:
		print("[econ] PASS act1{40/60} act2{80/130} victory200")
	get_tree().quit()
```

`_test_econ.tscn` — scaffold with script `res://_test_econ.gd`.

- [ ] **Step 2: Run test to verify it fails**

Run: `"C:/Program Files/Godot/Godot.exe" --headless --path . res://_test_econ.tscn 2>&1 | grep -iE "\[econ\]|SCRIPT ERROR"`
Expected: `[econ] FAIL victory core=150 ...`

- [ ] **Step 3: Update the constants in `battle_scene.gd`**

Change `const BOSS_VICTORY_CORE := 150` to:
```gdscript
const BOSS_VICTORY_CORE := 200
```
Change the `EXTRACT_REWARDS` dict to:
```gdscript
const EXTRACT_REWARDS := {
	1: {"continue": 40, "extract": 60},
	2: {"continue": 80, "extract": 130},
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `"C:/Program Files/Godot/Godot.exe" --headless --path . res://_test_econ.tscn 2>&1 | grep -iE "\[econ\]|SCRIPT ERROR"`
Expected: `[econ] PASS act1{40/60} act2{80/130} victory200`

- [ ] **Step 5: Smoke gate**

Run: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh 2>&1 | tail -3`
Expected: both `[OK]` lines.

- [ ] **Step 6: Clean up temp test + commit**

```bash
rm -f _test_econ.gd _test_econ.tscn _test_econ.gd.uid && rm -rf .godot/imported/_test_econ*
git add battle_scene/battle_scene.gd
git commit -m "balance(econ): sharpen extract/push/victory Core curve across acts"
```

---

## Task 5: UI — act in the run-history row

**Files:**
- Modify: `assets/translations/ui_home.csv` (`UI_HOME_RUN_ROW` row)
- Modify: `run_system/ui/home_base_scene.gd` (~line 384-391, the history row builder)
- Test: `_test_hist.gd` + `_test_hist.tscn` (temp) — asserts the run summary carries `act` and the formatted string includes it

- [ ] **Step 1: Write the failing test**

`_test_hist.gd`:
```gdscript
extends Node


func _ready() -> void:
	var ok := true
	var entry := {"hero_id": "cowboy_bill", "floor": 4, "act": 2, "core_earned": 60, "outcome": "extracted"}
	# Mirror home_base_scene's format call.
	var text: String = tr("UI_HOME_RUN_ROW").format(
		{
			"icon": "⤴",
			"hero": "Bill",
			"act": int(entry.get("act", 1)),
			"floor": int(entry.get("floor", 0)) + 1,
			"core": int(entry.get("core_earned", 0)),
		}
	)
	if not ("2" in text and "5" in text):  # act 2, floor 4+1=5
		ok = false
		print("[hist] FAIL row text missing act/floor: '%s'" % text)
	if "{act}" in text or "{floor}" in text:
		ok = false
		print("[hist] FAIL unsubstituted placeholder: '%s'" % text)
	if ok:
		print("[hist] PASS run row includes act+floor")
	get_tree().quit()
```

`_test_hist.tscn` — scaffold with script `res://_test_hist.gd`.

- [ ] **Step 2: Run test to verify it fails**

Run: `"C:/Program Files/Godot/Godot.exe" --headless --path . res://_test_hist.tscn 2>&1 | grep -iE "\[hist\]|SCRIPT ERROR"`
Expected: `[hist] FAIL unsubstituted placeholder: '...{act}...'` (the `{act}` token isn't in the translation yet, so `.format` leaves it).

- [ ] **Step 3: Update the translation row**

In `assets/translations/ui_home.csv`, replace the line:
```
UI_HOME_RUN_ROW,{icon}  {hero}  Floor {floor}  +{core} Core,{icon}  {hero}  第{floor}层  +{core} 核心
```
with:
```
UI_HOME_RUN_ROW,{icon}  {hero}  Act {act}·F{floor}  +{core} Core,{icon}  {hero}  第{act}幕·{floor}层  +{core} 核心
```

- [ ] **Step 4: Pass `act` into the format dict in `home_base_scene.gd`**

The current row builder:
```gdscript
	var hero: String = _humanize_hero_id(str(entry.get("hero_id", "?")))
	var floor: int = int(entry.get("floor", 0))
	var core_earned: int = int(entry.get("core_earned", 0))

	var row := Label.new()
	row.text = (tr("UI_HOME_RUN_ROW").format(
		{"icon": icon, "hero": hero, "floor": floor + 1, "core": core_earned}
	))
```
Replace with:
```gdscript
	var hero: String = _humanize_hero_id(str(entry.get("hero_id", "?")))
	var floor: int = int(entry.get("floor", 0))
	var act: int = int(entry.get("act", 1))  # legacy summaries predate `act`
	var core_earned: int = int(entry.get("core_earned", 0))

	var row := Label.new()
	row.text = (tr("UI_HOME_RUN_ROW").format(
		{"icon": icon, "hero": hero, "act": act, "floor": floor + 1, "core": core_earned}
	))
```

- [ ] **Step 5: Reimport translations + run test to verify it passes**

```bash
"C:/Program Files/Godot/Godot.exe" --headless --import --path . 2>&1 | grep -iE "script error" | head -3 || true
"C:/Program Files/Godot/Godot.exe" --headless --path . res://_test_hist.tscn 2>&1 | grep -iE "\[hist\]|SCRIPT ERROR"
```
Expected: `[hist] PASS run row includes act+floor`

- [ ] **Step 6: Smoke gate**

Run: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh 2>&1 | tail -3`
Expected: both `[OK]` lines.

- [ ] **Step 7: Clean up temp test + commit**

```bash
rm -f _test_hist.gd _test_hist.tscn _test_hist.gd.uid && rm -rf .godot/imported/_test_hist*
git add assets/translations/ui_home.csv run_system/ui/home_base_scene.gd
git commit -m "feat(ui): show act in home-base run history rows"
```

---

## Task 6: UI — act in the character-panel vitals

**Files:**
- Modify: `assets/translations/ui_equipment.csv` (`UI_EQUIP_VITALS` row)
- Modify: `run_system/ui/equipment_panel.gd` (~line 214-225, `_refresh` vitals format)
- Test: smoke gate only (vitals render inside the live panel; the string change is verified by the placeholder-free smoke boot + manual check)

- [ ] **Step 1: Update the translation row**

In `assets/translations/ui_equipment.csv`, replace:
```
UI_EQUIP_VITALS,HP {hp} / {max}     GOLD {gold}     FLOOR {floor},生命 {hp} / {max}     金币 {gold}     层数 {floor}
```
with:
```
UI_EQUIP_VITALS,HP {hp} / {max}     GOLD {gold}     ACT {act} · FLOOR {floor},生命 {hp} / {max}     金币 {gold}     第{act}幕 · {floor}层
```

- [ ] **Step 2: Pass `act` into the vitals format dict in `equipment_panel.gd`**

Current:
```gdscript
			tr("UI_EQUIP_VITALS")
			. format(
				{
					"hp": RunManager.current_health,
					"max": RunManager.max_health,
					"gold": RunManager.gold,
					"floor": max(1, RunManager.current_floor + 1),
				}
			)
```
Replace with:
```gdscript
			tr("UI_EQUIP_VITALS")
			. format(
				{
					"hp": RunManager.current_health,
					"max": RunManager.max_health,
					"gold": RunManager.gold,
					"act": RunManager.current_act,
					"floor": max(1, RunManager.current_floor + 1),
				}
			)
```

- [ ] **Step 3: Reimport translations + smoke gate**

```bash
"C:/Program Files/Godot/Godot.exe" --headless --import --path . 2>&1 | grep -iE "script error" | head -3 || true
GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh 2>&1 | tail -3
```
Expected: both `[OK]` lines.

- [ ] **Step 4: Commit**

```bash
git add assets/translations/ui_equipment.csv run_system/ui/equipment_panel.gd
git commit -m "feat(ui): show act in character-panel vitals"
```

---

## Task 7: UI — act-transition toast on the map

**Files:**
- Modify: `assets/translations/ui_map.csv` (add `UI_MAP_ENTER_ACT`)
- Modify: `run_system/ui/map_scene.gd` (`_ready`, after `_build_*` calls ~line 70-72)
- Test: smoke gate only (toast is a transient overlay on a live scene; verified by smoke boot + manual check). Guard logic is simple and reviewed inline.

- [ ] **Step 1: Add the translation key**

In `assets/translations/ui_map.csv`, after the `UI_MAP_TOPBAR_ACT` row, add:
```
UI_MAP_ENTER_ACT,⟐ ENTERING ACT {n},⟐ 进入第 {n} 幕
```

- [ ] **Step 2: Show the toast on fresh-act entry in `map_scene.gd`**

At the end of `_ready()`, after the existing `_build_relic_choice_layer()` / `_build_equipment_button()` / `_build_deck_button()` calls, add:
```gdscript
	# Act-transition toast: only when the map scene loads on a freshly generated
	# act > 1 (advance_act cleared the walk + node selection). Act 1's first map
	# is excluded by the act>1 guard.
	if rm.current_act > 1 and rm.current_node_id == "" and rm.visited_node_ids.is_empty():
		_show_popup(tr("UI_MAP_ENTER_ACT").format({"n": rm.current_act}))
```

- [ ] **Step 3: Reimport translations + smoke gate**

```bash
"C:/Program Files/Godot/Godot.exe" --headless --import --path . 2>&1 | grep -iE "script error" | head -3 || true
GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh 2>&1 | tail -3
```
Expected: both `[OK]` lines.

- [ ] **Step 4: Commit**

```bash
git add assets/translations/ui_map.csv run_system/ui/map_scene.gd
git commit -m "feat(ui): toast when entering a new act on the map"
```

---

## Task 8: Manual playtest verification

Not committable code — a checklist the human runs once the build is green. Boot the game (`home_base_scene` is the main scene) and verify:

- [ ] Start a run → character panel vitals read `ACT 1 · FLOOR 1`; map top bar reads `Act: 1/3`.
- [ ] Reach the Act 1 boss, win → extract modal offers **60** (extract) vs **40** (push); modal title says "act 1 boss".
- [ ] Choose **push on** → loot → map shows a fresh map with toast `⟐ ENTERING ACT 2` and top bar `Act: 2/3`.
- [ ] Act 2 trash enemies are visibly tankier/hit harder than Act 1's (HP bars / damage numbers), and the enemy types skew tougher (MID pool).
- [ ] Die in Act 2 → home base; run-history row shows `Act 2·F<n>`. Safe-cell items survived; rest forfeit (unchanged behavior).
- [ ] Win the final boss (Act 3) → `+200` Core banked; returns to home base.

---

## Self-Review notes (filled by plan author)

- **Spec coverage:** B1 stat scaling → Tasks 1-3; B2 pool offset → Task 1; A economy → Task 4; A UI run history → Task 5; A UI vitals → Task 6; A UI act toast → Task 7. All spec sections mapped.
- **Boss exemption** is enforced in one place (`scale_enemy_hp`/`scale_enemy_damage` `id in ACT_BOSSES` guard) and consumed by both HP and damage sites — single source of truth.
- **Type consistency:** helper names `act_hp_mult` / `act_dmg_mult` / `scale_enemy_hp` / `scale_enemy_damage`, const names `ACT_HP_MULT` / `ACT_DMG_MULT` / `ACT_POOL_OFFSET` are used identically across Tasks 1-3. Format keys `act` / `floor` match between CSV tokens and `.format` dicts in Tasks 5-6.
- **No new effect/action/status types** are introduced, so no `data_validator.gd` ALLOWED_* changes are needed (that work belongs to sub-project C).

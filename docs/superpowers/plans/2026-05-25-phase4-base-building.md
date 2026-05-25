# Phase 4 Base Building MVP — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the meta-progression loop (persistent Core currency + 5×3-tier base upgrades + Floor 1/2 extract choice) so the game becomes a roguelite — runs feed permanent progress.

**Architecture:** New `MetaProgress` autoload owns `user://meta.json` persistence. New `home_base_scene` is the boot/return-to-base UI. `RunManager.start_new_run()` reads `MetaProgress` and applies five effect keys. Extract choice gets injected after F1/F2 boss death; F3 boss death and player death route back to home base unconditionally.

**Tech Stack:** Godot 4.6, GDScript. No unit test framework — verification is `godot --headless --path . --quit-after 3` (DataValidator runs at boot, parse errors surface immediately) plus a manual smoke checklist.

**Note on TDD adaptation:** This project has no test framework. Each task substitutes "headless parse + boot check" for "write failing test → make it pass". When a task touches data (JSON), the DataValidator catches schema breakage at boot. When a task touches code, headless boot catches parse errors and autoload failures.

---

## File map

**Create:**
- `run_system/core/meta_progress.gd` — autoload, save/load + purchase API
- `run_system/data/base_upgrades/med_bay.json`
- `run_system/data/base_upgrades/arsenal.json`
- `run_system/data/base_upgrades/research_lab.json`
- `run_system/data/base_upgrades/scrap_workshop.json`
- `run_system/data/base_upgrades/command_center.json`
- `run_system/ui/home_base_scene.gd`
- `run_system/ui/home_base_scene.tscn`
- `run_system/ui/upgrade_panel.gd` — reusable widget inside home_base_scene
- `run_system/ui/extract_choice_modal.gd` — instantiated from battle_scene

**Modify:**
- `project.godot` — add MetaProgress autoload; switch main_scene to home_base_scene
- `battle_scene/data_validator.gd` — add `validate_base_upgrade` + new BASE_UPGRADE_DIR
- `run_system/core/run_manager.gd` — `start_new_run()` reads MetaProgress; new `_apply_meta_upgrades()`; new `return_to_home_base()`
- `run_system/ui/loot_reward.gd` — read `research_lab` level for rarity bias
- `run_system/ui/shop_scene.gd` — read `scrap_workshop` level for price discount
- `battle_scene/battle_scene.gd` — after boss death on F1/F2 show extract modal; on F3 victory or any death route to home_base

---

## Task 1: MetaProgress autoload skeleton

**Files:**
- Create: `run_system/core/meta_progress.gd`
- Modify: `project.godot:17-19` (autoload section)

- [ ] **Step 1: Create `run_system/core/meta_progress.gd`**

```gdscript
## Persistent meta-progression. Survives across runs. Loaded from
## user://meta.json at autoload _ready; saved on every mutation.
##
## Schema: { "core": int, "upgrades": { "<id>": int } }
##   - core: current spendable Core currency
##   - upgrades: id → current level (0..3)
extends Node

const SAVE_PATH := "user://meta.json"

signal core_changed(new_value: int)
signal upgrades_changed()

var core: int = 0
var upgrades: Dictionary = {}


func _ready() -> void:
	load_progress()


func add_core(amount: int) -> void:
	core = max(0, core + amount)
	save_progress()
	emit_signal("core_changed", core)


func get_upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))


func can_purchase(id: String, definition: Dictionary) -> bool:
	var tiers: Array = definition.get("tiers", [])
	var lvl := get_upgrade_level(id)
	if lvl >= tiers.size():
		return false
	return core >= int(tiers[lvl].get("cost", 999999))


func purchase_upgrade(id: String, definition: Dictionary) -> bool:
	if not can_purchase(id, definition):
		return false
	var lvl := get_upgrade_level(id)
	var cost := int(definition["tiers"][lvl]["cost"])
	core -= cost
	upgrades[id] = lvl + 1
	save_progress()
	emit_signal("core_changed", core)
	emit_signal("upgrades_changed")
	return true


func reset_all() -> void:
	core = 0
	upgrades.clear()
	save_progress()
	emit_signal("core_changed", core)
	emit_signal("upgrades_changed")


func save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not f:
		push_warning("MetaProgress: failed to open save file for write")
		return
	f.store_string(JSON.stringify({"core": core, "upgrades": upgrades}, "  "))
	f.close()


func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("MetaProgress: corrupt save file at %s, renaming to .bak" % SAVE_PATH)
		DirAccess.rename_absolute(SAVE_PATH, SAVE_PATH + ".bak")
		return
	core = int(parsed.get("core", 0))
	var raw_upgrades = parsed.get("upgrades", {})
	if typeof(raw_upgrades) == TYPE_DICTIONARY:
		upgrades = raw_upgrades
```

- [ ] **Step 2: Register autoload in `project.godot`**

Modify the `[autoload]` section so it becomes:

```
[autoload]

RunManager="*res://run_system/core/run_manager.gd"
MetaProgress="*res://run_system/core/meta_progress.gd"
```

- [ ] **Step 3: Headless boot check**

Run: `godot --headless --path . --quit-after 3`
Expected: clean exit, zero `script error`, no autoload failure.

- [ ] **Step 4: Commit**

```bash
git add run_system/core/meta_progress.gd project.godot
git commit -m "Add MetaProgress autoload with save/load + purchase API"
```

---

## Task 2: Base upgrade JSONs (5 files)

**Files:**
- Create: `run_system/data/base_upgrades/med_bay.json`
- Create: `run_system/data/base_upgrades/arsenal.json`
- Create: `run_system/data/base_upgrades/research_lab.json`
- Create: `run_system/data/base_upgrades/scrap_workshop.json`
- Create: `run_system/data/base_upgrades/command_center.json`

- [ ] **Step 1: Create `med_bay.json`**

```json
{
  "id": "med_bay",
  "name": "MED BAY",
  "description": "Permanently increase starting max HP.",
  "effect_key": "max_hp_bonus",
  "tiers": [
    {"level": 1, "cost": 30, "effect_value": {"hp": 10}, "effect_text": "+10 max HP at run start"},
    {"level": 2, "cost": 60, "effect_value": {"hp": 20}, "effect_text": "+20 max HP at run start"},
    {"level": 3, "cost": 100, "effect_value": {"hp": 30}, "effect_text": "+30 max HP at run start"}
  ]
}
```

- [ ] **Step 2: Create `arsenal.json`**

```json
{
  "id": "arsenal",
  "name": "ARSENAL",
  "description": "Start runs with bonus equipment in your inventory.",
  "effect_key": "starter_inventory",
  "tiers": [
    {"level": 1, "cost": 30, "effect_value": {"commons": 1, "uncommons": 0}, "effect_text": "1 random common equipment in inventory at run start"},
    {"level": 2, "cost": 60, "effect_value": {"commons": 2, "uncommons": 0}, "effect_text": "2 random common equipment in inventory at run start"},
    {"level": 3, "cost": 100, "effect_value": {"commons": 2, "uncommons": 1}, "effect_text": "2 commons + 1 uncommon in inventory at run start"}
  ]
}
```

- [ ] **Step 3: Create `research_lab.json`**

```json
{
  "id": "research_lab",
  "name": "RESEARCH LAB",
  "description": "Improve the quality of cards offered after battles.",
  "effect_key": "loot_rarity_bias",
  "tiers": [
    {"level": 1, "cost": 30, "effect_value": {"uncommon": 0.05, "rare": 0.0}, "effect_text": "+5% chance to upgrade a draft card to uncommon"},
    {"level": 2, "cost": 60, "effect_value": {"uncommon": 0.10, "rare": 0.0}, "effect_text": "+10% chance to upgrade a draft card to uncommon"},
    {"level": 3, "cost": 100, "effect_value": {"uncommon": 0.15, "rare": 0.05}, "effect_text": "+15% uncommon and +5% rare in draft cards"}
  ]
}
```

- [ ] **Step 4: Create `scrap_workshop.json`**

```json
{
  "id": "scrap_workshop",
  "name": "SCRAP WORKSHOP",
  "description": "Negotiate better prices at the merchant.",
  "effect_key": "shop_discount",
  "tiers": [
    {"level": 1, "cost": 30, "effect_value": {"multiplier": 0.90}, "effect_text": "All shop prices reduced by 10%"},
    {"level": 2, "cost": 60, "effect_value": {"multiplier": 0.80}, "effect_text": "All shop prices reduced by 20%"},
    {"level": 3, "cost": 100, "effect_value": {"multiplier": 0.70}, "effect_text": "All shop prices reduced by 30%"}
  ]
}
```

- [ ] **Step 5: Create `command_center.json`**

```json
{
  "id": "command_center",
  "name": "COMMAND CENTER",
  "description": "Begin each run with extra gold from your stockpile.",
  "effect_key": "starting_gold",
  "tiers": [
    {"level": 1, "cost": 30, "effect_value": {"gold": 50}, "effect_text": "+50 starting gold"},
    {"level": 2, "cost": 60, "effect_value": {"gold": 120}, "effect_text": "+120 starting gold"},
    {"level": 3, "cost": 100, "effect_value": {"gold": 200}, "effect_text": "+200 starting gold"}
  ]
}
```

- [ ] **Step 6: Commit (validation lands in Task 3, but headless boot here still succeeds)**

Run: `godot --headless --path . --quit-after 3`
Expected: clean exit (no validator running on these files yet — they're just sitting on disk).

```bash
git add run_system/data/base_upgrades/
git commit -m "Add 5 base upgrade JSON definitions (med_bay, arsenal, research_lab, scrap_workshop, command_center)"
```

---

## Task 3: DataValidator schema for base upgrades

**Files:**
- Modify: `battle_scene/data_validator.gd:15` (add BASE_UPGRADE_DIR), `:69-80` (call new validator), end-of-file (add `validate_base_upgrade` function)

- [ ] **Step 1: Add BASE_UPGRADE_DIR constant**

In `battle_scene/data_validator.gd`, find the line `const SET_DIR       = "res://run_system/data/equipment_sets/"` (line 16) and add immediately after it:

```gdscript
const BASE_UPGRADE_DIR = "res://run_system/data/base_upgrades/"
```

- [ ] **Step 2: Add base-upgrade schema constants**

After the equipment-set constants section (after the `STATUS_BEARING_SET_EFFECTS` const around line 62), add:

```gdscript
# ─── Base upgrade schema ─────────────────────────────────────────────────────
const REQUIRED_BASE_UPGRADE_KEYS = ["id", "name", "description", "effect_key", "tiers"]
const REQUIRED_BASE_UPGRADE_TIER_KEYS = ["level", "cost", "effect_value", "effect_text"]
const ALLOWED_BASE_UPGRADE_EFFECT_KEYS = [
	"max_hp_bonus", "starter_inventory", "loot_rarity_bias",
	"shop_discount", "starting_gold",
]
```

- [ ] **Step 3: Hook into `validate_all_data_at_startup`**

Find the line `failures += _validate_dir(SET_DIR,       Callable(DataValidator, "validate_equipment_set"))` (around line 76) and add this line right after it:

```gdscript
	failures += _validate_dir(BASE_UPGRADE_DIR, Callable(DataValidator, "validate_base_upgrade"))
```

- [ ] **Step 4: Implement `validate_base_upgrade`**

Append this function to the bottom of `data_validator.gd` (after the last existing `static func`):

```gdscript
static func validate_base_upgrade(data: Dictionary, path: String) -> int:
	var failures = 0
	for key in REQUIRED_BASE_UPGRADE_KEYS:
		if not data.has(key):
			push_error("[base_upgrade %s] missing required key '%s'" % [path, key])
			failures += 1
	if failures > 0:
		return failures
	if not data["effect_key"] in ALLOWED_BASE_UPGRADE_EFFECT_KEYS:
		push_error("[base_upgrade %s] unknown effect_key '%s' (allowed: %s)" % [path, data["effect_key"], ALLOWED_BASE_UPGRADE_EFFECT_KEYS])
		failures += 1
	var tiers = data.get("tiers", [])
	if typeof(tiers) != TYPE_ARRAY or tiers.size() == 0:
		push_error("[base_upgrade %s] 'tiers' must be a non-empty array" % path)
		return failures + 1
	for i in range(tiers.size()):
		var tier = tiers[i]
		if typeof(tier) != TYPE_DICTIONARY:
			push_error("[base_upgrade %s] tier %d is not a dictionary" % [path, i])
			failures += 1
			continue
		for key in REQUIRED_BASE_UPGRADE_TIER_KEYS:
			if not tier.has(key):
				push_error("[base_upgrade %s] tier %d missing required key '%s'" % [path, i, key])
				failures += 1
		if tier.has("effect_value") and typeof(tier["effect_value"]) != TYPE_DICTIONARY:
			push_error("[base_upgrade %s] tier %d 'effect_value' must be a dictionary" % [path, i])
			failures += 1
	return failures
```

- [ ] **Step 5: Headless boot check**

Run: `godot --headless --path . --quit-after 3`
Expected: `DataValidator: ... passed` line shows; no `[base_upgrade ...]` errors.

- [ ] **Step 6: Commit**

```bash
git add battle_scene/data_validator.gd
git commit -m "DataValidator: add base_upgrade schema validation"
```

---

## Task 4: UpgradePanel widget

**Files:**
- Create: `run_system/ui/upgrade_panel.gd`

- [ ] **Step 1: Create `run_system/ui/upgrade_panel.gd`**

```gdscript
## Reusable upgrade-card widget used inside home_base_scene.
## Renders: title, level dots (●●○), next-tier preview text, cost,
## BUY button. Listens to MetaProgress.core_changed + upgrades_changed
## to refresh state. When BUY is pressed, calls MetaProgress.purchase_upgrade.
extends PanelContainer
class_name UpgradePanel

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")

var _definition: Dictionary = {}

var _title_label: Label
var _level_label: Label
var _effect_label: Label
var _cost_label: Label
var _buy_button: Button


func _ready() -> void:
	custom_minimum_size = Vector2(320, 200)
	add_theme_stylebox_override("panel", T.panel_textured("dark"))
	if not _title_label:
		_build()


func _build() -> void:
	if _title_label:
		return
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	vbox.add_child(_title_label)

	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 18)
	_level_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(_level_label)

	_effect_label = Label.new()
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.75))
	_effect_label.custom_minimum_size = Vector2(280, 0)
	vbox.add_child(_effect_label)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	vbox.add_child(bottom)

	_cost_label = Label.new()
	_cost_label.add_theme_font_size_override("font_size", 18)
	_cost_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	bottom.add_child(_cost_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)

	_buy_button = Button.new()
	_buy_button.custom_minimum_size = Vector2(96, 36)
	_buy_button.pressed.connect(_on_buy_pressed)
	bottom.add_child(_buy_button)

	MetaProgress.core_changed.connect(func(_v): _refresh())
	MetaProgress.upgrades_changed.connect(_refresh)


func set_definition(definition: Dictionary) -> void:
	_definition = definition
	if not _title_label:
		_build()
	_refresh()


func _refresh() -> void:
	if not _title_label or _definition.is_empty():
		return
	var id := str(_definition.get("id", ""))
	var tiers: Array = _definition.get("tiers", [])
	var lvl := MetaProgress.get_upgrade_level(id)

	_title_label.text = str(_definition.get("name", id)).to_upper()

	# Level dots: ●●○ for 2/3, etc.
	var dots := ""
	for i in range(tiers.size()):
		dots += "●" if i < lvl else "○"
	_level_label.text = "Level: %s  (%d/%d)" % [dots, lvl, tiers.size()]

	if lvl >= tiers.size():
		# Maxed.
		_effect_label.text = "Fully upgraded."
		_cost_label.text = ""
		_buy_button.text = "MAXED"
		_buy_button.disabled = true
		return

	var next_tier: Dictionary = tiers[lvl]
	_effect_label.text = "Next: %s" % str(next_tier.get("effect_text", ""))
	_cost_label.text = "Cost: %d Core" % int(next_tier.get("cost", 0))
	_buy_button.text = "BUY"
	_buy_button.disabled = not MetaProgress.can_purchase(id, _definition)


func _on_buy_pressed() -> void:
	if _definition.is_empty():
		return
	MetaProgress.purchase_upgrade(str(_definition.get("id", "")), _definition)
```

- [ ] **Step 2: Headless boot check**

Run: `godot --headless --path . --quit-after 3`
Expected: clean exit (file is unused yet, but parse errors would surface).

- [ ] **Step 3: Commit**

```bash
git add run_system/ui/upgrade_panel.gd
git commit -m "Add UpgradePanel widget for home_base_scene"
```

---

## Task 5: HomeBaseScene (.gd + .tscn) and boot routing

**Files:**
- Create: `run_system/ui/home_base_scene.gd`
- Create: `run_system/ui/home_base_scene.tscn`
- Modify: `project.godot:14` (main_scene)

- [ ] **Step 1: Create `run_system/ui/home_base_scene.gd`**

```gdscript
## Home base scene — the boot scene + post-run return point.
## Shows Core balance + 5 UpgradePanels + START NEW RUN button.
## Loads upgrade definitions from run_system/data/base_upgrades/.
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const UPGRADE_PANEL_SCRIPT = preload("res://run_system/ui/upgrade_panel.gd")
const HERO_SELECT_SCENE := "res://run_system/ui/hero_select.tscn"
const UPGRADE_DIR := "res://run_system/data/base_upgrades/"
const UPGRADE_ORDER := ["med_bay", "arsenal", "research_lab", "scrap_workshop", "command_center"]

var _core_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	MetaProgress.core_changed.connect(func(_v): _refresh_core())


func _build() -> void:
	# Solid background
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.05, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	margin.add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "HOME BASE"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_core_label = Label.new()
	_core_label.add_theme_font_size_override("font_size", 32)
	_core_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	header.add_child(_core_label)
	_refresh_core()

	# Upgrade grid (3 cols)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 20)
	vbox.add_child(grid)

	for upgrade_id in UPGRADE_ORDER:
		var definition := _load_upgrade(upgrade_id)
		if definition.is_empty():
			push_warning("HomeBaseScene: missing upgrade JSON for '%s'" % upgrade_id)
			continue
		var panel := UPGRADE_PANEL_SCRIPT.new()
		grid.add_child(panel)
		panel.set_definition(definition)

	# Spacer push START to bottom
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(grow)

	# Action row
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(actions)
	var start_btn := Button.new()
	start_btn.text = "START NEW RUN"
	start_btn.custom_minimum_size = Vector2(260, 60)
	start_btn.add_theme_font_size_override("font_size", 24)
	start_btn.pressed.connect(_on_start_pressed)
	actions.add_child(start_btn)


func _refresh_core() -> void:
	if _core_label:
		_core_label.text = "CORE: %d" % MetaProgress.core


func _load_upgrade(id: String) -> Dictionary:
	var path := UPGRADE_DIR + id + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(HERO_SELECT_SCENE)
```

- [ ] **Step 2: Create `run_system/ui/home_base_scene.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://run_system/ui/home_base_scene.gd" id="1_home"]

[node name="HomeBaseScene" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_home")
```

- [ ] **Step 3: Switch main_scene in `project.godot`**

Change line 14 from:
```
run/main_scene="res://run_system/ui/hero_select.tscn"
```
to:
```
run/main_scene="res://run_system/ui/home_base_scene.tscn"
```

- [ ] **Step 4: Headless boot check**

Run: `godot --headless --path . --quit-after 3`
Expected: clean exit. The home base scene loads, autoload runs, scene tree builds without errors, then quits.

- [ ] **Step 5: Commit**

```bash
git add run_system/ui/home_base_scene.gd run_system/ui/home_base_scene.tscn project.godot
git commit -m "Add home_base_scene as boot scene with 5 upgrade panels + START NEW RUN"
```

---

## Task 6: Apply meta upgrades in start_new_run

**Files:**
- Modify: `run_system/core/run_manager.gd:380-405` (extend `start_new_run`), add new helpers near `add_to_inventory`.

- [ ] **Step 1: Add `_load_upgrade_def` helper near `_load_json_by_id` (around line 655)**

Insert after `_load_json_by_id`:

```gdscript
## Load a base-upgrade definition JSON. Returns {} if missing/invalid.
func _load_upgrade_def(id: String) -> Dictionary:
	var path := "res://run_system/data/base_upgrades/" + id + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


## Resolve an upgrade's current-tier effect_value dictionary, or {} if not owned.
func _get_meta_effect_value(upgrade_id: String) -> Dictionary:
	var lvl := MetaProgress.get_upgrade_level(upgrade_id)
	if lvl <= 0:
		return {}
	var def := _load_upgrade_def(upgrade_id)
	if def.is_empty():
		return {}
	var tiers: Array = def.get("tiers", [])
	if lvl > tiers.size():
		return {}
	var tier: Dictionary = tiers[lvl - 1]
	return tier.get("effect_value", {})
```

- [ ] **Step 2: Add `_apply_meta_upgrades` near end of file**

Insert before `_handle_run_loss` (around line 742):

```gdscript
## Apply all owned meta-progression upgrades to the freshly-reset run state.
## Called at the END of start_new_run (after defaults are set so we can add
## on top of them). Pure additive — never reduces a base value.
func _apply_meta_upgrades() -> void:
	# Med Bay → +max HP
	var hp := int(_get_meta_effect_value("med_bay").get("hp", 0))
	if hp > 0:
		max_health += hp
		current_health = max_health

	# Command Center → +starting gold
	var bonus_gold := int(_get_meta_effect_value("command_center").get("gold", 0))
	if bonus_gold > 0:
		gold += bonus_gold

	# Arsenal → starter inventory items
	var arsenal := _get_meta_effect_value("arsenal")
	if not arsenal.is_empty():
		var commons := int(arsenal.get("commons", 0))
		var uncommons := int(arsenal.get("uncommons", 0))
		for i in range(commons):
			var item_id := roll_equipment_drop("common")
			if item_id != "":
				add_to_inventory(item_id)
		for i in range(uncommons):
			var item_id := roll_equipment_drop("uncommon")
			if item_id != "":
				add_to_inventory(item_id)
	# (loot_rarity_bias + shop_discount are read on-demand by loot_reward / shop_scene;
	# nothing to apply here.)
```

- [ ] **Step 3: Call `_apply_meta_upgrades` at end of `start_new_run`**

Modify `start_new_run` (line 380) — find the last line `_emit_all_state()` and add immediately BEFORE it:

```gdscript
	_apply_meta_upgrades()
```

Final tail of `start_new_run` becomes:

```gdscript
	is_run_active = true
	_apply_meta_upgrades()
	_emit_all_state()
```

- [ ] **Step 4: Headless boot check**

Run: `godot --headless --path . --quit-after 3`
Expected: clean exit. No `_apply_meta_upgrades` is invoked (no run starts in headless), so this is purely a parse check.

- [ ] **Step 5: Commit**

```bash
git add run_system/core/run_manager.gd
git commit -m "RunManager: apply meta upgrades at start_new_run (max HP, gold, starter inventory)"
```

---

## Task 7: Loot rarity bias hook (Research Lab)

**Files:**
- Modify: `run_system/ui/loot_reward.gd` — find the function that rolls draft card rarities

- [ ] **Step 1: Locate the draft-card rarity roll**

Run:
```
grep -n "rarity\|common\|uncommon\|rare\|_roll" run_system/ui/loot_reward.gd | head -30
```

Identify the function that picks a card's rarity for the draft pool (likely something like `_roll_card_rarity()` or inline rarity logic inside `_make_draft_card_slot` / a draft setup function).

- [ ] **Step 2: Add the bias-application helper at the top of `loot_reward.gd`**

Right after the class-level `extends` line / preloads, add:

```gdscript
## Apply Research Lab meta-progression bias to a base rarity.
## Returns the (possibly upgraded) rarity string.
func _apply_research_lab_bias(base_rarity: String) -> String:
	var lvl := MetaProgress.get_upgrade_level("research_lab")
	if lvl <= 0:
		return base_rarity
	# Look up effect_value from RunManager helper
	var bias = RunManager._get_meta_effect_value("research_lab")
	var uncommon_chance := float(bias.get("uncommon", 0.0))
	var rare_chance := float(bias.get("rare", 0.0))
	if base_rarity == "common" and randf() < uncommon_chance:
		base_rarity = "uncommon"
	if base_rarity == "uncommon" and randf() < rare_chance:
		base_rarity = "rare"
	return base_rarity
```

- [ ] **Step 3: Apply the helper at the rarity-roll site**

In the draft-card rarity selection code, wrap the result with `_apply_research_lab_bias(rarity)`. For example, if the code reads:

```gdscript
var rarity = _pick_rarity()  # returns "common" / "uncommon" / "rare"
```

Change to:

```gdscript
var rarity = _apply_research_lab_bias(_pick_rarity())
```

If rarity is inlined (e.g., directly used in a pool lookup), refactor minimally: extract the rarity to a local var first, pass through the bias helper, then use.

- [ ] **Step 4: Headless boot check**

Run: `godot --headless --path . --quit-after 3`
Expected: clean exit, no parse errors.

- [ ] **Step 5: Commit**

```bash
git add run_system/ui/loot_reward.gd
git commit -m "loot_reward: apply Research Lab rarity bias to draft cards"
```

---

## Task 8: Shop discount hook (Scrap Workshop)

**Files:**
- Modify: `run_system/ui/shop_scene.gd`

- [ ] **Step 1: Add discount helper near top of `shop_scene.gd` (after const declarations)**

```gdscript
## Apply Scrap Workshop discount to a base price. Always rounds up
## so the player never gets things for free due to rounding.
func _discounted_price(base_cost: int) -> int:
	var bias = RunManager._get_meta_effect_value("scrap_workshop")
	var multiplier := float(bias.get("multiplier", 1.0))
	if multiplier >= 1.0:
		return base_cost
	return int(ceil(base_cost * multiplier))
```

- [ ] **Step 2: Wrap every price display + purchase call**

In `shop_scene.gd`, every place that reads from `CARD_PRICE[rarity]`, `EQUIP_PRICE[rarity]`, `RELIC_PRICE`, or `REMOVE_CARD_PRICE` (or wherever costs are computed), pipe the cost through `_discounted_price(...)`. For example, find lines like:

```gdscript
var cost = CARD_PRICE[rarity]
```

and change to:

```gdscript
var cost = _discounted_price(CARD_PRICE[rarity])
```

There are roughly 4 cost sites (one per category + remove service). Ensure both the displayed cost label AND the cost passed to `RunManager.purchase_*` use the discounted value (so the player isn't charged the full cost when the label shows discount).

- [ ] **Step 3: Headless boot check**

Run: `godot --headless --path . --quit-after 3`
Expected: clean exit.

- [ ] **Step 4: Commit**

```bash
git add run_system/ui/shop_scene.gd
git commit -m "shop_scene: apply Scrap Workshop discount to all prices"
```

---

## Task 9: Extract choice modal

**Files:**
- Create: `run_system/ui/extract_choice_modal.gd`

- [ ] **Step 1: Create `run_system/ui/extract_choice_modal.gd`**

```gdscript
## Modal shown after F1 or F2 boss death. Player chooses to extract now
## (more Core, run ends, return to home base) or push deeper (less Core
## now, continue to next floor's map).
##
## Owner instantiates, sets reward_continue / reward_extract / floor_num,
## then calls add_child. Listens to `chosen(extract: bool)` signal.
extends Control
class_name ExtractChoiceModal

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")

signal chosen(extract: bool)

var floor_num: int = 1
var reward_continue: int = 25
var reward_extract: int = 50


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	panel.custom_minimum_size = Vector2(640, 380)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "EXTRACT?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	vbox.add_child(title)

	var summary := Label.new()
	summary.text = "You killed the Floor %d boss." % floor_num
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 20)
	summary.add_theme_color_override("font_color", Color(0.92, 0.9, 0.78))
	vbox.add_child(summary)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer)

	# Extract button
	var extract_btn := Button.new()
	extract_btn.text = "EXTRACT NOW   ( +%d Core, end run )" % reward_extract
	extract_btn.custom_minimum_size = Vector2(560, 56)
	extract_btn.add_theme_font_size_override("font_size", 20)
	extract_btn.pressed.connect(_on_extract_pressed)
	vbox.add_child(extract_btn)

	# Continue button
	var continue_btn := Button.new()
	continue_btn.text = "CONTINUE TO FLOOR %d   ( +%d Core, push on )" % [floor_num + 1, reward_continue]
	continue_btn.custom_minimum_size = Vector2(560, 56)
	continue_btn.add_theme_font_size_override("font_size", 20)
	continue_btn.pressed.connect(_on_continue_pressed)
	vbox.add_child(continue_btn)


func _on_extract_pressed() -> void:
	emit_signal("chosen", true)
	queue_free()


func _on_continue_pressed() -> void:
	emit_signal("chosen", false)
	queue_free()
```

- [ ] **Step 2: Headless boot check**

Run: `godot --headless --path . --quit-after 3`
Expected: clean exit (modal unused so far).

- [ ] **Step 3: Commit**

```bash
git add run_system/ui/extract_choice_modal.gd
git commit -m "Add ExtractChoiceModal for Floor 1/2 boss post-victory choice"
```

---

## Task 10: Wire extract modal into battle_scene boss flow + game-over routing

**Files:**
- Modify: `battle_scene/battle_scene.gd` — boss death handler and game-over screen exits

- [ ] **Step 1: Locate boss-victory and game-over flow**

Run:
```
grep -n "is_boss\|node_type.*boss\|last_battle_node_type\|game_over\|victory\|on_battle_won\|_show_game_over" battle_scene/battle_scene.gd | head -40
```

Identify:
- (A) Where the player wins a battle (all enemies dead) → currently transitions to loot_reward
- (B) Where the player loses → currently transitions to a game_over screen or back to map

- [ ] **Step 2: Add extract-modal helper in battle_scene.gd**

Add at the top of `battle_scene.gd` (near other preloads):

```gdscript
const EXTRACT_CHOICE_MODAL_SCRIPT = preload("res://run_system/ui/extract_choice_modal.gd")
const HOME_BASE_SCENE := "res://run_system/ui/home_base_scene.tscn"

const EXTRACT_REWARDS := {
	1: {"continue": 25, "extract": 50},
	2: {"continue": 50, "extract": 90},
}
const F3_VICTORY_CORE := 150
```

- [ ] **Step 3: Insert extract-choice branch at boss victory**

At site (A) (battle victory handler), after determining the player won, BEFORE transitioning to loot_reward, check if the last battle was a boss:

```gdscript
# Boss victory hook: F1/F2 → extract choice; F3 → game complete.
if RunManager.last_battle_node_type == "boss":
	var floor_num := RunManager.current_floor
	if floor_num >= 3:
		MetaProgress.add_core(F3_VICTORY_CORE)
		_return_to_home_base()
		return
	if EXTRACT_REWARDS.has(floor_num):
		_show_extract_choice(floor_num)
		return
# (non-boss → fall through to normal loot reward)
```

Then add these helper functions to `battle_scene.gd`:

```gdscript
func _show_extract_choice(floor_num: int) -> void:
	var modal = EXTRACT_CHOICE_MODAL_SCRIPT.new()
	modal.floor_num = floor_num
	modal.reward_continue = int(EXTRACT_REWARDS[floor_num]["continue"])
	modal.reward_extract = int(EXTRACT_REWARDS[floor_num]["extract"])
	modal.chosen.connect(_on_extract_chosen.bind(floor_num))
	add_child(modal)


func _on_extract_chosen(extract: bool, floor_num: int) -> void:
	if extract:
		MetaProgress.add_core(int(EXTRACT_REWARDS[floor_num]["extract"]))
		_return_to_home_base()
	else:
		MetaProgress.add_core(int(EXTRACT_REWARDS[floor_num]["continue"]))
		# Continue to loot, then map (existing flow)
		_proceed_to_loot_reward()


func _return_to_home_base() -> void:
	get_tree().change_scene_to_file(HOME_BASE_SCENE)


func _proceed_to_loot_reward() -> void:
	# Implementation: call whatever the existing post-victory transition already does.
	# Look at site (A) in step 1's grep output — paste that transition here.
	pass  # REPLACE with actual existing transition code
```

**IMPORTANT:** The `_proceed_to_loot_reward()` function body must contain the exact transition code that today fires after a battle win (likely `get_tree().change_scene_to_file(...)` or similar). Copy it verbatim from site (A); don't paraphrase.

- [ ] **Step 4: Wire game-over (player death) to home base**

At site (B) (game-over / player-death handler), replace whatever returns to map with:

```gdscript
get_tree().change_scene_to_file(HOME_BASE_SCENE)
```

If there's a "TRY AGAIN" / "RETURN" button on a game_over scene, point its `pressed` handler at home_base_scene.tscn.

- [ ] **Step 5: Headless boot check**

Run: `godot --headless --path . --quit-after 3`
Expected: clean exit.

- [ ] **Step 6: Commit**

```bash
git add battle_scene/battle_scene.gd
git commit -m "battle_scene: wire boss victory to extract choice (F1/F2) or home base (F3/death)"
```

---

## Task 11: Map-screen game-over routing audit

**Files:**
- Modify: `run_system/ui/map_scene.gd` if it has any "return to title" or "quit run" UI

- [ ] **Step 1: Audit map_scene for run-exit paths**

Run:
```
grep -n "hero_select\|change_scene_to_file\|quit\|exit\|return.*title" run_system/ui/map_scene.gd
```

If any path goes to `hero_select.tscn` as a "give up / abandon run" route, change it to `home_base_scene.tscn` (since post-run state lives in home base now).

If no such path exists, this task is a no-op — record that.

- [ ] **Step 2: Headless boot check**

Run: `godot --headless --path . --quit-after 3`
Expected: clean exit.

- [ ] **Step 3: Commit (only if changes made)**

```bash
git add run_system/ui/map_scene.gd
git commit -m "map_scene: route run-abandon paths to home_base_scene"
```

If no changes, skip commit.

---

## Task 12: End-to-end headless smoke + manual smoke checklist

**Files:** none (verification only)

- [ ] **Step 1: Final headless boot**

Run: `godot --headless --path . --quit-after 5`
Expected: clean exit, `DataValidator: ... passed`, zero `push_error` / `push_warning`.

- [ ] **Step 2: Open Godot editor and run the project**

The first scene should be `home_base_scene`. Verify:
- CORE: 0 in top-right
- 5 upgrade panels visible, all at Lv0
- All BUY buttons disabled (no Core)
- START NEW RUN button visible bottom-right

- [ ] **Step 3: Smoke playthrough — first run**

1. Click START NEW RUN → hero select appears
2. Pick a hero → map appears
3. Play through to Floor 1 boss → win
4. Extract modal appears → click EXTRACT NOW (+50 Core)
5. Return to home base — verify CORE: 50

- [ ] **Step 4: Buy an upgrade**

1. Click BUY on Med Bay → CORE drops to 20, Med Bay shows Lv1, BUY now shows next tier cost (60)
2. Verify save file exists: open `%APPDATA%\Godot\app_userdata\CardFramework\meta.json` (or platform equivalent) → contains `{"core":20,"upgrades":{"med_bay":1}}`

- [ ] **Step 5: Smoke playthrough — second run with Med Bay**

1. START NEW RUN → battle 1
2. Verify max HP = base + 10
3. Push past F1 → click CONTINUE → +25 Core
4. Beat F2 boss → click EXTRACT → +90 Core
5. Verify CORE: 20 + 25 + 90 = 135

- [ ] **Step 6: Persistence check**

1. Quit Godot completely
2. Relaunch the project
3. Verify home base loads with CORE: 135 and Med Bay still Lv1

- [ ] **Step 7: Shop discount check**

1. Buy Scrap Workshop Lv1 (cost 30)
2. Start a run, walk to merchant
3. Verify shop prices visibly reduced (e.g., common card showed 70g before, should show 63g now → ceil(70 × 0.9))

- [ ] **Step 8: Note any failures**

If any step fails, add notes to a NEW commit:
```bash
git commit --allow-empty -m "Phase 4 smoke notes: [list any deviations from expected behavior]"
```

The implementation tasks above are then revised in follow-up commits.

- [ ] **Step 9: Update PRD + PROJECT_STRUCTURE if all green**

In `docs/PRD.md`, find the `⬜ Phase 4` block and mark items shipped:
```markdown
### 🟡 Phase 4 — Base Building & Meta-Progression (MVP shipped)
- ✅ Home base scene with upgrade nodes
- ✅ Core currency persistence across runs
- ✅ Base upgrades: Med Bay, Arsenal, Research Lab, Scrap Workshop, Command Center
- ✅ Extraction flow: post-boss choice screen → base reward
- ⬜ Hero unlock system via base upgrades (deferred)
```

In `docs/PROJECT_STRUCTURE.md`, add a `Base Building` section near the existing systems list:
```markdown
### Base Building (Meta-Progression)
- `run_system/core/meta_progress.gd` — autoload, owns `user://meta.json`
- `run_system/ui/home_base_scene.{gd,tscn}` — boot scene, upgrade UI
- `run_system/ui/upgrade_panel.gd` — reusable widget
- `run_system/ui/extract_choice_modal.gd` — F1/F2 boss extract prompt
- `run_system/data/base_upgrades/*.json` — 5 upgrade definitions
```

Commit:
```bash
git add docs/PRD.md docs/PROJECT_STRUCTURE.md
git commit -m "Docs: mark Phase 4 MVP shipped (base building + extract flow)"
```

---

## Self-review

**Spec coverage:**
- ✅ MetaProgress autoload + persistence — Task 1
- ✅ 5 upgrade JSONs — Task 2
- ✅ DataValidator schema — Task 3
- ✅ UpgradePanel widget — Task 4
- ✅ HomeBaseScene + boot routing — Task 5
- ✅ start_new_run applies upgrades — Task 6
- ✅ Loot rarity bias — Task 7
- ✅ Shop discount — Task 8
- ✅ Extract modal — Task 9
- ✅ Boss victory + death routing — Task 10, 11
- ✅ Smoke verification + docs — Task 12

**Placeholder scan:** Only Task 10 Step 3 has a `pass  # REPLACE with actual existing transition code` placeholder — this is intentional because the existing transition code can't be predicted from outside the file; the implementing agent reads the grep output then copies the line verbatim. The instruction makes this explicit.

**Type consistency:**
- `MetaProgress.get_upgrade_level(id)` returns int — used consistently in upgrade_panel, run_manager helpers, loot_reward, shop_scene
- `_get_meta_effect_value(id)` returns Dictionary — keys vary per effect_key but each consumer knows its own schema (documented in spec)
- `MetaProgress.purchase_upgrade(id, definition)` takes both id AND definition — upgrade_panel passes both
- `chosen(extract: bool)` signal on ExtractChoiceModal — battle_scene binds with `.bind(floor_num)` to know the floor

**Scope check:** 12 tasks, each ≤ 30min implementation work. Total ≈ 4-6 hours. Fits overnight window.

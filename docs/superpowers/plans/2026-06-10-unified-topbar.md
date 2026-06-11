# Unified StS-style Top Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the two divergent top bars (raw-text map bar, chip-based battle bar) with one shared StS-style component that renders HP/XP progress bars, gold/act chips, configurable buttons, and a relic shelf — shown on both map and battle.

**Architecture:** A new scene-agnostic `Control` component (`run_system/ui/run_top_bar.gd`) reads `RunManager` state and emits intent signals; each host scene (map, battle) instantiates it, sets a few config flags, and wires the button signals to its existing handlers. The map's old `_draw_top_bar()` text bar and hand-built buttons are deleted; `battle_top_bar.gd` slims to a host that keeps only its settings menu.

**Tech Stack:** Godot 4.6, GDScript, `wasteland_theme.gd` styling primitives, `Tooltip` + `RunManager` autoloads.

**Verification note (read first):** This project has no unit-test harness; UI is visual. The verification gate for every task is:
1. `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh` → expect `[OK] DataValidator: all schemas passed.` + `[OK] Headless boot clean.`
2. The godot MCP `validate` tool over the project (catches parse errors in the new script, which the headless smoke boot does NOT load on its own).
3. Where noted, a runtime launch + screenshot via the godot MCP for visual confirmation.

**Confirmed API (verified against source):**
- `PlayerEntity` (`battle_scene/player.gd`): `health: int`, `max_health: int`, `signal health_changed(new_amount)`.
- `RunManager` (autoload): `current_health`, `max_health`, `gold`, `current_act`, `const ACTS_TOTAL = 3`, `current_floor`, `level`, `xp`, `xp_to_next(lvl) -> int`, `relics: Array`; signals `health_changed(current, maximum)`, `resources_changed(gold, core)`, `relics_updated`, `backpack_changed`.
- `wasteland_theme.gd` (preload `res://run_system/ui/theme/wasteland_theme.gd`): `panel_flat(bg, border, radius, border_width)`, `panel_textured(variant)`, `button_textured(state)`, `rounded_button(...)`, constants `TEXT_MAIN`, `TEXT_SECONDARY`, `PANEL_BORDER`, `ACCENT_NEON_GREEN`, `ACCENT_NEON_BLUE`.
- `Tooltip` autoload: `show(bbcode, global_pos, owner_id)`, `hide_if_owner(owner_id)`.
- `Settings.t(key, fallback)` for content translation.

---

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `run_system/ui/run_top_bar.gd` | The shared bar: vitals bars, gold/act chips, buttons, relic shelf, refresh + signals | **Create** |
| `run_system/ui/map_scene.gd` | Map host: instantiate bar, wire deck/character signals, drop old buttons | **Modify** |
| `run_system/ui/map_renderer.gd` | Remove the obsolete `_draw_top_bar()` text bar | **Modify** |
| `battle_scene/ui/battle_top_bar.gd` | Battle host: keep settings menu, delegate the visible bar to the component | **Modify** |

No `.tscn` edits: the component is built programmatically and added via `.new()`, matching the existing `battle_top_bar` / map-modal pattern.

---

### Task 1: Create the shared `run_top_bar.gd` component

**Files:**
- Create: `run_system/ui/run_top_bar.gd`

- [ ] **Step 1: Write the full component**

Create `run_system/ui/run_top_bar.gd` with exactly this content:

```gdscript
extends Control

## Shared StS-style top bar used by BOTH the map and battle scenes.
## Renders HP + XP as progress bars, a gold chip, an act/floor chip, a
## configurable button group, and a relic shelf row below the main bar.
##
## Scene-agnostic: it reads RunManager (autoload) state and emits intent
## signals; the HOST scene wires the buttons to its own handlers. Set the
## config properties BEFORE add_child() so _ready() sees them.

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const RELIC_DATA_DIR := "res://run_system/data/relics/"

const MAIN_BAR_HEIGHT := 62.0
const RELIC_ROW_TOP := 66.0
const RELIC_ROW_HEIGHT := 42.0
const BAR_HEIGHT := 108.0

signal deck_pressed
signal character_pressed
signal settings_pressed

## ─── Config (set by host before add_child) ──────────────────────────────────
var hp_from_player: bool = false       # battle = true (live player HP)
var player_source: Node = null         # the PlayerEntity when hp_from_player
var show_character_button: bool = true  # map only (equipment locked in combat)
var show_settings_button: bool = false  # battle only

## ─── Cached nodes ───────────────────────────────────────────────────────────
var _hp_bar: ProgressBar
var _hp_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _gold_label: Label
var _act_label: Label
var _relic_shelf: HBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	anchor_right = 1.0
	offset_bottom = BAR_HEIGHT
	custom_minimum_size = Vector2(0, BAR_HEIGHT)
	_build()
	_connect_state_sources()
	_refresh_all()


# ─── Build ────────────────────────────────────────────────────────────────────

func _build() -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.045, 0.038, 0.03, 0.94)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.anchor_right = 1.0
	bg.offset_bottom = MAIN_BAR_HEIGHT
	add_child(bg)

	var bottom_line := ColorRect.new()
	bottom_line.name = "BottomLine"
	bottom_line.color = Color(0.65, 0.48, 0.25, 0.62)
	bottom_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_line.anchor_right = 1.0
	bottom_line.offset_top = MAIN_BAR_HEIGHT - 3.0
	bottom_line.offset_bottom = MAIN_BAR_HEIGHT
	add_child(bottom_line)

	var margin := MarginContainer.new()
	margin.name = "MainMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.anchor_right = 1.0
	margin.offset_bottom = MAIN_BAR_HEIGHT
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	add_child(margin)

	var row := HBoxContainer.new()
	row.name = "MainRow"
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	# Vitals: HP bar over XP bar.
	var vitals := VBoxContainer.new()
	vitals.add_theme_constant_override("separation", 4)
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(vitals)

	var hp_pair := _make_stat_bar(178, 22, Color(0.82, 0.16, 0.10), Color(0.22, 0.06, 0.05))
	_hp_bar = hp_pair[0]
	_hp_label = hp_pair[1]
	vitals.add_child(_hp_bar)

	var xp_pair := _make_stat_bar(178, 15, T.ACCENT_NEON_GREEN, Color(0.10, 0.14, 0.05))
	_xp_bar = xp_pair[0]
	_xp_label = xp_pair[1]
	vitals.add_child(_xp_bar)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_gold_label = _make_chip(row, Color(0.95, 0.66, 0.22))
	_act_label = _make_chip(row, T.ACCENT_NEON_BLUE)

	var deck_btn := _make_icon_button("D", tr("UI_BATTLE_VIEW_RUN_DECK"))
	deck_btn.pressed.connect(func(): deck_pressed.emit())
	row.add_child(deck_btn)

	if show_character_button:
		var char_btn := _make_icon_button("C", tr("UI_MAP_CHARACTER_BTN"))
		char_btn.pressed.connect(func(): character_pressed.emit())
		row.add_child(char_btn)

	if show_settings_button:
		var set_btn := _make_icon_button("⚙", TranslationServer.translate("SETTINGS_BUTTON"))
		set_btn.pressed.connect(func(): settings_pressed.emit())
		row.add_child(set_btn)

	# Relic shelf (second row).
	_relic_shelf = HBoxContainer.new()
	_relic_shelf.name = "RelicShelf"
	_relic_shelf.anchor_right = 1.0
	_relic_shelf.offset_left = 16.0
	_relic_shelf.offset_top = RELIC_ROW_TOP
	_relic_shelf.offset_right = -16.0
	_relic_shelf.offset_bottom = RELIC_ROW_TOP + RELIC_ROW_HEIGHT
	_relic_shelf.mouse_filter = Control.MOUSE_FILTER_PASS
	_relic_shelf.add_theme_constant_override("separation", 7)
	add_child(_relic_shelf)


func _make_stat_bar(width: float, height: float, fill: Color, track: Color) -> Array:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(width, height)
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", T.panel_flat(track, T.PANEL_BORDER, 4, 2))
	bar.add_theme_stylebox_override("fill", T.panel_flat(fill, fill, 4, 0))

	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", T.TEXT_MAIN)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 3)
	bar.add_child(label)
	return [bar, label]


func _make_chip(parent: Control, accent: Color) -> Label:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _chip_style(accent))
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 11)
	margin.add_theme_constant_override("margin_right", 11)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var label := Label.new()
	label.text = "-"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", T.TEXT_MAIN)
	margin.add_child(label)
	return label


func _chip_style(accent: Color) -> StyleBoxFlat:
	var style := T.panel_flat(Color(0.105, 0.062, 0.035, 0.92), accent.darkened(0.18), 5, 2)
	style.border_width_left = 5
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	style.shadow_size = 3
	style.shadow_offset = Vector2(2, 2)
	return style


func _make_icon_button(text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(42, 40)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", T.TEXT_MAIN)
	button.add_theme_stylebox_override("normal", T.button_textured("normal"))
	button.add_theme_stylebox_override("hover", T.button_textured("hover"))
	button.add_theme_stylebox_override("pressed", T.button_textured("pressed"))
	return button


# ─── State refresh ──────────────────────────────────────────────────────────

func _connect_state_sources() -> void:
	_connect_once(RunManager, "health_changed", "_on_rm_health")
	_connect_once(RunManager, "resources_changed", "_on_rm_resources")
	_connect_once(RunManager, "backpack_changed", "_on_rm_backpack")
	_connect_once(RunManager, "relics_updated", "_on_rm_relics")
	if hp_from_player and is_instance_valid(player_source):
		_connect_once(player_source, "health_changed", "_on_player_health")


func _connect_once(source: Object, signal_name: String, method_name: String) -> void:
	if not is_instance_valid(source) or not source.has_signal(signal_name):
		return
	var cb := Callable(self, method_name)
	if not source.is_connected(signal_name, cb):
		source.connect(signal_name, cb)


func _refresh_all() -> void:
	_refresh_vitals()
	_refresh_gold_act()
	_refresh_relics()


func _hp_values() -> Vector2:
	if hp_from_player and is_instance_valid(player_source):
		return Vector2(player_source.health, player_source.max_health)
	return Vector2(RunManager.current_health, RunManager.max_health)


func _refresh_vitals() -> void:
	if not _hp_bar:
		return
	var hp := _hp_values()
	var hp_max: float = maxf(1.0, hp.y)
	_hp_bar.max_value = hp_max
	_hp_bar.value = clampf(hp.x, 0.0, hp_max)
	_hp_label.text = "%d / %d" % [int(hp.x), int(hp.y)]

	var lvl: int = RunManager.level
	var need: int = RunManager.xp_to_next(lvl)
	var have: int = RunManager.xp
	_xp_bar.max_value = maxf(1.0, float(need))
	_xp_bar.value = clampf(float(have), 0.0, float(need))
	_xp_label.text = "Lv %d · %d/%d" % [lvl, have, need]


func _refresh_gold_act() -> void:
	if not _gold_label:
		return
	_gold_label.text = tr("UI_MAP_TOPBAR_GOLD").format({"n": RunManager.gold})
	_act_label.text = "%s %d/%d · %s %d" % [
		tr("UI_TOPBAR_ACT_SHORT"), RunManager.current_act, RunManager.ACTS_TOTAL,
		tr("UI_TOPBAR_FLOOR_SHORT"), RunManager.current_floor
	]


func _refresh_relics() -> void:
	if not _relic_shelf:
		return
	for child in _relic_shelf.get_children():
		child.queue_free()
	var ids: Array = RunManager.relics if typeof(RunManager.relics) == TYPE_ARRAY else []
	if ids.is_empty():
		return
	var caption := Label.new()
	caption.text = tr("UI_TOPBAR_RELICS_CAPTION")
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", T.TEXT_SECONDARY)
	_relic_shelf.add_child(caption)
	for relic_id in ids:
		_relic_shelf.add_child(_make_relic_medallion(str(relic_id)))


func _make_relic_medallion(relic_id: String) -> Button:
	var data := _load_relic_data(relic_id)
	var title := Settings.t("RELIC_%s_TITLE" % relic_id, str(data.get("title", _humanize_id(relic_id))))
	var desc := Settings.t("RELIC_%s_DESC" % relic_id, str(data.get("description", "")))

	var chip := Button.new()
	chip.text = _short_label(title)
	chip.custom_minimum_size = Vector2(36, 36)
	chip.focus_mode = Control.FOCUS_NONE
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.add_theme_stylebox_override("normal", T.rounded_button(Color(0.09, 0.055, 0.035, 0.82), Color(0.62, 0.42, 0.20), 18, 2))
	chip.add_theme_stylebox_override("hover", T.rounded_button(Color(0.14, 0.085, 0.045, 0.92), T.ACCENT_NEON_BLUE, 18, 2))
	chip.add_theme_stylebox_override("pressed", T.rounded_button(Color(0.05, 0.035, 0.026, 0.95), Color(0.92, 0.70, 0.28), 18, 2))
	chip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	chip.add_theme_color_override("font_color", T.TEXT_MAIN)
	chip.add_theme_font_size_override("font_size", 16)

	var icon_path := str(data.get("icon", ""))
	if not icon_path.is_empty():
		var tex := _load_icon_texture(_resolve_relic_icon_path(icon_path))
		if tex is Texture2D:
			chip.icon = tex
			chip.expand_icon = true
			chip.text = ""

	# Lambda safety (project bug class): guard the captured chip with
	# is_instance_valid; hide-on-tree_exited with an owner token so a stale
	# callback can't leak a tooltip past a relic-shelf rebuild.
	var tip_text := ("[b]%s[/b]\n%s" % [title, desc]) if not desc.is_empty() else "[b]%s[/b]" % title
	var chip_ref: Button = chip
	var chip_id: int = chip.get_instance_id()
	chip.mouse_entered.connect(func():
		if not is_instance_valid(chip_ref):
			return
		Tooltip.show(tip_text, chip_ref.global_position + Vector2(chip_ref.size.x * 0.5, 0), chip_id)
	)
	chip.mouse_exited.connect(Tooltip.hide_if_owner.bind(chip_id))
	chip.tree_exited.connect(Tooltip.hide_if_owner.bind(chip_id))
	return chip


# ─── Signal handlers ──────────────────────────────────────────────────────────

func _on_rm_health(_c: int, _m: int) -> void:
	_refresh_vitals()

func _on_rm_resources(_g: int, _co: int) -> void:
	_refresh_gold_act()

func _on_rm_backpack() -> void:
	_refresh_gold_act()

func _on_rm_relics() -> void:
	_refresh_relics()

func _on_player_health(_current: int) -> void:
	_refresh_vitals()


# ─── Relic data helpers (defensive, mirror battle_top_bar) ────────────────────

func _load_relic_data(relic_id: String) -> Dictionary:
	var data := {"id": relic_id, "title": _humanize_id(relic_id), "description": "", "icon": ""}
	var file := FileAccess.open(RELIC_DATA_DIR + relic_id + ".json", FileAccess.READ)
	if not file:
		return data
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		for key in parsed.keys():
			data[key] = parsed[key]
	return data


func _resolve_relic_icon_path(icon_path: String) -> String:
	if icon_path.begins_with("res://"):
		return icon_path
	return RELIC_DATA_DIR + icon_path


func _load_icon_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is Texture2D:
			return loaded
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image:
			return ImageTexture.create_from_image(image)
	return null


func _humanize_id(value: String) -> String:
	return value.replace("_", " ").capitalize()


func _short_label(value: String) -> String:
	if value.is_empty():
		return "?"
	return value.substr(0, 1).to_upper()
```

- [ ] **Step 2: Add the three new translation keys (zh + en)**

The component references `UI_TOPBAR_ACT_SHORT`, `UI_TOPBAR_FLOOR_SHORT`, and `UI_TOPBAR_RELICS_CAPTION`. Find the UI translation CSV (run: `mcp__godot__search_project` or `Grep` for `UI_MAP_TOPBAR_GOLD` to locate the file — it is the same CSV). Add rows:

```
UI_TOPBAR_ACT_SHORT,幕,Act
UI_TOPBAR_FLOOR_SHORT,层,Floor
UI_TOPBAR_RELICS_CAPTION,遗物,Relics
```

Match the CSV's exact column order/header (keys, `zh`/`en` columns) as the existing `UI_MAP_TOPBAR_*` rows. If the CSV has more locale columns, fill them with the English value.

- [ ] **Step 3: Reimport translations**

Run: `"C:/Program Files/Godot/Godot.exe" --headless --path . --import`
Expected: completes without error (regenerates `.translation` from the edited CSV).

- [ ] **Step 4: Validate the new script parses**

Use the godot MCP `validate` tool on the project (or run a headless editor import). Expected: no parse errors reported for `run_system/ui/run_top_bar.gd`.

- [ ] **Step 5: Smoke test**

Run: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
Expected tail: `[OK] DataValidator: all schemas passed.` + `[OK] Headless boot clean.`

- [ ] **Step 6: Commit**

```bash
git add run_system/ui/run_top_bar.gd
git add <the translations CSV path from Step 2>
git commit -m "feat(ui): shared StS-style run_top_bar component (vitals bars + relic shelf)"
```

(Do NOT stage the regenerated `*.translation` / `*.import` sidecars — per handoff rules.)

---

### Task 2: Wire the component into the map scene

**Files:**
- Modify: `run_system/ui/map_scene.gd`
- Modify: `run_system/ui/map_renderer.gd`

- [ ] **Step 1: Add the component preload to map_scene**

In `run_system/ui/map_scene.gd`, add to the preload block near the top (after the existing `RUN_DECK_VIEWER_MODAL` const, around line 10):

```gdscript
const RUN_TOP_BAR = preload("res://run_system/ui/run_top_bar.gd")
```

- [ ] **Step 2: Replace the two button builders with a top-bar builder**

In `map_scene._ready()`, find these two calls (around lines 71-72):

```gdscript
	_build_equipment_button()
	_build_deck_button()
```

Replace them with:

```gdscript
	_build_top_bar()
```

Then DELETE the `_build_equipment_button()` function (lines ~564-579) and the `_build_deck_button()` function (lines ~592-607) entirely. KEEP `_open_equipment_panel()` and `_open_run_deck_viewer()` — they are now invoked via signal.

Add this new function in their place:

```gdscript
func _build_top_bar() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TopBarLayer"
	layer.layer = 50
	add_child(layer)

	var bar = RUN_TOP_BAR.new()
	bar.hp_from_player = false
	bar.show_character_button = true
	bar.show_settings_button = false
	bar.deck_pressed.connect(_open_run_deck_viewer)
	bar.character_pressed.connect(_open_equipment_panel)
	layer.add_child(bar)
```

- [ ] **Step 3: Remove the obsolete drawn top bar from the renderer**

In `run_system/ui/map_renderer.gd`, in `draw()` (around line 55), remove the line:

```gdscript
	_draw_top_bar(vp)
```

Then DELETE the entire `_draw_top_bar(vp: Vector2)` function (lines ~261-317). The legend draw stays.

- [ ] **Step 4: Validate both scripts parse**

Use the godot MCP `validate` tool. Expected: no parse errors in `map_scene.gd` or `map_renderer.gd`.

- [ ] **Step 5: Smoke test**

Run: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
Expected tail: `[OK] DataValidator: all schemas passed.` + `[OK] Headless boot clean.`

- [ ] **Step 6: Runtime visual check (map)**

Launch the project via the godot MCP `run_project`, navigate to / start a run so the map scene shows, and `take_screenshot`. Expected: top bar shows framed HP bar + XP bar on the left, gold + act/floor chips and Deck/Character buttons on the right, and (if any relics are owned) a relic shelf below. No raw `生命 40/50` text remains. Confirm Deck and Character buttons open their panels.

- [ ] **Step 7: Commit**

```bash
git add run_system/ui/map_scene.gd run_system/ui/map_renderer.gd
git commit -m "feat(ui): map scene uses shared run_top_bar; drop drawn text bar + hand-built buttons"
```

---

### Task 3: Slim `battle_top_bar.gd` to a host for the component

**Files:**
- Modify: `battle_scene/ui/battle_top_bar.gd`

- [ ] **Step 1: Add the component preload**

In `battle_scene/ui/battle_top_bar.gd`, add after the existing `SETTINGS_PANEL` preload (around line 4):

```gdscript
const RUN_TOP_BAR = preload("res://run_system/ui/run_top_bar.gd")
```

- [ ] **Step 2: Replace the build/refresh internals with component instantiation**

Replace the `_setup()` function (currently lines ~31-37) with:

```gdscript
func _setup() -> void:
	main = get_tree().current_scene
	_build_settings_menu()

	var bar = RUN_TOP_BAR.new()
	bar.hp_from_player = true
	bar.player_source = main.player if (main and "player" in main) else null
	bar.show_character_button = false
	bar.show_settings_button = true
	bar.deck_pressed.connect(_on_deck_pressed)
	bar.settings_pressed.connect(_show_settings)
	add_child(bar)
```

- [ ] **Step 3: Delete the migrated members**

DELETE the following from `battle_top_bar.gd` — they now live in `run_top_bar.gd`:
- Constants: `RELIC_DATA_DIR`, `TOP_BAR_HEIGHT`, `RELIC_ROW_TOP`, `BAR_HEIGHT`.
- Vars: `hp_value_label`, `gold_value_label`, `floor_value_label`, `level_value_label`, `relic_strip`, `deck_button`, `settings_button`.
- Functions: `_build_bar`, `_connect_state_sources`, `_connect_signal_once`, `_refresh_all`, `_refresh_status`, `_refresh_relics`, `_make_relic_chip`, `_add_status_chip`, `_status_chip_style`, `_load_relic_data`, `_resolve_relic_icon_path`, `_load_icon_texture`, `_make_icon_button`, `_on_run_health_changed`, `_on_resources_changed`, `_on_deck_updated`, `_on_relics_updated`, `_on_player_health_changed`, `_on_relic_pressed`, `_humanize_id`, `_short_label`.

KEEP: `main` var, `settings_layer`, `return_map_button` vars; `_ready`, `_input`, `_build_settings_menu`, `_make_menu_button`, `_on_deck_pressed`, `_show_settings`, `_hide_settings`, `_on_return_map_pressed`, `_get_run_manager`.

`_make_menu_button` currently calls `_make_icon_button` (being deleted). Make it self-contained by replacing it with:

```gdscript
func _make_menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300, 44)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", T.TEXT_MAIN)
	button.add_theme_stylebox_override("normal", T.button_textured("normal"))
	button.add_theme_stylebox_override("hover", T.button_textured("hover"))
	button.add_theme_stylebox_override("pressed", T.button_textured("pressed"))
	return button
```

Confirm the surviving `_ready` no longer sets `custom_minimum_size`/`BAR_HEIGHT` (the component owns its own size). If `_ready` referenced `BAR_HEIGHT`, change it to a literal `108` or drop that line — the host Control is sized by the `.tscn` anchors.

- [ ] **Step 4: Verify `_on_deck_pressed` and `_show_settings` signatures take no args**

`deck_pressed` and `settings_pressed` emit with no arguments. Confirm `_on_deck_pressed()` and `_show_settings()` are zero-arg (they are in the current file). No change needed; this step is a read-check.

- [ ] **Step 5: Validate the script parses**

Use the godot MCP `validate` tool. Expected: no parse errors, no references to deleted members.

- [ ] **Step 6: Smoke test**

Run: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
Expected tail: `[OK] DataValidator: all schemas passed.` + `[OK] Headless boot clean.`

- [ ] **Step 7: Runtime visual check (battle)**

Launch via godot MCP, enter a battle, `take_screenshot`. Expected: same StS-style bar as the map (HP bar reflects LIVE combat HP, XP bar, gold + act/floor chips, Deck + Settings buttons, relic shelf). Take damage and confirm the HP bar updates live. Open Settings and confirm the menu still works (resume / return-to-map).

- [ ] **Step 8: Commit**

```bash
git add battle_scene/ui/battle_top_bar.gd
git commit -m "refactor(ui): battle_top_bar hosts shared run_top_bar; keep only settings menu"
```

---

### Task 4: Final verification + file-size + docs

**Files:**
- Modify (docs): `docs/conventions/ui-code.md` (locations table + file-size table)

- [ ] **Step 1: Confirm file sizes are under the ~400-line soft cap**

Run (PowerShell): `(Get-Content run_system/ui/run_top_bar.gd).Count; (Get-Content battle_scene/ui/battle_top_bar.gd).Count`
Expected: both well under 400. If `run_top_bar.gd` exceeds ~400, note it (it should land ~300).

- [ ] **Step 2: Update the UI conventions doc**

In `docs/conventions/ui-code.md`:
- In the Locations table (around line 12), update the battle top-bar row and add a shared row:
  - `| Shared top bar (HP/XP bars, gold/act chips, relic shelf) | run_system/ui/run_top_bar.gd |`
  - `| Battle top-bar host (settings menu only) | battle_scene/ui/battle_top_bar.gd |`
- In the File-size table (around line 89-93), replace the `battle_top_bar.gd | ~385 | ⚠️ Approaching cap` row with the new measured count + `✅ Slimmed (delegates to run_top_bar)`, and add a `run_top_bar.gd` row with its measured count.

- [ ] **Step 3: Regenerate catalogs (only if content changed — it did NOT)**

No card/relic/equipment/enemy data changed, so `gen_catalog_html.py` is not required this task. Skip.

- [ ] **Step 4: Final smoke test**

Run: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
Expected tail: `[OK] DataValidator: all schemas passed.` + `[OK] Headless boot clean.`

- [ ] **Step 5: Commit**

```bash
git add docs/conventions/ui-code.md
git commit -m "docs: ui-code conventions reflect shared run_top_bar split"
```

---

## Self-Review

**Spec coverage:**
- Shared component used by both scenes → Task 1 (create) + Task 2 (map host) + Task 3 (battle host). ✅
- HP/XP as progress bars with overlay labels → Task 1 `_make_stat_bar` + `_refresh_vitals`. ✅
- Relic shelf on both scenes → Task 1 `_relic_shelf` + `_make_relic_medallion`, rendered in both hosts. ✅
- Config flags (`hp_from_player`, `player_source`, `show_character_button`, `show_settings_button`) → Task 1 vars, set in Tasks 2-3. ✅
- Signals (`deck_pressed`/`character_pressed`/`settings_pressed`) wired per host → Tasks 2-3. ✅
- Gold from `backpack_changed` (stale-gold risk) → Task 1 `_connect_state_sources` connects `backpack_changed`. ✅
- Remove map drawn bar + hand-built buttons → Task 2. ✅
- Slim battle host, keep settings menu → Task 3. ✅
- Battle shows act/floor too (unified) → Task 1 `_refresh_gold_act` used by both. ✅
- File-size cap watch → Task 4. ✅
- Lambda-safety for relic tooltips → Task 1 `_make_relic_medallion`. ✅

**Placeholder scan:** No TBD/TODO; all code blocks complete. The one lookup deferred to execution is the translations CSV path (Task 1 Step 2) — resolved by an explicit Grep instruction, not a guess. ✅

**Type consistency:** `_make_stat_bar` returns `Array [bar, label]` consumed in `_build`; signal names (`deck_pressed`/`character_pressed`/`settings_pressed`) match between emit sites (Task 1) and connect sites (Tasks 2-3); `_on_deck_pressed`/`_show_settings`/`_open_run_deck_viewer`/`_open_equipment_panel` are all confirmed zero-arg. ✅

**Out-of-scope confirmed untouched:** `character_hud.gd`, relic data, map settings menu, `.tres` migration. ✅

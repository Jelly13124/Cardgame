## Home base scene — the boot scene + post-run return point.
## Shows Core balance + 5 UpgradePanels + START NEW RUN button.
## Loads upgrade definitions from run_system/data/base_upgrades/.
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const UPGRADE_PANEL_SCRIPT = preload("res://run_system/ui/upgrade_panel.gd")
const HERO_SELECT_PACKED = preload("res://run_system/ui/hero_select.tscn")
const UPGRADE_DIR := "res://run_system/data/base_upgrades/"
const UPGRADE_ORDER := ["med_bay", "arsenal", "research_lab", "scrap_workshop", "command_center"]

var _core_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	MetaProgress.core_changed.connect(func(_v): _refresh_core())


func _build() -> void:
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
	get_tree().change_scene_to_packed(HERO_SELECT_PACKED)

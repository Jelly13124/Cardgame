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
var hp_from_player: bool = false  # battle = true (live player HP)
var player_source: Node = null  # the PlayerEntity when hp_from_player
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
		var set_btn := _make_icon_button("⚙", tr("SETTINGS_BUTTON"))
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
	_xp_label.text = tr("UI_TOPBAR_LEVEL_FMT").format({"lvl": lvl, "xp": have, "next": need})


func _refresh_gold_act() -> void:
	if not _gold_label:
		return
	_gold_label.text = tr("UI_MAP_TOPBAR_GOLD").format({"n": RunManager.gold})
	_act_label.text = (
		"%s %d/%d · %s %d"
		% [
			tr("UI_TOPBAR_ACT_SHORT"),
			RunManager.current_act,
			RunManager.ACTS_TOTAL,
			tr("UI_TOPBAR_FLOOR_SHORT"),
			RunManager.current_floor
		]
	)


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
	var title := Settings.t(
		"RELIC_%s_TITLE" % relic_id, str(data.get("title", _humanize_id(relic_id)))
	)
	var desc := Settings.t("RELIC_%s_DESC" % relic_id, str(data.get("description", "")))

	var chip := Button.new()
	chip.text = _short_label(title)
	chip.custom_minimum_size = Vector2(36, 36)
	chip.focus_mode = Control.FOCUS_NONE
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.add_theme_stylebox_override(
		"normal", T.rounded_button(Color(0.09, 0.055, 0.035, 0.82), Color(0.62, 0.42, 0.20), 18, 2)
	)
	chip.add_theme_stylebox_override(
		"hover", T.rounded_button(Color(0.14, 0.085, 0.045, 0.92), T.ACCENT_NEON_BLUE, 18, 2)
	)
	chip.add_theme_stylebox_override(
		"pressed", T.rounded_button(Color(0.05, 0.035, 0.026, 0.95), Color(0.92, 0.70, 0.28), 18, 2)
	)
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
	var tip_text := (
		("[b]%s[/b]\n%s" % [title, desc]) if not desc.is_empty() else "[b]%s[/b]" % title
	)
	var chip_ref: Button = chip
	var chip_id: int = chip.get_instance_id()
	chip.mouse_entered.connect(
		func():
			if not is_instance_valid(chip_ref):
				return
			Tooltip.show(
				tip_text, chip_ref.global_position + Vector2(chip_ref.size.x * 0.5, 0), chip_id
			)
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

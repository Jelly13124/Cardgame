extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const SETTINGS_PANEL = preload("res://run_system/ui/settings_panel.gd")
const RELIC_DATA_DIR := "res://run_system/data/relics/"
# Lazy-loaded at call site to avoid map→battle→map cyclic preload.
const MAP_SCENE_PATH := "res://run_system/ui/map_scene.tscn"
const TOP_BAR_HEIGHT := 62.0
const RELIC_ROW_TOP := 68.0
const BAR_HEIGHT := 108.0

## --- Kenney Sci-Fi UI demo (CC0, kenney.nl) — reversible top-bar reskin test ---
const KENNEY_TRACK = preload("res://battle_scene/assets/images/ui/kenney_demo/bar_track.png")
const KENNEY_HP = preload("res://battle_scene/assets/images/ui/kenney_demo/bar_hp.png")
const KENNEY_XP = preload("res://battle_scene/assets/images/ui/kenney_demo/bar_xp.png")

var main: Node
var hp_value_label: Label
var gold_value_label: Label
var floor_value_label: Label
var level_value_label: Label
var hp_bar: TextureProgressBar
var xp_bar: TextureProgressBar
var relic_strip: HBoxContainer
var deck_button: Button
var settings_button: Button
var settings_layer: CanvasLayer
var return_map_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(0, BAR_HEIGHT)
	call_deferred("_setup")


func _setup() -> void:
	main = get_tree().current_scene
	_build_bar()
	_build_settings_menu()
	_connect_state_sources()
	_refresh_all()


func _input(event: InputEvent) -> void:
	if settings_layer and settings_layer.visible and event.is_action_pressed("ui_cancel"):
		_hide_settings()
		get_viewport().set_input_as_handled()


func _build_bar() -> void:
	for child in get_children():
		child.queue_free()

	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.045, 0.038, 0.03, 0.94)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.anchor_right = 1.0
	bg.offset_bottom = TOP_BAR_HEIGHT
	add_child(bg)

	var bottom_line = ColorRect.new()
	bottom_line.name = "BottomLine"
	bottom_line.color = Color(0.65, 0.48, 0.25, 0.58)
	bottom_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_line.anchor_right = 1.0
	bottom_line.offset_top = TOP_BAR_HEIGHT - 2.0
	bottom_line.offset_bottom = TOP_BAR_HEIGHT
	add_child(bottom_line)

	var margin = MarginContainer.new()
	margin.name = "Margin"
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.anchor_right = 1.0
	margin.offset_bottom = TOP_BAR_HEIGHT
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	add_child(margin)

	var row = HBoxContainer.new()
	row.name = "StatusRow"
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var hp_chip = _add_bar_chip(row, "HP", KENNEY_HP, Color(0.82, 0.16, 0.10))
	hp_value_label = hp_chip["label"]
	hp_bar = hp_chip["bar"]
	gold_value_label = _add_status_chip(row, "GOLD", 122, Color(0.95, 0.66, 0.22))
	floor_value_label = _add_status_chip(row, "FLOOR", 92, T.ACCENT_NEON_BLUE)
	var lv_chip = _add_bar_chip(row, "LV", KENNEY_XP, Color(0.55, 0.9, 0.7))
	level_value_label = lv_chip["label"]
	xp_bar = lv_chip["bar"]

	var spacer = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	deck_button = _make_icon_button("D", tr("UI_BATTLE_VIEW_RUN_DECK"))
	deck_button.pressed.connect(_on_deck_pressed)
	row.add_child(deck_button)

	settings_button = _make_icon_button("⚙", TranslationServer.translate("SETTINGS_BUTTON"))
	settings_button.pressed.connect(_show_settings)
	row.add_child(settings_button)

	relic_strip = HBoxContainer.new()
	relic_strip.name = "RelicStrip"
	relic_strip.custom_minimum_size = Vector2(0, 40)
	relic_strip.anchor_right = 1.0
	relic_strip.offset_left = 14.0
	relic_strip.offset_top = RELIC_ROW_TOP
	relic_strip.offset_right = -14.0
	relic_strip.offset_bottom = RELIC_ROW_TOP + 40.0
	relic_strip.mouse_filter = Control.MOUSE_FILTER_PASS
	relic_strip.add_theme_constant_override("separation", 7)
	add_child(relic_strip)


func _build_settings_menu() -> void:
	settings_layer = CanvasLayer.new()
	settings_layer.name = "SettingsLayer"
	settings_layer.layer = 130
	settings_layer.visible = false
	settings_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(settings_layer)

	var root = Control.new()
	root.name = "SettingsRoot"
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_layer.add_child(root)

	var overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.58)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)

	var center = CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(420, 420)
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	center.add_child(panel)

	var box = VBoxContainer.new()
	box.name = "Content"
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title = Label.new()
	title.text = TranslationServer.translate("SETTINGS_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48))
	box.add_child(title)

	# Language / Fullscreen / Volume. Language change reloads the battle scene.
	SETTINGS_PANEL.add_controls(box, func() -> void: get_tree().reload_current_scene(), true)

	var sep = HSeparator.new()
	box.add_child(sep)

	var resume = _make_menu_button(TranslationServer.translate("SETTINGS_RESUME"))
	resume.pressed.connect(_hide_settings)
	box.add_child(resume)

	return_map_button = _make_menu_button(TranslationServer.translate("SETTINGS_RETURN_MAP"))
	return_map_button.pressed.connect(_on_return_map_pressed)
	box.add_child(return_map_button)

	var exit_button = _make_menu_button(TranslationServer.translate("SETTINGS_EXIT"))
	exit_button.disabled = true
	box.add_child(exit_button)


func _connect_state_sources() -> void:
	var rm = _get_run_manager()
	if rm:
		_connect_signal_once(rm, "health_changed", "_on_run_health_changed")
		_connect_signal_once(rm, "resources_changed", "_on_resources_changed")
		_connect_signal_once(rm, "deck_updated", "_on_deck_updated")
		_connect_signal_once(rm, "relics_updated", "_on_relics_updated")

	if main and "player" in main and main.player:
		_connect_signal_once(main.player, "health_changed", "_on_player_health_changed")


func _connect_signal_once(source: Object, signal_name: String, method_name: String) -> void:
	if not source.has_signal(signal_name):
		return
	var cb = Callable(self, method_name)
	if not source.is_connected(signal_name, cb):
		source.connect(signal_name, cb)


func _refresh_all() -> void:
	_refresh_status()
	_refresh_relics()


func _refresh_status() -> void:
	if not hp_value_label or not gold_value_label or not floor_value_label:
		return

	var hp_current = 0
	var hp_max = 0
	if main and "player" in main and main.player and is_instance_valid(main.player):
		hp_current = int(main.player.health)
		hp_max = int(main.player.max_health)

	var rm = _get_run_manager()
	var gold = int(rm.gold) if rm else 0
	var floor_text = str(rm.current_floor) if rm and rm.get("is_run_active") else "-"
	hp_value_label.text = "%d / %d" % [hp_current, hp_max]
	if hp_bar and hp_max > 0:
		hp_bar.value = clampf(100.0 * float(hp_current) / float(hp_max), 0.0, 100.0)
	gold_value_label.text = str(gold)
	floor_value_label.text = floor_text
	if level_value_label and rm:
		level_value_label.text = "LV %d" % rm.level
		if xp_bar:
			var nxt: int = max(1, rm.xp_to_next(rm.level))
			xp_bar.value = clampf(100.0 * float(rm.xp) / float(nxt), 0.0, 100.0)


func _refresh_relics() -> void:
	if not relic_strip:
		return
	for child in relic_strip.get_children():
		child.queue_free()

	var rm = _get_run_manager()
	var ids: Array = []
	if rm:
		var raw = rm.get("relics")
		if typeof(raw) == TYPE_ARRAY:
			ids = raw

	if ids.is_empty():
		return

	for relic_id in ids:
		relic_strip.add_child(_make_relic_chip(str(relic_id)))


func _make_relic_chip(relic_id: String) -> Button:
	var data = _load_relic_data(relic_id)
	# Relic title/description are CONTENT (owned by the content_relics CSV) —
	# route through Settings.t with the deterministic content keys, English fallback.
	var title = Settings.t(
		"RELIC_%s_TITLE" % relic_id, str(data.get("title", _humanize_id(relic_id)))
	)
	var desc = Settings.t("RELIC_%s_DESC" % relic_id, str(data.get("description", "")))
	var chip = Button.new()
	chip.text = _short_label(title)
	chip.custom_minimum_size = Vector2(38, 38)
	chip.focus_mode = Control.FOCUS_NONE
	# Use the custom Tooltip autoload (richer styling than Godot's default
	# tooltip_text). Anchored above the chip center so it doesn't follow
	# the cursor across the top bar. Guard the lambda against firing on a
	# freed chip (e.g. relic strip refresh mid-hover), and tree_exited
	# forces hide so a stuck tooltip can't leak past the chip's lifetime.
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
	chip.add_theme_stylebox_override(
		"normal", T.rounded_button(Color(0.09, 0.055, 0.035, 0.78), Color(0.52, 0.35, 0.16), 4, 2)
	)
	chip.add_theme_stylebox_override(
		"hover", T.rounded_button(Color(0.14, 0.085, 0.045, 0.90), T.ACCENT_NEON_BLUE, 4, 2)
	)
	chip.add_theme_stylebox_override(
		"pressed", T.rounded_button(Color(0.05, 0.035, 0.026, 0.95), Color(0.92, 0.70, 0.28), 4, 2)
	)
	chip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	chip.add_theme_color_override("font_color", T.TEXT_MAIN)
	chip.add_theme_font_size_override("font_size", 17)

	var icon_path = str(data.get("icon", ""))
	if not icon_path.is_empty():
		var tex = _load_icon_texture(_resolve_relic_icon_path(icon_path))
		if tex is Texture2D:
			chip.icon = tex
			chip.expand_icon = true
			chip.text = ""

	chip.pressed.connect(_on_relic_pressed.bind(data))
	return chip


## A chip with a caption + a Kenney textured progress bar, the value drawn over it.
## Returns {label, bar}. Used for HP and XP/LV.
func _add_bar_chip(
	parent: Control, caption: String, fill_tex: Texture2D, accent: Color
) -> Dictionary:
	var panel = PanelContainer.new()
	panel.name = "%sBarChip" % caption.capitalize()
	panel.custom_minimum_size = Vector2(150, 46)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _status_chip_style(accent))
	parent.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	margin.add_child(box)

	var caption_label = Label.new()
	caption_label.text = caption
	caption_label.add_theme_font_size_override("font_size", 11)
	caption_label.add_theme_color_override("font_color", Color(0.78, 0.62, 0.42))
	box.add_child(caption_label)

	var bar = TextureProgressBar.new()
	bar.texture_under = KENNEY_TRACK
	bar.texture_progress = fill_tex
	bar.nine_patch_stretch = true
	bar.stretch_margin_left = 8
	bar.stretch_margin_right = 8
	bar.custom_minimum_size = Vector2(126, 18)
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 100
	box.add_child(bar)

	var value_label = Label.new()
	value_label.text = "-"
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.85))
	value_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	value_label.add_theme_constant_override("outline_size", 3)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(value_label)
	return {"label": value_label, "bar": bar}


func _add_status_chip(parent: Control, caption: String, min_width: float, accent: Color) -> Label:
	var panel = PanelContainer.new()
	panel.name = "%sChip" % caption.capitalize()
	panel.custom_minimum_size = Vector2(min_width, 46)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _status_chip_style(accent))
	parent.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	margin.add_child(box)

	var caption_label = Label.new()
	caption_label.text = caption
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption_label.add_theme_font_size_override("font_size", 11)
	caption_label.add_theme_color_override("font_color", Color(0.78, 0.62, 0.42))
	box.add_child(caption_label)

	var value_label = Label.new()
	value_label.text = "-"
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.add_theme_color_override("font_color", T.TEXT_MAIN)
	box.add_child(value_label)
	return value_label


func _status_chip_style(accent: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.105, 0.062, 0.035, 0.92)
	style.border_color = Color(0.42, 0.24, 0.12)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	style.shadow_size = 3
	style.shadow_offset = Vector2(2, 2)
	style.border_width_left = 5
	style.border_color = accent.darkened(0.18)
	return style


func _load_relic_data(relic_id: String) -> Dictionary:
	var data = {
		"id": relic_id,
		"title": _humanize_id(relic_id),
		"description": "",
		"icon": "",
	}
	var file = FileAccess.open(RELIC_DATA_DIR + relic_id + ".json", FileAccess.READ)
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
		var image = Image.load_from_file(path)
		if image:
			return ImageTexture.create_from_image(image)
	return null


func _make_icon_button(text: String, tooltip: String) -> Button:
	var button = Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(44, 42)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", T.TEXT_MAIN)
	# Codex's textured 9-slice button (normal / hover / pressed PNGs)
	button.add_theme_stylebox_override("normal", T.button_textured("normal"))
	button.add_theme_stylebox_override("hover", T.button_textured("hover"))
	button.add_theme_stylebox_override("pressed", T.button_textured("pressed"))
	return button


func _make_menu_button(text: String) -> Button:
	var button = _make_icon_button(text, text)
	button.custom_minimum_size = Vector2(300, 44)
	button.add_theme_font_size_override("font_size", 20)
	return button


func _on_deck_pressed() -> void:
	if main and main.ui_manager:
		main.ui_manager.show_run_deck_viewer()


func _show_settings() -> void:
	if not settings_layer:
		return
	var rm = _get_run_manager()
	if return_map_button:
		return_map_button.disabled = not (rm and rm.get("is_run_active"))
	settings_layer.visible = true
	get_tree().paused = true


func _hide_settings() -> void:
	if settings_layer:
		settings_layer.visible = false
	get_tree().paused = false


func _on_return_map_pressed() -> void:
	var rm = _get_run_manager()
	if not (rm and rm.get("is_run_active")):
		return
	_hide_settings()
	get_tree().change_scene_to_file(MAP_SCENE_PATH)


func _on_relic_pressed(data: Dictionary) -> void:
	var relic_id = str(data.get("id", ""))
	var title = Settings.t("RELIC_%s_TITLE" % relic_id, str(data.get("title", "Relic")))
	var desc = Settings.t("RELIC_%s_DESC" % relic_id, str(data.get("description", "")))
	var text = title if desc.is_empty() else "%s: %s" % [title, desc]
	if main and main.has_method("show_notification"):
		main.show_notification(text, Color(1.0, 0.86, 0.45))


func _on_run_health_changed(_current: int, _maximum: int) -> void:
	_refresh_status()


func _on_resources_changed(_gold: int, _core: int) -> void:
	_refresh_status()


func _on_deck_updated() -> void:
	pass


func _on_relics_updated() -> void:
	_refresh_relics()


func _on_player_health_changed(_current: int) -> void:
	_refresh_status()


func _get_run_manager() -> Node:
	# RunManager is a registered autoload (project.godot) — always available.
	return RunManager


func _humanize_id(value: String) -> String:
	return value.replace("_", " ").capitalize()


func _short_label(value: String) -> String:
	if value.is_empty():
		return "?"
	return value.substr(0, 1).to_upper()

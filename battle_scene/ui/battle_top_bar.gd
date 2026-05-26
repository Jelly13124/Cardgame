extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const RELIC_DATA_DIR := "res://run_system/data/relics/"
# Lazy-loaded at call site to avoid map→battle→map cyclic preload.
const MAP_SCENE_PATH := "res://run_system/ui/map_scene.tscn"
const BAR_HEIGHT := 62.0

var main: Node
var status_label: Label
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
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var bottom_line = ColorRect.new()
	bottom_line.name = "BottomLine"
	bottom_line.color = Color(0.65, 0.48, 0.25, 0.58)
	bottom_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_line.anchor_top = 1.0
	bottom_line.anchor_right = 1.0
	bottom_line.anchor_bottom = 1.0
	bottom_line.offset_top = -2.0
	add_child(bottom_line)
	
	var margin = MarginContainer.new()
	margin.name = "Margin"
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	add_child(margin)
	
	var row = HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)
	
	status_label = Label.new()
	status_label.name = "RunStatus"
	status_label.custom_minimum_size = Vector2(360, 42)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color(0.94, 0.86, 0.68))
	row.add_child(status_label)
	
	relic_strip = HBoxContainer.new()
	relic_strip.name = "RelicStrip"
	relic_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relic_strip.mouse_filter = Control.MOUSE_FILTER_PASS
	relic_strip.add_theme_constant_override("separation", 8)
	row.add_child(relic_strip)
	
	deck_button = _make_icon_button("D", "View run deck")
	deck_button.pressed.connect(_on_deck_pressed)
	row.add_child(deck_button)
	
	settings_button = _make_icon_button("⚙", "Settings")
	settings_button.pressed.connect(_show_settings)
	row.add_child(settings_button)


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
	panel.custom_minimum_size = Vector2(360, 250)
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	center.add_child(panel)
	
	var box = VBoxContainer.new()
	box.name = "Content"
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	
	var title = Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48))
	box.add_child(title)
	
	var resume = _make_menu_button("Resume")
	resume.pressed.connect(_hide_settings)
	box.add_child(resume)
	
	return_map_button = _make_menu_button("Return to Map")
	return_map_button.pressed.connect(_on_return_map_pressed)
	box.add_child(return_map_button)
	
	var exit_button = _make_menu_button("Exit")
	exit_button.disabled = true
	exit_button.tooltip_text = "Coming soon"
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
	if not status_label:
		return
	
	var hp_current = 0
	var hp_max = 0
	if main and "player" in main and main.player and is_instance_valid(main.player):
		hp_current = int(main.player.health)
		hp_max = int(main.player.max_health)
	
	var rm = _get_run_manager()
	var gold = int(rm.gold) if rm else 0
	var floor_text = str(rm.current_floor) if rm and rm.get("is_run_active") else "-"
	status_label.text = "HP %d/%d    Gold %d    Floor %s" % [hp_current, hp_max, gold, floor_text]


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
		var empty = Label.new()
		empty.text = "No relics"
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", Color(0.65, 0.6, 0.5, 0.8))
		relic_strip.add_child(empty)
		return
	
	for relic_id in ids:
		relic_strip.add_child(_make_relic_chip(str(relic_id)))


func _make_relic_chip(relic_id: String) -> Button:
	var data = _load_relic_data(relic_id)
	var title = str(data.get("title", _humanize_id(relic_id)))
	var desc = str(data.get("description", ""))
	var chip = Button.new()
	chip.text = _short_label(title)
	chip.custom_minimum_size = Vector2(42, 42)
	chip.focus_mode = Control.FOCUS_NONE
	# Use the custom Tooltip autoload (richer styling than Godot's default
	# tooltip_text). Anchored above the chip center so it doesn't follow
	# the cursor across the top bar.
	var tip_text := ("[b]%s[/b]\n%s" % [title, desc]) if not desc.is_empty() else "[b]%s[/b]" % title
	chip.mouse_entered.connect(func(): Tooltip.show(tip_text, chip.global_position + Vector2(chip.size.x * 0.5, 0)))
	chip.mouse_exited.connect(Tooltip.hide)
	chip.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	chip.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	chip.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	chip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	chip.add_theme_color_override("font_color", T.TEXT_MAIN)
	chip.add_theme_font_size_override("font_size", 18)
	
	var icon_path = str(data.get("icon", ""))
	if not icon_path.is_empty():
		var tex = _load_icon_texture(_resolve_relic_icon_path(icon_path))
		if tex is Texture2D:
			chip.icon = tex
			chip.expand_icon = true
			chip.text = ""
	
	chip.pressed.connect(_on_relic_pressed.bind(data))
	return chip


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
	button.add_theme_stylebox_override("normal",  T.button_textured("normal"))
	button.add_theme_stylebox_override("hover",   T.button_textured("hover"))
	button.add_theme_stylebox_override("pressed", T.button_textured("pressed"))
	return button


func _make_menu_button(text: String) -> Button:
	var button = _make_icon_button(text, text)
	button.custom_minimum_size = Vector2(300, 44)
	button.add_theme_font_size_override("font_size", 18)
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
	var title = str(data.get("title", "Relic"))
	var desc = str(data.get("description", ""))
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

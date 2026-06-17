extends Control
## Host for the battle scene's top bar. Mounts the shared run_top_bar component
## and owns the in-battle settings overlay (pause menu).

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const SETTINGS_PANEL = preload("res://run_system/ui/settings_panel.gd")
const RUN_TOP_BAR = preload("res://run_system/ui/run_top_bar.gd")
# Lazy-loaded at call site to avoid map→battle→map cyclic preload.
const MAP_SCENE_PATH := "res://run_system/ui/map_scene.tscn"

var main: Node
var settings_layer: CanvasLayer
var return_map_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_PASS
	call_deferred("_setup")


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


func _input(event: InputEvent) -> void:
	# ESC toggles the in-battle settings/pause menu: open it when closed, close it
	# when open. (battle_top_bar is PROCESS_MODE_ALWAYS so this still fires while
	# the menu has the tree paused.)
	if not event.is_action_pressed("ui_cancel"):
		return
	if not settings_layer:
		return
	if settings_layer.visible:
		_hide_settings()
	else:
		_show_settings()
	get_viewport().set_input_as_handled()


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
	SETTINGS_PANEL.add_key_controls(box)

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


func _on_deck_pressed() -> void:
	if main and main.ui_manager:
		main.ui_manager.show_run_deck_viewer()


func _show_settings() -> void:
	if not settings_layer:
		return
	var rm = RunManager
	if return_map_button:
		return_map_button.disabled = not (rm and rm.get("is_run_active"))
	settings_layer.visible = true
	get_tree().paused = true


func _hide_settings() -> void:
	if settings_layer:
		settings_layer.visible = false
	get_tree().paused = false


func _on_return_map_pressed() -> void:
	var rm = RunManager
	if not (rm and rm.get("is_run_active")):
		return
	_hide_settings()
	get_tree().change_scene_to_file(MAP_SCENE_PATH)

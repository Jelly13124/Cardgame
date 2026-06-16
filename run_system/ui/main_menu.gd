## Title screen — the project's entry scene (project.godot main_scene).
##
## Routes into the existing home-base hub on Play, resumes a saved run on
## Continue, and reuses settings_panel.gd for the Settings overlay. Built in code
## following the project's modal pattern; no class_name per ADR-0006.
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const SETTINGS_PANEL = preload("res://run_system/ui/settings_panel.gd")

const HOME_BASE_PATH := "res://run_system/ui/home_base_scene.tscn"
const MAP_SCENE_PATH := "res://run_system/ui/map_scene.tscn"
const RULES_PANEL_PATH := "res://run_system/ui/rules_panel.gd"
const BG_TEXTURE_PATH := "res://battle_scene/assets/images/backgrounds/wasteland_battlefield.png"

var _settings_layer: CanvasLayer = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	# ── Background: darkened wasteland art, falling back to a flat dark fill. ──
	var bg_tex = load(BG_TEXTURE_PATH) if ResourceLoader.exists(BG_TEXTURE_PATH) else null
	if bg_tex:
		var tex := TextureRect.new()
		tex.texture = bg_tex
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tex)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.55 if bg_tex else 1.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# ── Centered content column ──
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var title := Label.new()
	title.text = tr("MENU_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = tr("MENU_SUBTITLE")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", T.ACCENT_NEON_BLUE)
	box.add_child(subtitle)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 28)
	box.add_child(gap)

	# New Game auto-creates a save in the first free slot (or prompts to delete one
	# if full); Continue resumes the most recently played slot.
	box.add_child(_menu_button(tr("MENU_NEW_GAME"), _on_new_game))
	var continue_btn := _menu_button(tr("MENU_CONTINUE"), _on_continue)
	continue_btn.disabled = MetaProgress.most_recent_slot() == 0
	box.add_child(continue_btn)

	box.add_child(_menu_button(tr("MENU_HOWTO"), _on_howto))
	box.add_child(_menu_button(tr("MENU_SETTINGS"), _on_settings))
	box.add_child(_menu_button(tr("MENU_QUIT"), _on_quit))

	var version := Label.new()
	version.text = tr("MENU_VERSION")
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_size_override("font_size", 16)
	version.add_theme_color_override("font_color", T.TEXT_SECONDARY)
	var vgap := Control.new()
	vgap.custom_minimum_size = Vector2(0, 20)
	box.add_child(vgap)
	box.add_child(version)


func _menu_button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(360, 58)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 24)
	T.apply_button_theme(button)
	button.pressed.connect(handler)
	return button


## New Game — use the first empty slot, or open the delete picker when full.
func _on_new_game() -> void:
	var empty: int = MetaProgress.first_empty_slot()
	if empty > 0:
		MetaProgress.reset_for_new_game(empty)
		get_tree().change_scene_to_file(HOME_BASE_PATH)
	else:
		_open_slot_manager()


## Continue — resume the most recently played slot (run if any, else its base).
func _on_continue() -> void:
	var slot: int = MetaProgress.most_recent_slot()
	if slot == 0:
		return
	MetaProgress.set_active_slot(slot)
	if RunManager.has_method("load_run") and RunManager.has_run_save() and RunManager.load_run():
		get_tree().change_scene_to_file(MAP_SCENE_PATH)
	else:
		get_tree().change_scene_to_file(HOME_BASE_PATH)


## Open the slot manager (delete a save to free a slot, then start a new game).
func _open_slot_manager() -> void:
	var layer := CanvasLayer.new()
	layer.name = "SlotSelectLayer"
	layer.layer = 130
	add_child(layer)
	var panel = preload("res://run_system/ui/slot_select.gd").new()
	panel.tree_exited.connect(layer.queue_free)
	layer.add_child(panel)


func _on_howto() -> void:
	# rules_panel.gd lands in a later phase; load at runtime so this scene
	# compiles before it exists, and no-op gracefully if it's missing.
	if not ResourceLoader.exists(RULES_PANEL_PATH):
		return
	var script = load(RULES_PANEL_PATH)
	if script == null:
		return
	var layer := CanvasLayer.new()
	layer.name = "RulesLayer"
	layer.layer = 130
	add_child(layer)
	var panel = script.new()
	panel.tree_exited.connect(layer.queue_free)
	layer.add_child(panel)


func _on_settings() -> void:
	if _settings_layer and is_instance_valid(_settings_layer):
		_settings_layer.visible = true
		return
	_build_settings_overlay()
	_settings_layer.visible = true


func _on_quit() -> void:
	get_tree().quit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _settings_layer and _settings_layer.visible:
		_settings_layer.visible = false
		get_viewport().set_input_as_handled()


func _build_settings_overlay() -> void:
	_settings_layer = CanvasLayer.new()
	_settings_layer.name = "SettingsLayer"
	_settings_layer.layer = 130
	_settings_layer.visible = false
	add_child(_settings_layer)

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_layer.add_child(root)

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.58)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 360)
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.text = tr("SETTINGS_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48))
	box.add_child(title)

	# Language change reloads this menu so the new locale applies immediately.
	SETTINGS_PANEL.add_controls(box, func() -> void: get_tree().reload_current_scene(), false)

	box.add_child(HSeparator.new())

	var close := _menu_button(tr("RULES_CLOSE"), func() -> void: _settings_layer.visible = false)
	close.custom_minimum_size = Vector2(300, 48)
	box.add_child(close)

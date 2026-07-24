## Title screen — the project's entry scene (project.godot main_scene).
##
## Three primary actions: New Game (pops a slot picker), Continue (resumes the
## most-recently-played slot), and Saves (a 3-slot manager: continue or delete any
## slot). Reuses settings_panel.gd for the Settings overlay. Built in code following
## the project's modal pattern; no class_name per project convention.
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const SETTINGS_PANEL = preload("res://run_system/ui/settings_panel.gd")

const HOME_BASE_PATH := "res://run_system/ui/home_base_scene.tscn"
const MAP_SCENE_PATH := "res://run_system/ui/map_scene.tscn"
const RULES_PANEL_PATH := "res://run_system/ui/rules_panel.gd"
const START_BG_TEXTURE_PATH := "res://run_system/assets/images/ui/start_screen/bottlecap_hunter_start_background.png"
const START_TITLE_TEXTURE_PATH := "res://run_system/assets/images/ui/start_screen/title_bottlecap_hunter.png"
const START_DIVIDER_TEXTURE_PATH := "res://run_system/assets/images/ui/start_screen/divider_bottlecap.png"
const START_BUTTON_NORMAL_PATH := "res://run_system/assets/images/ui/start_screen/button_main_normal_v2.png"
const START_BUTTON_SELECTED_PATH := "res://run_system/assets/images/ui/start_screen/button_main_selected_v2.png"
const START_SAVE_STRIP_PATH := "res://run_system/assets/images/ui/start_screen/save_info_strip_clean.png"
const START_LANGUAGE_BUTTON_PATH := "res://run_system/assets/images/ui/start_screen/icon_button_language.png"
const START_SETTINGS_BUTTON_PATH := "res://run_system/assets/images/ui/start_screen/icon_button_settings.png"

var _settings_layer: CanvasLayer = null
## The currently-open slot picker / saves manager (one at a time). ESC closes it.
var _modal_layer: CanvasLayer = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# OS window title carries the brand name. project.godot's config/name stays
	# "CardFramework" on purpose — it anchors the user:// save directory, and
	# renaming it would orphan every existing save.
	get_window().title = tr("MENU_TITLE")
	# Title screen is intentionally silent (menu BGM removed). stop_music() also kills
	# any track that carried over when returning to the menu from another scene.
	AudioManager.stop_music()
	_build()
	T.fade_in(self, 0.35)  # smooth title-screen intro instead of a hard cut on boot


func _build() -> void:
	_build_start_screen_concept()


func _build_start_screen_concept() -> void:
	var bg_tex := _load_texture(START_BG_TEXTURE_PATH)
	if bg_tex:
		var bg := TextureRect.new()
		bg.texture = bg_tex
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.035, 0.024, 0.018, 0.16 if bg_tex else 1.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var title_tex := _place_image(START_TITLE_TEXTURE_PATH, Rect2(72, 92, 740, 236))
	if title_tex == null:
		var title := Label.new()
		title.text = tr("MENU_TITLE")
		T.style_display(title, 76, 700)
		title.add_theme_color_override("font_color", Color(1.0, 0.81, 0.27))
		_place_control(title, Rect2(120, 68, 1020, 130))
	_place_image(START_DIVIDER_TEXTURE_PATH, Rect2(150, 326, 610, 92))

	_place_control(_start_icon_button(START_LANGUAGE_BUTTON_PATH, _on_settings), Rect2(1678, 28, 92, 92))
	_place_control(_start_icon_button(START_SETTINGS_BUTTON_PATH, _on_settings), Rect2(1782, 28, 92, 92))

	var button_y := 403.0
	var button_x := 226.0
	var button_size := Vector2(420, 96)
	var button_gap := -2.0
	var new_game := _start_menu_button(tr("MENU_NEW_GAME"), _on_new_game)
	_place_control(new_game, Rect2(button_x, button_y, button_size.x, button_size.y))

	var cont := _start_menu_button(tr("MENU_CONTINUE"), _on_continue)
	cont.disabled = MetaProgress.most_recent_slot() == 0
	_place_control(cont, Rect2(button_x, button_y + (button_size.y + button_gap), button_size.x, button_size.y))
	_place_control(_start_menu_button(tr("MENU_SETTINGS"), _on_settings), Rect2(button_x, button_y + (button_size.y + button_gap) * 2.0, button_size.x, button_size.y))
	_place_control(_start_menu_button(tr("MENU_QUIT"), _on_quit), Rect2(button_x, button_y + (button_size.y + button_gap) * 3.0, button_size.x, button_size.y))

	_place_control(_start_save_info_button(), Rect2(44, 956, 298, 76))


func _place_control(control: Control, rect: Rect2) -> Control:
	control.position = rect.position
	control.size = rect.size
	control.custom_minimum_size = rect.size
	add_child(control)
	return control


func _place_image(path: String, rect: Rect2) -> TextureRect:
	var tex := _load_texture(path)
	if tex == null:
		return null
	var image := TextureRect.new()
	image.texture = tex
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_control(image, rect)
	return image


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	return null


func _start_stylebox(path: String, state: String = "normal") -> StyleBox:
	var tex := _load_texture(path)
	if tex == null:
		return T.ll_button("normal") if path == START_BUTTON_SELECTED_PATH else T.ll_button_olive("normal")
	var box := StyleBoxTexture.new()
	box.texture = tex
	box.texture_margin_left = 30
	box.texture_margin_right = 30
	box.texture_margin_top = 20
	box.texture_margin_bottom = 20
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	match state:
		"hover":
			box.modulate_color = Color(1.10, 1.10, 1.10, 1.0)
		"pressed":
			box.modulate_color = Color(0.86, 0.86, 0.86, 1.0)
		"disabled":
			box.modulate_color = Color(0.46, 0.46, 0.46, 0.82)
	return box


func _start_menu_button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(420, 96)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", T.display_font(700))
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_stylebox_override("normal", _start_stylebox(START_BUTTON_NORMAL_PATH))
	button.add_theme_stylebox_override("hover", _start_stylebox(START_BUTTON_SELECTED_PATH, "hover"))
	button.add_theme_stylebox_override("pressed", _start_stylebox(START_BUTTON_SELECTED_PATH, "pressed"))
	button.add_theme_stylebox_override("disabled", _start_stylebox(START_BUTTON_NORMAL_PATH, "disabled"))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(0.93, 0.80, 0.56))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.93, 0.70))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.88, 0.62))
	button.add_theme_color_override("font_disabled_color", Color(0.60, 0.52, 0.40, 0.86))
	button.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.92))
	button.add_theme_constant_override("outline_size", 3)
	button.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	button.pressed.connect(handler)
	button.mouse_entered.connect(
		func() -> void:
			if not is_instance_valid(button) or button.disabled:
				return
			AudioManager.play_sfx("ui_hover")
			T._button_pop(button, Vector2(1.035, 1.035), 0.08)
	)
	button.mouse_exited.connect(
		func() -> void:
			if is_instance_valid(button):
				T._button_pop(button, Vector2.ONE, 0.10)
	)
	return button


func _start_icon_button(texture_path: String, handler: Callable) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	button.pressed.connect(handler)
	var icon := TextureRect.new()
	icon.texture = _load_texture(texture_path)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	button.mouse_entered.connect(
		func() -> void:
			if not is_instance_valid(button):
				return
			AudioManager.play_sfx("ui_hover")
			T._button_pop(button, Vector2(1.035, 1.035), 0.08)
	)
	button.mouse_exited.connect(
		func() -> void:
			if is_instance_valid(button):
				T._button_pop(button, Vector2.ONE, 0.10)
	)
	return button


func _start_save_info_button() -> Button:
	var slot := Settings.active_slot
	if slot < 1:
		slot = MetaProgress.most_recent_slot()
	if slot < 1:
		slot = 1
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	button.pressed.connect(_on_saves)

	var bg := NinePatchRect.new()
	bg.name = "SaveStripBackground"
	bg.texture = _load_texture(START_SAVE_STRIP_PATH)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.patch_margin_left = 30
	bg.patch_margin_top = 22
	bg.patch_margin_right = 30
	bg.patch_margin_bottom = 22
	bg.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	bg.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(bg)

	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", 24)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 13)
	pad.add_theme_constant_override("margin_bottom", 10)
	button.add_child(pad)

	var labels := VBoxContainer.new()
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_theme_constant_override("separation", 0)
	pad.add_child(labels)

	var slot_label := Label.new()
	slot_label.text = "存档槽位： %d" % slot
	T.style_display(slot_label, 16, 600)
	slot_label.add_theme_color_override("font_color", Color(0.93, 0.80, 0.56))
	slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(slot_label)

	var version := Label.new()
	version.text = "v0.1.0"
	T.style_display(version, 15, 600)
	version.add_theme_color_override("font_color", Color(0.78, 0.66, 0.46))
	version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(version)
	return button


func _menu_button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(360, 52)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", T.display_font(600))
	button.add_theme_font_size_override("font_size", 21)
	T.apply_button_theme(button)
	button.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	button.pressed.connect(handler)
	return button


func _small_button(text: String, handler: Callable, accent: Color = T.TEXT_MAIN) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(92, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", T.display_font(600))
	b.add_theme_font_size_override("font_size", 16)
	T.apply_button_theme(b)
	b.add_theme_color_override("font_color", accent)
	b.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	b.pressed.connect(handler)
	return b


# ─── Primary action handlers ─────────────────────────────────────────────────


## New Game — open a slot picker; clicking a slot starts a fresh game there
## (with an overwrite confirm if that slot already holds a save).
func _on_new_game() -> void:
	_open_slot_modal("new")


## Continue — jump straight into the most-recently-played slot.
func _on_continue() -> void:
	var slot: int = MetaProgress.most_recent_slot()
	if slot >= 1:
		_enter_slot(slot)


## Saves — open the 3-slot manager (continue or delete any slot).
func _on_saves() -> void:
	_open_slot_modal("saves")


## Enter a slot: load its in-run save if any (→ map), else its home base.
func _enter_slot(slot: int) -> void:
	MetaProgress.set_active_slot(slot)
	if RunManager.has_method("load_run") and RunManager.has_run_save() and RunManager.load_run():
		SceneTransition.change_to(MAP_SCENE_PATH)
	else:
		SceneTransition.change_to(HOME_BASE_PATH)


## Wipe a slot and start a brand-new game there.
func _start_new_in(slot: int) -> void:
	MetaProgress.delete_slot(slot)
	MetaProgress.reset_for_new_game(slot)
	SceneTransition.change_to(HOME_BASE_PATH)


# ─── Slot picker / saves manager modal ───────────────────────────────────────


## Shared modal. mode "new" = New Game slot picker; mode "saves" = saves manager.
func _open_slot_modal(mode: String) -> void:
	if _modal_layer and is_instance_valid(_modal_layer):
		_modal_layer.queue_free()
	var layer := CanvasLayer.new()
	layer.layer = 130
	add_child(layer)
	_modal_layer = layer
	layer.tree_exited.connect(
		func() -> void:
			if _modal_layer == layer:
				_modal_layer = null
	)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(
		func(e: InputEvent) -> void:
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
				layer.queue_free()
	)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	center.add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 30)
	panel.add_child(pad)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 11)
	box.custom_minimum_size = Vector2(540, 0)
	pad.add_child(box)

	var heading := Label.new()
	heading.text = tr("MENU_NEW_GAME") if mode == "new" else tr("MENU_SAVES")
	T.style_display(heading, 30, 700)
	heading.add_theme_color_override("font_color", Color(1.0, 0.81, 0.27))
	box.add_child(heading)
	var sub := Label.new()
	sub.text = tr("SLOT_SELECT_TITLE") if mode == "new" else tr("SLOT_MANAGE_TITLE")
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", T.TEXT_SECONDARY)
	box.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	box.add_child(spacer)

	for n in range(1, MetaProgress.SLOT_COUNT + 1):
		box.add_child(_modal_slot_card(n, mode, layer))

	var close := _menu_button(tr("RULES_CLOSE"), func() -> void: layer.queue_free())
	close.custom_minimum_size = Vector2(0, 48)
	box.add_child(close)


## One slot row inside the modal. "new" = whole row clickable to start there;
## "saves" = info + Continue/Delete (or a dim "empty" label).
func _modal_slot_card(n: int, mode: String, layer: CanvasLayer) -> Control:
	var info := MetaProgress.peek_slot(n)
	var occupied := MetaProgress.slot_exists(n)
	var sub_text := _slot_summary_text(n, info)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.075, 0.04, 0.96)
	normal.border_color = Color(0.34, 0.26, 0.15)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(7)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10

	# Info column (shared by both modes).
	var info_box := VBoxContainer.new()
	info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 1)
	var name_lbl := Label.new()
	name_lbl.text = tr("SLOT_LABEL").format({"n": n})
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	T.style_display(name_lbl, 20, 600)
	name_lbl.add_theme_color_override("font_color", T.TEXT_MAIN if occupied else T.TEXT_SECONDARY)
	info_box.add_child(name_lbl)
	var sub := Label.new()
	sub.text = sub_text
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", T.TEXT_SECONDARY)
	info_box.add_child(sub)

	if mode == "new":
		# Whole row is a button → start a new game in this slot.
		var card := Button.new()
		card.focus_mode = Control.FOCUS_NONE
		card.custom_minimum_size = Vector2(0, 58)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.add_theme_stylebox_override("normal", normal)
		var hov := normal.duplicate()
		hov.bg_color = Color(0.18, 0.13, 0.07, 0.98)
		hov.border_color = Color(1.0, 0.81, 0.27)
		card.add_theme_stylebox_override("hover", hov)
		card.add_theme_stylebox_override("pressed", normal)
		card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		card.pressed.connect(
			func() -> void:
				AudioManager.play_sfx("ui_click")
				layer.queue_free()
				if occupied:
					_confirm_overwrite(n)
				else:
					_start_new_in(n)
		)
		var cmargin := MarginContainer.new()
		cmargin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cmargin.set_anchors_preset(Control.PRESET_FULL_RECT)
		cmargin.add_theme_constant_override("margin_left", 16)
		cmargin.add_theme_constant_override("margin_right", 16)
		cmargin.add_theme_constant_override("margin_top", 8)
		cmargin.add_theme_constant_override("margin_bottom", 8)
		cmargin.add_child(info_box)
		card.add_child(cmargin)
		return card

	# mode == "saves": a panel row with action buttons.
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", normal)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	pc.add_child(hbox)
	hbox.add_child(info_box)
	if occupied:
		var cont_btn := _small_button(
			tr("SLOT_CONTINUE_SHORT"),
			func() -> void:
				layer.queue_free()
				_enter_slot(n),
			Color(1.0, 0.86, 0.4)
		)
		hbox.add_child(cont_btn)
		var del_btn := _small_button(
			tr("SLOT_DELETE"), func() -> void: _confirm_delete(n), T.ACCENT_DANGER
		)
		hbox.add_child(del_btn)
	else:
		var empty := Label.new()
		empty.text = tr("SLOT_EMPTY_SHORT")
		empty.add_theme_font_size_override("font_size", 15)
		empty.add_theme_color_override("font_color", Color(0.5, 0.42, 0.3))
		empty.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(empty)
	return pc


## Summary line for a slot row (empty / stats + in-progress badge).
func _slot_summary_text(n: int, info: Dictionary) -> String:
	if info.is_empty():
		return tr("SLOT_EMPTY")
	var line: String = (
		tr("SLOT_SUMMARY")
		. format(
			{
				"scrap": int(info.get("scrap", 0)),
				"caps": int(info.get("caps", 0)),
				"runs": int(info.get("runs", 0)),
			}
		)
	)
	if FileAccess.file_exists("user://slot_%d/run_save.json" % n):
		line += " · " + tr("SLOT_IN_PROGRESS")
	return line


## Overwrite confirmation — New Game onto an occupied slot wipes it first.
func _confirm_overwrite(slot: int) -> void:
	_confirm_modal(tr("SLOT_OVERWRITE"), tr("SLOT_CONFIRM"), func() -> void: _start_new_in(slot))


## Delete confirmation — removes a slot's save, then refreshes the saves manager.
func _confirm_delete(slot: int) -> void:
	_confirm_modal(
		tr("SLOT_DELETE_CONFIRM"),
		tr("SLOT_DELETE"),
		func() -> void:
			MetaProgress.delete_slot(slot)
			_rebuild()
			_open_slot_modal("saves")
	)


## Generic yes/cancel modal.
func _confirm_modal(message: String, confirm_label: String, on_yes: Callable) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 140
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	center.add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(pad)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	vb.custom_minimum_size = Vector2(420, 0)
	pad.add_child(vb)

	var msg := Label.new()
	msg.text = message
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(420, 0)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 19)
	msg.add_theme_color_override("font_color", T.TEXT_MAIN)
	vb.add_child(msg)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var yes := _menu_button(
		confirm_label,
		func() -> void:
			layer.queue_free()
			on_yes.call()
	)
	yes.custom_minimum_size = Vector2(180, 50)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.add_theme_color_override("font_color", Color(1.0, 0.72, 0.4))
	var no := _menu_button(tr("MENU_CANCEL"), func() -> void: layer.queue_free())
	no.custom_minimum_size = Vector2(180, 50)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(yes)
	btn_row.add_child(no)
	vb.add_child(btn_row)


## Tear down and rebuild the menu body (keeps the settings overlay alive). Used
## after a save is deleted so the Continue button's enabled state refreshes.
func _rebuild() -> void:
	for c in get_children():
		if c == _settings_layer:
			continue
		c.queue_free()
	_build()


# ─── Secondary surfaces ──────────────────────────────────────────────────────


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
	if not event.is_action_pressed("ui_cancel"):
		return
	if _settings_layer and _settings_layer.visible:
		_settings_layer.visible = false
		get_viewport().set_input_as_handled()
	elif _modal_layer and is_instance_valid(_modal_layer):
		_modal_layer.queue_free()
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
	SETTINGS_PANEL.add_key_controls(box)

	box.add_child(HSeparator.new())

	var close := _menu_button(tr("RULES_CLOSE"), func() -> void: _settings_layer.visible = false)
	close.custom_minimum_size = Vector2(300, 48)
	box.add_child(close)

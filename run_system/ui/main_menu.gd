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
## Currently highlighted save slot (1..SLOT_COUNT). Drives Continue / New Game.
## 0 = uninitialised; _build() seeds it from the most-recent save on first paint.
var _selected_slot: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	AudioManager.play_music("menu")
	_build()


func _build() -> void:
	# ── Background art (stays visible to the left of the menu panel) ──
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
	dim.color = Color(0.05, 0.035, 0.02, 0.4 if bg_tex else 1.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# ── Right-side menu panel (dark, gold left edge) ──
	var panel := Panel.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -470.0
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.11, 0.08, 0.045, 0.97)
	ps.border_width_left = 3
	ps.border_color = Color(0.78, 0.56, 0.22)
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 52)
	margin.add_theme_constant_override("margin_right", 52)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	center.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(360, 0)
	margin.add_child(box)

	# Title (Oswald) — gold; falls back to Noto for zh.
	var title := Label.new()
	title.text = tr("MENU_TITLE")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.custom_minimum_size = Vector2(360, 0)
	T.style_display(title, 52, 700)
	title.add_theme_color_override("font_color", Color(1.0, 0.81, 0.27))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(title)

	# DEMO tag (cyan pill)
	var tag := Label.new()
	tag.text = tr("MENU_SUBTITLE")
	T.style_display(tag, 16, 600)
	tag.add_theme_color_override("font_color", Color(0.06, 0.09, 0.11))
	var tagbg := StyleBoxFlat.new()
	tagbg.bg_color = T.ACCENT_NEON_BLUE
	tagbg.set_corner_radius_all(6)
	tagbg.content_margin_left = 9
	tagbg.content_margin_right = 9
	tagbg.content_margin_top = 2
	tagbg.content_margin_bottom = 2
	var tagwrap := PanelContainer.new()
	tagwrap.add_theme_stylebox_override("panel", tagbg)
	tagwrap.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tagwrap.add_child(tag)
	box.add_child(tagwrap)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	box.add_child(gap)

	# Default selection = the slot Continue would resume (most-recent save), or
	# slot 1 when there are no saves yet. Preserved across rebuilds on re-select.
	if _selected_slot < 1:
		_selected_slot = maxi(1, MetaProgress.most_recent_slot())

	# ── Save-slot selector — click a card to pick the active slot ──
	var slots_header := Label.new()
	slots_header.text = tr("MENU_SLOTS")
	T.style_display(slots_header, 16, 600)
	slots_header.add_theme_color_override("font_color", Color(0.78, 0.62, 0.36))
	box.add_child(slots_header)

	for n in range(1, MetaProgress.SLOT_COUNT + 1):
		box.add_child(_slot_card(n))

	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 8)
	box.add_child(gap2)

	# Continue resumes the currently-selected slot; disabled when it's empty.
	var cont := _menu_button(tr("MENU_CONTINUE"), _on_continue)
	cont.disabled = not MetaProgress.slot_exists(_selected_slot)
	box.add_child(cont)
	box.add_child(_menu_button(tr("MENU_NEW_GAME"), _on_new_game))
	box.add_child(_menu_button(tr("MENU_HOWTO"), _on_howto))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	var sbtn := _menu_button(tr("MENU_SETTINGS"), _on_settings)
	sbtn.custom_minimum_size = Vector2(0, 52)
	sbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var qbtn := _menu_button(tr("MENU_QUIT"), _on_quit)
	qbtn.custom_minimum_size = Vector2(0, 52)
	qbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sbtn)
	row.add_child(qbtn)
	box.add_child(row)

	var vgap := Control.new()
	vgap.custom_minimum_size = Vector2(0, 18)
	box.add_child(vgap)
	var ver := Label.new()
	ver.text = tr("MENU_VERSION")
	T.style_display(ver, 13, 500)
	ver.add_theme_color_override("font_color", Color(0.5, 0.39, 0.25))
	box.add_child(ver)


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


## A clickable save-slot card. Click selects the slot (drives Continue / New Game).
func _slot_card(n: int) -> Button:
	var selected := n == _selected_slot
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(0, 58)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.pressed.connect(
		func() -> void:
			AudioManager.play_sfx("ui_click")
			_select_slot(n)
	)

	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.17, 0.12, 0.06, 0.96) if selected else Color(0.08, 0.06, 0.035, 0.94)
	box.border_color = Color(1.0, 0.81, 0.27) if selected else Color(0.34, 0.26, 0.15)
	box.set_border_width_all(2 if selected else 1)
	box.set_corner_radius_all(7)
	card.add_theme_stylebox_override("normal", box)
	var hov := box.duplicate()
	hov.bg_color = Color(0.21, 0.15, 0.08, 0.98)
	if not selected:
		hov.border_color = Color(0.55, 0.42, 0.24)
	card.add_theme_stylebox_override("hover", hov)
	card.add_theme_stylebox_override("pressed", box)
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 1)
	margin.add_child(content)

	var name_lbl := Label.new()
	name_lbl.text = tr("SLOT_LABEL").format({"n": n})
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	T.style_display(name_lbl, 20, 600)
	name_lbl.add_theme_color_override(
		"font_color", Color(1.0, 0.86, 0.4) if selected else T.TEXT_MAIN
	)
	content.add_child(name_lbl)

	var sub := Label.new()
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info := MetaProgress.peek_slot(n)
	if info.is_empty():
		sub.text = tr("SLOT_EMPTY")
	else:
		var line: String = (
			tr("SLOT_SUMMARY")
			. format(
				{
					"scrap": int(info.get("scrap", 0)),
					"core": int(info.get("core", 0)),
					"runs": int(info.get("runs", 0)),
				}
			)
		)
		if FileAccess.file_exists("user://slot_%d/run_save.json" % n):
			line += " · " + tr("SLOT_IN_PROGRESS")
		sub.text = line
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", T.TEXT_SECONDARY)
	content.add_child(sub)
	return card


## Select a slot and rebuild the menu so the highlight + Continue state refresh.
func _select_slot(n: int) -> void:
	_selected_slot = n
	_rebuild()


## Tear down and rebuild the menu body (keeps the settings overlay alive).
func _rebuild() -> void:
	for c in get_children():
		if c == _settings_layer:
			continue
		c.queue_free()
	_build()


## New Game — start in the selected slot, confirming first if it's occupied.
func _on_new_game() -> void:
	if _selected_slot < 1:
		return
	if MetaProgress.slot_exists(_selected_slot):
		_confirm_overwrite(_selected_slot)
	else:
		_start_new_in(_selected_slot)


func _start_new_in(slot: int) -> void:
	MetaProgress.delete_slot(slot)
	MetaProgress.reset_for_new_game(slot)
	get_tree().change_scene_to_file(HOME_BASE_PATH)


## Continue — resume the selected slot (its in-run save if any, else its base).
func _on_continue() -> void:
	if _selected_slot < 1 or not MetaProgress.slot_exists(_selected_slot):
		return
	MetaProgress.set_active_slot(_selected_slot)
	if RunManager.has_method("load_run") and RunManager.has_run_save() and RunManager.load_run():
		get_tree().change_scene_to_file(MAP_SCENE_PATH)
	else:
		get_tree().change_scene_to_file(HOME_BASE_PATH)


## Overwrite confirmation modal — New Game onto an occupied slot wipes it first.
func _confirm_overwrite(slot: int) -> void:
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
	msg.text = tr("SLOT_OVERWRITE")
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
		tr("SLOT_CONFIRM"),
		func() -> void:
			layer.queue_free()
			_start_new_in(slot)
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

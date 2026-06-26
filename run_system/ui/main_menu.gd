## Title screen — the project's entry scene (project.godot main_scene).
##
## Three primary actions: New Game (pops a slot picker), Continue (resumes the
## most-recently-played slot), and Saves (a 3-slot manager: continue or delete any
## slot). Reuses settings_panel.gd for the Settings overlay. Built in code following
## the project's modal pattern; no class_name per ADR-0006.
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const SETTINGS_PANEL = preload("res://run_system/ui/settings_panel.gd")

const HOME_BASE_PATH := "res://run_system/ui/home_base_scene.tscn"
const MAP_SCENE_PATH := "res://run_system/ui/map_scene.tscn"
const RULES_PANEL_PATH := "res://run_system/ui/rules_panel.gd"
const BG_TEXTURE_PATH := "res://battle_scene/assets/images/backgrounds/title_key_art.png"

var _settings_layer: CanvasLayer = null
## The currently-open slot picker / saves manager (one at a time). ESC closes it.
var _modal_layer: CanvasLayer = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Title screen is intentionally silent (menu BGM removed). stop_music() also kills
	# any track that carried over when returning to the menu from another scene.
	AudioManager.stop_music()
	_build()
	T.fade_in(self, 0.35)  # smooth title-screen intro instead of a hard cut on boot


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
	gap.custom_minimum_size = Vector2(0, 26)
	box.add_child(gap)

	# ── Three primary actions ──
	box.add_child(_menu_button(tr("MENU_NEW_GAME"), _on_new_game))
	var cont := _menu_button(tr("MENU_CONTINUE"), _on_continue)
	cont.disabled = MetaProgress.most_recent_slot() == 0
	box.add_child(cont)
	box.add_child(_menu_button(tr("MENU_SAVES"), _on_saves))
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
				"core": int(info.get("core", 0)),
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

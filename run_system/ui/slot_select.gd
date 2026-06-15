## Save-slot select screen — three independent profile slots. Opened from the
## title menu. Each slot shows its summary (or "Empty"); New Game wipes + starts a
## fresh profile, Continue loads the slot (resuming its in-run save if any, else
## its home base). No class_name per ADR-0006; owner instances on a CanvasLayer.
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const HOME_BASE_PATH := "res://run_system/ui/home_base_scene.tscn"
const MAP_SCENE_PATH := "res://run_system/ui/map_scene.tscn"

var _pending_overwrite_slot: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.025, 0.02, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var title := Label.new()
	title.text = tr("SLOT_SELECT_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48))
	box.add_child(title)

	for n in range(1, MetaProgress.SLOT_COUNT + 1):
		box.add_child(_slot_row(n))

	var close := _button(tr("RULES_CLOSE"), 300, func() -> void: queue_free())
	close.add_theme_color_override("font_color", T.TEXT_SECONDARY)
	box.add_child(close)


func _slot_row(slot: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 0)
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = tr("SLOT_LABEL").format({"n": slot})
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color", T.TEXT_MAIN)
	info.add_child(name_lbl)

	var summary := MetaProgress.peek_slot(slot)
	var sub := Label.new()
	if summary.is_empty():
		sub.text = tr("SLOT_EMPTY")
	else:
		sub.text = (
			tr("SLOT_SUMMARY")
			. format(
				{
					"scrap": int(summary.get("scrap", 0)),
					"core": int(summary.get("core", 0)),
					"runs": int(summary.get("runs", 0)),
				}
			)
		)
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", T.TEXT_SECONDARY)
	info.add_child(sub)

	var continue_btn := _button(tr("SLOT_CONTINUE"), 160, _on_continue.bind(slot))
	continue_btn.disabled = summary.is_empty()
	row.add_child(continue_btn)
	row.add_child(_button(tr("SLOT_NEW_GAME"), 160, _on_new_game.bind(slot)))

	return panel


func _button(text: String, width: int, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 52)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	T.apply_button_theme(b)
	b.pressed.connect(handler)
	return b


func _on_continue(slot: int) -> void:
	MetaProgress.set_active_slot(slot)
	if RunManager.has_method("load_run") and RunManager.has_run_save() and RunManager.load_run():
		get_tree().change_scene_to_file(MAP_SCENE_PATH)
	else:
		get_tree().change_scene_to_file(HOME_BASE_PATH)


func _on_new_game(slot: int) -> void:
	# Confirm before overwriting a slot that already has progress.
	if MetaProgress.slot_exists(slot):
		_pending_overwrite_slot = slot
		_show_overwrite_confirm(slot)
		return
	_start_new_game(slot)


func _start_new_game(slot: int) -> void:
	MetaProgress.reset_for_new_game(slot)
	get_tree().change_scene_to_file(HOME_BASE_PATH)


func _show_overwrite_confirm(slot: int) -> void:
	var layer := ColorRect.new()
	layer.name = "OverwriteConfirm"
	layer.color = Color(0, 0, 0, 0.75)
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(layer)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	var msg := Label.new()
	msg.text = tr("SLOT_OVERWRITE")
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(460, 0)
	msg.add_theme_font_size_override("font_size", 19)
	msg.add_theme_color_override("font_color", T.TEXT_MAIN)
	box.add_child(msg)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 16)
	box.add_child(btns)
	btns.add_child(_button(tr("RULES_CLOSE"), 160, func() -> void: layer.queue_free()))
	var confirm := _button(tr("SLOT_CONFIRM"), 200, func() -> void: _start_new_game(slot))
	confirm.add_theme_color_override("font_color", T.ACCENT_DANGER)
	btns.add_child(confirm)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if get_node_or_null("OverwriteConfirm"):
			get_node("OverwriteConfirm").queue_free()
		else:
			queue_free()

## Slot manager — shown by New Game when all save slots are full. Each slot lists
## its summary and a Delete button; deleting a slot immediately starts a new game
## in that freed slot. No class_name per ADR-0006; owner instances on a CanvasLayer.
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const HOME_BASE_PATH := "res://run_system/ui/home_base_scene.tscn"


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
	title.text = tr("SLOT_FULL_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(720, 0)
	title.add_theme_font_size_override("font_size", 26)
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

	var del := _button(tr("SLOT_DELETE"), 180, _on_delete.bind(slot))
	del.disabled = summary.is_empty()
	del.add_theme_color_override("font_color", T.ACCENT_DANGER)
	row.add_child(del)

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


## Delete the slot's save, then immediately start a new game in that freed slot.
func _on_delete(slot: int) -> void:
	MetaProgress.delete_slot(slot)
	MetaProgress.reset_for_new_game(slot)
	get_tree().change_scene_to_file(HOME_BASE_PATH)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()

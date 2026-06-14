## First-battle tutorial tips — a short sequence of dismissible center-screen
## cards shown once on the player's first-ever battle. Center overlay only (no
## anchored arrows) so it's robust to layout. No class_name per ADR-0006.
## Owner instances it on a CanvasLayer; it frees itself after the last tip.
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")

## Localized tip keys, shown in order.
const TIPS := ["TIP_1", "TIP_2", "TIP_3", "TIP_4"]

var _index: int = 0
var _body: Label = null
var _next_btn: Button = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_show_tip()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 240)
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)

	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(500, 110)
	_body.add_theme_font_size_override("font_size", 21)
	_body.add_theme_color_override("font_color", T.TEXT_MAIN)
	box.add_child(_body)

	_next_btn = Button.new()
	_next_btn.custom_minimum_size = Vector2(220, 48)
	_next_btn.focus_mode = Control.FOCUS_NONE
	_next_btn.add_theme_font_size_override("font_size", 20)
	T.apply_button_theme(_next_btn)
	_next_btn.pressed.connect(_advance)
	box.add_child(_next_btn)


func _show_tip() -> void:
	_body.text = tr(TIPS[_index])
	var last := _index >= TIPS.size() - 1
	_next_btn.text = tr("TIP_DONE") if last else tr("TIP_NEXT")


func _advance() -> void:
	_index += 1
	if _index >= TIPS.size():
		queue_free()
		return
	_show_tip()

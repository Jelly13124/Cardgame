## First-battle tips use an upper content lane, leaving the persistent HUD and
## lower energy/hand controls clear. No class_name per project convention.
## Owner instances it on a CanvasLayer; it frees itself after the last tip.
extends Control

signal completed

const T = preload("uid://dfcqloc58bvde")  # res://ui/common/theme/wasteland_theme.gd
const RUN_TOP_BAR = preload("uid://dd4fkkrkiwgrj")  # res://ui/common/run_top_bar.gd

## Localized tip keys, shown in order.
const TIPS := ["TIP_1", "TIP_2", "TIP_3", "TIP_4"]

var _index: int = 0
var _body: Label = null
var _next_btn: Button = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_top = RUN_TOP_BAR.BAR_HEIGHT
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_show_tip()


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "TutorialDim"
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "TutorialPanel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -280.0
	panel.offset_right = 280.0
	panel.offset_top = 68.0
	panel.offset_bottom = 328.0
	panel.custom_minimum_size = Vector2(560, 260)
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	add_child(panel)

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
	_body.custom_minimum_size = Vector2(0, 110)
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
		completed.emit()
		queue_free()
		return
	_show_tip()

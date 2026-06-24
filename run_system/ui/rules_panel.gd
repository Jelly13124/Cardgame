## "How to Play" rules panel — a scrollable full-screen overlay of the core
## rules. Opened from the title menu and the map pause panel. Closes on the
## Close button or ESC. No class_name per ADR-0006; owner instances + add_child.
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")

## Localized section keys, shown top to bottom.
const SECTIONS := [
	"RULES_ENERGY",
	"RULES_CARDS",
	"RULES_BLOCK",
	"RULES_INTENT",
	"RULES_CRIT",
	"RULES_ATTRS",
	"RULES_TOOLS",
	"RULES_EQUIPMENT",
	"RULES_RELICS",
	"RULES_GEMS",
	"RULES_BACKPACK",
	"RULES_BASE",
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 620)
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := Label.new()
	title.text = tr("RULES_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48))
	box.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680, 460)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 16)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for key in SECTIONS:
		var line := Label.new()
		line.text = tr(key)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(660, 0)
		line.add_theme_font_size_override("font_size", 19)
		line.add_theme_color_override("font_color", T.TEXT_MAIN)
		list.add_child(line)

	var close := Button.new()
	close.text = tr("RULES_CLOSE")
	close.custom_minimum_size = Vector2(280, 50)
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 20)
	T.apply_button_theme(close)
	close.pressed.connect(queue_free)
	box.add_child(close)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()

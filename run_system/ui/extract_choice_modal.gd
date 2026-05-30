## Modal shown after a mid-act boss death. Player chooses to extract now
## (more Core, run ends, return to home base) or push deeper (less Core
## now, continue to next act).
##
## Owner instantiates, sets reward_continue / reward_extract / act_num,
## then calls add_child. Listens to `chosen(extract: bool)` signal.
extends Control
class_name ExtractChoiceModal

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")

signal chosen(extract: bool)

var act_num: int = 1
var reward_continue: int = 25
var reward_extract: int = 50

var _extract_btn: Button
var _continue_btn: Button
var _resolved: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	panel.custom_minimum_size = Vector2(640, 380)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = tr("UI_HERO_EXTRACT_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	vbox.add_child(title)

	var summary := Label.new()
	summary.text = tr("UI_HERO_EXTRACT_SUMMARY").format({"n": act_num})
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 20)
	summary.add_theme_color_override("font_color", Color(0.92, 0.9, 0.78))
	vbox.add_child(summary)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer)

	var extract_btn := Button.new()
	extract_btn.text = tr("UI_HERO_EXTRACT_NOW").format({"n": reward_extract})
	extract_btn.custom_minimum_size = Vector2(560, 56)
	extract_btn.add_theme_font_size_override("font_size", 20)
	extract_btn.pressed.connect(_on_extract_pressed)
	vbox.add_child(extract_btn)
	_extract_btn = extract_btn

	var continue_btn := Button.new()
	continue_btn.text = tr("UI_HERO_PUSH_ON").format({"n": reward_continue})
	continue_btn.custom_minimum_size = Vector2(560, 56)
	continue_btn.add_theme_font_size_override("font_size", 20)
	continue_btn.pressed.connect(_on_continue_pressed)
	vbox.add_child(continue_btn)
	_continue_btn = continue_btn


# Debounce: queue_free is deferred so without this flag a double-click on
# the same button (or rapid clicks across both buttons) would emit `chosen`
# more than once, leading to double Core grants and stacked loot modals.
func _on_extract_pressed() -> void:
	if _resolved:
		return
	_resolved = true
	_disable_buttons()
	emit_signal("chosen", true)
	queue_free()


func _on_continue_pressed() -> void:
	if _resolved:
		return
	_resolved = true
	_disable_buttons()
	emit_signal("chosen", false)
	queue_free()


func _disable_buttons() -> void:
	if is_instance_valid(_extract_btn):
		_extract_btn.disabled = true
	if is_instance_valid(_continue_btn):
		_continue_btn.disabled = true

## Random-event modal for the "?" map node. Owner sets `event_data` (a loaded
## event dict from RunManager.pick_random_event()), then add_child. Renders the
## title + description + one button per option. Options whose `requires`
## (luck/charm) gate is unmet are shown DISABLED with a [Charm N]/[Luck N] hint.
##
## On pick: luck_check options roll RunManager.luck_check_chance() and apply
## effects_success/effects_fail; plain options apply RunManager.apply_event_effects
## (opt.effects). A result popup is shown, then `resolved` fires and the modal
## frees itself. Listen to `resolved` to release the map's click guard.
##
## class_name is intentionally omitted (banned project-wide, ADR-0006) — owner
## reaches the script via preload.
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")

signal resolved

var event_data: Dictionary = {}

var _resolved: bool = false
var _option_buttons: Array[Button] = []
var _result_label: Label
var _vbox: VBoxContainer


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
	panel.custom_minimum_size = Vector2(680, 420)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 16)
	margin.add_child(_vbox)

	var title := Label.new()
	title.text = str(event_data.get("title", "Event"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	_vbox.add_child(title)

	var desc := Label.new()
	desc.text = str(event_data.get("description", ""))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 19)
	desc.add_theme_color_override("font_color", Color(0.92, 0.9, 0.78))
	_vbox.add_child(desc)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	_vbox.add_child(spacer)

	var options: Variant = event_data.get("options", [])
	if typeof(options) == TYPE_ARRAY:
		for i in options.size():
			var opt: Variant = options[i]
			if typeof(opt) != TYPE_DICTIONARY:
				continue
			_vbox.add_child(_make_option_button(opt, i))


func _make_option_button(opt: Dictionary, index: int) -> Button:
	var button := Button.new()
	button.text = str(opt.get("text", "..."))
	button.custom_minimum_size = Vector2(600, 56)
	button.add_theme_font_size_override("font_size", 19)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var unlocked: bool = RunManager.option_unlocked(opt)
	if not unlocked:
		button.disabled = true
		button.tooltip_text = _lock_hint(opt)
	button.pressed.connect(_on_option_pressed.bind(index))
	_option_buttons.append(button)
	return button


## Human-readable "[Charm N] [Luck N]" hint for a locked option's requires gate.
func _lock_hint(opt: Dictionary) -> String:
	var requires: Variant = opt.get("requires", {})
	if typeof(requires) != TYPE_DICTIONARY:
		return ""
	var parts: Array[String] = []
	for attr in requires.keys():
		parts.append("[%s %d]" % [str(attr).capitalize(), int(requires[attr])])
	return " ".join(parts)


func _on_option_pressed(index: int) -> void:
	if _resolved:
		return
	var options: Variant = event_data.get("options", [])
	if typeof(options) != TYPE_ARRAY or index < 0 or index >= options.size():
		return
	var opt: Variant = options[index]
	if typeof(opt) != TYPE_DICTIONARY:
		return
	# Locked options should already be disabled, but guard defensively.
	if not RunManager.option_unlocked(opt):
		return

	_resolved = true
	_disable_buttons()

	var result_text := ""
	if bool(opt.get("luck_check", false)):
		if randf() < RunManager.luck_check_chance():
			RunManager.apply_event_effects(opt.get("effects_success", []))
			result_text = str(opt.get("result_success", opt.get("result", "")))
		else:
			RunManager.apply_event_effects(opt.get("effects_fail", []))
			result_text = str(opt.get("result_fail", opt.get("result", "")))
	else:
		RunManager.apply_event_effects(opt.get("effects", []))
		result_text = str(opt.get("result", opt.get("result_text", "")))

	_show_result(result_text)


## Replace the options with the outcome text + a Continue button that finalizes.
func _show_result(text: String) -> void:
	for button in _option_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_option_buttons.clear()

	_result_label = Label.new()
	_result_label.text = text
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.add_theme_font_size_override("font_size", 21)
	_result_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	_vbox.add_child(_result_label)

	var continue_btn := Button.new()
	continue_btn.text = "Continue"
	continue_btn.custom_minimum_size = Vector2(600, 56)
	continue_btn.add_theme_font_size_override("font_size", 20)
	continue_btn.pressed.connect(_finalize)
	_vbox.add_child(continue_btn)


func _finalize() -> void:
	emit_signal("resolved")
	queue_free()


func _disable_buttons() -> void:
	for button in _option_buttons:
		if is_instance_valid(button):
			button.disabled = true

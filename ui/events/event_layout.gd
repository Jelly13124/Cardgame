## Title, page text and option list of an event (STS2 NEventLayout). Rebuilds
## on the model's `state_changed`; a click disables every button until then,
## so one click runs one option.
## class_name is intentionally omitted by project convention — preload.
extends VBoxContainer

const T = preload("uid://dfcqloc58bvde")  # res://ui/common/theme/wasteland_theme.gd
const OPTION_BUTTON = preload("res://ui/events/event_option_button.gd")

signal option_pressed(index: int)

var model
var _body: Label
var _options: VBoxContainer


func bind(p_model) -> void:
	model = p_model
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 18)
	var title := Label.new()
	title.text = Settings.t(model.text_key("TITLE"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_override("font", T.display_font(700))
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.96, 0.79, 0.51))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 3)
	add_child(title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_override("font", T.display_font(500))
	_body.add_theme_font_size_override("font_size", 22)
	_body.add_theme_color_override("font_color", Color(0.94, 0.78, 0.52))
	add_child(_body)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	add_child(spacer)
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 12)
	add_child(_options)
	model.state_changed.connect(rebuild)
	rebuild()


func rebuild() -> void:
	_body.text = model.format(Settings.t(model.page_text_key()))
	for child in _options.get_children():
		_options.remove_child(child)
		child.queue_free()
	for i in model.current_options.size():
		var button = OPTION_BUTTON.new()
		button.setup(model.current_options[i], model)
		button.pressed.connect(_on_pressed.bind(i, button))
		_options.add_child(button)


func _on_pressed(index: int, button: Button) -> void:
	if button.disabled:
		return  # a second press on a button this click already disabled
	for child in _options.get_children():
		child.disabled = true
	option_pressed.emit(index)

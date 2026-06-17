## One rebindable key row: "<action label> …… [current key]". Clicking the key
## button listens for the next key press and saves it via Settings.set_key.
## Instanced (not static) because it needs _input to capture the key press.
## No class_name per ADR-0006.
extends HBoxContainer

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")

var _action: String = ""
var _btn: Button = null
var _listening: bool = false


func setup(action: String, label_text: String) -> void:
	_action = action
	add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.text = label_text
	l.add_theme_color_override("font_color", T.TEXT_MAIN)
	l.add_theme_font_size_override("font_size", 19)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(l)
	_btn = Button.new()
	_btn.custom_minimum_size = Vector2(150, 38)
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.add_theme_color_override("font_color", T.TEXT_MAIN)
	_btn.add_theme_stylebox_override("normal", T.button_textured("normal"))
	_btn.add_theme_stylebox_override("hover", T.button_textured("hover"))
	_btn.add_theme_stylebox_override("pressed", T.button_textured("pressed"))
	_btn.pressed.connect(_start_listening)
	add_child(_btn)
	refresh()


## Re-read the bound key onto the button (public so a "reset" button can refresh).
func refresh() -> void:
	if _btn == null:
		return
	if _listening:
		_btn.text = TranslationServer.translate("SETTINGS_PRESS_KEY")
		return
	var key_name := OS.get_keycode_string(Settings.get_key(_action))
	_btn.text = key_name if key_name != "" else "?"


func _start_listening() -> void:
	_listening = true
	refresh()


func _input(event: InputEvent) -> void:
	if not _listening:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_ESCAPE:
			# Cancel the rebind (let ESC still bubble so it can close the overlay).
			_listening = false
			refresh()
			return
		_listening = false
		Settings.set_key(_action, key.keycode)
		refresh()
		get_viewport().set_input_as_handled()

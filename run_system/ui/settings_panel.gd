## Reusable builder for the settings controls (Language / Fullscreen / Master
## Volume). Shared by the in-battle settings overlay (battle_top_bar) and the
## home-base settings overlay so the two stay in sync.
##
## Preloaded, not class_name (project rule ADR-0006). Labels are resolved via
## TranslationServer.translate (tr() needs an instance; these builders are
## static) at build time — the app reloads the current scene on language change,
## so a rebuilt overlay always shows the new locale.
extends RefCounted

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const KEYBIND_ROW = preload("res://run_system/ui/keybind_row.gd")


## Append Language / Fullscreen / Volume rows to `box`. `on_language_change` is
## invoked (no args) AFTER Settings.set_language + persistence so the caller can
## reload the current scene. `in_battle` adds the "(restarts battle)" hint.
static func add_controls(
	box: VBoxContainer, on_language_change: Callable, in_battle: bool = false
) -> void:
	# ── Language ──
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 10)
	box.add_child(lang_row)
	lang_row.add_child(_label(TranslationServer.translate("SETTINGS_LANGUAGE")))
	var lang_btn := Button.new()
	lang_btn.text = "中文" if Settings.language == "zh" else "English"
	lang_btn.custom_minimum_size = Vector2(150, 40)
	lang_btn.focus_mode = Control.FOCUS_NONE
	_style_button(lang_btn)
	lang_btn.pressed.connect(
		func() -> void:
			Settings.set_language("en" if Settings.language == "zh" else "zh")
			on_language_change.call()
	)
	lang_row.add_child(lang_btn)
	if in_battle:
		var note := _label(TranslationServer.translate("SETTINGS_LANG_NOTE"))
		note.add_theme_font_size_override("font_size", 16)
		note.add_theme_color_override("font_color", T.TEXT_SECONDARY)
		box.add_child(note)

	# ── Fullscreen ──
	var fs := CheckButton.new()
	fs.text = TranslationServer.translate("SETTINGS_FULLSCREEN")
	fs.button_pressed = Settings.fullscreen
	fs.focus_mode = Control.FOCUS_NONE
	fs.add_theme_color_override("font_color", T.TEXT_MAIN)
	fs.toggled.connect(func(on: bool) -> void: Settings.set_fullscreen(on))
	box.add_child(fs)

	# ── Volume: Master / Music / SFX ──
	_volume_row(box, "SETTINGS_VOLUME", Settings.master_volume, Settings.set_master_volume)
	_volume_row(box, "SETTINGS_MUSIC", Settings.music_volume, Settings.set_music_volume)
	_volume_row(box, "SETTINGS_SFX", Settings.sfx_volume, Settings.set_sfx_volume)


## Append a Key Bindings section: one rebind row per battle action + a Reset.
static func add_key_controls(box: VBoxContainer) -> void:
	box.add_child(HSeparator.new())
	var header := _label(TranslationServer.translate("SETTINGS_KEYBINDS"))
	header.add_theme_color_override("font_color", T.SAND_LIGHT)
	box.add_child(header)
	var actions := [
		["end_turn", "SETTINGS_KEY_END_TURN"],
		["view_draw", "SETTINGS_KEY_DRAW"],
		["view_discard", "SETTINGS_KEY_DISCARD"],
		["view_exhaust", "SETTINGS_KEY_EXHAUST"],
		["view_attributes", "SETTINGS_KEY_ATTRS"],
	]
	for pair in actions:
		var row = KEYBIND_ROW.new()
		box.add_child(row)
		row.setup(pair[0], TranslationServer.translate(pair[1]))
	var reset := Button.new()
	reset.text = TranslationServer.translate("SETTINGS_RESET_KEYS")
	reset.custom_minimum_size = Vector2(0, 38)
	reset.focus_mode = Control.FOCUS_NONE
	_style_button(reset)
	reset.pressed.connect(
		func() -> void:
			Settings.reset_keys()
			for c in box.get_children():
				if c.has_method("refresh"):
					c.refresh()
	)
	box.add_child(reset)


static func _volume_row(box: VBoxContainer, key: String, value: float, setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	row.add_child(_label(TranslationServer.translate(key)))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(170, 24)
	slider.value_changed.connect(func(v: float) -> void: setter.call(v))
	row.add_child(slider)


static func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", T.TEXT_MAIN)
	l.add_theme_font_size_override("font_size", 20)
	return l


static func _style_button(b: Button) -> void:
	b.add_theme_color_override("font_color", T.TEXT_MAIN)
	b.add_theme_stylebox_override("normal", T.button_textured("normal"))
	b.add_theme_stylebox_override("hover", T.button_textured("hover"))
	b.add_theme_stylebox_override("pressed", T.button_textured("pressed"))

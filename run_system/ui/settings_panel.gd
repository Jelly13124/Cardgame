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
		note.add_theme_font_size_override("font_size", 12)
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

	# ── Master volume ──
	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 10)
	box.add_child(vol_row)
	vol_row.add_child(_label(TranslationServer.translate("SETTINGS_VOLUME")))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Settings.master_volume
	slider.custom_minimum_size = Vector2(170, 24)
	slider.value_changed.connect(func(v: float) -> void: Settings.set_master_volume(v))
	vol_row.add_child(slider)


static func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", T.TEXT_MAIN)
	l.add_theme_font_size_override("font_size", 16)
	return l


static func _style_button(b: Button) -> void:
	b.add_theme_color_override("font_color", T.TEXT_MAIN)
	b.add_theme_stylebox_override("normal", T.button_textured("normal"))
	b.add_theme_stylebox_override("hover", T.button_textured("hover"))
	b.add_theme_stylebox_override("pressed", T.button_textured("pressed"))

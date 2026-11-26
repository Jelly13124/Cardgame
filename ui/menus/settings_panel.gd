## Reusable builder for the settings controls. Shared by the main-menu settings
## overlay and the pause panel (battle, map, shop, home base) so they stay in sync.
##
## Layout: rust section headers, then rows of "label | control" with one fixed
## label column so every control starts on the same line. Choices are segmented
## buttons (the picked one is the rust primary plate, the others cream secondary
## plates); volumes are sliders with a bottle-cap knob and a percent readout.
##
## Preloaded, not class_name (project convention). Labels are resolved via
## TranslationServer.translate (tr() needs an instance; these builders are
## static) at build time — the app reloads the current scene on language change,
## so a rebuilt overlay always shows the new locale.
extends RefCounted

const T = preload("uid://dfcqloc58bvde")  # res://ui/common/theme/wasteland_theme.gd
const KEYBIND_ROW = preload("uid://kgnqlot8dw5g")  # res://ui/menus/keybind_row.gd

## Width of the label column; the pause panel's 470 px scroll still fits a row.
const LABEL_WIDTH := 150.0
const ROW_HEIGHT := 46.0
const LABEL_FONT_SIZE := 20
const SEGMENT_SIZE := Vector2(92, 42)


## Append the General (language, fullscreen, battle speed) and Sound sections to
## `box`. `on_language_change` is invoked (no args) AFTER Settings.set_language +
## persistence so the caller can reload the current scene. `in_battle` adds the
## "(restarts battle)" hint.
static func add_controls(
	box: VBoxContainer, on_language_change: Callable, in_battle: bool = false
) -> void:
	box.add_child(section_header("SETTINGS_SECTION_GENERAL"))
	var lang := _segmented(
		[["中文", "zh"], ["English", "en"]], Settings.language,
		func(value) -> void:
			if value == Settings.language:
				return
			Settings.set_language(value)
			on_language_change.call()
	)
	box.add_child(row("SETTINGS_LANGUAGE", lang))
	if in_battle:
		var note := _label(TranslationServer.translate("SETTINGS_LANG_NOTE"))
		note.add_theme_font_size_override("font_size", 16)
		note.add_theme_color_override("font_color", T.PANEL_INK_SOFT)
		note.custom_minimum_size.x = 0
		var note_row := HBoxContainer.new()
		var indent := Control.new()
		indent.custom_minimum_size.x = LABEL_WIDTH + 12.0
		note_row.add_child(indent)
		note_row.add_child(note)
		box.add_child(note_row)
	var on_off := [
		[TranslationServer.translate("SETTINGS_ON"), true],
		[TranslationServer.translate("SETTINGS_OFF"), false],
	]
	box.add_child(row("SETTINGS_FULLSCREEN", _segmented(
		on_off, Settings.fullscreen, func(value) -> void: Settings.set_fullscreen(value)
	)))
	box.add_child(row("SETTINGS_GAME_SPEED", _segmented(
		[["1x", 1.0], ["1.5x", 1.5], ["2x", 2.0]], Settings.game_speed,
		func(value) -> void: Settings.set_game_speed(value)
	)))

	box.add_child(section_header("SETTINGS_SECTION_AUDIO"))
	box.add_child(row("SETTINGS_VOLUME", _volume(Settings.master_volume, Settings.set_master_volume)))
	box.add_child(row("SETTINGS_MUSIC", _volume(Settings.music_volume, Settings.set_music_volume)))
	box.add_child(row("SETTINGS_SFX", _volume(Settings.sfx_volume, Settings.set_sfx_volume)))


## The full settings body used by every overlay: General + Sound on the left,
## key bindings on the right.
static func build_columns(on_language_change: Callable, in_battle: bool = false) -> HBoxContainer:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 56)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size.x = 420
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.custom_minimum_size.x = 380
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	add_controls(left, on_language_change, in_battle)
	add_key_controls(right)
	return columns


## Append a Key Bindings section: one rebind row per battle action + a Reset.
static func add_key_controls(box: VBoxContainer) -> void:
	box.add_child(section_header("SETTINGS_KEYBINDS"))
	var actions := [
		["end_turn", "SETTINGS_KEY_END_TURN"],
		["view_draw", "SETTINGS_KEY_DRAW"],
		["view_discard", "SETTINGS_KEY_DISCARD"],
		["view_exhaust", "SETTINGS_KEY_EXHAUST"],
		["view_attributes", "SETTINGS_KEY_ATTRS"],
	]
	for pair in actions:
		var key_row = KEYBIND_ROW.new()
		box.add_child(key_row)
		key_row.setup(pair[0], TranslationServer.translate(pair[1]))
	var reset := Button.new()
	reset.text = TranslationServer.translate("SETTINGS_RESET_KEYS")
	reset.custom_minimum_size = Vector2(170, 42)
	reset.focus_mode = Control.FOCUS_NONE
	reset.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	reset.size_flags_horizontal = Control.SIZE_SHRINK_END
	reset.add_theme_font_size_override("font_size", 18)
	T.apply_action_button(reset, "secondary")
	reset.pressed.connect(
		func() -> void:
			AudioManager.play_sfx("ui_click")
			Settings.reset_keys()
			for c in box.get_children():
				if c.has_method("refresh"):
					c.refresh()
	)
	box.add_child(reset)


## A rust section title with a thin ink rule under it.
static func section_header(key: String) -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 4)
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	wrap.add_child(gap)
	var title := Label.new()
	title.text = TranslationServer.translate(key)
	T.style_display(title, 22, 700)
	title.add_theme_color_override("font_color", T.PANEL_HEADER)
	wrap.add_child(title)
	var rule := ColorRect.new()
	rule.color = Color(T.PANEL_INK, 0.35)
	rule.custom_minimum_size = Vector2(0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(rule)
	return wrap


## "label | control" on one line; the label column has a fixed width.
static func row(key: String, control: Control) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	line.custom_minimum_size.y = ROW_HEIGHT
	var label := _label(TranslationServer.translate(key))
	line.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(control)
	return line


## Segmented choice: one button per [text, value]; the picked one is rust.
static func _segmented(options: Array, current, on_pick: Callable) -> HBoxContainer:
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 6)
	var buttons: Array[Button] = []
	for option in options:
		var b := Button.new()
		b.text = String(option[0])
		b.custom_minimum_size = SEGMENT_SIZE
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_override("font", T.display_font(600))
		b.add_theme_font_size_override("font_size", 18)
		b.set_meta("value", option[1])
		group.add_child(b)
		buttons.append(b)
	var paint := func(picked) -> void:
		for b in buttons:
			var on: bool = _same(b.get_meta("value"), picked)
			T.apply_action_button(b, "primary" if on else "secondary", Vector4(10, 6, 10, 8))
	paint.call(current)
	for b in buttons:
		b.pressed.connect(
			func() -> void:
				AudioManager.play_sfx("ui_click")
				var value = b.get_meta("value")
				paint.call(value)
				on_pick.call(value)
		)
	return group


static func _same(a, b) -> bool:
	if typeof(a) == TYPE_FLOAT or typeof(b) == TYPE_FLOAT:
		return is_equal_approx(float(a), float(b))
	return a == b


## Slider + percent readout.
static func _volume(value: float, setter: Callable) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(180, 32)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	T.style_paper_slider(slider)
	line.add_child(slider)
	var readout := Label.new()
	readout.custom_minimum_size.x = 52
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.add_theme_font_override("font", T.display_font(600))
	readout.add_theme_font_size_override("font_size", 18)
	readout.add_theme_color_override("font_color", T.PANEL_INK_SOFT)
	readout.text = "%d%%" % roundi(value * 100.0)
	line.add_child(readout)
	slider.value_changed.connect(
		func(v: float) -> void:
			setter.call(v)
			readout.text = "%d%%" % roundi(v * 100.0)
	)
	return line


static func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = LABEL_WIDTH
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", T.PANEL_INK)
	l.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	return l

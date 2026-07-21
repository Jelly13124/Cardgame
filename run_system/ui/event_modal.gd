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
const RUN_TOP_BAR = preload("res://run_system/ui/run_top_bar.gd")

const TOP_BAR_CLEARANCE := RUN_TOP_BAR.BAR_HEIGHT

signal resolved

var event_data: Dictionary = {}

## Upper-cased event id; builds EVENT_<ID>_* translation keys. Strings render via
## Settings.t(key, english_fallback) — the JSON text is the English fallback, the
## localized columns live in assets/translations/ui_events.csv.
var _eid: String = ""

var _resolved: bool = false
var _option_buttons: Array[Button] = []
var _result_label: Label
var _vbox: VBoxContainer

## BGM playing when the event opened (usually "map") — restored on close so the event
## reads as its own scene with its own music.
var _prev_music: String = ""


func _ready() -> void:
	# Fill the whole screen regardless of parent (a Control under a CanvasLayer or a
	# zero-size parent does NOT get a viewport-sized rect from anchors alone — the
	# background/scrim would render 0x0). Pin top-left and drive the size from the
	# viewport ourselves (top-left anchors avoid the non-equal-anchors size warning).
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	_build()
	_prev_music = AudioManager.current_track()
	AudioManager.play_music("event")


func _fit_to_viewport() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x > 0.0 and vp.y > 0.0:
		position = Vector2.ZERO
		size = vp


func _build() -> void:
	_eid = str(event_data.get("id", "")).to_upper()
	_add_event_background()

	# Accepted concept: the illustration owns the left two-thirds of the page;
	# event copy and choices float directly over the quieter right side. No modal
	# window or ornamental frame.
	var margin := MarginContainer.new()
	margin.name = "EventContent"
	margin.anchor_left = 0.57
	margin.anchor_top = 0.0
	margin.anchor_right = 0.96
	margin.anchor_bottom = 0.93
	margin.offset_top = TOP_BAR_CLEARANCE + 16.0
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	_vbox = VBoxContainer.new()
	_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_theme_constant_override("separation", 18)
	margin.add_child(_vbox)

	var title := Label.new()
	title.text = Settings.t("EVENT_%s_TITLE" % _eid, str(event_data.get("title", "Event")))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_override("font", T.display_font(700))
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.96, 0.79, 0.51))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 3)
	_vbox.add_child(title)

	var desc := Label.new()
	desc.text = Settings.t("EVENT_%s_DESC" % _eid, str(event_data.get("description", "")))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_override("font", T.display_font(500))
	desc.add_theme_font_size_override("font_size", 22)
	desc.add_theme_color_override("font_color", Color(0.94, 0.78, 0.52))
	_vbox.add_child(desc)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size = Vector2(0, 36)
	_vbox.add_child(spacer)

	var options: Variant = event_data.get("options", [])
	if typeof(options) == TYPE_ARRAY:
		for i in options.size():
			var opt: Variant = options[i]
			if typeof(opt) != TYPE_DICTIONARY:
				continue
			_vbox.add_child(_make_option_button(opt, i))


## Fullscreen OPAQUE background so the event reads as its own screen — the map is
## fully hidden (not just dimmed). Per-event art at events/<id>.png, cover-fit; a dark
## scrim keeps the panel legible; falls back to an opaque tint if the art is missing.
func _add_event_background() -> void:
	var eid_lower := str(event_data.get("id", "")).to_lower()
	var path := "res://run_system/assets/images/events/%s.png" % eid_lower
	if eid_lower != "" and ResourceLoader.exists(path):
		var bg := TextureRect.new()
		bg.name = "EventBackground"
		bg.texture = load(path)
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.anchor_right = 1.0
		bg.anchor_bottom = 1.0
		bg.offset_top = RUN_TOP_BAR.PAGE_ART_TOP
		bg.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(bg)
	else:
		var tint := ColorRect.new()
		tint.name = "EventBackground"
		tint.color = Color(0.06, 0.05, 0.04, 1.0)  # OPAQUE — fully covers the map
		tint.anchor_right = 1.0
		tint.anchor_bottom = 1.0
		tint.offset_top = RUN_TOP_BAR.PAGE_ART_TOP
		tint.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(tint)
	# A light global grade preserves the illustration. The copy gets a soft STS2-
	# style edge vignette rather than a rectangular panel behind the whole column.
	var scrim := ColorRect.new()
	scrim.name = "EventGlobalScrim"
	scrim.color = Color(0.0, 0.025, 0.055, 0.34)
	scrim.anchor_right = 1.0
	scrim.anchor_bottom = 1.0
	scrim.offset_top = RUN_TOP_BAR.PAGE_ART_TOP
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var text_vignette := TextureRect.new()
	text_vignette.name = "EventTextVignette"
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.48, 1.0])
	fade.colors = PackedColorArray([
		Color(0.012, 0.025, 0.040, 0.0),
		Color(0.012, 0.025, 0.040, 0.12),
		Color(0.012, 0.025, 0.040, 0.76),
	])
	var fade_texture := GradientTexture2D.new()
	fade_texture.gradient = fade
	fade_texture.width = 1024
	fade_texture.height = 1
	fade_texture.fill_from = Vector2(0.0, 0.5)
	fade_texture.fill_to = Vector2(1.0, 0.5)
	text_vignette.texture = fade_texture
	text_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	text_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	text_vignette.anchor_right = 1.0
	text_vignette.anchor_bottom = 1.0
	text_vignette.offset_top = RUN_TOP_BAR.PAGE_ART_TOP
	text_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(text_vignette)


func _make_option_button(opt: Dictionary, index: int) -> Button:
	var unlocked: bool = RunManager.option_unlocked(opt)
	var button := Button.new()
	button.text = Settings.t("EVENT_%s_OPT%d_TEXT" % [_eid, index], str(opt.get("text", "...")))
	button.custom_minimum_size = Vector2(0, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", T.display_font(600))
	button.add_theme_font_size_override("font_size", 21)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.focus_mode = Control.FOCUS_NONE
	# STS-style option card: frosted-dark row, gold edge + lift on hover, dim when locked.
	button.add_theme_stylebox_override("normal", _option_style(false, not unlocked))
	button.add_theme_stylebox_override("hover", _option_style(true, not unlocked))
	button.add_theme_stylebox_override("pressed", _option_style(true, not unlocked))
	button.add_theme_stylebox_override("disabled", _option_style(false, true))
	var fg := Color(0.95, 0.91, 0.79) if unlocked else Color(0.60, 0.56, 0.49)
	button.add_theme_color_override("font_color", fg)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.84))
	button.add_theme_color_override("font_pressed_color", fg)
	button.add_theme_color_override("font_disabled_color", fg)
	if unlocked:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		button.disabled = true
		button.tooltip_text = _lock_hint(opt)
	button.pressed.connect(_on_option_pressed.bind(index))
	_option_buttons.append(button)
	return button


## A frosted-dark option row. Gold-bordered + brighter on hover; dim grey when locked.
func _option_style(hover: bool, locked: bool) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	if locked:
		st.bg_color = Color(0.055, 0.068, 0.072, 0.90)
		st.border_color = Color(0.30, 0.31, 0.29, 0.78)
	elif hover:
		st.bg_color = Color(0.09, 0.11, 0.115, 0.98)
		st.border_color = Color(1.0, 0.48, 0.08)
	else:
		st.bg_color = Color(0.045, 0.060, 0.066, 0.96)
		st.border_color = Color(0.62, 0.52, 0.32, 0.88)
	st.set_border_width_all(1)
	st.border_width_left = 3 if not locked else 1
	st.set_corner_radius_all(4)
	st.content_margin_left = 22
	st.content_margin_right = 22
	st.content_margin_top = 14
	st.content_margin_bottom = 14
	return st


## Human-readable "[Charm N] [Luck N]" hint for a locked option's requires gate.
func _lock_hint(opt: Dictionary) -> String:
	var requires: Variant = opt.get("requires", {})
	if typeof(requires) != TYPE_DICTIONARY:
		return ""
	var parts: Array[String] = []
	for attr in requires.keys():
		var attr_name := Settings.t(
			"UI_BATTLE_ATTR_%s" % str(attr).to_upper(), str(attr).capitalize()
		)
		parts.append("[%s %d]" % [attr_name, int(requires[attr])])
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

	# Pick the (effects, key-suffix, english-fallback) triple, then apply + render
	# once — the plain and luck_check success/fail paths differ only in these three.
	var effects_key := "effects"
	var suffix := "RESULT"
	var fallback := str(opt.get("result", opt.get("result_text", "")))
	if bool(opt.get("luck_check", false)):
		if randf() < RunManager.luck_check_chance():
			effects_key = "effects_success"
			suffix = "RESULT_OK"
			fallback = str(opt.get("result_success", opt.get("result", "")))
		else:
			effects_key = "effects_fail"
			suffix = "RESULT_FAIL"
			fallback = str(opt.get("result_fail", opt.get("result", "")))

	RunManager.apply_event_effects(opt.get(effects_key, []))
	_show_result(Settings.t("EVENT_%s_OPT%d_%s" % [_eid, index, suffix], fallback))


## Replace the options with the outcome text + a Continue button that finalizes.
func _show_result(text: String) -> void:
	for button in _option_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_option_buttons.clear()

	_result_label = Label.new()
	_result_label.text = text
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.add_theme_font_size_override("font_size", 21)
	_result_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	_vbox.add_child(_result_label)

	var continue_btn := Button.new()
	continue_btn.text = Settings.t("UI_EVENT_CONTINUE", "Continue")
	continue_btn.custom_minimum_size = Vector2(0, 64)
	continue_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continue_btn.add_theme_font_size_override("font_size", 20)
	continue_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_btn.focus_mode = Control.FOCUS_NONE
	continue_btn.add_theme_stylebox_override("normal", _option_style(false, false))
	continue_btn.add_theme_stylebox_override("hover", _option_style(true, false))
	continue_btn.add_theme_stylebox_override("pressed", _option_style(true, false))
	continue_btn.add_theme_color_override("font_color", Color(0.95, 0.91, 0.79))
	continue_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.84))
	continue_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	continue_btn.pressed.connect(_finalize)
	_vbox.add_child(continue_btn)


func _finalize() -> void:
	if _prev_music != "":
		AudioManager.play_music(_prev_music)
	resolved.emit()
	queue_free()

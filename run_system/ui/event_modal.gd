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

## Upper-cased event id; builds EVENT_<ID>_* translation keys. Strings render via
## Settings.t(key, english_fallback) — the JSON text is the English fallback, the
## localized columns live in assets/translations/ui_events.csv.
var _eid: String = ""

var _resolved: bool = false
var _option_buttons: Array[Button] = []
var _result_label: Label
var _vbox: VBoxContainer


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


func _fit_to_viewport() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x > 0.0 and vp.y > 0.0:
		position = Vector2.ZERO
		size = vp


func _build() -> void:
	_eid = str(event_data.get("id", "")).to_upper()
	_add_event_background()

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
	title.text = Settings.t("EVENT_%s_TITLE" % _eid, str(event_data.get("title", "Event")))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	_vbox.add_child(title)

	var desc := Label.new()
	desc.text = Settings.t("EVENT_%s_DESC" % _eid, str(event_data.get("description", "")))
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


## Fullscreen OPAQUE background so the event reads as its own screen — the map is
## fully hidden (not just dimmed). Per-event art at events/<id>.png, cover-fit; a dark
## scrim keeps the panel legible; falls back to an opaque tint if the art is missing.
func _add_event_background() -> void:
	var eid_lower := str(event_data.get("id", "")).to_lower()
	var path := "res://run_system/assets/images/events/%s.png" % eid_lower
	if eid_lower != "" and ResourceLoader.exists(path):
		var bg := TextureRect.new()
		bg.texture = load(path)
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(bg)
	else:
		var tint := ColorRect.new()
		tint.color = Color(0.06, 0.05, 0.04, 1.0)  # OPAQUE — fully covers the map
		tint.set_anchors_preset(Control.PRESET_FULL_RECT)
		tint.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(tint)
	# Readability scrim over the art so the title/desc/options stay legible.
	var scrim := ColorRect.new()
	scrim.color = Color(0.0, 0.0, 0.0, 0.5)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)


func _make_option_button(opt: Dictionary, index: int) -> Button:
	var button := Button.new()
	button.text = Settings.t("EVENT_%s_OPT%d_TEXT" % [_eid, index], str(opt.get("text", "...")))
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
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.add_theme_font_size_override("font_size", 21)
	_result_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	_vbox.add_child(_result_label)

	var continue_btn := Button.new()
	continue_btn.text = Settings.t("UI_EVENT_CONTINUE", "Continue")
	continue_btn.custom_minimum_size = Vector2(600, 56)
	continue_btn.add_theme_font_size_override("font_size", 20)
	continue_btn.pressed.connect(_finalize)
	_vbox.add_child(continue_btn)


func _finalize() -> void:
	resolved.emit()
	queue_free()

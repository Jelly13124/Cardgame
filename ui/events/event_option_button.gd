## One event option as a button (STS2 NEventOptionButton): its text, plus the
## lock reason, the luck chance and a lethal warning. Icons from
## ui/events/icons/ show when present; a text suffix stands in until then.
## class_name is intentionally omitted by project convention — preload.
extends Button

const T = preload("uid://dfcqloc58bvde")  # res://ui/common/theme/wasteland_theme.gd
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const ICON_DIR := "res://ui/events/icons/"
## Locked options use the shared ui_v2 padlock on the grey strip.
const LOCK_ICON := "res://run_system/assets/images/ui_v2/icons/lock.png"
const INK := Color("#1a100a")
const LOCKED_INK := Color("#3f3a35")
const LETHAL_INK := Color("#9a2414")

var option


func setup(p_option, model) -> void:
	option = p_option
	var label: String = model.format(Settings.t(option.text_key))
	var locked: bool = option.is_locked()
	if locked and option.lock_reason != "":
		var reason: String = option.lock_reason
		if option.lock_attr != "":
			reason = "%s %d" % [Settings.t("UI_BATTLE_ATTR_%s" % option.lock_attr.to_upper(), option.lock_attr.capitalize()), option.lock_need]
		label += _marker("lock", "[%s]" % reason, reason)
	if option.chance >= 0.0:
		var pct := "%d%%" % roundi(option.chance * 100.0)
		label += _marker("luck", "(%s)" % pct, pct)
	if option.will_kill_player:
		label += _marker("lethal", "☠", "")
	text = label
	custom_minimum_size = Vector2(0, 64)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_font_override("font", T.display_font(600))
	add_theme_font_size_override("font_size", 21)
	alignment = HORIZONTAL_ALIGNMENT_CENTER if option.is_proceed else HORIZONTAL_ALIGNMENT_LEFT
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	focus_mode = Control.FOCUS_NONE
	# ui_v2 option strip: cream rounded rectangle, lighter on hover, grey when locked.
	add_theme_stylebox_override("normal", _style("normal", locked))
	add_theme_stylebox_override("hover", _style("hover", locked))
	add_theme_stylebox_override("pressed", _style("pressed", locked))
	add_theme_stylebox_override("disabled", _style("disabled", true))
	var fg := INK if not locked else LOCKED_INK
	if option.will_kill_player:
		fg = LETHAL_INK
	add_theme_color_override("font_color", fg)
	add_theme_color_override("font_hover_color", fg)
	add_theme_constant_override("icon_max_width", 30)
	add_theme_color_override("font_pressed_color", fg)
	add_theme_color_override("font_disabled_color", fg)
	disabled = locked
	if not locked:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Tooltip.bind_hover(self, _hover_tip())


## "  <text>" for a marker: with its icon file present, the icon shows and only
## `icon_text` follows the label; without it, the whole `fallback`.
func _marker(kind: String, fallback: String, icon_text: String) -> String:
	var path := LOCK_ICON if kind == "lock" else ICON_DIR + kind + ".png"
	if not ResourceLoader.exists(path):
		return "  " + fallback
	icon = load(path)
	return "  " + icon_text if icon_text != "" else ""


## Relic or card hover text from ModelDb.
func _hover_tip() -> String:
	for pair in [["relic", option.relic_id], ["card", option.card_id]]:
		if pair[1] == "":
			continue
		var data: Dictionary = MODEL_DB.data(pair[0], pair[1])
		if not data.is_empty():
			return "%s\n%s" % [str(data.get("title", pair[1])), str(data.get("description", ""))]
	return ""


func _style(state: String, locked: bool) -> StyleBoxTexture:
	var st := T.v2_box(
		"events/option_locked" if locked else "events/option_9slice", Vector4(26, 14, 22, 14)
	)
	if not locked and state == "hover":
		st.modulate_color = Color(1.07, 1.06, 1.04)
	elif not locked and state == "pressed":
		st.modulate_color = Color(0.88, 0.86, 0.83)
	return st

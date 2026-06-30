## In-combat Discover popup — frosted scrim over the battle + N enlarged PlayCard
## candidates centered, a bare gold title, pick one. NOT the loot/reward frame skin.
## No class_name (ADR-0006) — owner reaches it via preload.
extends Control

const PLAY_CARD := preload("res://battle_scene/play_card.tscn")

signal discovered(card_id: String)

var _card_ids: Array = []
var _title_text: String = ""


## Caller sets the candidate ids + title BEFORE add_child.
func setup(card_ids: Array, title: String) -> void:
	_card_ids = card_ids
	_title_text = title


func _ready() -> void:
	# Top-left anchors (equal opposite) + explicit size fills the viewport without the
	# "size overridden by anchors" warning (mirrors event_modal's _fit_to_viewport).
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # eat all input → battle is paused
	var vp := get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = vp

	# Frosted scrim: dim the battle but let it show through (NOT an opaque reward frame).
	var scrim := ColorRect.new()
	scrim.color = Color(0.0, 0.0, 0.0, 0.72)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 28)
	add_child(vbox)

	var title := Label.new()
	title.text = _title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 6)
	vbox.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 36)
	vbox.add_child(row)

	for cid in _card_ids:
		row.add_child(_build_candidate(str(cid)))


func _build_candidate(card_id: String) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(208, 286) * 1.25
	var card = PLAY_CARD.instantiate()
	card.scale = Vector2(1.25, 1.25)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(card)
	var info := _card_info(card_id)
	card.card_info = info
	if card.is_node_ready() and card.has_method("set_card_data"):
		card.set_card_data(info)
	# A transparent button over the card captures the click + hover.
	var btn := Button.new()
	btn.flat = true
	btn.custom_minimum_size = holder.custom_minimum_size
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_entered.connect(func() -> void: card.scale = Vector2(1.38, 1.38))
	btn.mouse_exited.connect(func() -> void: card.scale = Vector2(1.25, 1.25))
	btn.pressed.connect(func() -> void: _pick(card_id))
	holder.add_child(btn)
	return holder


func _card_info(card_id: String) -> Dictionary:
	var path := "res://battle_scene/card_info/player/%s.json" % card_id
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"name": card_id, "cost": 0, "type": "skill"}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {"name": card_id}


func _pick(card_id: String) -> void:
	discovered.emit(card_id)
	queue_free()

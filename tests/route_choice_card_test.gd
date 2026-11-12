extends Node

## One route choice card (ui/map/route_choice_card.gd): the room's name, the
## rewards its node prints, the next floor's room icons, and a click that
## chooses it only when the card is interactive.

const CARD = preload("uid://e44exoef6xwg")  # res://ui/map/route_choice_card.tscn

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var card = _card({"id": "f0.1", "type": "elite", "rewards": {"gold": 18, "scrap": 11}}, ["rest", "enemy"], 20, true)
	_expect(card.custom_minimum_size == Vector2(320, 460), "route cards use the wider three-choice size")
	_expect(card.get_node_or_null("ChoiceNumber") != null, "route cards expose a compact choice number")
	_expect(card.get_node("%Rewards").size_flags_vertical == Control.SIZE_SHRINK_CENTER, "route rewards stay compact instead of expanding into a blank well")
	_expect(card.get_node("%TypeName").text == tr("UI_MAP_LEGEND_ELITE"), "the card names its room")
	var rows := _rows(card)
	_expect(rows.size() == 3, "an elite prints Caps, Scrap and a card draft (%s)" % [rows])
	_expect(rows.size() == 3 and "18" in rows[0] and "11" in rows[1] and tr("UI_ROUTE_CARD_DRAFT") in rows[2], "the elite's rows show 18, 11 and the draft (%s)" % [rows])
	_expect(card.get_node("%NextRow").get_child_count() == 2, "the next floor shows two room icons")
	var picked: Array = []
	card.chosen.connect(func(id): picked.append(id))
	card._gui_input(_click())
	_expect(picked == ["f0.1"], "a click chooses the card once (%s)" % [picked])

	_expect(_rows(_card({"id": "a", "type": "enemy", "rewards": {"gold": 6}}, [], 20, true)).size() == 2, "a fight prints Caps and a card draft")
	var rest_rows := _rows(_card({"id": "b", "type": "rest", "rewards": {}}, [], 20, true))
	_expect(rest_rows.size() == 1 and "20" in rest_rows[0], "a campfire prints its heal (%s)" % [rest_rows])
	_expect(_rows(_card({"id": "c", "type": "unknown", "rewards": {}}, [], 20, true)).is_empty(), "an event prints nothing")
	_expect(_rows(_card({"id": "d", "type": "merchant", "rewards": {}}, [], 20, true)).is_empty(), "a merchant prints nothing")
	var chest := _rows(_card({"id": "e", "type": "treasure", "rewards": {}}, [], 20, true))
	_expect(chest == [tr("UI_ROUTE_RELIC_CHOICE")], "a treasure prints the relic choice (%s)" % [chest])

	var still = _card({"id": "f", "type": "enemy", "rewards": {"gold": 6}}, [], 20, false)
	var none: Array = []
	still.chosen.connect(func(id): none.append(id))
	still._gui_input(_click())
	_expect(none.is_empty(), "a card that is not interactive ignores clicks")

	var fight = _card({"id": "g", "type": "enemy", "encounter": "base:scrap_rat_pair", "strength": "strong", "rewards": {"gold": 11}}, [], 20, true)
	_expect(fight.get_node("%Portraits").get_child_count() == 2, "a fight shows its two monsters")
	_expect(fight.get_node("%StrengthTag").visible and fight.get_node("%StrengthTag").text == tr("UI_ROUTE_STRENGTH_STRONG"), "a strong fight is tagged strong")
	_expect("11" in _rows(fight)[0], "a strong fight prints 11 Caps (%s)" % [_rows(fight)])
	var elite = _card({"id": "h", "type": "elite", "encounter": "base:armored_patrol", "strength": "", "rewards": {"gold": 18, "scrap": 9}}, [], 20, true)
	_expect(elite.get_node("%Portraits").get_child_count() == 1 and not elite.get_node("%StrengthTag").visible, "an elite shows one portrait and no tag")
	var camp = _card({"id": "i", "type": "rest", "rewards": {}}, [], 20, true)
	_expect(camp.get_node("%Portraits").get_child_count() == 0, "a campfire shows no portraits")

	if failures.is_empty():
		print("[OK] route choice card passed")
		get_tree().quit(0)
		return
	push_error("route choice card failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _card(node: Dictionary, next_types: Array, heal: int, interactive: bool):
	var card = CARD.instantiate()
	add_child(card)
	card.setup(node, next_types, heal, interactive)
	return card


## Each reward row's labels joined.
func _rows(card) -> Array:
	var out: Array = []
	for row in card.get_node("%Rewards").get_children():
		var parts: PackedStringArray = []
		for c in row.get_children():
			if c is Label:
				parts.append(c.text)
		out.append(" ".join(parts))
	return out


func _click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e

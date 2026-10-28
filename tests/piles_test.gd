extends Node

## Combat piles (core/combat/piles.gd) draw, reshuffle and discard card
## instances deterministically per seed, with no card nodes.

const PILES = preload("uid://cei2a7t4pll5c")  # res://core/combat/piles.gd
const CARD_INSTANCE = preload("uid://c50mv4hudoncd")  # res://core/combat/card_instance.gd
const RNG = preload("uid://ds3dd0kmgq0ib")  # res://core/rng/rng.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	_test_same_seed_same_order()
	_test_reshuffle_once()
	_test_hand_limit()
	_test_discard_hand_keeps_retain()
	_test_card_costs()
	if failures.is_empty():
		print("[OK] piles passed")
		get_tree().quit(0)
		return
	push_error("piles failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _deck(n: int) -> Array:
	var out: Array = []
	for i in range(n):
		out.append(CARD_INSTANCE.make("base:card_%d" % i, {"type": "skill", "cost": 1}))
	return out


func _piles(seed_value: int, n: int) -> RefCounted:
	var p = PILES.new()
	p.rng = RNG.new(seed_value)
	p.fill_draw(_deck(n))
	return p


func _ids(cards: Array) -> Array:
	return cards.map(func(c): return c.model_id)


func _test_same_seed_same_order() -> void:
	var a = _piles(7, 10)
	var b = _piles(7, 10)
	a.draw_cards(5)
	b.draw_cards(5)
	_expect(_ids(a.hand.cards) == _ids(b.hand.cards), "same seed draws the same hand")
	var c = _piles(8, 10)
	c.draw_cards(5)
	_expect(_ids(c.hand.cards) != _ids(a.hand.cards), "another seed draws another hand")


func _test_reshuffle_once() -> void:
	var p = _piles(3, 4)
	p.draw_cards(4)
	for card in p.hand.cards.duplicate():
		p.move(card, "discard")
	var moved := [0]
	p.card_moved.connect(func(_c, from, to): if from == "discard" and to == "draw": moved[0] += 1)
	var events: Array = p.draw_cards(3)
	var kinds: Array = events.map(func(e): return e["kind"])
	_expect(kinds == ["reshuffle", "draw", "draw", "draw"], "an empty draw pile reshuffles once, then draws: %s" % [kinds])
	_expect(moved[0] == 4 and p.size("draw") == 1 and p.size("discard") == 0, "the whole discard pile went back")
	_expect(p.draw_cards(5).map(func(e): return e["kind"]) == ["draw"], "nothing left to reshuffle: the draw stops")


func _test_hand_limit() -> void:
	var p = _piles(1, 14)
	var events: Array = p.draw_cards(12)
	_expect(p.size("hand") == PILES.HAND_LIMIT, "the hand stops at %d cards" % PILES.HAND_LIMIT)
	_expect(events[events.size() - 1]["kind"] == "hand_full", "a draw past the limit reports a full hand")


func _test_discard_hand_keeps_retain() -> void:
	var p = PILES.new()
	var keep = CARD_INSTANCE.make("base:keep", {"type": "skill", "retain": true})
	var drop = CARD_INSTANCE.make("base:drop", {"type": "skill"})
	p.add_new(keep, "hand")
	p.add_new(drop, "hand")
	_expect(p.discard_hand() == [drop], "end of turn discards every card that does not retain")
	_expect(p.where(keep) == "hand" and p.where(drop) == "discard", "the retained card stays in hand")


func _test_card_costs() -> void:
	var card = CARD_INSTANCE.make("base:x", {"type": "attack", "cost": 2})
	_expect(card.cost() == 2, "printed cost")
	card.cost_override = 0
	_expect(card.cost() == 0, "a combat cost override wins")
	_expect(CARD_INSTANCE.make("base:c", {"type": "curse"}).is_unplayable(), "curses are unplayable")
	_expect(CARD_INSTANCE.make("base:e", {"effects": [{"type": "exhaust_self"}]}).exhausts(), "exhaust_self exhausts")

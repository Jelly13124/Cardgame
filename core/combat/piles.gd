extends RefCounted

## The player's combat piles (STS2 PlayerCombatState piles + CardPileCmd):
## draw, hand, discard and exhaust, as card instances. Every operation changes
## the piles at once and returns the events the view animates, in order:
##   {"kind": "draw", "card": c}            draw → hand
##   {"kind": "reshuffle", "cards": [...]}  discard → draw, then shuffled
##   {"kind": "hand_full"}                  a draw stopped at the hand limit
## and every single-card move emits `card_moved(card, from, to)` ("" = created).

const CARD_PILE = preload("uid://i2va650blxo7")  # res://core/combat/card_pile.gd (res://core/combat/card_pile.gd)
const CARD_INSTANCE = preload("uid://c50mv4hudoncd")  # res://core/combat/card_instance.gd (res://core/combat/card_instance.gd)

const HAND_LIMIT := 10

signal card_moved(card: RefCounted, from: String, to: String)

var draw = CARD_PILE.named("draw")
var hand = CARD_PILE.named("hand")
var discard = CARD_PILE.named("discard")
var exhaust = CARD_PILE.named("exhaust")
## Shuffles an Array in place with the run's `shuffle` stream (core/rng/rng.gd).
var rng = null


func pile(pile_name: String) -> RefCounted:
	match pile_name:
		"draw":
			return draw
		"hand":
			return hand
		"discard":
			return discard
		"exhaust":
			return exhaust
	return null


## Name of the pile holding `card`, or "".
func where(card) -> String:
	for p in [hand, draw, discard, exhaust]:
		if p.has(card):
			return p.name
	return ""


## Moves `card` to the top of `to` (from wherever it is).
func move(card, to: String) -> void:
	var from := where(card)
	if from != "":
		pile(from).cards.erase(card)
	pile(to).cards.append(card)
	card_moved.emit(card, from, to)


## A new card created this combat, put on `to`; `shuffle_in` reshuffles the
## draw pile afterwards (an enemy's curse).
func add_new(card, to: String, shuffle_in := false) -> void:
	pile(to).cards.append(card)
	card_moved.emit(card, "", to)
	if shuffle_in and to == "draw":
		_shuffle(draw.cards)


## Fills the draw pile from deck instances and shuffles it.
func fill_draw(cards: Array) -> void:
	for c in cards:
		add_new(c, "draw")
	_shuffle(draw.cards)


## Draw `count` cards: one at a time from the top; an empty draw pile takes the
## whole discard pile back once per need and shuffles it. Stops at the hand
## limit. Returns the events for the view.
func draw_cards(count: int) -> Array:
	var events: Array = []
	var remaining := count
	while remaining > 0:
		if draw.is_empty():
			if discard.is_empty():
				break
			var back: Array = discard.cards.duplicate()
			discard.cards.clear()
			draw.cards.append_array(back)
			_shuffle(draw.cards)
			for c in back:
				card_moved.emit(c, "discard", "draw")
			events.append({"kind": "reshuffle", "cards": back})
			continue
		if hand.size() >= HAND_LIMIT:
			events.append({"kind": "hand_full"})
			break
		var card = draw.top()
		move(card, "hand")
		events.append({"kind": "draw", "card": card})
		remaining -= 1
	return events


## End of turn: every hand card that does not retain goes to the discard pile,
## in hand order. Returns the discarded cards.
func discard_hand() -> Array:
	var out: Array = []
	for c in hand.cards.duplicate():
		if c.retains():
			continue
		move(c, "discard")
		out.append(c)
	return out


func size(pile_name: String) -> int:
	return pile(pile_name).size()


func _shuffle(cards: Array) -> void:
	if rng != null:
		rng.shuffle(cards)
	else:
		cards.shuffle()  # rng-ok: piles built without a run stream (tests)

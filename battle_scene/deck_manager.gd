extends Node

var battle_scene: Node
var deck: Node
var discard_pile: Node
var hand: Node
var card_factory: Node


# Special opening hand logic
func first_round_draw() -> void:
	draw_cards(3)


# Moves a specific number of cards from the top of the Deck to the Hand.
## Single-card draws use a 0.1s stagger for visual feedback. After a reshuffle,
## remaining draws are batched into ONE hand.move_cards() call — adding cards
## one-by-one would re-fan the hand on every add, so any cards still in hand
## (drawn before deck depleted) visibly shift positions N times. Batching makes
## the hand re-fan only once to its final layout.
## Serialized draw guard. draw_cards is an async coroutine but most callers
## fire-and-forget it (card draw effects, turn-start draw, relic/harmony draws).
## If a second draw is requested while one is running (e.g. during a reshuffle's
## ~0.5s animation), running both concurrently double-draws / corrupts the piles.
## So: queue the extra count and draw it AFTER the current draw finishes.
var _drawing: bool = false
var _pending_draw: int = 0


## True while a draw (incl. a slow reshuffle) is in flight. Callers like the
## auto-end-turn check must NOT treat an empty hand as "unplayable" mid-draw.
func is_drawing() -> bool:
	return _drawing or _pending_draw > 0


func draw_cards(count: int) -> void:
	if count <= 0:
		return
	if _drawing:
		_pending_draw += count
		return
	_drawing = true
	await _draw_internal(count)
	while _pending_draw > 0:
		var n: int = _pending_draw
		_pending_draw = 0
		await _draw_internal(n)
	_drawing = false


func _draw_internal(count: int) -> void:
	var remaining = count
	while remaining > 0:
		if deck.get_card_count() > 0:
			# Normal staggered single-card draw
			var cards = deck.get_top_cards(1)
			var success = hand.move_cards(cards)
			if not success:
				battle_scene.show_notification("HAND FULL", Color(1, 0.4, 0.4))
				return
			battle_scene._update_ui_labels()
			remaining -= 1
			if remaining > 0:
				await battle_scene._wait(0.1)
		elif discard_pile.get_card_count() > 0:
			# Deck empty → visibly fly each discard card back to the deck FIRST,
			# then shuffle and batch-draw. Just calling deck.move_cards() would
			# teleport invisibly (deck has hide_cards=true), so the player would
			# see cards apparently drawn straight from the discard pile.
			battle_scene.show_notification("RESHUFFLING", Color(0.4, 0.8, 1.0))
			var discarded = discard_pile.get_cards().duplicate()

			var start_positions: Array = []
			for c in discarded:
				start_positions.append(c.global_position)

			# Detach from discard pile so the pile's _update_target_positions
			# stops fighting our manual transforms during the flight.
			for c in discarded:
				if c.card_container and c.card_container.has_card(c):
					c.card_container.remove_card(c)

			const RESHUFFLE_STAGGER := 0.04
			const RESHUFFLE_FLIGHT := 0.34
			for i in range(discarded.size()):
				var c = discarded[i]
				if not is_instance_valid(c):
					continue
				battle_scene.card_animator.fly_to_deck(c, start_positions[i])
				if i < discarded.size() - 1:
					await battle_scene._wait(RESHUFFLE_STAGGER)
			await battle_scene._wait(RESHUFFLE_FLIGHT)

			# Land all cards in the deck, then shuffle.
			for c in discarded:
				if is_instance_valid(c):
					deck.add_card(c)
			deck.shuffle()
			battle_scene._update_ui_labels()
			await battle_scene._wait(0.15)

			var batch_size = min(remaining, deck.get_card_count())
			if batch_size <= 0:
				break
			var cards = deck.get_top_cards(batch_size)
			var success = hand.move_cards(cards)
			if not success:
				battle_scene.show_notification("HAND FULL", Color(1, 0.4, 0.4))
				return
			battle_scene._update_ui_labels()
			remaining -= batch_size
		else:
			# Both piles empty
			break


# Clears the deck and refills it with a fresh, shuffled list of cards
func reset_deck() -> void:
	var list = []
	if RunManager.is_run_active:
		list = RunManager.player_deck.duplicate()
	else:
		list = get_randomized_card_list()

	deck.clear_cards()
	discard_pile.clear_cards()
	for item in list:
		var card_name = item if typeof(item) == TYPE_STRING else item["card_id"]
		var card = card_factory.create_card(card_name, deck)
		if card and typeof(item) == TYPE_DICTIONARY:
			card.set_meta("uid", item.get("uid", ""))
			card.set_meta("gems", item.get("gems", []))

	deck.shuffle()
	battle_scene._update_ui_labels()


# Returns the master list of all available cards in the deck
func get_randomized_card_list() -> Array:
	var list = [
		"strike",
		"strike",
		"strike",
		"strike",
		"weak_strike",
		"defend",
		"defend",
		"defend",
		"defend",
		"siphon",
		"preemptive_strike"
	]
	list.shuffle()
	return list

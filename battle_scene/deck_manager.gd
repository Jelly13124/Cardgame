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
func draw_cards(count: int) -> void:
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
		"override",
		"preemptive_strike"
	]
	list.shuffle()
	return list

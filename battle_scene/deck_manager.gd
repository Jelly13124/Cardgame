extends Node

var battle_scene: Node
var deck: Node
var discard_pile: Node
var hand: Node
var card_factory: Node

# Special opening hand logic
func first_round_draw() -> void:
	draw_cards(3)

# Moves a specific number of cards from the top of the Deck to the Hand
func draw_cards(count: int) -> void:
	for i in range(count):
		# Re-check deck every iteration in case of reshuffle
		if deck.get_card_count() == 0:
			if discard_pile.get_card_count() > 0:
				battle_scene.show_notification("RESHUFFLING", Color(0.4, 0.8, 1.0))
				var discarded = discard_pile.get_cards().duplicate()
				# Move cards back to deck
				deck.move_cards(discarded)
				deck.shuffle()
				battle_scene._update_ui_labels()
				# Wait a bit for the shuffle animation/state to settle
				await battle_scene._wait(0.3)
			else:
				# Both piles are empty
				break
		
		# Now try to draw
		var cards = deck.get_top_cards(1)
		if cards.size() > 0:
			var success = hand.move_cards(cards)
			if not success:
				battle_scene.show_notification("HAND FULL", Color(1, 0.4, 0.4))
				break
			
			# Wait briefly between draws for visual clarity and layout stability
			battle_scene._update_ui_labels()
			await battle_scene._wait(0.1)

# Clears the deck and refills it with a fresh, shuffled list of cards
func reset_deck() -> void:
	var list = []
	var run_manager = get_node_or_null("/root/RunManager")
	if run_manager and run_manager.get("is_run_active"):
		list = run_manager.player_deck.duplicate()
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
		"strike", "strike", "strike", "strike",
		"defend", "defend", "defend", "defend",
		"override", "preemptive_strike"
	]
	list.shuffle()
	return list

extends Node

var battle_scene: Node
var deck: Node
var discard_pile: Node
var hand: Node
var card_factory: Node

# Special opening hand logic
func first_round_draw() -> void:
	# Always give the player the Hero card first
	var _hero = card_factory.create_card("hero_robot_bill", hand)
	
	# Draw up to 3 random UNITS specifically for the first round
	var units_found = []
	var all_deck_cards = deck.get_cards()
	# Reverse to get from 'top' of pile if needed, but deck is shuffled
	for i in range(all_deck_cards.size() - 1, -1, -1):
		var card = all_deck_cards[i]
		if card.card_info.get("type", "") == "unit":
			units_found.append(card)
			if units_found.size() >= 3:
				break
				
	if units_found.size() > 0:
		hand.move_cards(units_found)
	
	battle_scene._update_ui_labels()

# Moves a specific number of cards from the top of the Deck to the Hand
func draw_cards(count: int) -> void:
	for i in range(count):
		# Re-check deck every iteration in case of reshuffle
		if deck.get_card_count() == 0:
			if discard_pile.get_card_count() > 0:
				battle_scene.show_notification("RESHUFFLING DECK", Color(0.4, 0.8, 1.0))
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
			await battle_scene._wait(0.25)

# Clears the deck and refills it with a fresh, shuffled list of cards
func reset_deck() -> void:
	var list = []
	var run_manager = get_node_or_null("/root/RunManager")
	if run_manager and run_manager.is_run_active:
		list = run_manager.player_deck.duplicate()
	else:
		list = get_randomized_card_list()
	
	deck.clear_cards()
	discard_pile.clear_cards()
	for item in list:
		var card_name = item if typeof(item) == TYPE_STRING else item["card_id"]
		var card = card_factory.create_card(card_name, deck)
		if card and typeof(item) == TYPE_DICTIONARY:
			card.set_meta("uid", item["uid"])
			if card is UnitCard:
				var b_atk = item.get("bonus_attack", 0)
				var b_hp = item.get("bonus_health", 0)
				if b_atk > 0 or b_hp > 0:
					card.add_permanent_stats(b_atk, b_hp)
	deck.shuffle()
	battle_scene._update_ui_labels()

# Returns the master list of all available cards in the deck
func get_randomized_card_list() -> Array:
	var list = [
		"spell_zap", "spell_zap",
		"spell_energize", "spell_modify",
		"spell_draft", "spell_air_raid",
		"unit_robot_leader", "unit_robot_leader"
	]
	
	list.shuffle()
	return list

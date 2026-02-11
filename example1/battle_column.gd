class_name BattleColumn
extends CardContainer

@export var is_player_column: bool = true

func _ready() -> void:
	super._ready()
	# Ensure the container itself can receive drops
	enable_drop_zone = true
	# Set a large sensor area that covers the whole column
	if drop_zone:
		drop_zone.set_sensor(Vector2(225, 700), Vector2.ZERO, null, false)
	
	# Visual color based on territory (Initial)
	update_card_ui()

func _card_can_be_added(cards: Array) -> bool:
	var main = get_tree().current_scene
	
	# Prevent spells from being played on the field directly - SILENTLY REJECT so SpellPlayZone can catch it
	for card in cards:
		if card.card_info.get("type", "") == "spell":
			return false
	
	# 1. Block deployment if the column is occupied by enemies
	var column_has_enemy = false
	for card in _held_cards:
		if card.card_info.get("side", "player") == "enemy":
			column_has_enemy = true
			break
			
	if column_has_enemy:
		for card in cards:
			if card.card_info.get("side", "player") == "player":
				if main and main.has_method("show_notification"):
					main.show_notification("COLUMN OCCUPIED", Color(1, 0.4, 0.4))
				return false

	# 2. Territory check: Block player units from entering dedicated enemy territory
	if not is_player_column:
		for card in cards:
			if card.card_info.get("side", "player") == "player":
				if main and main.has_method("show_notification"):
					main.show_notification("NOT YOUR TERRITORY", Color(1, 0.4, 0.4))
				return false
		
	# Max 5 cards per column (including the Mothership if it's here)
	if _held_cards.size() + cards.size() > 5:
		if main and main.has_method("show_notification"):
			main.show_notification("COLUMN FULL", Color(1, 0.8, 0.2))
		return false
	
	# Check Energy in Example1 (only if playing from hand)
	if main and main.has_method("can_afford"):
		var from_hand = false
		for card in cards:
			if card.card_container and card.card_container is Hand:
				from_hand = true
				break
				
		if from_hand:
			if not main.can_afford(cards):
				if main.has_method("show_notification"):
					main.show_notification("NOT ENOUGH ENERGY", Color(0.2, 0.6, 1))
				return false
			
	return true


## Override target position logic to separate cards completely
func _update_target_positions() -> void:
	var v_spacing = 135 # Fixed gap between separate cards
	var start_y = 20
	# 1. Determine background color based on faction and occupation
	if has_node("Background"):
		var column_has_enemy = false
		for card in _held_cards:
			if card.card_info.get("side", "player") == "enemy":
				column_has_enemy = true
				break
				
		if column_has_enemy:
			$Background.color = Color(0.6, 0.2, 0.2, 0.25) # Stronger Red for occupied
		elif is_player_column:
			$Background.color = Color(0.2, 0.4, 0.2, 0.15) # Normal Player Green
		else:
			$Background.color = Color(0.4, 0.2, 0.2, 0.15) # Normal Enemy Red

	# 2. Separate cards into Mothership and regular units
	var mothership_card = null
	var other_cards = []
	
	for card in _held_cards:
		if card.card_info.get("name", "") == "building_mothership":
			mothership_card = card
		else:
			other_cards.append(card)
	
	# 1. Position the Mother Ship at Slot 3 (Index 2)
	if mothership_card:
		var ship_pos = global_position + Vector2(64, start_y + (2 * v_spacing))
		mothership_card.move(ship_pos, 0)
		mothership_card.scale = Vector2(0.6, 0.6)
		mothership_card.original_scale = Vector2(0.6, 0.6)
		mothership_card.show_front = true
		mothership_card.can_be_interacted_with = false # Safety lock
		
		# Trigger Token View
		if mothership_card.has_method("set_view_mode"):
			mothership_card.set_view_mode("token")
	
	# 2. Position other cards in remaining slots (0, 1, 3, 4)
	var available_slots = [0, 1, 3, 4]
	# If no Mothership is present, use all 5 slots (0, 1, 2, 3, 4)
	if not mothership_card:
		available_slots = [0, 1, 2, 3, 4]
		
	for i in range(other_cards.size()):
		if i >= available_slots.size(): break
		
		var card = other_cards[i]
		var layout_index = available_slots[i]
		var target_pos = global_position + Vector2(64, start_y + (layout_index * v_spacing))
		
		card.move(target_pos, 0)
		card.scale = Vector2(0.6, 0.6)
		card.original_scale = Vector2(0.6, 0.6)
		card.show_front = true
		
		# Lock interaction if this is an enemy unit that has invaded player territory
		if card.card_info.get("side", "player") == "enemy":
			card.can_be_interacted_with = false
		else:
			card.can_be_interacted_with = true
		
		# Trigger Token View for UnitCards
		if card.has_method("set_view_mode"):
			card.set_view_mode("token")

## Handle energy deduction on move
func move_cards(cards: Array, index: int = -1, with_history: bool = true) -> bool:
	var hand_cards = []
	for card in cards:
		if card.card_container is Hand:
			hand_cards.append(card)
	
	var success = super.move_cards(cards, index, with_history)
	
	if success and hand_cards.size() > 0:
		var main = get_tree().current_scene
		if main and main.has_method("spend_energy"):
			main.spend_energy(hand_cards)
			
	return success

## When a card leaves this container, reset its scale
func remove_card(card: Card) -> bool:
	var result = super.remove_card(card)
	if result:
		card.scale = Vector2(1, 1)
		card.original_scale = Vector2(1, 1)
		
		# Revert to Full Card View when leaving the field
		if card.has_method("set_view_mode"):
			card.set_view_mode("card")
	return result

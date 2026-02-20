extends Node

func execute(context: Dictionary) -> void:
	var target_row = context.get("target")
	
	if not target_row or not is_instance_valid(target_row):
		return
		
	# Iterate through all cards in the row
	# We need to be careful about modifying the list while iterating if units die
	var cards = target_row.get_cards().duplicate()
	
	for card in cards:
		if not is_instance_valid(card): continue
		
		# Check if it's an enemy
		if card.card_info.get("side", "player") != "player":
			if card.has_method("take_damage"):
				card.take_damage(1)
		
	# Visual feedback?
	# Could spawn an explosion effect on the row center if we had one

extends "res://battle_scene/units/keywords/keyword_base.gd"

# Grants +1/+1 to all friendly units in the same row at the start of the turn
func on_turn_start(row: Node) -> void:
	if not is_instance_valid(unit) or not unit.get_parent(): return
	
	var my_side = unit.card_info.get("side", "player")
	var buffed_anyone = false
	
	for card in row.get_cards():
		if is_instance_valid(card) and card != unit:
			if card.card_info.get("side", "player") == my_side:
				if card.has_method("add_temporary_stats"):
					card.add_temporary_stats(1, 1)
					buffed_anyone = true
				
	if buffed_anyone:
		unit.show_notification("LEADERSHIP!", Color.GOLD)

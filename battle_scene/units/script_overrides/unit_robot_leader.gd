extends Node

var unit_card: Control

func setup(card: Control) -> void:
	unit_card = card

func execute_battle_cry(row: Node, slot_index: int) -> void:
	if not is_instance_valid(unit_card) or not unit_card.get_parent(): return
	var my_side = unit_card.card_info.get("side", "player")
	
	var adjacent_slots = [slot_index - 1, slot_index + 1]
	var buffed_anyone = false
	
	for slot in adjacent_slots:
		if slot >= 0 and slot <= 3: # Player slots only
			var neighbor = row.get_card_at_slot(slot)
			if neighbor and is_instance_valid(neighbor) and neighbor.card_info.get("side", "player") == my_side:
				if neighbor.has_method("add_permanent_stats"):
					neighbor.add_permanent_stats(1, 1)
					buffed_anyone = true
	
	if buffed_anyone:
		if unit_card.has_method("show_notification"):
			unit_card.show_notification("BATTLE CRY!", Color.GOLD)

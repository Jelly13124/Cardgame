extends Node

var unit_card: Control

func setup(card: Control) -> void:
	unit_card = card

func execute_end_of_turn(row: Node) -> void:
	if not is_instance_valid(unit_card) or not unit_card.get_parent(): return
	
	var main = unit_card.get_tree().current_scene
	if not main or not main.has_method("_get_battle_rows"): return
	
	var my_side = unit_card.card_info.get("side", "player")
	var target_side = "enemy" if my_side == "player" else "player"
	
	var all_rows = main._get_battle_rows()
	var enemy_row = null
	
	for r in all_rows:
		if r.row_side == target_side:
			enemy_row = r
			break
			
	if enemy_row:
		var targets = []
		for c in enemy_row.get_cards():
			if is_instance_valid(c):
				targets.append(c)
				
		if targets.size() > 0:
			var target = targets[randi() % targets.size()]
			if target.has_method("take_damage"):
				target.take_damage(2)
				unit_card.show_notification("ENFORCE BARRAGE!", Color.RED)

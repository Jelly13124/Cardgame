extends "res://battle_scene/units/keywords/keyword_base.gd"

func on_before_attack(targets: Array, row: Node) -> Array:
	# Ignore existing target list and instead target ALL opposing units in the row
	var new_targets = []
	var is_player = unit.card_info.get("side", "player") == "player"
	
	# Scopes range: slots 0-3 (Player) or 4-7 (Enemy)
	var slots = range(4, 8) if is_player else range(0, 4)
	
	for i in slots:
		var target = row.get_card_at_slot(i)
		if is_instance_valid(target) and target != unit:
			new_targets.append(target)
	
	if new_targets.size() > 0:
		unit.show_notification("WIPE!", Color.ORANGE)
		
	return new_targets

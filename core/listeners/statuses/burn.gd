extends "res://core/listeners/status_listener.gd"

## Burn: at the bearer's turn start take damage equal to stacks, then stacks
## are halved (rounded down).


func at_owner_turn_start(entity: Node) -> void:
	var dmg := amount()
	if dmg <= 0:
		return
	system.deal_status_damage(entity, dmg, id)
	system.set_stacks(id, dmg / 2, entity)

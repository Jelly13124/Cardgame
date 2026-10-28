extends "res://core/listeners/status_listener.gd"

## Regen: at the bearer's turn start heal stacks HP, then lose 1 stack.


func at_owner_turn_start(entity: Object) -> void:
	var n := amount()
	if n <= 0:
		return
	if entity.has_method("heal"):
		entity.heal(n)
	system.set_stacks(id, n - 1, entity)

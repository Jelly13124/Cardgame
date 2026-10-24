extends "res://core/listeners/status_listener.gd"

## Reactive Plating: whenever a card grants the bearer Block, gain Thorns equal
## to stacks.


func after_block_gained(result: Dictionary) -> void:
	var source = result.get("source")
	if source == null or not source.is_card() or result.get("creature") != owner or commands() == null:
		return
	var n := amount()
	if n > 0:
		await commands().apply_status(source, owner, "thorns", n, "reactive_plating")

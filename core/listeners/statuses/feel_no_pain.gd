extends "res://core/listeners/status_listener.gd"

## Feel No Pain: whenever the player Exhausts a card, gain stacks Block. A player
## power: an enemy bearer ignores the player's Exhausts.


func after_card_exhausted(_card) -> void:
	if side() != "player":
		return
	await gain_power_block(amount())

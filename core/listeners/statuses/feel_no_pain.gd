extends "res://core/listeners/status_listener.gd"

## Feel No Pain: whenever a card is Exhausted, gain stacks Block.


func after_card_exhausted(_card) -> void:
	await gain_power_block(amount())

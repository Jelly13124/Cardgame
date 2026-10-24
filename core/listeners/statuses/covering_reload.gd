extends "res://core/listeners/status_listener.gd"

## Covering Reload: whenever the player Reloads, gain `vars.block` (3) Block. A
## player power: an enemy bearer ignores the player's Reloads.


func after_reload(_source) -> void:
	if side() == "player" and amount() > 0:
		await gain_power_block(int(var_value("block", 3)))

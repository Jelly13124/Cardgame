extends "res://core/listeners/status_listener.gd"

## Covering Reload: whenever you Reload, gain `vars.block` (3) Block.


func after_reload(_source) -> void:
	if amount() > 0:
		await gain_power_block(int(var_value("block", 3)))

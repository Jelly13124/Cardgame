extends "res://core/listeners/status_listener.gd"

## Hot Streak: whenever the bearer Crits, gain `vars.loaded` (2) Loaded.


func after_crit(calc) -> void:
	if calc.dealer == owner and amount() > 0:
		owner.add_status("loaded", int(var_value("loaded", 2)))

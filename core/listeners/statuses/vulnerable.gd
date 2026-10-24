extends "res://core/listeners/status_listener.gd"

## Vulnerable: powered damage to the bearer is multiplied by `vars.mult` (1.5).


func modify_damage_multiplicative(calc) -> void:
	if calc.is_powered() and calc.target == owner and amount() > 0:
		calc.value *= float(var_value("mult", 1.5))

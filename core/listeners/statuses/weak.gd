extends "res://core/listeners/status_listener.gd"

## Weak: the bearer's powered damage is multiplied by `vars.mult` (0.5).


func modify_damage_multiplicative(calc) -> void:
	if calc.is_powered() and calc.dealer == owner and amount() > 0:
		calc.value *= float(var_value("mult", 0.5))

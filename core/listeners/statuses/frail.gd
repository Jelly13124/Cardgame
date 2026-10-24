extends "res://core/listeners/status_listener.gd"

## Frail: the bearer's powered Block is multiplied by `vars.mult` (0.75).


func modify_block_multiplicative(calc) -> void:
	if calc.is_powered() and calc.target == owner and amount() > 0:
		calc.value *= float(var_value("mult", 0.75))

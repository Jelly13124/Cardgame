extends "res://core/listeners/status_listener.gd"

## Intangible: every hit (and HP loss) on the bearer is at most 1.


func modify_damage_cap(calc) -> void:
	if calc.target == owner and amount() > 0:
		calc.value = minf(calc.value, 1.0)

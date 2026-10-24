extends "res://core/listeners/status_listener.gd"

## Overload Protocol: the bearer's Overloads can Crit.


func can_crit_overload(calc) -> bool:
	return calc.dealer == owner and amount() > 0

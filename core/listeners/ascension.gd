extends "res://core/listeners/listener.gd"

## Combat-side ascension rules as one listener (the run-side ones are asked in
## place through RunManager.has_ascension): Cold Start costs energy on the first
## turn of each combat.


func modify_turn_energy(calc) -> void:
	if int(calc.get_field("round", 0)) == 1 and RunManager.has_ascension("base:a3_cold_start"):
		calc.value -= int(RunManager.ascension_param("base:a3_cold_start", "energy", 1))

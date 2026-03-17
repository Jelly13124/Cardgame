extends "res://battle_scene/spells/logic/spell_logic_base.gd"

func execute(context: Dictionary) -> void:
	var main = context.get("main")
	
	if main and main.has_method("gain_energy"):
		main.gain_energy(2)
		main.show_notification("+2 ENERGY", Color(0.2, 0.8, 1.0))

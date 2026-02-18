extends "res://battle_scene/spells/logic/spell_logic_base.gd"

func execute(context: Dictionary) -> void:
	var main = context.get("main")
	
	main.current_energy = max(0, main.current_energy - 2)
	main._update_ui_labels()
	main.show_notification("ENERGY DRAINED!", Color(0.2, 0.4, 1.0))

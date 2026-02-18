extends "res://battle_scene/spells/logic/spell_logic_base.gd"

func execute(context: Dictionary) -> void:
	var main = context.get("main")
	
	main._draw_cards(1)
	main.show_notification("CARD DRAWN", Color(0.2, 0.8, 0.4))

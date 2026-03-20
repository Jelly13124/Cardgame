extends "res://battle_scene/spells/logic/spell_logic_base.gd"

func execute(context: Dictionary) -> void:
	var main = context.get("main")
	
	main.deck_manager.draw_cards(2)
	main.show_notification("2 CARDS DRAWN", Color(0.2, 0.8, 0.4))

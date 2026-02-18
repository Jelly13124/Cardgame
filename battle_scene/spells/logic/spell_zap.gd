extends "res://battle_scene/spells/logic/spell_logic_base.gd"

func execute(context: Dictionary) -> void:
	var main = context.get("main")
	var target = context.get("target")
	
	if target:
		main.show_notification("ZAP! 2 DAMAGE", Color(1, 1, 0))
		target.take_damage(2)

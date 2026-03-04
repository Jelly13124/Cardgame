extends "res://battle_scene/units/keywords/keyword_base.gd"

## Generic End of Turn Trigger
func on_turn_end(row: Node) -> void:
	if not is_instance_valid(unit) or not unit.get_parent(): return
	
	if unit.custom_script_instance and unit.custom_script_instance.has_method("execute_end_of_turn"):
		unit.custom_script_instance.execute_end_of_turn(row)

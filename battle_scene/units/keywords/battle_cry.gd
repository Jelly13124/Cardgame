extends "res://battle_scene/units/keywords/keyword_base.gd"

## Generic Battle Cry Trigger
## This keyword only detects when a unit is deployed and delegates the actual 
## effect logic to the unit's custom script, enforcing a clean architecture.
func on_deploy(row: Node, slot_index: int) -> void:
	if not is_instance_valid(unit) or not unit.get_parent(): return
	
	if unit.custom_script_instance and unit.custom_script_instance.has_method("execute_battle_cry"):
		unit.custom_script_instance.execute_battle_cry(row, slot_index)

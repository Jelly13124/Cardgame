extends "res://battle_scene/units/keywords/keyword_base.gd"

var active: bool = true

func on_damage_taken(amount: int) -> int:
	if active and amount > 0:
		active = false
		unit.show_notification("SHIELD BLOCKED!", Color.CYAN)
		# Update visual feedback if needed
		_update_visuals()
		return 0 # Negate damage
	return amount

func _update_visuals() -> void:
	if not active:
		# Could hide a shield overlay node here if we added one to the scene
		pass

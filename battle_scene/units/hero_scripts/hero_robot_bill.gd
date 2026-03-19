extends Node

var unit_card: Control

func setup(card: Control) -> void:
	unit_card = card
	var main = card.get_tree().current_scene
	if main and main.has_signal("unit_stats_changed"):
		main.connect("unit_stats_changed", _on_unit_stats_changed)

func _on_unit_stats_changed(target_unit: Control, atk: int, hp: int, _is_permanent: bool) -> void:
	if not is_instance_valid(unit_card): return
	if not is_instance_valid(target_unit): return
	
	# Make sure Robot Bill is actually deployed on the battlefield
	if not unit_card.card_container or not unit_card.card_container.is_in_group("battle_row"):
		return
		
	# Only execute passive if it's a friendly ROBOT and it's NOT Robot Bill himself
	var is_player = target_unit.card_info.get("side", "") == "player"
	var the_race = str(target_unit.card_info.get("race", "robot"))
	var is_robot = the_race.to_lower() == "robot"
	if not is_player or not is_robot or target_unit == unit_card:
		return
		
	# Apply +1/+2 permanently to Bill regardless of the actual buff size
	if atk > 0 or hp > 0:
		if unit_card.has_method("add_permanent_stats"):
			unit_card.add_permanent_stats(1, 2)

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
	
	# Only execute passive if it's a friendly unit AND it's NOT Robot Bill himself
	var is_player = target_unit.card_info.get("side", "") == "player"
	if not is_player or target_unit == unit_card:
		return
		
	# Apply +1/+1 permanently to Bill regardless of the actual buff size
	if atk > 0 or hp > 0:
		if unit_card.has_method("add_permanent_stats"):
			unit_card.add_permanent_stats(1, 1)
			unit_card.show_notification("BILL GROWS! (+1/+1)", Color.GOLD)

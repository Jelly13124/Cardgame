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
		
	# Apply Permanent Stats to Bill! If the buff was temporary, Bill's buff is currently coded to be permanent
	# or should it mirror the buff? The user explicitly said:
	# "for robot bill, we have an atriibute which is when friendly unit gain attibute like +1+1, hero bill gain +1+1 permantly"
	if unit_card.has_method("add_permanent_stats"):
		unit_card.add_permanent_stats(atk, hp)
		unit_card.show_notification("BILL GROWS! (+%d/+%d)" % [atk, hp], Color.GOLD)

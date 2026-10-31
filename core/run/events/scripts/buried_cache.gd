extends "res://core/run/events/event_model.gd"

## Buried Cache (text: EVENT_BURIED_CACHE_* in assets/translations/ui_events.csv).


func generate_initial_options() -> Array:
	return [
		option("PRY", _pry),
		luck_option("DIVE", _dive_ok, _dive_fail),
	]


func _pry() -> void:
	apply([{"type": "gain_equipment", "rarity": "uncommon"}])
	set_event_finished("PRY")


func _dive_ok() -> void:
	apply([{"type": "gain_equipment", "rarity": "rare"}, {"type": "gain_gold", "amount": 25}])
	set_event_finished("DIVE_OK")


func _dive_fail() -> void:
	apply([{"type": "lose_hp", "amount": 8}])
	set_event_finished("DIVE_FAIL")

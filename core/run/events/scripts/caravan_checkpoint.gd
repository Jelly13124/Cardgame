extends "res://core/run/events/event_model.gd"

## The Caravan Checkpoint (text: EVENT_CARAVAN_CHECKPOINT_* in assets/translations/ui_events.csv).


func generate_initial_options() -> Array:
	return [
		option("HELP", _help),
		option("TALK", _talk).requires({"charm": 5}),
		luck_option("BLUFF", _bluff_ok, _bluff_fail),
	]


func _help() -> void:
	apply([{"type": "gain_gold", "amount": 15}])
	set_event_finished("HELP")


func _talk() -> void:
	apply([{"type": "gain_gold", "amount": 30}, {"type": "gain_attribute", "attr": "charm", "amount": 1}])
	set_event_finished("TALK")


func _bluff_ok() -> void:
	apply([{"type": "gain_gold", "amount": 25}, {"type": "gain_scrap", "amount": 10}])
	set_event_finished("BLUFF_OK")


func _bluff_fail() -> void:
	apply([{"type": "lose_hp", "amount": 7}])
	set_event_finished("BLUFF_FAIL")

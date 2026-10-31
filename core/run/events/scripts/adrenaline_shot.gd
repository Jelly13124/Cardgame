extends "res://core/run/events/event_model.gd"

## Pre-War Auto-Injector (text: EVENT_ADRENALINE_SHOT_* in assets/translations/ui_events.csv).


func generate_initial_options() -> Array:
	return [
		option("INJECT", _inject),
		option("CRUSH", _crush),
	]


func _inject() -> void:
	apply([{"type": "gain_attribute", "attr": "strength", "amount": 1}, {"type": "add_curse", "curse": "base:panic"}])
	set_event_finished("INJECT")


func _crush() -> void:
	set_event_finished("CRUSH")

extends "res://core/run/events/event_model.gd"

## Rad Storm (text: EVENT_RAD_STORM_* in assets/translations/ui_events.csv).


func generate_initial_options() -> Array:
	return [
		option("HUNKER", _hunker),
		option("CONVOY", _convoy).requires({"charm": 5}),
		luck_option("SPRINT", _sprint_ok, _sprint_fail),
	]


func _hunker() -> void:
	apply([{"type": "lose_hp", "amount": 4}])
	set_event_finished("HUNKER")


func _convoy() -> void:
	apply([{"type": "heal", "amount": 6}, {"type": "gain_gold", "amount": 15}])
	set_event_finished("CONVOY")


func _sprint_ok() -> void:
	apply([{"type": "gain_scrap", "amount": 20}, {"type": "gain_attribute", "attr": "luck", "amount": 1}])
	set_event_finished("SPRINT_OK")


func _sprint_fail() -> void:
	apply([{"type": "lose_hp", "amount": 10}])
	set_event_finished("SPRINT_FAIL")

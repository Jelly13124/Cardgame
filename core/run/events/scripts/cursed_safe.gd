extends "res://core/run/events/event_model.gd"

## Humming Strongbox (text: EVENT_CURSED_SAFE_* in assets/translations/ui_events.csv).


func generate_initial_options() -> Array:
	return [
		option("CRACK", _crack),
		option("LEAVE", _leave),
	]


func _crack() -> void:
	apply([{"type": "gain_gold", "amount": 40}, {"type": "add_curse", "curse": "base:rust"}])
	set_event_finished("CRACK")


func _leave() -> void:
	set_event_finished("LEAVE")

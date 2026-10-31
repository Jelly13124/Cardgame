extends "res://core/run/events/event_model.gd"

## The Deserter's Charm (text: EVENT_DESERTER_CHARM_* in assets/translations/ui_events.csv).


func generate_initial_options() -> Array:
	return [
		option("WEAR", _wear),
		option("LEAVE", _leave),
	]


func _wear() -> void:
	apply([{"type": "heal", "amount": 999}, {"type": "add_curse", "curse": "base:cowardice"}])
	set_event_finished("WEAR")


func _leave() -> void:
	set_event_finished("LEAVE")

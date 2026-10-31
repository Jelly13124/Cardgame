extends "res://core/run/events/event_model.gd"

## Torn Coin Pouch (text: EVENT_TORN_COIN_POUCH_* in assets/translations/ui_events.csv).


func generate_initial_options() -> Array:
	return [
		option("POCKET", _pocket),
		option("DROP", _drop),
	]


func _pocket() -> void:
	apply([{"type": "gain_gold", "amount": 100}, {"type": "add_curse", "curse": "base:leaking_wealth"}])
	set_event_finished("POCKET")


func _drop() -> void:
	set_event_finished("DROP")

extends "res://core/run/events/event_model.gd"

## Stranded Trader (text: EVENT_STRANDED_TRADER_* in assets/translations/ui_events.csv).


func generate_initial_options() -> Array:
	return [
		option("DIG", _dig),
		_with_relic(option("TALK", _talk).requires({"charm": 5}), "base:lucky_cog"),
		luck_option("ROLL", _roll_ok, _roll_fail),
	]


func _dig() -> void:
	apply([{"type": "gain_gold", "amount": 40}])
	set_event_finished("DIG")


func _talk() -> void:
	apply([{"type": "gain_relic", "id": "base:lucky_cog"}])
	set_event_finished("TALK")


func _roll_ok() -> void:
	apply([{"type": "gain_scrap", "amount": 30}])
	set_event_finished("ROLL_OK")


func _roll_fail() -> void:
	apply([{"type": "lose_hp", "amount": 6}])
	set_event_finished("ROLL_FAIL")


func _with_relic(opt, relic: String):
	opt.relic_id = relic
	return opt

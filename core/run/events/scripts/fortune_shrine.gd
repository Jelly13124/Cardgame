extends "res://core/run/events/event_model.gd"

## The Fortune Shrine (text: EVENT_FORTUNE_SHRINE_* in assets/translations/ui_events.csv).


func generate_initial_options() -> Array:
	return [
		option("OFFER", _offer),
		_with_relic(luck_option("ROLL", _roll_ok, _roll_fail), "base:lucky_cog"),
	]


func _offer() -> void:
	apply([{"type": "gain_attribute", "attr": "luck", "amount": 1}])
	set_event_finished("OFFER")


func _roll_ok() -> void:
	apply([{"type": "gain_relic", "id": "base:lucky_cog"}, {"type": "gain_gold", "amount": 15}])
	set_event_finished("ROLL_OK")


func _roll_fail() -> void:
	apply([{"type": "lose_hp", "amount": 6}])
	set_event_finished("ROLL_FAIL")


func _with_relic(opt, relic: String):
	opt.relic_id = relic
	return opt

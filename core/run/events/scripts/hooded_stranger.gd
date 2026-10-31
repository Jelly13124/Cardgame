extends "res://core/run/events/event_model.gd"

## The Hooded Stranger (text: EVENT_HOODED_STRANGER_* in assets/translations/ui_events.csv).


func generate_initial_options() -> Array:
	return [
		option("SHARE", _share),
		option("READ", _read).requires({"charm": 5}),
		_with_relic(luck_option("CUT", _cut_ok, _cut_fail), "base:scavenger_lens"),
	]


func _share() -> void:
	apply([{"type": "heal", "amount": 8}, {"type": "gain_attribute", "attr": "charm", "amount": 1}])
	set_event_finished("SHARE")


func _read() -> void:
	apply([{"type": "gain_attribute", "attr": "luck", "amount": 2}])
	set_event_finished("READ")


func _cut_ok() -> void:
	apply([{"type": "gain_relic", "id": "base:scavenger_lens"}])
	set_event_finished("CUT_OK")


func _cut_fail() -> void:
	apply([{"type": "lose_hp", "amount": 5}, {"type": "gain_gold", "amount": 10}])
	set_event_finished("CUT_FAIL")


func _with_relic(opt, relic: String):
	opt.relic_id = relic
	return opt

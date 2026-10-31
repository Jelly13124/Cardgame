extends "res://core/run/events/event_model.gd"

## The Collapsed Overpass (text: EVENT_COLLAPSED_OVERPASS_* in assets/translations/ui_events.csv).


func generate_initial_options() -> Array:
	return [
		option("PICK", _pick),
		option("FLAG", _flag).requires({"charm": 5}),
		luck_option("CRAWL", _crawl_ok, _crawl_fail),
	]


func _pick() -> void:
	apply([{"type": "gain_gold", "amount": 25}])
	set_event_finished("PICK")


func _flag() -> void:
	apply([{"type": "gain_gold", "amount": 50}, {"type": "gain_scrap", "amount": 15}])
	set_event_finished("FLAG")


func _crawl_ok() -> void:
	apply([{"type": "gain_scrap", "amount": 35}, {"type": "gain_gold", "amount": 20}])
	set_event_finished("CRAWL_OK")


func _crawl_fail() -> void:
	apply([{"type": "lose_hp", "amount": 8}])
	set_event_finished("CRAWL_FAIL")

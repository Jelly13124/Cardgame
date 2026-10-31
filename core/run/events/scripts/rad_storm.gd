extends "res://core/run/events/event_model.gd"

## Rad Storm (text: EVENT_RAD_STORM_* in assets/translations/ui_events.csv).
## A successful sprint reaches a bunker where each dig pays scrap and costs
## `{rad}` HP, rising by 2; DEATH_WARNING shows when the next dig would kill.

const HUNKER_DAMAGE := 4
const RAD_START := 3
const RAD_STEP := 2


func calculate_vars() -> void:
	dynamic_vars = {"rad": RAD_START}


## The opening hunker must never be lethal.
func is_allowed(_run_state) -> bool:
	return int(owner.current_health) > HUNKER_DAMAGE


func page_art(p: String) -> String:
	return "rad_storm_bunker" if p == "BUNKER" or p == "DEATH_WARNING" else ""


func generate_initial_options() -> Array:
	return [
		option("HUNKER", _hunker),
		option("CONVOY", _convoy).requires({"charm": 5}),
		luck_option("SPRINT", _sprint_ok, _sprint_fail),
	]


## DIG and LEAVE, with DIG marked lethal when it would kill.
func dig_options() -> Array:
	var dig = option("DIG", _dig)
	dig.will_kill_player = will_kill(int(dynamic_vars["rad"]))
	return [dig, option("LEAVE", func(): set_event_finished("LEAVE"))]


func _hunker() -> void:
	apply([{"type": "lose_hp", "amount": HUNKER_DAMAGE}])
	set_event_finished("HUNKER")


func _convoy() -> void:
	apply([{"type": "heal", "amount": 6}, {"type": "gain_gold", "amount": 15}])
	set_event_finished("CONVOY")


func _sprint_ok() -> void:
	apply([{"type": "gain_scrap", "amount": 20}])
	set_event_state("BUNKER", dig_options())


func _sprint_fail() -> void:
	apply([{"type": "lose_hp", "amount": 10}])
	set_event_finished("SPRINT_FAIL")


func _dig() -> void:
	var rad := int(dynamic_vars["rad"])
	apply([{"type": "gain_scrap", "amount": 10}, {"type": "lose_hp", "amount": rad}])
	dynamic_vars["rad"] = rad + RAD_STEP
	var next := "DEATH_WARNING" if will_kill(int(dynamic_vars["rad"])) else "BUNKER"
	set_event_state(next, dig_options())

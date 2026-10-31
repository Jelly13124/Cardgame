extends "res://core/run/events/event_model.gd"

## Humming Strongbox (text: EVENT_CURSED_SAFE_* in assets/translations/ui_events.csv).
## Cracking the box opens a second page: take the coins, or gamble on the core.

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const MAX_CURSES := 2


## Not dealt to a deck that already carries two curses.
func is_allowed(_run_state) -> bool:
	var curses := 0
	for entry in owner.player_deck:
		var card_id := str(entry.get("card_id", "")) if entry is Dictionary else str(entry)
		if str(MODEL_DB.data("card", card_id).get("type", "")) == "curse":
			curses += 1
	return curses < MAX_CURSES


func page_art(p: String) -> String:
	return "cursed_safe_open" if p == "OPEN" else ""


func generate_initial_options() -> Array:
	return [
		option("CRACK", func(): set_event_state("OPEN", _open_options())),
		option("LEAVE", func(): set_event_finished("LEAVE")),
	]


func _open_options() -> Array:
	return [
		option("POCKET", _pocket),
		luck_option("PRY", _pry_ok, _pry_fail),
	]


func _pocket() -> void:
	apply([{"type": "gain_gold", "amount": 40}, {"type": "add_curse", "curse": "base:rust"}])
	set_event_finished("POCKET")


func _pry_ok() -> void:
	apply([
		{"type": "gain_gold", "amount": 40},
		{"type": "gain_scrap", "amount": 20},
		{"type": "add_curse", "curse": "base:rust"},
	])
	set_event_finished("PRY_OK")


func _pry_fail() -> void:
	apply([
		{"type": "gain_gold", "amount": 40},
		{"type": "add_curse", "curse": "base:rust"},
		{"type": "add_curse", "curse": "base:panic"},
	])
	set_event_finished("PRY_FAIL")

extends "res://core/run/events/event_model.gd"

## The Mutant Bazaar (text: EVENT_MUTANT_BAZAAR_* in assets/translations/ui_events.csv).


func generate_initial_options() -> Array:
	return [
		option("PAY", _pay),
		_with_relic(option("HAGGLE", _haggle).requires({"charm": 6}), "base:repair_kit"),
		option("BROWSE", _browse),
	]


func _pay() -> void:
	apply([{"type": "gain_equipment", "rarity": "common"}])
	set_event_finished("PAY")


func _haggle() -> void:
	apply([{"type": "gain_relic", "id": "base:repair_kit"}, {"type": "gain_gold", "amount": 8}])
	set_event_finished("HAGGLE")


func _browse() -> void:
	apply([{"type": "gain_attribute", "attr": "charm", "amount": 1}])
	set_event_finished("BROWSE")


func _with_relic(opt, relic: String):
	opt.relic_id = relic
	return opt

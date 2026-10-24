extends "res://core/listeners/data_relic.gd"

## Fixture relic for the listener model: every third Attack played in a battle
## grants 3 Block. Data + this script is all a new trigger needs.


func after_card_played(card_info: Dictionary) -> void:
	if str(card_info.get("type", "")) != "attack":
		return
	counters["attacks"] = int(counters.get("attacks", 0)) + 1
	if int(counters["attacks"]) % 3 == 0:
		await commands().gain_block(relic_source(), _player(), 3, 0)

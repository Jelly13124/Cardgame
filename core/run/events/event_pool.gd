extends RefCounted

## Deals events (STS2 ActModel.GenerateRooms event part + EventModel.IsAllowed).
## Each act shuffles its own deck at act start: the act's events plus the shared
## ones, minus events already seen this run. An event never repeats in a run;
## an empty deck deals nothing and the map falls back to the `?` table.
## No class_name — preload.

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd


## Scripted events that `act_number` may deal (absent `acts` = every act),
## minus `exclude`, shuffled with `rng`.
static func build_deck(act_number: int, exclude: Array, rng) -> Array[String]:
	var deck: Array[String] = []
	for id in MODEL_DB.ids("event"):
		if id in exclude or MODEL_DB.event_script(id) == null:
			continue
		var data := MODEL_DB.data("event", id)
		if data.has("acts") and not act_number in data["acts"]:
			continue
		deck.append(id)
	rng.shuffle(deck)
	return deck


## A fresh model for `id` with `id`, `owner` and `rng` set, or null when the
## event has no script.
static func instantiate(id: String):
	var script: Script = MODEL_DB.event_script(id)
	if script == null:
		return null
	var model = script.new()
	model.id = id
	model.owner = RunManager
	model.rng = RunManager.rng("events")
	return model


## The first event in the deck that fits the run. It leaves the deck and joins
## `seen_event_ids`; events skipped on the way stay. Null when none fits.
static func next(run_state):
	for i in run_state.event_deck.size():
		var model = instantiate(run_state.event_deck[i])
		if model == null or not model.is_allowed(run_state):
			continue
		run_state.event_deck.remove_at(i)
		run_state.seen_event_ids.append(model.id)
		return model
	return null

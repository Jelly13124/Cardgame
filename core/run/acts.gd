extends RefCounted

## Acts and the run configuration (STS2 ActModel + game mode), read from
## content: `content/runs/<id>.json` lists the run's acts; `content/acts/` holds
## each act's floors, boss, encounter bands, elites, enemy multipliers, map
## rules and extract rewards. Demo and full game differ only by the active run
## configuration.

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd

## The run configuration this build plays.
const ACTIVE_RUN := "base:demo"

## The run configuration in use (tests switch it).
static var active_run: String = ACTIVE_RUN


static func run_config() -> Dictionary:
	return MODEL_DB.data("run_config", active_run)


static func is_demo() -> bool:
	return bool(run_config().get("demo", false))  # bare-ok: run config flag


## Act ids of the run, in order.
static func run_act_ids() -> Array:
	return run_config().get("acts", [])


## Acts in this run.
static func count() -> int:
	return run_act_ids().size()


## Heroes this run configuration offers.
static func heroes() -> Array:
	return run_config().get("heroes", [])


## The definition of act `number` (1-based). Acts the run lists come first; an
## act number past the run (stale state, tests) reads the defined act with that
## number, else the last defined one.
static func act(number: int) -> Dictionary:
	var ids: Array = run_act_ids()
	if number >= 1 and number <= ids.size():
		return MODEL_DB.data("act", str(ids[number - 1]))
	var best: Dictionary = {}
	for model in MODEL_DB.models("act"):
		var n := int(model.data.get("number", 0))
		if n == number:
			return model.data
		if best.is_empty() or n > int(best.get("number", 0)):
			best = model.data
	return best


## The boss encounter of act `number`, capped at the run's last act.
static func boss_encounter(number: int) -> String:
	var n := clampi(number, 1, maxi(1, count()))
	return str(act(n).get("boss", ""))


static func floors(number: int) -> int:
	return int(act(number).get("floors", 12))


## {continue, extract} Scrap offered after the boss of a non-final act; {} on
## the final act. A non-final act without rewards falls back to a formula so a
## new act never silently ends the run.
static func extract_rewards(number: int) -> Dictionary:
	if number >= count():
		return {}
	var rewards = act(number).get("extract_rewards")
	if typeof(rewards) == TYPE_DICTIONARY:
		return rewards
	return {"continue": maxi(16, number * 16), "extract": maxi(33, number * 29)}


## True when `monster_id` appears in an encounter of `room` ("elite", "boss").
static func monster_in_room(monster_id: String, room: String) -> bool:
	for model in MODEL_DB.models("encounter"):
		if str(model.data.get("room", "")) == room and monster_id in model.data.get("monsters", []):
			return true
	return false

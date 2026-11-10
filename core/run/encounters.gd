extends RefCounted

## Encounter selection (STS2 EncounterModel pools): a map node's room type and
## floor pick an encounter from the current act's data with the run's named
## streams (`encounters`, `elites`). Returns the encounter's monster ids.

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd


## Monster ids for a `node_type` room on `floor_idx` of `act` (an act
## definition, core/run/acts.gd). `boss_encounter` is the run's boss for it.
static func select(act: Dictionary, boss_encounter: String, node_type: String, floor_idx: int, streams) -> Array[String]:
	var encounter_id := ""
	match node_type:
		"boss":
			encounter_id = boss_encounter
		"elite":
			encounter_id = str(streams.call("elites").pick(act.get("elites", [])))
		"enemy", "unknown":
			encounter_id = str(streams.call("encounters").pick(band_pool(act, floor_idx)))
	var result := monsters_of(encounter_id)
	if result.is_empty():
		result.append("base:trash_robot")
	return result


## The monster ids of `encounter_id` (empty when it is unknown).
static func monsters_of(encounter_id: String) -> Array[String]:
	var result: Array[String] = []
	for id in MODEL_DB.data("encounter", encounter_id).get("monsters", []):
		result.append(str(id))
	return result


## How hard a normal encounter is for its floor: the summed max HP of its
## monsters against the mean of its band — "weak" under 85%, "strong" over
## 115%, else "normal" (also when the encounter or its band is unknown).
static func strength(act: Dictionary, floor_idx: int, encounter_id: String) -> String:
	var own := _total_hp(encounter_id)
	var pool := band_pool(act, floor_idx)
	if own <= 0 or pool.is_empty():
		return "normal"
	var total := 0.0
	for enc in pool:
		total += _total_hp(str(enc))
	var mean := total / float(pool.size())
	if own < mean * 0.85:
		return "weak"
	if own > mean * 1.15:
		return "strong"
	return "normal"


static func _total_hp(encounter_id: String) -> int:
	var sum := 0
	for m in monsters_of(encounter_id):
		sum += int(MODEL_DB.data("monster", m).get("max_health", 0))
	return sum


## The normal encounter pool of the band `floor_idx` falls in.
static func band_pool(act: Dictionary, floor_idx: int) -> Array:
	var bands: Array = act.get("encounters", [])
	for band in bands:
		if not band.has("max_floor") or floor_idx <= int(band["max_floor"]):
			return band.get("pool", [])
	return bands[bands.size() - 1].get("pool", []) if not bands.is_empty() else []

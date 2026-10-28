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
	var result: Array[String] = []
	for id in MODEL_DB.data("encounter", encounter_id).get("monsters", []):
		result.append(str(id))
	if result.is_empty():
		result.append("base:trash_robot")
	return result


## The normal encounter pool of the band `floor_idx` falls in.
static func band_pool(act: Dictionary, floor_idx: int) -> Array:
	var bands: Array = act.get("encounters", [])
	for band in bands:
		if not band.has("max_floor") or floor_idx <= int(band["max_floor"]):
			return band.get("pool", [])
	return bands[bands.size() - 1].get("pool", []) if not bands.is_empty() else []

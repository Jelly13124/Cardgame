extends RefCounted

## Turns any equipment value an old save holds into the current instance shape
## ({base, rarity, affixes, cursed, set_id}), once, during migration: a bare
## item id becomes an instance with its legacy `bonuses` as affixes, and a
## set piece gets the set rarity with up to three positive affixes (kept ones
## first, then the pool's in order — deterministic, never rerolled). Returns {}
## for empty or unknown values.

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const AFFIX_POOL = preload("uid://dvbrdiqme425c")  # res://run_system/core/affix_pool.gd


static func instance(x: Variant) -> Dictionary:
	if typeof(x) == TYPE_DICTIONARY:
		return normalize_set(x) if x.has("base") else {}
	if typeof(x) != TYPE_STRING or str(x) == "":
		return {}
	var item_id := str(x)
	var data := MODEL_DB.data("equipment", item_id)
	var affixes: Array = []
	var bonuses: Variant = data.get("bonuses", {})
	if typeof(bonuses) == TYPE_DICTIONARY:
		for attr in bonuses.keys():
			affixes.append({"type": "attr_" + str(attr), "value": int(bonuses[attr])})
	return normalize_set({
		"base": item_id,
		"rarity": str(data.get("rarity", "common")),
		"affixes": affixes,
		"cursed": false,
		"set_id": str(data.get("set_id", "")),
	})


## A set piece carries the set rarity, no curse and three distinct positive
## affixes; anything else is returned as is.
static func normalize_set(inst: Dictionary) -> Dictionary:
	var base_id := str(inst.get("base", ""))
	if base_id == "":
		return inst
	var set_id := str(inst.get("set_id", MODEL_DB.data("equipment", base_id).get("set_id", "")))
	if set_id == "":
		return inst
	var source_affixes: Variant = inst.get("affixes", [])
	var affixes: Array = []
	var used_types := {}
	if typeof(source_affixes) == TYPE_ARRAY:
		for entry in source_affixes:
			if typeof(entry) != TYPE_DICTIONARY or AFFIX_POOL.is_curse(entry):
				continue
			var affix_type := str(entry.get("type", ""))
			if affix_type == "" or used_types.has(affix_type):
				continue
			affixes.append((entry as Dictionary).duplicate(true))
			used_types[affix_type] = true
			if affixes.size() == 3:
				break
	for template in AFFIX_POOL.POSITIVE:
		if affixes.size() == 3:
			break
		var affix_type := str(template.get("type", ""))
		if used_types.has(affix_type):
			continue
		affixes.append((template as Dictionary).duplicate(true))
		used_types[affix_type] = true
	var out := inst.duplicate(true)
	out["rarity"] = "set"
	out["set_id"] = set_id
	out["cursed"] = false
	out["affixes"] = affixes
	return out

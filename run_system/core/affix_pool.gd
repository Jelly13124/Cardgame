## Affix pool — stateless helper for rolling per-instance equipment affixes.
##
## Used via `const AFFIX_POOL = preload("res://run_system/core/affix_pool.gd")`
## and its static funcs (no class_name per ADR-0006). This module owns only the
## affix DATA + roll/reroll/summary logic. Storage, save migration, and the
## recompute consumer live elsewhere (Phase 2 E_B). No UI here.
##
## An affix is `{ "type": String, "value": int }`. Positives are deliberately
## small (a single common affix should sit below the old multi-bonus items).
extends RefCounted

## Roll-able positive affixes (the "weaker" tuning — small values).
const POSITIVE := [
	{"type": "attr_strength", "value": 1},
	{"type": "attr_constitution", "value": 1},
	{"type": "attr_intelligence", "value": 1},
	{"type": "attr_luck", "value": 1},
	{"type": "attr_charm", "value": 1},
	{"type": "max_hp", "value": 10},
]

## Curse affixes (consumed in Phase 5). Negative values.
## (crit_pct / curse_crit affixes were removed — crit is now Bill's keyword via the
## crit clip, not an equipment stat. Old saves may still carry them; harmless.)
const CURSE := [
	{"type": "curse_attr_strength", "value": -1},
	{"type": "curse_attr_constitution", "value": -1},
	{"type": "curse_max_hp", "value": -8},
]

## Positive affix count granted per rarity. Rare adds a set bonus separately
## (via set_id on the instance), NOT an extra affix here.
const AFFIX_COUNT := {"common": 1, "uncommon": 2, "rare": 2}


## Roll the affix list for a freshly generated item.
## Picks `AFFIX_COUNT.get(rarity, 1)` distinct-type positives. When `cursed`,
## ALSO adds 1 curse affix and grants one extra positive (cursed = 1 curse + up
## to AFFIX_COUNT+1 positives). Returned dicts are duplicated so callers may
## mutate them freely.
static func roll(rarity: String, cursed: bool = false) -> Array:
	var positives_wanted: int = int(AFFIX_COUNT.get(rarity, 1))
	if cursed:
		positives_wanted += 1
	var result: Array = []
	var used_types: Array = []
	for picked in _pick_distinct_positives(positives_wanted, used_types):
		result.append(picked)
	if cursed:
		var curse: Dictionary = CURSE[randi() % CURSE.size()].duplicate(true)
		result.append(curse)
	return result


## Return a deep copy of `affixes` with ONE random non-curse affix replaced by a
## fresh positive (distinct from the other affixes' types when possible). Curse
## affixes are never rerolled. If there are no non-curse affixes, the copy is
## returned unchanged.
static func reroll_one(affixes: Array) -> Array:
	var result: Array = []
	for affix in affixes:
		result.append((affix as Dictionary).duplicate(true))
	var non_curse_indices: Array = []
	for i in result.size():
		if not is_curse(result[i]):
			non_curse_indices.append(i)
	if non_curse_indices.is_empty():
		return result
	var target_index: int = non_curse_indices[randi() % non_curse_indices.size()]
	# Avoid reproducing a type already present on the OTHER affixes.
	var used_types: Array = []
	for i in result.size():
		if i != target_index:
			used_types.append(result[i].get("type", ""))
	var fresh: Array = _pick_distinct_positives(1, used_types)
	if fresh.is_empty():
		# Every positive type is already taken — fall back to any positive.
		fresh = [POSITIVE[randi() % POSITIVE.size()].duplicate(true)]
	result[target_index] = fresh[0]
	return result


## Sum every affix's contribution into a flat totals dict. This is what the
## recompute consumer (E_B) calls. attr_* / curse_attr_* map to the five
## attributes; max_hp / curse_max_hp → max_hp; crit_pct / curse_crit → crit_pct.
static func attribute_totals(affixes: Array) -> Dictionary:
	var totals := {
		"strength": 0,
		"constitution": 0,
		"intelligence": 0,
		"luck": 0,
		"charm": 0,
		"max_hp": 0,
		"crit_pct": 0,
	}
	for affix in affixes:
		var type: String = String((affix as Dictionary).get("type", ""))
		var value: int = int((affix as Dictionary).get("value", 0))
		match type:
			"attr_strength", "curse_attr_strength":
				totals["strength"] += value
			"attr_constitution", "curse_attr_constitution":
				totals["constitution"] += value
			"attr_intelligence", "curse_attr_intelligence":
				totals["intelligence"] += value
			"attr_luck", "curse_attr_luck":
				totals["luck"] += value
			"attr_charm", "curse_attr_charm":
				totals["charm"] += value
			"max_hp", "curse_max_hp":
				totals["max_hp"] += value
			"crit_pct", "curse_crit":
				totals["crit_pct"] += value
	return totals


## Short human-readable label for tooltips/UI, e.g. "+1 Strength", "+5% Crit",
## "+10 Max HP", "-1 Constitution (Curse)". Localizes via tr() when a
## UI_AFFIX_<TYPE> key is present; otherwise falls back to readable English.
static func describe(affix: Dictionary) -> String:
	var type: String = String(affix.get("type", ""))
	var value: int = int(affix.get("value", 0))
	var key := "UI_AFFIX_" + type.to_upper()
	# Static context: tr() is an instance method, so use TranslationServer directly.
	var localized := TranslationServer.translate(key)
	if localized != key:
		return localized.format({"value": value, "abs": abs(value)})
	var value_sign := "+" if value >= 0 else ""
	var label: String
	match type:
		"attr_strength", "curse_attr_strength":
			label = "%s%d Strength" % [value_sign, value]
		"attr_constitution", "curse_attr_constitution":
			label = "%s%d Constitution" % [value_sign, value]
		"attr_intelligence", "curse_attr_intelligence":
			label = "%s%d Intelligence" % [value_sign, value]
		"attr_luck", "curse_attr_luck":
			label = "%s%d Luck" % [value_sign, value]
		"attr_charm", "curse_attr_charm":
			label = "%s%d Charm" % [value_sign, value]
		"max_hp", "curse_max_hp":
			label = "%s%d Max HP" % [value_sign, value]
		"crit_pct", "curse_crit":
			label = "%s%d%% Crit" % [value_sign, value]
		_:
			label = "%s%d %s" % [value_sign, value, type]
	if is_curse(affix):
		label += " (Curse)"
	return label


## True when the affix is a curse (its type begins with "curse_").
static func is_curse(affix: Dictionary) -> bool:
	return String(affix.get("type", "")).begins_with("curse_")


## Pick `count` distinct-type positives, avoiding any type already in
## `used_types` (which is extended in-place as picks are made). Returns deep
## copies. Caps at the number of remaining distinct positive types.
static func _pick_distinct_positives(count: int, used_types: Array) -> Array:
	var picked: Array = []
	var available: Array = []
	for entry in POSITIVE:
		if not used_types.has(entry["type"]):
			available.append(entry)
	var to_pick: int = min(count, available.size())
	for _i in to_pick:
		var idx: int = randi() % available.size()
		var chosen: Dictionary = available[idx]
		picked.append(chosen.duplicate(true))
		used_types.append(chosen["type"])
		available.remove_at(idx)
	return picked

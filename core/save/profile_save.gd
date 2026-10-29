extends RefCounted

## The profile save's schema (STS2 ProfileSave / ProgressState): its version
## and the chain that brings an older profile to it. v1 bare content ids · v2
## namespaced ids · v3 current: equipment always instances, building tiers
## seeded from the legacy facility/upgrade state, removed upgrades refunded,
## retired fields gone.

const MIGRATION_CHAIN = preload("uid://bmeya57dgtty2")  # res://core/save/migration_chain.gd
const CONTENT_ID_MIGRATION = preload("uid://27jpcb0ubw68")  # res://core/save/content_id_migration.gd
const LEGACY_EQUIPMENT = preload("uid://bpsstam8gekpw")  # res://core/save/legacy_equipment.gd
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd

const CURRENT := 3
const EQUIPMENT_SLOTS := ["head", "chest", "weapon", "hands", "accessory"]
## Upgrades removed from the game, refunded in Caps by level (cost per level).
const REMOVED_UPGRADE_REFUND_COSTS := {
	"med_bay": [50, 110, 180],
	"starter_boost": [50, 110, 180],
	"scrap_workshop": [50, 110, 180],
}


static func chain() -> RefCounted:
	return MIGRATION_CHAIN.make("profile", 1, CURRENT).add(1, _v1_to_v2).add(2, _v2_to_v3)


static func version_of(data: Dictionary) -> int:
	return int(data.get("schema_version", data.get("content_v", 1)))


## The profile in the current shape (a copy; the input is never changed).
static func migrate(data: Dictionary) -> Dictionary:
	var out: Dictionary = chain().migrate(data, version_of(data))
	out.erase("content_v")
	out["schema_version"] = CURRENT
	return out


## The current-schema save of `profile` (core/meta/profile_state.gd).
static func to_dict(profile) -> Dictionary:
	return {
		"schema_version": CURRENT,
		"caps": profile.caps,
		"scrap": profile.scrap,
		"upgrades": profile.upgrades,
		"facilities": profile.facilities,
		"caps_perk_levels": profile.caps_perk_levels,
		"run_history": profile.run_history,
		"max_ascension": profile.max_ascension,
		"stash": profile.stash,
		"base_loadout": profile.base_loadout,
		"base_equipped": profile.base_equipped,
		"buildings": profile.buildings,
		"tutorial_seen": profile.tutorial_seen,
		"active_bounties": profile.active_bounties,
		"bounty_shelf": profile.bounty_shelf,
		"bounty_shelf_date": profile.bounty_shelf_date,
		"cards_seen": profile.cards_seen,
	}


## Fill `profile` from a current-schema save. JSON numbers come back as floats
## and dictionary keys as Strings, so typed values are re-coerced;
## `max_ascension` is clamped to `ascension_cap`.
static func apply(profile, d: Dictionary, ascension_cap: int) -> void:
	profile.caps = int(d.get("caps", 0))
	profile.scrap = int(d.get("scrap", 0))
	profile.upgrades = _dict(d.get("upgrades"))
	profile.facilities = _dict(d.get("facilities"))
	profile.caps_perk_levels = _dict(d.get("caps_perk_levels"))
	profile.run_history = d.get("run_history", []) if typeof(d.get("run_history")) == TYPE_ARRAY else []
	profile.max_ascension = clampi(int(d.get("max_ascension", 0)), 0, ascension_cap)
	profile.tutorial_seen = bool(d.get("tutorial_seen", false))
	profile.stash = _instances(d.get("stash", []))
	profile.base_loadout = _instances(d.get("base_loadout", []))
	var equipped := {}
	var raw_equipped = d.get("base_equipped", {})
	if typeof(raw_equipped) == TYPE_DICTIONARY:
		for slot in raw_equipped:
			if typeof(raw_equipped[slot]) == TYPE_DICTIONARY:
				equipped[str(slot)] = raw_equipped[slot]
	profile.base_equipped = equipped
	var buildings := {}
	for bid in _dict(d.get("buildings")):
		buildings[str(bid)] = int(d["buildings"][bid])
	profile.buildings = buildings
	var bounties: Array = []
	for entry in d.get("active_bounties", []):
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("id", "")) != "":
			bounties.append({"id": str(entry["id"]), "progress": int(entry.get("progress", 0))})
	profile.active_bounties = bounties
	profile.bounty_shelf = (d.get("bounty_shelf", []) as Array).map(func(id): return str(id)) if typeof(d.get("bounty_shelf")) == TYPE_ARRAY else []
	profile.bounty_shelf_date = str(d.get("bounty_shelf_date", ""))
	var seen := {}
	for card_id in _dict(d.get("cards_seen")):
		seen[str(card_id)] = true
	profile.cards_seen = seen


static func _dict(v: Variant) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}


static func _instances(v: Variant) -> Array:
	var out: Array = []
	if typeof(v) == TYPE_ARRAY:
		for item in v:
			if typeof(item) == TYPE_DICTIONARY:
				out.append(item)
	return out


static func _v1_to_v2(d: Dictionary) -> Dictionary:
	CONTENT_ID_MIGRATION.migrate_meta_ids(d)
	return d


static func _v2_to_v3(d: Dictionary) -> Dictionary:
	var stash: Array = []
	for item in d.get("stash", []):
		var inst := LEGACY_EQUIPMENT.instance(item)
		if not inst.is_empty():
			stash.append(inst)
	d["stash"] = stash
	var loadout: Array = []
	for item in d.get("base_loadout", []):
		var inst := LEGACY_EQUIPMENT.instance(item)
		if not inst.is_empty():
			loadout.append(inst)
	d["base_loadout"] = loadout
	var equipped := {}
	var raw_equipped = d.get("base_equipped", {})
	if typeof(raw_equipped) == TYPE_DICTIONARY:
		for raw_slot in raw_equipped:
			var slot := str(raw_slot)
			var inst := LEGACY_EQUIPMENT.instance(raw_equipped[raw_slot])
			if slot in EQUIPMENT_SLOTS and not inst.is_empty():
				if str(MODEL_DB.data("equipment", str(inst["base"])).get("slot", "")) == slot:
					equipped[slot] = inst
	d["base_equipped"] = equipped
	# Building tiers from the legacy facility / upgrade state (never lowered).
	var buildings := {}
	var raw_buildings = d.get("buildings", {})
	if typeof(raw_buildings) == TYPE_DICTIONARY:
		for bid in raw_buildings:
			buildings[str(bid)] = int(raw_buildings[bid])
	var facilities = d.get("facilities", {})
	if typeof(facilities) == TYPE_DICTIONARY and bool(facilities.get("cyber_doc", false)):
		buildings["clinic"] = maxi(int(buildings.get("clinic", 0)), 1)
	var upgrades = d.get("upgrades", {})
	if typeof(upgrades) != TYPE_DICTIONARY:
		upgrades = {}
	if int(upgrades.get("base:blacksmith", 0)) > 0:
		buildings["outpost"] = maxi(int(buildings.get("outpost", 0)), 2)
	d["buildings"] = buildings
	# Removed upgrades: refund their Caps and erase them.
	var refund := 0
	for upgrade_id in REMOVED_UPGRADE_REFUND_COSTS:
		if not upgrades.has(upgrade_id):
			continue
		var costs: Array = REMOVED_UPGRADE_REFUND_COSTS[upgrade_id]
		for i in range(clampi(int(upgrades[upgrade_id]), 0, costs.size())):
			refund += int(costs[i])
		upgrades.erase(upgrade_id)
	d["upgrades"] = upgrades
	d["caps"] = int(d.get("caps", 0)) + refund
	d.erase("starter_deck_override")
	d.erase("bounty_free_claimed")
	return d

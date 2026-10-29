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

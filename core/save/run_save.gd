extends RefCounted

## The run save's schema (STS2 SerializableRun): its version and the chain that
## brings an older run save to it. v1 bare content ids · v2 namespaced ids ·
## v3 seeded RNG streams · v4 current: equipment always instances, no hero data
## copy, retired cards and gem leftovers gone, elapsed time only.

const MIGRATION_CHAIN = preload("uid://bmeya57dgtty2")  # res://core/save/migration_chain.gd
const CONTENT_ID_MIGRATION = preload("uid://27jpcb0ubw68")  # res://core/save/content_id_migration.gd
const LEGACY_EQUIPMENT = preload("uid://bpsstam8gekpw")  # res://core/save/legacy_equipment.gd

const CURRENT := 4
## Cards removed from the game; old saves may still hold their bare ids.
const RETIRED_CARD_IDS := [
	"crowbar_smash",
	"pipe_swing",
	"breach_charge",
	"bulkhead_bleed",
	"combat_stim",  # bare-ok: retired card id from v1 saves (a tool shares the name)
	"focusing_blow",
	"hemo_drive",
	"last_breath",
	"siphon_valve",
]
const CARD_ID_MIGRATIONS := {
	"vent_plating": "base:kinetic_baffle",
}


static func chain() -> RefCounted:
	return (
		MIGRATION_CHAIN.make("run", 1, CURRENT)
		.add(1, _v1_to_v2)
		.add(2, func(d): return d)  # v3 only added the `rng` key; the loader defaults it
		.add(3, _v3_to_v4)
	)


static func version_of(data: Dictionary) -> int:
	return int(data.get("schema_version", data.get("v", 1)))


## The save in the current shape (a copy; the input is never changed).
static func migrate(data: Dictionary) -> Dictionary:
	var out: Dictionary = chain().migrate(data, version_of(data))
	out.erase("v")
	out["schema_version"] = CURRENT
	return out


static func _v1_to_v2(d: Dictionary) -> Dictionary:
	CONTENT_ID_MIGRATION.migrate_run_ids(d)
	return d


static func _v3_to_v4(d: Dictionary) -> Dictionary:
	var deck: Array = []
	for entry in d.get("player_deck", []):
		var card_id := str(entry.get("card_id", "")) if entry is Dictionary else str(entry)
		if card_id in RETIRED_CARD_IDS:
			continue
		if CARD_ID_MIGRATIONS.has(card_id):
			card_id = str(CARD_ID_MIGRATIONS[card_id])
		if entry is Dictionary:
			entry["card_id"] = card_id
			entry.erase("gems")
			deck.append(entry)
		else:
			deck.append(card_id)
	d["player_deck"] = deck
	var equipped := {}
	var raw_equipped = d.get("equipped_items", {})
	if typeof(raw_equipped) == TYPE_DICTIONARY:
		for slot in raw_equipped:
			equipped[str(slot)] = LEGACY_EQUIPMENT.instance(raw_equipped[slot])
	d["equipped_items"] = equipped
	var bag: Array = []
	for cell in d.get("backpack", []):  # bare-ok: save key
		bag.append(_cell(cell))
	d["backpack"] = bag  # bare-ok: save key
	if not d.has("demo_set_piece_ids_claimed") and d.has("demo_set_piece_ids_offered"):
		d["demo_set_piece_ids_claimed"] = d["demo_set_piece_ids_offered"]
	d.erase("demo_set_piece_ids_offered")
	# A process-local tick stamp cannot survive a restart: old saves resume
	# their timer from zero.
	if not d.has("run_elapsed_msec"):
		d["run_elapsed_msec"] = 0
	d.erase("run_started_msec")
	# Hero data is read from ModelDb by id.
	d.erase("current_hero_data")
	return d


## A backpack cell in the current shape: null, currency/tool cells as they are,
## an equipment cell {kind: equip, item: instance}; gem cells are gone.
static func _cell(cell: Variant) -> Variant:
	if typeof(cell) != TYPE_DICTIONARY:
		return null
	match str(cell.get("kind", "")):
		"gem":
			return null
		"equip":
			var inst := LEGACY_EQUIPMENT.instance(cell.get("item", cell.get("id", "")))
			return {"kind": "equip", "item": inst} if not inst.is_empty() else null
	return cell

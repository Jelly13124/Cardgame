extends RefCounted

## The run save's schema (STS2 SerializableRun): its version and the chain that
## brings an older run save to it. v1 bare content ids · v2 namespaced ids ·
## v3 seeded RNG streams · v4 current: equipment always instances, no hero data
## copy, retired cards and gem leftovers gone, elapsed time only.

const MIGRATION_CHAIN = preload("uid://bmeya57dgtty2")  # res://core/save/migration_chain.gd
const CONTENT_ID_MIGRATION = preload("uid://27jpcb0ubw68")  # res://core/save/content_id_migration.gd
const RUN_RNG_SET = preload("uid://ealvw2c6utr7")  # res://core/rng/run_rng_set.gd
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


## The current-schema save of `state` (core/run/run_state.gd).
## `elapsed_msec`: run time so far (the tick stamp itself is process-local).
static func to_dict(state, elapsed_msec: int) -> Dictionary:
	return {
		"schema_version": CURRENT,
		"rng": state.rng.to_dict() if state.rng != null else {},
		"is_run_active": state.is_run_active,
		"current_hero_id": state.hero_id,
		"ascension": state.ascension,
		"max_health": state.max_health,
		"current_health": state.current_health,
		"run_scrap": state.run_scrap,
		"run_caps": state.run_caps,
		"current_floor": state.current_floor,
		"current_act": state.current_act,
		"player_deck": state.deck,
		"equipped_items": state.equipped,
		"backpack": state.backpack,  # bare-ok: save key
		"relics": state.relics,
		"tool_inventory": state.tools,
		"xp": state.xp,
		"level": state.level,
		"pending_attr_points": state.pending_attr_points,
		"reward_rerolls": state.reward_rerolls,
		"run_elapsed_msec": elapsed_msec,
		"base_attributes": state.base_attributes,
		"player_attributes": state.player_attributes,
		"current_encounter": state.current_encounter,
		"last_battle_node_type": state.last_battle_node_type,
		"seen_random_event_ids": state.seen_event_ids,
		"demo_featured_set_id": state.demo_featured_set_id,
		"demo_set_piece_ids_claimed": state.demo_set_piece_ids_claimed,
		"map_data": state.map_data,
		"current_node_id": state.current_node_id,
		"visited_node_ids": state.visited_node_ids,
		"shop_stock": state.shop_stock,
	}


## Fill `state` from a current-schema save (JSON numbers come back as floats;
## typed fields are re-coerced). A save without valid RNG continues on a fresh
## seed.
static func apply(state, d: Dictionary) -> void:
	var saved_rng: Variant = d.get("rng", {})
	if typeof(saved_rng) == TYPE_DICTIONARY and RUN_RNG_SET.is_valid_seed(str(saved_rng.get("seed_string", ""))):
		state.rng = RUN_RNG_SET.from_dict(saved_rng)
	else:
		state.rng = RUN_RNG_SET.new(RUN_RNG_SET.random_seed_string())
	state.is_run_active = bool(d.get("is_run_active", false))
	state.hero_id = str(d.get("current_hero_id", ""))
	state.ascension = int(d.get("ascension", 0))
	state.max_health = int(d.get("max_health", 50))
	state.current_health = int(d.get("current_health", state.max_health))
	state.run_scrap = int(d.get("run_scrap", 0))
	state.run_caps = int(d.get("run_caps", 0))
	state.current_floor = int(d.get("current_floor", 0))
	state.current_act = int(d.get("current_act", 1))
	state.deck = d.get("player_deck", [])
	state.equipped = d.get("equipped_items", {})
	state.backpack = d.get("backpack", [])  # bare-ok: save key
	state.relics = strings(d.get("relics", []))
	state.tools = strings(d.get("tool_inventory", []))
	state.xp = int(d.get("xp", 0))
	state.level = int(d.get("level", 1))
	state.pending_attr_points = int(d.get("pending_attr_points", 0))
	state.reward_rerolls = int(d.get("reward_rerolls", 0))
	state.base_attributes = d.get("base_attributes", state.base_attributes)
	state.player_attributes = d.get("player_attributes", state.player_attributes)
	state.current_encounter = strings(d.get("current_encounter", []))
	state.last_battle_node_type = str(d.get("last_battle_node_type", "enemy"))
	state.seen_event_ids = strings(d.get("seen_random_event_ids", []))
	state.demo_featured_set_id = str(d.get("demo_featured_set_id", ""))
	state.demo_set_piece_ids_claimed = strings(d.get("demo_set_piece_ids_claimed", []))
	state.map_data = map_nodes(d.get("map_data", []))
	state.current_node_id = str(d.get("current_node_id", ""))
	state.visited_node_ids = strings(d.get("visited_node_ids", []))
	var stock = d.get("shop_stock", {})
	state.shop_stock = stock if typeof(stock) == TYPE_DICTIONARY else {}


static func strings(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(v) == TYPE_ARRAY:
		for e in v:
			out.append(str(e))
	return out


## Map nodes with their numeric fields re-coerced and children as Strings; extra
## generator fields kept as they are.
static func map_nodes(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for node in raw:
		if typeof(node) != TYPE_DICTIONARY:
			continue
		var n := {
			"id": str(node.get("id", "")),
			"floor": int(node.get("floor", 0)),
			"slot": int(node.get("slot", 0)),
			"type": str(node.get("type", "enemy")),
			"children": strings(node.get("children", [])),
		}
		for k in node.keys():
			if not n.has(k):
				n[k] = node[k]
		out.append(n)
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

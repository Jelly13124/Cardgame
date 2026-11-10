extends RefCounted

## An act's route: the map grows one floor at a time instead of being built
## whole. Each floor offers 2–3 choice cards (one on the fixed floors: the start
## relic, the guaranteed treasure, the campfire before the boss and the boss).
## A node's `children` are the cards of the floor after it, so they are its
## binding preview. Entering a node rolls its children's children and prunes
## the branches that were not taken. Room types come from the act's tables
## (core/run/acts.gd); rewards are rolled with the node and printed on its card.
##
## A map node: {id, floor, slot, type, children: Array[String], encounter,
## strength, rewards}.
## Ids are the parent's id plus the card's index ("f0", "f0.1", "f0.1.2").
## A node's children come from the stream "map_act_<act>_<parent id>" and its
## rewards from "map_act_<act>_<id>_rewards", so the same seed and the same
## route always give the same cards, whatever order they are generated in.

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const ENCOUNTERS = preload("uid://mlx3xqfjwlpq")  # res://core/run/encounters.gd

## Room types a floor never offers twice.
const UNIQUE_PER_FLOOR := ["merchant", "rest", "unknown", "treasure"]
## Re-rolls allowed for one card before a repeated type is dropped.
const MAX_REROLLS := 8


## The start node, its children and their children. `elite_bias_floor` > 0
## compresses rolls into [floor, 1) (ascension Dangerous Paths).
static func start(act: Dictionary, act_number: int, run_rng, elite_bias_floor := 0.0) -> Array:
	var root := {
		"id": "f0", "floor": 0, "slot": 0, "type": "relic", "children": [] as Array[String], "rewards": {},
	}
	var map_data: Array = [root]
	for child in roll_children(root, map_data, act, act_number, run_rng, elite_bias_floor):
		roll_children(child, map_data, act, act_number, run_rng, elite_bias_floor)
	return map_data


## The map after entering `entered_id`: each of its children gets its own
## children (rolled again when missing or pointing at pruned nodes), then only
## the walked path, the entered node's children and their children remain.
static func grow(map_data: Array, entered_id: String, act: Dictionary, act_number: int, run_rng, elite_bias_floor := 0.0) -> Array:
	var entered: Dictionary = _find(map_data, entered_id)
	if entered.is_empty():
		return map_data
	if _needs_children(map_data, entered, act):
		roll_children(entered, map_data, act, act_number, run_rng, elite_bias_floor)
	for child_id in entered.children:
		var child: Dictionary = _find(map_data, child_id)
		if _needs_children(map_data, child, act):
			roll_children(child, map_data, act, act_number, run_rng, elite_bias_floor)
	var keep := {entered_id: true}
	for child_id in entered.children:
		keep[child_id] = true
		for grandchild_id in _find(map_data, child_id).get("children", []):
			keep[grandchild_id] = true
	return map_data.filter(
		func(n): return keep.has(str(n.id)) or entered_id.begins_with(str(n.id) + ".")
	)


## Rolls `parent`'s children (the next floor's cards), replaces any earlier
## nodes with the same ids, appends them to `map_data`, sets `parent.children`
## and returns them. A parent on the top floor gets none.
static func roll_children(parent: Dictionary, map_data: Array, act: Dictionary, act_number: int, run_rng, elite_bias_floor: float) -> Array:
	var rules: Dictionary = act.get("map", {})
	var num_floors := int(act.get("floors", 12))
	var f := int(parent.floor) + 1
	var ids: Array[String] = []
	var nodes: Array = []
	if f >= num_floors:
		parent.children = ids
		return nodes
	var rng = run_rng.derived("map_act_%d_%s" % [act_number, str(parent.id)])
	var extras := _extra_treasures_on_path(map_data, str(parent.id), rules)
	var types: Array[String] = []
	if _is_fixed_floor(f, num_floors, rules):
		types.append(_pick_node_type(rules, f, num_floors, extras, rng, elite_bias_floor))
	else:
		var count: int = rng.next_range(2, 3)
		for i in range(count):
			var t := _pick_node_type(rules, f, num_floors, extras, rng, elite_bias_floor)
			var tries := 0
			while t in UNIQUE_PER_FLOOR and t in types and tries < MAX_REROLLS:
				t = _pick_node_type(rules, f, num_floors, extras, rng, elite_bias_floor)
				tries += 1
			if t in UNIQUE_PER_FLOOR and t in types:
				continue
			types.append(t)
			if t == "treasure":
				extras += 1
		while types.size() < 2:
			types.append("enemy")
	for i in range(types.size()):
		var id := "%s.%d" % [str(parent.id), i]
		ids.append(id)
		var node := {"id": id, "floor": f, "slot": i, "type": types[i], "children": [] as Array[String]}
		fill_fight(node, act, act_number, run_rng)
		nodes.append(node)
	for i in range(map_data.size() - 1, -1, -1):
		if str(map_data[i].id) in ids:
			map_data.remove_at(i)
	map_data.append_array(nodes)
	parent.children = ids
	return nodes


## Rolls `node`'s encounter, strength and rewards from its rewards stream
## ("map_act_<act>_<id>_rewards"): an enemy fights an encounter of its floor's
## band and pays by its strength, an elite fights one of the act's elites
## (none when the act lists none), other rooms fight nothing.
static func fill_fight(node: Dictionary, act: Dictionary, act_number: int, run_rng) -> void:
	var rng = run_rng.derived("map_act_%d_%s_rewards" % [act_number, str(node.id)])
	var type := str(node.type)
	node["encounter"] = ""
	node["strength"] = ""
	match type:
		"enemy":
			var pool := ENCOUNTERS.band_pool(act, int(node.floor))
			if not pool.is_empty():
				node["encounter"] = str(rng.pick(pool))
			node["strength"] = ENCOUNTERS.strength(act, int(node.floor), str(node.encounter))
		"elite":
			var elites: Array = act.get("elites", [])
			if not elites.is_empty():
				node["encounter"] = str(rng.pick(elites))
	node["rewards"] = node_rewards(type, rng, str(node.strength) if node.strength != "" else "normal")


## What a room of `type` pays, rolled from `rng`: Caps (backpack gold) for
## fights by `strength`, Caps and Scrap for elites, nothing printed for the
## other rooms. Values: content/economy/loot_economy.json.
static func node_rewards(type: String, rng, strength := "normal") -> Dictionary:
	var eco: Dictionary = MODEL_DB.data("economy", "base:loot_economy")
	match type:
		"enemy":
			var by_strength: Dictionary = eco.get("combat_gold_by_strength", {})
			return {"gold": int(by_strength.get(strength, by_strength.get("normal", 8)))}
		"elite":
			var scrap: Array = eco.get("elite_scrap", [8, 16])
			return {"gold": int(eco.get("elite_gold", 18)), "scrap": rng.next_range(int(scrap[0]), int(scrap[1]))}
	return {}


static func _is_fixed_floor(f: int, num_floors: int, rules: Dictionary) -> bool:
	return f == 0 or f >= num_floors - 2 or f == int(rules.get("guaranteed_treasure_floor", 6))


## True when `node` should get (new) children: it is below the top floor and
## has none, or names a child that is no longer on the map.
static func _needs_children(map_data: Array, node: Dictionary, act: Dictionary) -> bool:
	if node.is_empty() or int(node.floor) + 1 >= int(act.get("floors", 12)):
		return false
	if node.children.is_empty():
		return true
	for child_id in node.children:
		if _find(map_data, child_id).is_empty():
			return true
	return false


static func _find(map_data: Array, id: String) -> Dictionary:
	for n in map_data:
		if str(n.id) == id:
			return n
	return {}


static func _pick_node_type(
	rules: Dictionary, floor_idx: int, total: int, treasure_extras_used: int, rng, elite_bias_floor: float
) -> String:
	if floor_idx == 0:
		return "relic"
	if floor_idx == total - 1:
		return "boss"
	if floor_idx == total - 2:
		return "rest"  # campfire before the boss
	if floor_idx == int(rules.get("guaranteed_treasure_floor", 6)):
		return "treasure"
	var roll: float = rng.next_float()
	if elite_bias_floor > 0.0:
		roll = roll * (1.0 - elite_bias_floor) + elite_bias_floor
	var table: Array = (
		rules.get("early_rolls", []) if floor_idx <= int(rules.get("early_floor_last", 4)) else rules.get("rolls", [])
	)
	for entry in table:
		if entry.has("below") and roll >= float(entry["below"]):
			continue
		if bool(entry.get("capped", false)) and treasure_extras_used >= int(rules.get("max_extra_treasures", 2)):
			continue
		return str(entry.get("type", "enemy"))
	return "enemy"


## Treasures off the guaranteed floor on the walked path up to `parent_id`
## (the parent and its ancestors).
static func _extra_treasures_on_path(map_data: Array, parent_id: String, rules: Dictionary) -> int:
	var guaranteed := int(rules.get("guaranteed_treasure_floor", 6))
	var count := 0
	for n in map_data:
		var id := str(n.id)
		if (id == parent_id or parent_id.begins_with(id + ".")) and n.type == "treasure" and int(n.floor) != guaranteed:
			count += 1
	return count

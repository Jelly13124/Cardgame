extends RefCounted

## An act's map (STS2 StandardActMap): `floors` floors of 1–`width` nodes, the
## first and the top floor single nodes (start relic, boss), the floor below
## the boss a rest, a guaranteed treasure floor, and node types rolled from the
## act's tables. Each node connects to at most `max_children_per_node` nodes on
## the next floor. Parameters come from the act definition (core/run/acts.gd);
## rolls use the act's own map stream.

## A map node: {id, floor, slot, type, children: Array[String]}.


## `elite_bias_floor` > 0 compresses rolls into [floor, 1) (ascension Dangerous
## Paths).
static func generate(act: Dictionary, rng, elite_bias_floor := 0.0) -> Array:
	var rules: Dictionary = act.get("map", {})
	var num_floors := int(act.get("floors", 12))
	var width := int(act.get("width", 4))
	var max_children := int(rules.get("max_children_per_node", 3))
	var map_data: Array = []
	for f in range(num_floors):
		var num_nodes: int
		if f == 0 or f == num_floors - 1:
			num_nodes = 1  # start (relic) and the boss are single nodes
		else:
			num_nodes = mini(rng.next_range(2, 4), width)
			# A floor right above a single node must fit within that node's
			# fan-out cap, or the orphan fallback would break the cap.
			if f == 1 or f - 1 == num_floors - 1:
				num_nodes = mini(num_nodes, max_children)
		var slots: Array[int] = []
		if num_nodes == 1:
			@warning_ignore("integer_division")
			slots.append(width / 2)
		else:
			var available: Array[int] = []
			for s in range(width):
				available.append(s)
			rng.shuffle(available)
			for i in range(num_nodes):
				slots.append(available[i])
			slots.sort()
		for slot in slots:
			map_data.append({
				"id": "f%d_s%d" % [f, slot],
				"floor": f,
				"slot": slot,
				"type": _pick_node_type(rules, f, num_floors, _count_extra_treasures(map_data, rules), rng, elite_bias_floor),
				"children": [] as Array[String],
			})
	for f in range(num_floors - 1):
		var current_nodes := _nodes_on_floor(map_data, f)
		var next_nodes := _nodes_on_floor(map_data, f + 1)
		if current_nodes.size() == 1:
			for nn in _closest_n_by_slot(next_nodes, current_nodes[0].slot, max_children):
				current_nodes[0].children.append(nn.id)
			continue
		if next_nodes.size() == 1:
			for cn in current_nodes:
				cn.children.append(next_nodes[0].id)
			continue
		for node in current_nodes:
			var fresh_children: Array[String] = []
			for nn in _closest_n_by_slot_within(next_nodes, node.slot, max_children, 2):
				fresh_children.append(nn.id)
			if fresh_children.is_empty():
				var closest = _closest_n_by_slot(next_nodes, node.slot, 1)
				if closest.size() > 0:
					fresh_children.append(closest[0].id)
			node.children = fresh_children
		# Every next-floor node gets a parent, preferring one under the cap.
		for next_node in next_nodes:
			var has_parent := false
			for node in current_nodes:
				if next_node.id in node.children:
					has_parent = true
					break
			if not has_parent:
				_attach_orphan(next_node, current_nodes, max_children)
	return map_data


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


## Treasure nodes generated so far outside the guaranteed treasure floor.
static func _count_extra_treasures(map_data: Array, rules: Dictionary) -> int:
	var guaranteed := int(rules.get("guaranteed_treasure_floor", 6))
	var count := 0
	for node in map_data:
		if node.type == "treasure" and node.floor != guaranteed:
			count += 1
	return count


static func _nodes_on_floor(map_data: Array, f: int) -> Array:
	return map_data.filter(func(n): return n.floor == f)


static func _closest_n_by_slot(candidates: Array, origin_slot: int, count: int) -> Array:
	return _closest_n_by_slot_within(candidates, origin_slot, count, 1 << 30)


static func _closest_n_by_slot_within(candidates: Array, origin_slot: int, count: int, max_dist: int) -> Array:
	var with_dist: Array = []
	for c in candidates:
		var d: int = abs(int(c.slot) - origin_slot)
		if d <= max_dist:
			with_dist.append({"node": c, "dist": d})
	with_dist.sort_custom(func(a, b): return a.dist < b.dist)
	var out: Array = []
	for i in range(mini(count, with_dist.size())):
		out.append(with_dist[i].node)
	return out


## The closest parent still under the cap takes the orphan; if all are full the
## closest one exceeds the cap (rare) so no node is unreachable.
static func _attach_orphan(orphan: Dictionary, current_nodes: Array, max_children: int) -> void:
	var sorted: Array = current_nodes.duplicate()
	sorted.sort_custom(
		func(a, b): return abs(int(a.slot) - int(orphan.slot)) < abs(int(b.slot) - int(orphan.slot))
	)
	for parent in sorted:
		if parent.children.size() < max_children:
			parent.children.append(orphan.id)
			return
	if sorted.size() > 0:
		sorted[0].children.append(orphan.id)

extends RefCounted

## An act's map (STS2 StandardActMap): `floors` floors of 1–`width` nodes, the
## first and the top floor single nodes (start relic, boss), the floor below
## the boss a rest, a guaranteed treasure floor and an all-fight first floor.
## Each node connects to at most `max_children_per_node` nodes on the next floor.
##
## Like STS2, room types are dealt, not rolled: the act fixes how many merchants,
## elites, rests and "?" nodes the map holds (`map.point_counts`), they are
## dealt onto random free nodes under STS2's placement rules, and any type still
## short afterwards replaces fights until its count is met. Every other node is
## a fight. Parameters come from the act definition (core/run/acts.gd); rolls use
## the act's own map stream.

## A map node: {id, floor, slot, type, children: Array[String]}.

## STS2 MapPointTypeCounts: queue order and default counts per act map.
const DEALT_TYPES := ["rest", "merchant", "elite", "unknown"]
const DEFAULT_COUNTS := {"rest": 3, "merchant": 2, "elite": 3, "unknown": 5}
## STS2 _lowerMapPointRestrictions: not below `lower_floor_min`.
const LOWER_RESTRICTED := ["rest", "elite"]
## STS2 _upperMapPointRestrictions: not on the last three floors.
const UPPER_RESTRICTED := ["rest"]
## STS2 _parent/_childMapPointRestrictions: never twice in a row on a path.
const NO_REPEAT_ON_PATH := ["elite", "rest", "treasure", "merchant"]
## STS2 _siblingPointTypeRestrictions: branches of one node differ.
const NO_REPEAT_ON_SIBLINGS := ["rest", "enemy", "unknown", "elite", "merchant"]
const UNASSIGNED := ""


## `elite_mult` scales the elite count (ascension Dangerous Paths, like STS2
## Swarming Elites).
static func generate(act: Dictionary, rng, elite_mult := 1.0) -> Array:
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
				"type": UNASSIGNED,
				"children": [] as Array[String],
			})
	for f in range(num_floors - 1):
		_link_floor(_nodes_on_floor(map_data, f), _nodes_on_floor(map_data, f + 1), max_children, rng)
	_assign_types(map_data, rules, num_floors, rng, elite_mult)
	return map_data


## The act's dealt-room counts; `elite_mult` scales elites (rounded).
static func point_counts(rules: Dictionary, elite_mult := 1.0) -> Dictionary:
	var counts: Dictionary = DEFAULT_COUNTS.duplicate()
	var custom: Dictionary = rules.get("point_counts", {})
	for type in custom:
		counts[str(type)] = int(custom[type])
	counts["elite"] = int(round(float(counts["elite"]) * elite_mult))
	return counts


## STS2 StandardActMap.AssignPointTypes + MapPathPruning.RepairPrunedPointTypes.
static func _assign_types(map_data: Array, rules: Dictionary, num_floors: int, rng, elite_mult: float) -> void:
	var by_id := {}
	var parents := {}
	for node in map_data:
		by_id[node.id] = node
		parents[node.id] = []
	for node in map_data:
		for c in node.children:
			parents[c].append(node)
	var ctx := {
		"by_id": by_id,
		"parents": parents,
		"floors": num_floors,
		"lower_min": int(rules.get("lower_floor_min", 4)),
	}
	# Fixed floors cannot be changed later (STS2 CanBeModified = false).
	var fixed := {}
	var treasure_floor := int(rules.get("guaranteed_treasure_floor", 6))
	for node in map_data:
		var f := int(node.floor)
		var t := UNASSIGNED
		if f == 0:
			t = "relic"
		elif f == num_floors - 1:
			t = "boss"
		elif f == num_floors - 2:
			t = "rest"  # campfire before the boss
		elif f == treasure_floor:
			t = "treasure"
		elif f == 1:
			t = "enemy"  # the first room is always a fight
		if t != UNASSIGNED:
			node.type = t
			fixed[node.id] = true

	var counts := point_counts(rules, elite_mult)
	var queue: Array[String] = []
	for type in DEALT_TYPES:
		for i in range(int(counts.get(type, 0))):
			queue.append(type)
	# Three passes over the free nodes in random order; each takes the first
	# queued type its placement rules allow (STS2 GetNextValidPointType).
	for _pass in range(3):
		if queue.is_empty():
			break
		var free: Array = map_data.filter(func(n): return n.type == UNASSIGNED)
		rng.shuffle(free)
		for node in free:
			if queue.is_empty():
				break
			for i in range(queue.size()):
				var type: String = queue.pop_front()
				if _is_valid(type, node, ctx):
					node.type = type
					break
				queue.push_back(type)
	for node in map_data:
		if node.type == UNASSIGNED:
			node.type = "enemy"

	# Repair: a type still short replaces fights that allow it. A last pass for
	# merchants drops the sibling rule so the act's merchants always appear.
	for strict in [true, false]:
		for type in DEALT_TYPES:
			if not strict and type != "merchant":
				continue
			var short: int = int(counts.get(type, 0)) - map_data.filter(func(n): return n.type == type).size()
			if short <= 0:
				continue
			var fights: Array = map_data.filter(func(n): return n.type == "enemy" and not fixed.has(n.id))
			rng.shuffle(fights)
			for node in fights:
				if short <= 0:
					break
				if _is_valid(type, node, ctx, strict):
					node.type = type
					short -= 1


## STS2 StandardActMap.IsValidPointType.
static func _is_valid(type: String, node: Dictionary, ctx: Dictionary, check_siblings := true) -> bool:
	if not _is_valid_floor(type, node, ctx):
		return false
	var parents: Array = ctx.parents[node.id]
	if type in NO_REPEAT_ON_PATH:
		for p in parents:
			if p.type == type:
				return false
		for c in node.children:
			if ctx.by_id[c].type == type:
				return false
	if check_siblings and type in NO_REPEAT_ON_SIBLINGS:
		for p in parents:
			for c in p.children:
				if c != node.id and ctx.by_id[c].type == type:
					return false
	return true


## The floor-band rules alone: rests and elites not low, rests not near the top.
static func _is_valid_floor(type: String, node: Dictionary, ctx: Dictionary) -> bool:
	var f := int(node.floor)
	if f < int(ctx.lower_min) and type in LOWER_RESTRICTED:
		return false
	if f >= int(ctx.floors) - 3 and type in UPPER_RESTRICTED:
		return false
	return true


static func _nodes_on_floor(map_data: Array, f: int) -> Array:
	return map_data.filter(func(n): return n.floor == f)


## Links two neighbouring floors without crossing paths (STS2 maps never
## cross). Both floors are walked bottom-up in slot order like a merge: the
## next pair joined is whichever step keeps slots closest, so every node gets
## at least one link and links stay short. Where the walk steps diagonally, a
## second branch may be added on one side only, which still cannot cross.
## Fan-out stays within `max_children` (a single node above feeds its whole
## next floor, which is capped to fit when the map is built).
static func _link_floor(current: Array, next: Array, max_children: int, rng) -> void:
	current.sort_custom(func(a, b): return int(a.slot) < int(b.slot))
	next.sort_custom(func(a, b): return int(a.slot) < int(b.slot))
	var i := 0
	var j := 0
	var forks: Array = []
	_link(current[0], next[0])
	while i < current.size() - 1 or j < next.size() - 1:
		var step_i := j == next.size() - 1
		var step_j := i == current.size() - 1
		if not step_i and not step_j:
			var si := int(current[i + 1].slot)
			var sj := int(next[j + 1].slot)
			step_i = si <= sj
			step_j = sj <= si
		if step_i and step_j:
			# Diagonal: maybe fork one side; forks are added after the walk so
			# they never push a node past the fan-out cap.
			if rng.next_bool():
				forks.append([current[i], next[j + 1]] if rng.next_bool() else [current[i + 1], next[j]])
			i += 1
			j += 1
		elif step_i:
			i += 1
		else:
			j += 1
		_link(current[i], next[j])
	for fork in forks:
		var parent: Dictionary = fork[0]
		var child: Dictionary = fork[1]
		if parent.children.size() < max_children and abs(int(parent.slot) - int(child.slot)) <= 2:
			_link(parent, child)


static func _link(parent: Dictionary, child: Dictionary) -> void:
	if not (child.id in parent.children):
		parent.children.append(child.id)


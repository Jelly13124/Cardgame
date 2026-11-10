extends Node

## The route map (core/run/map_generator.gd) grows one floor at a time: each
## floor offers 2–3 choice cards except the fixed floors, a node's children are
## its binding preview, unchosen branches are pruned, rewards are rolled with
## the node, and everything follows from the seed and the route.

const MAP_GENERATOR = preload("uid://gi3vuuinl2vb")  # res://core/run/map_generator.gd
const RUN_RNG_SET = preload("uid://ealvw2c6utr7")  # res://core/rng/run_rng_set.gd
const ACTS = preload("uid://c7qo73muxvmd4")  # res://core/run/acts.gd
const ENCOUNTERS = preload("uid://mlx3xqfjwlpq")  # res://core/run/encounters.gd

const SEED := "ROUTEMAP01"
const UNIQUE_TYPES := ["merchant", "rest", "unknown", "treasure"]

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	ACTS.active_run = "base:demo"
	var act: Dictionary = ACTS.act(1)
	_check_start(act)
	_check_walks(act)
	_check_determinism(act)
	_check_elite_bias(act)
	_check_encounters(act)
	_check_act_two_differs()
	if failures.is_empty():
		print("[OK] route map generator passed")
		get_tree().quit(0)
		return
	push_error("route map generator failed: %s" % "; ".join(failures))
	get_tree().quit(1)


static func _by_id(map_data: Array) -> Dictionary:
	var out := {}
	for n in map_data:
		out[str(n.id)] = n
	return out


func _check_start(act: Dictionary) -> void:
	var map: Array = MAP_GENERATOR.start(act, 1, RUN_RNG_SET.new(SEED))
	var by_id := _by_id(map)
	var floor0 := map.filter(func(n): return int(n.floor) == 0)
	_expect(floor0.size() == 1 and floor0[0].id == "f0" and floor0[0].type == "relic", "floor 0 is the single relic node f0")
	var floor1 := map.filter(func(n): return int(n.floor) == 1)
	_expect(floor1.size() == by_id["f0"].children.size(), "floor 1 is exactly f0's children")
	for n in floor1:
		_expect(n.children.size() >= 1 and n.children.size() <= 3, "a floor-1 node previews 1–3 floor-2 nodes")
		for c in n.children:
			_expect(by_id.has(c) and int(by_id[c].floor) == 2, "a floor-1 preview names a floor-2 node")


## Walks a route from the start to the boss, choosing with `pick_rng`.
## Returns {sets: Array of choice-id arrays per floor, map: final map, trace}.
func _walk(act: Dictionary, act_number: int, rng_set, pick_rng, elite_bias := 0.0) -> Dictionary:
	var map: Array = MAP_GENERATOR.start(act, act_number, rng_set, elite_bias)
	var sets: Array = []
	var trace: Array = []
	var current := "f0"
	sets.append(["f0"])
	map = MAP_GENERATOR.grow(map, current, act, act_number, rng_set, elite_bias)
	trace.append(_snapshot(map))
	var floors := int(act.get("floors", 12))
	for f in range(1, floors):
		var by_id := _by_id(map)
		var choices: Array = by_id[current].children.duplicate()
		sets.append(choices)
		if choices.is_empty():
			_expect(false, "floor %d offers no choice" % f)
			break
		var chosen: String = choices[pick_rng.next_int(choices.size())]
		var preview: Array = []
		for c in by_id[chosen].children:
			preview.append([c, by_id[c].type])
		map = MAP_GENERATOR.grow(map, chosen, act, act_number, rng_set, elite_bias)
		var after := _by_id(map)
		var seen: Array = []
		for c in after[chosen].children:
			seen.append([c, after[c].type])
		_expect(seen == preview, "the preview of %s is what the next floor offers" % chosen)
		_check_pruned(map, chosen)
		current = chosen
		trace.append(_snapshot(map))
	return {"sets": sets, "map": map, "trace": trace}


func _snapshot(map: Array) -> Array:
	return map.map(func(n): return [n.id, n.type, Array(n.children), n.rewards])


func _check_pruned(map: Array, entered: String) -> void:
	var by_id := _by_id(map)
	_expect(by_id.size() == map.size(), "node ids are unique")
	var keep := {}
	for c in by_id[entered].children:
		keep[c] = true
		for g in by_id[c].children:
			keep[g] = true
	for n in map:
		var id := str(n.id)
		var on_path := id == entered or entered.begins_with(id + ".")
		_expect(on_path or keep.has(id), "node %s was pruned after entering %s" % [id, entered])


func _check_walks(act: Dictionary) -> void:
	var fixed := {6: "treasure", 10: "rest", 11: "boss"}
	var pick_rng = RUN_RNG_SET.new(SEED).derived("test_picks")
	var early_seen := {}
	for i in range(200):
		var rng_set = RUN_RNG_SET.new("ROUTEW%04d" % i)
		var walk := _walk(act, 1, rng_set, pick_rng)
		for f in range(walk.sets.size()):
			var ids: Array = walk.sets[f]
			# Types are read from the map snapshot taken when the floor was offered.
			var snap: Array = walk.trace[maxi(f - 1, 0)]
			var types: Array = []
			for row in snap:
				if row[0] in ids:
					types.append(row[1])
			if fixed.has(f):
				_expect(types == [fixed[f]], "floor %d is one %s (%s)" % [f, fixed[f], types])
			elif f > 0:
				_expect(types.size() >= 2 and types.size() <= 3, "floor %d offers 2–3 cards (%d)" % [f, types.size()])
				for t in UNIQUE_TYPES:
					_expect(types.count(t) <= 1, "floor %d repeats %s" % [f, t])
				if f == 1:
					_expect(types.all(func(t): return t == "enemy"), "floor 1 offers only fights (%s)" % [types])
				if f <= 4:
					_expect(not "elite" in types, "no elite on floor %d" % f)
					if f >= 2:
						for t in types:
							early_seen[t] = true
			for row in snap:
				if row[0] in ids:
					_check_rewards(str(row[1]), row[3])
		if not failures.is_empty():
			return
	for t in ["merchant", "rest", "treasure"]:
		_expect(early_seen.has(t), "floors 2–4 sometimes offer a %s" % t)


func _check_rewards(type: String, rewards: Dictionary) -> void:
	match type:
		"enemy":
			_expect(int(rewards.get("gold", 0)) in [6, 8, 11], "a fight prints 6, 8 or 11 Caps (%s)" % rewards)
		"elite":
			_expect(int(rewards.get("gold", 0)) == 18, "an elite prints 18 Caps (%s)" % rewards)
			var scrap := int(rewards.get("scrap", 0))
			_expect(scrap >= 8 and scrap <= 16, "an elite prints 8–16 Scrap (%s)" % rewards)
		_:
			_expect(rewards.is_empty(), "a %s prints no amounts (%s)" % [type, rewards])


func _check_determinism(act: Dictionary) -> void:
	var a := _walk(act, 1, RUN_RNG_SET.new(SEED), RUN_RNG_SET.new(SEED).derived("picks"))
	var b := _walk(act, 1, RUN_RNG_SET.new(SEED), RUN_RNG_SET.new(SEED).derived("picks"))
	_expect(a.trace == b.trace, "the same seed and route give the same cards")


func _check_elite_bias(act: Dictionary) -> void:
	var walk := _walk(act, 1, RUN_RNG_SET.new(SEED), RUN_RNG_SET.new(SEED).derived("bias_picks"), 0.99)
	for f in [5, 7, 8, 9]:  # floor 6 is the fixed treasure
		var snap: Array = walk.trace[f - 1]
		for row in snap:
			if row[0] in walk.sets[f]:
				_expect(row[1] == "elite", "with the A5 bias floor %d rolls elites (%s)" % [f, row[1]])


func _check_act_two_differs() -> void:
	ACTS.active_run = "base:full"
	var flat := func(map: Array) -> Array:
		return map.filter(func(n): return int(n.floor) >= 1).map(func(n): return [n.type, n.rewards])
	var one: Array = flat.call(MAP_GENERATOR.start(ACTS.act(1), 1, RUN_RNG_SET.new(SEED)))
	var two: Array = flat.call(MAP_GENERATOR.start(ACTS.act(2), 2, RUN_RNG_SET.new(SEED)))
	_expect(one != two, "act 2 route differs from act 1")
	ACTS.active_run = "base:demo"


## Fight nodes carry their encounter: enemies from their floor's band with a
## strength that sets their gold, elites from the act's elite list; an act with
## no elites leaves elite encounters empty (battle falls back to selection).
func _check_encounters(act: Dictionary) -> void:
	var gold_by := {"weak": 6, "normal": 8, "strong": 11}
	for bias in [0.0, 0.99]:
		var map: Array = MAP_GENERATOR.start(act, 1, RUN_RNG_SET.new(SEED), bias)
		var current := "f0"
		for f in range(11):
			map = MAP_GENERATOR.grow(map, current, act, 1, RUN_RNG_SET.new(SEED), bias)
			for n in map:
				if n.type == "enemy":
					_expect(str(n.encounter) in ENCOUNTERS.band_pool(act, int(n.floor)), "%s fights its band (%s)" % [n.id, n.get("encounter")])
					_expect(str(n.strength) in gold_by, "%s has a strength (%s)" % [n.id, n.get("strength")])
					_expect(int(n.rewards.get("gold", 0)) == int(gold_by.get(str(n.get("strength")), -1)), "%s pays by strength" % n.id)
				elif n.type == "elite":
					_expect(str(n.encounter) in act.elites and str(n.strength) == "", "%s fights an elite (%s)" % [n.id, n.get("encounter")])
				else:
					_expect(str(n.get("encounter", "")) == "", "%s holds no encounter" % n.id)
			var children: Array = _by_id(map)[current].children
			if children.is_empty():
				break
			current = str(children[0])
	# empty elite list falls back
	var no_elites := act.duplicate(true)
	no_elites["elites"] = []
	var map2: Array = MAP_GENERATOR.start(no_elites, 1, RUN_RNG_SET.new(SEED), 0.99)
	var at := "f0"
	var found := false
	for f in range(11):
		map2 = MAP_GENERATOR.grow(map2, at, no_elites, 1, RUN_RNG_SET.new(SEED), 0.99)
		for n in map2:
			if n.type == "elite":
				found = true
				_expect(str(n.encounter) == "", "an act without elites leaves %s empty" % n.id)
		var kids: Array = _by_id(map2)[at].children
		if kids.is_empty():
			break
		at = str(kids[0])
	_expect(found, "the A5 bias rolled at least one elite")

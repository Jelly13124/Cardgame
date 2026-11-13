extends Node

## The act map (core/run/map_generator.gd): 12 floors, a single relic start and
## boss, an all-treasure floor 6 and an all-rest floor 10, 2–4 nodes on middle
## floors (at most 3 on floor 1), every node linked forward and reachable, no
## merchant before floor 5, and the A5 bias raising elites.

const MAP_GENERATOR = preload("uid://gi3vuuinl2vb")  # res://core/run/map_generator.gd
const RUN_RNG_SET = preload("uid://ealvw2c6utr7")  # res://core/rng/run_rng_set.gd
const ACTS = preload("uid://c7qo73muxvmd4")  # res://core/run/acts.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	ACTS.active_run = ACTS.ACTIVE_RUN
	var act: Dictionary = ACTS.act(1)
	var id_shape := RegEx.create_from_string("^f[0-9]+_s[0-9]+$")
	var elites := 0
	var middle := 0
	for i in range(200):
		var map: Array = MAP_GENERATOR.generate(act, RUN_RNG_SET.new("MAPRULE%03d" % i).derived("map_act_1"))
		_check_map(map, id_shape, "seed %d" % i)
		if not failures.is_empty():
			break
	for i in range(50):
		var biased: Array = MAP_GENERATOR.generate(act, RUN_RNG_SET.new("MAPBIAS%03d" % i).derived("map_act_1"), 0.99)
		for n in biased:
			if int(n.floor) >= 5 and int(n.floor) <= 9 and int(n.floor) != 6:
				middle += 1
				if n.type == "elite":
					elites += 1
	_expect(middle > 0 and float(elites) / float(middle) > 0.5, "the A5 bias makes most mid floors elites (%d/%d)" % [elites, middle])
	# act 2 map differs
	ACTS.active_run = "base:full"
	var one: Array = MAP_GENERATOR.generate(ACTS.act(1), RUN_RNG_SET.new("MAPACT0001").derived("map_act_1"))
	var two: Array = MAP_GENERATOR.generate(ACTS.act(2), RUN_RNG_SET.new("MAPACT0001").derived("map_act_2"))
	_expect(_flat(one) != _flat(two), "act 2 map differs from act 1")
	ACTS.active_run = ACTS.ACTIVE_RUN
	if failures.is_empty():
		print("[OK] map generator rules passed")
		get_tree().quit(0)
		return
	push_error("map generator rules failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _flat(map: Array) -> Array:
	return map.map(func(n): return [n.id, n.type, Array(n.children)])


func _check_map(map: Array, id_shape: RegEx, label: String) -> void:
	var by_floor := {}
	var by_id := {}
	for n in map:
		by_floor[int(n.floor)] = by_floor.get(int(n.floor), []) + [n]
		by_id[str(n.id)] = n
		_expect(id_shape.search(str(n.id)) != null, "%s: id %s has the f<floor>_s<slot> shape" % [label, n.id])
	_expect(by_floor.size() == 12, "%s: 12 floors (%d)" % [label, by_floor.size()])
	_expect(by_floor[0].size() == 1 and by_floor[0][0].type == "relic", "%s: floor 0 is one relic" % label)
	_expect(by_floor[11].size() == 1 and by_floor[11][0].type == "boss", "%s: floor 11 is one boss" % label)
	_expect(by_floor[6].all(func(n): return n.type == "treasure"), "%s: floor 6 is all treasure" % label)
	_expect(by_floor[10].all(func(n): return n.type == "rest"), "%s: floor 10 is all rest" % label)
	for f in range(1, 10):
		var count: int = by_floor[f].size()
		_expect(count >= 2 and count <= 4, "%s: floor %d holds 2–4 nodes (%d)" % [label, f, count])
		if f < 5:
			_expect(by_floor[f].all(func(n): return n.type != "merchant"), "%s: no merchant on floor %d" % [label, f])
	_expect(by_floor[1].size() <= 3, "%s: floor 1 holds at most 3 nodes" % label)
	var has_parent := {}
	for n in map:
		if n.type == "boss":
			continue
		_expect(n.children.size() >= 1 and n.children.size() <= 4, "%s: %s has 1–4 children (%d)" % [label, n.id, n.children.size()])
		for c in n.children:
			_expect(by_id.has(c) and int(by_id[c].floor) == int(n.floor) + 1, "%s: %s links to the next floor" % [label, n.id])
			has_parent[c] = true
	for n in map:
		if int(n.floor) > 0:
			_expect(has_parent.has(str(n.id)), "%s: %s is reachable" % [label, n.id])

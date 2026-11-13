extends Node

## Run save v9: a save from the route-card map becomes the act map for its seed,
## with the player on their current floor (or still at the start), an event in
## progress re-keyed to the new node, and no route fields left on any node. An
## act-graph save keeps its graph.

const RUN_SAVE = preload("uid://dkhd2poukjb61")  # res://core/save/run_save.gd
const SAVE_IO = preload("uid://seo0j510xyq1")  # res://core/save/save_io.gd
const MAP_GENERATOR = preload("uid://gi3vuuinl2vb")  # res://core/run/map_generator.gd
const MAP_TRAVEL = preload("uid://0qgp786g5ulg")  # res://core/run/map_travel.gd
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
	var route := _route_save("f0.1.0.2", 3)
	var migrated: Dictionary = RUN_SAVE.migrate(route)
	_expect(int(migrated["schema_version"]) == 9 and RUN_SAVE.CURRENT == 9, "the save is now v9")
	var want: Array = MAP_GENERATOR.generate(ACTS.act(1), RUN_RNG_SET.new("ROUTEOLD01").derived("map_act_1"))
	_expect(_ids(migrated["map_data"]) == _ids(want), "a route save gets the act map for its seed")
	var floor3: Array = want.filter(func(n): return int(n.floor) == 3)
	floor3.sort_custom(func(a, b): return int(a.slot) < int(b.slot))
	_expect(str(migrated["current_node_id"]) == str(floor3[0].id), "the player stands on floor 3's lowest slot (%s)" % migrated["current_node_id"])
	_expect(Array(migrated["visited_node_ids"]) == [str(floor3[0].id)], "only the current node is visited")
	_expect(migrated["map_data"].all(func(n): return not n.has("rewards") and not n.has("encounter") and not n.has("strength")), "no route fields remain")

	# route save inside an event resumes
	var in_event := _route_save("f0.1.0.2", 3)
	in_event["current_event"] = {"node_id": "f0.1.0.2", "event_id": "base:hooded_stranger", "finished": false}
	in_event["shop_stock"] = {"f0.1.0.2": {}}
	var m2: Dictionary = RUN_SAVE.migrate(in_event)
	_expect(str(m2["current_event"].get("node_id", "")) == str(m2["current_node_id"]) and str(m2["current_event"].get("event_id", "")) == "base:hooded_stranger", "the event in progress is re-keyed to the new node")
	_expect(m2["shop_stock"].is_empty(), "route shop stock is dropped")

	var lost := _route_save("f0.1.0.2", 30)
	var m5: Dictionary = RUN_SAVE.migrate(lost)
	_expect(str(m5["current_node_id"]) == "" and int(m5["current_floor"]) == 0, "a floor the new map lacks puts the player at the start, floor 0 (%s, %s)" % [m5["current_node_id"], m5["current_floor"]])
	_expect(int(migrated["current_floor"]) == 3, "the migrated floor matches the chosen node")
	var at_start := _route_save("", 0)
	var m3: Dictionary = RUN_SAVE.migrate(at_start)
	_expect(str(m3["current_node_id"]) == "" and Array(m3["visited_node_ids"]).is_empty(), "a save at the start stays at the start")

	var graph := _route_save("f2_s0", 2)
	graph["map_data"] = [
		{"id": "f0_s1", "floor": 0, "slot": 1, "type": "relic", "children": ["f1_s0"], "rewards": {"gold": 8}},
		{"id": "f1_s0", "floor": 1, "slot": 0, "type": "enemy", "children": ["f2_s0"], "encounter": "base:scrap_rat", "strength": "weak"},
		{"id": "f2_s0", "floor": 2, "slot": 0, "type": "enemy", "children": []},
	]
	var m4: Dictionary = RUN_SAVE.migrate(graph)
	_expect(_ids(m4["map_data"]) == ["f0_s1", "f1_s0", "f2_s0"] and str(m4["current_node_id"]) == "f2_s0", "an act-graph save keeps its graph")
	_expect(m4["map_data"].all(func(n): return not n.has("rewards") and not n.has("encounter") and not n.has("strength")), "route fields are erased from a graph too")

	# the migrated route save loads and walks to the boss
	RunManager.start_new_run("base:cowboy_bill", [], 0, "ROUTEOLD01")
	SAVE_IO.write_json(RunManager._run_save_path(), _route_save("f0.1.0.2", 3))
	_expect(RunManager.load_run(), "the v8 route save loads")
	var steps := 0
	while RunManager.current_floor < 11 and steps < 12:
		steps += 1
		var here: Dictionary = RunManager.get_node_by_id(RunManager.current_node_id)
		var next: Dictionary = RunManager.get_node_by_id(str(here.children[0]))
		_expect(MAP_TRAVEL.enter(RunManager.state, RunManager._node_index, next)["ok"], "entering %s works" % next.get("id", "?"))
	_expect(RunManager.get_node_by_id(RunManager.current_node_id).get("type", "") == "boss", "the walk reaches the boss")
	RunManager.is_run_active = false
	RunManager.clear_run_save()
	if failures.is_empty():
		print("[OK] map save migration passed")
		get_tree().quit(0)
		return
	push_error("map save migration failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _ids(map: Array) -> Array:
	return map.map(func(n): return str(n["id"]))


## A v8 save on the route-card map: route ids with dots, standing on `current`.
func _route_save(current: String, floor_idx: int) -> Dictionary:
	RunManager.start_new_run("base:cowboy_bill", [], 0, "ROUTEOLD01")
	var d: Dictionary = RUN_SAVE.to_dict(RunManager.state, 0)
	d["schema_version"] = 8
	d["map_data"] = [
		{"id": "f0", "floor": 0, "slot": 0, "type": "relic", "children": ["f0.0", "f0.1"], "rewards": {}},
		{"id": "f0.1", "floor": 1, "slot": 1, "type": "enemy", "children": ["f0.1.0"], "rewards": {"gold": 8}, "encounter": "base:scrap_rat", "strength": "normal"},
		{"id": "f0.1.0.2", "floor": 3, "slot": 2, "type": "unknown", "children": [], "rewards": {}},
	]
	d["current_node_id"] = current
	d["current_floor"] = floor_idx
	d["visited_node_ids"] = [] if current == "" else ["f0", "f0.1", current]
	d["current_act"] = 1
	return d

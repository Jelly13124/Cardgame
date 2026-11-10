extends Node

## A v6 run save holds a whole act's node graph without printed rewards. The
## v7 migration gives every node its rewards, and the old graph is then walked
## to the boss on the route rules: nodes whose children were pruned get fresh
## children instead of dangling ids.

const RUN_SAVE = preload("uid://dkhd2poukjb61")  # res://core/save/run_save.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	RunManager.start_new_run("base:cowboy_bill", [], 0, "OLDMAP0001")
	var d: Dictionary = RUN_SAVE.to_dict(RunManager.state, 0)
	d["schema_version"] = 6
	d["map_data"] = _old_graph()
	d["current_node_id"] = "f3_s0"
	d["current_floor"] = 3
	d["visited_node_ids"] = ["f0_s0", "f1_s0", "f2_s0", "f3_s0"]
	var migrated: Dictionary = RUN_SAVE.migrate(d)
	_expect(int(migrated["schema_version"]) == RUN_SAVE.CURRENT and RUN_SAVE.CURRENT == 7, "the save is now v7")
	for n in migrated["map_data"]:
		_expect(n.has("rewards"), "node %s gained rewards" % n["id"])
		if n["type"] == "enemy":
			_expect(int(n["rewards"].get("gold", 0)) in [6, 8, 11], "an old fight prints its Caps (%s)" % n["rewards"])
		if n["type"] == "elite":
			var scrap := int(n["rewards"].get("scrap", 0))
			_expect(int(n["rewards"].get("gold", 0)) == 18 and scrap >= 8 and scrap <= 16, "an old elite prints 18 Caps and 8–16 Scrap")
	_expect(RUN_SAVE.migrate(d) == migrated, "the migration is deterministic")
	RUN_SAVE.apply(RunManager.state, migrated)
	RunManager._reindex_map()
	# old graph walks to the boss
	var floors := RunManager.floors_per_act()
	var steps := 0
	while RunManager.current_floor < floors - 1 and steps < floors:
		steps += 1
		var here: Dictionary = RunManager.get_node_by_id(RunManager.current_node_id)
		if here.children.is_empty():
			_expect(false, "%s offers no choice" % here.get("id", "?"))
			break
		var next := str(here.children[0])
		_expect(RunManager.enter_map_node(next)["ok"], "entering %s is accepted" % next)
		for c in RunManager.get_node_by_id(next).children:
			_expect(not RunManager.get_node_by_id(c).is_empty(), "%s's child %s is on the map" % [next, c])
	_expect(RunManager.current_floor == floors - 1, "the old graph reaches the boss floor")
	RunManager.is_run_active = false
	RunManager.clear_run_save()
	if failures.is_empty():
		print("[OK] route map save passed")
		get_tree().quit(0)
		return
	push_error("route map save failed: %s" % "; ".join(failures))
	get_tree().quit(1)


## A v6-shaped act: 12 floors, ids f<floor>_s<slot>, one node on floors 0 and
## 11, two elsewhere, every node linked to every node of the next floor.
func _old_graph() -> Array:
	var fixed := {0: "relic", 6: "treasure", 10: "rest", 11: "boss"}
	var nodes: Array = []
	for f in range(12):
		var slots := [0] if f == 0 or f == 11 else [0, 1]
		for s in slots:
			var children: Array = []
			if f < 11:
				for cs in ([0] if f + 1 == 11 else [0, 1]):
					children.append("f%d_s%d" % [f + 1, cs])
			nodes.append({
				"id": "f%d_s%d" % [f, s],
				"floor": f,
				"slot": s,
				"type": fixed.get(f, "enemy" if s == 0 else "elite"),
				"children": children,
			})
	return nodes

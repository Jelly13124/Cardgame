extends Node

## The run walks the route through RunManager.enter_map_node: every move is
## accepted, the map stays a handful of floors big, pruned siblings can no
## longer be entered, and a save made mid-route reloads the same cards.

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	RunManager.start_new_run("base:cowboy_bill", [], 0, "ROUTERUN01")
	RunManager.generate_map()
	_expect(RunManager.enter_map_node("f0")["ok"], "the start node is entered")
	var floors := RunManager.floors_per_act()
	var saved_at_floor_3 := false
	while RunManager.current_floor < floors - 1:
		var here: Dictionary = RunManager.get_node_by_id(RunManager.current_node_id)
		var choices: Array = here.children
		if choices.is_empty():
			_expect(false, "floor %d offers no choice" % RunManager.current_floor)
			break
		var sibling := str(choices[1]) if choices.size() > 1 else ""
		_expect(RunManager.enter_map_node(str(choices[0]))["ok"], "entering %s is accepted" % choices[0])
		_expect(RunManager.map_data.size() <= 1 + 11 + 3 + 9, "the map stays small (%d nodes)" % RunManager.map_data.size())
		if sibling != "":
			_expect(not RunManager.enter_map_node(sibling)["ok"], "a pruned sibling %s cannot be entered" % sibling)
		if RunManager.current_floor == 3 and not saved_at_floor_3:
			saved_at_floor_3 = true
			_check_reload()
	_expect(RunManager.current_floor == floors - 1, "the route reaches the boss floor")
	_expect(RunManager.get_node_by_id(RunManager.current_node_id).get("type", "") == "boss", "the last node is the boss")
	RunManager.is_run_active = false
	RunManager.clear_run_save()
	if failures.is_empty():
		print("[OK] route map run passed")
		get_tree().quit(0)
		return
	push_error("route map run failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _check_reload() -> void:
	RunManager.save_run()
	var before := JSON.stringify(RunManager.map_data)
	var children_before: Array = RunManager.get_node_by_id(RunManager.current_node_id).children.duplicate()
	RunManager.map_data = []
	RunManager._reindex_map()
	_expect(RunManager.load_run(), "the mid-route save loads")
	_expect(JSON.stringify(RunManager.map_data) == before, "the reloaded map is the saved one")
	_expect(
		Array(RunManager.get_node_by_id(RunManager.current_node_id).children) == Array(children_before),
		"the reloaded node offers the same cards"
	)

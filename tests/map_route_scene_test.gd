extends Node

## The map screen presents the progressively known route as a linked node graph.
## Only the current node's children are interactive; travel and pruning remain
## owned by RunManager and the core route generator.

const MAP_SCENE = preload("uid://d3x5b8wvg2q")  # res://ui/map/map_scene.tscn

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	RunManager.start_new_run("base:cowboy_bill", [], 0, "ROUTEUI001")
	RunManager.generate_map()
	var map = await _open_map(false)
	var graph: Node = map.find_child("RouteGraph", true, false)
	_expect(graph != null, "route map uses a full-screen node graph")
	_expect(map.find_child("ChoiceRow", true, false) == null, "route map no longer creates a choice-card row")
	_expect(map.find_child("RouteChoicesPanel", true, false) == null, "route map has no shared card panel")
	var nodes := _nodes(map)
	_expect(nodes.size() == RunManager.map_data.size(), "graph shows every currently known node")
	_expect(_interactive_nodes(nodes).size() == 1, "fresh map exposes only the relic start node")
	_expect(map.find_child("RouteTitle", true, false) != null, "route map keeps its title hierarchy")

	map.queue_free()
	await get_tree().process_frame
	RunManager.enter_map_node("f0")
	RunManager.enter_map_node(str(RunManager.get_node_by_id("f0").children[0]))
	var here: Dictionary = RunManager.get_node_by_id(RunManager.current_node_id)
	map = await _open_map(false)
	nodes = _nodes(map)
	_expect(_interactive_nodes(nodes).size() == here.children.size(), "only the current node's children are interactive")
	for button in _interactive_nodes(nodes):
		_expect(str(button.get_meta("node_id", "")) in here.children, "interactive node belongs to the current branch")

	var before: String = RunManager.current_node_id
	if not here.children.is_empty():
		map._choose(str(here.children[0]))
		if here.children.size() > 1:
			map._choose(str(here.children[1]))
		_expect(RunManager.current_node_id == str(here.children[0]), "only the first graph choice travels")
		_expect(before != RunManager.current_node_id, "the first graph choice moved the run")
	map.queue_free()
	await get_tree().process_frame

	var peek = await _open_map(true)
	var at: String = RunManager.current_node_id
	_expect(_interactive_nodes(_nodes(peek)).is_empty(), "peek graph does not expose interactive nodes")
	var choices: Array = peek._choices()
	if not choices.is_empty():
		peek._choose(str(choices[0].get("id", "")))
	_expect(RunManager.current_node_id == at, "a peek never travels")
	peek.queue_free()

	RunManager.is_run_active = false
	RunManager.clear_run_save()
	if failures.is_empty():
		print("[OK] map route scene passed")
		get_tree().quit(0)
		return
	push_error("map route scene failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _open_map(peek: bool):
	var map = MAP_SCENE.instantiate()
	map.peek_mode = peek
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	return map


func _nodes(map) -> Array:
	var graph = map.find_child("RouteGraph", true, false)
	var out: Array = []
	if graph == null:
		return out
	for child in graph.get_children():
		if child is Button and str(child.name).begins_with("RouteNode_"):
			out.append(child)
	return out


func _interactive_nodes(nodes: Array) -> Array:
	return nodes.filter(func(button): return bool(button.get_meta("interactive", false)))

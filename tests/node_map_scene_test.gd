extends Node

## The map screen draws the whole act as a node map (ui/map/node_map_view.gd):
## one node control per map node, the current node's children available, the
## current node marked, a legend of the room types, the view scrolled to the
## current node, and guarded choosing (one move per pick, none in a peek).

const MAP_SCENE = preload("uid://d3x5b8wvg2q")  # res://ui/map/map_scene.tscn
const MAP_TRAVEL = preload("uid://0qgp786g5ulg")  # res://core/run/map_travel.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	RunManager.start_new_run("base:cowboy_bill", [], 0, "NODEMAP001")
	RunManager.generate_map()
	var map = await _open(false)
	var view = map.find_child("NodeMapView", true, false)
	_expect(view != null, "the map screen holds a NodeMapView")
	var start_id := ""
	for n in RunManager.map_data:
		if int(n.floor) == 0:
			start_id = str(n.id)
	_expect(_buttons(view).size() == RunManager.map_data.size(), "one node control per node (%d vs %d)" % [_buttons(view).size(), RunManager.map_data.size()])
	_expect(_available(view) == [start_id], "only the start is available on a fresh act (%s)" % [_available(view)])
	_expect(view.find_child("LegendEntries", true, false).get_child_count() == 8, "the legend lists 8 room types")
	# The wheel and drags reach the view over a node: nodes pass mouse events on
	# (headless runs do not route pushed mouse events, so the filter and the
	# view's own handler are checked directly).
	_expect(_buttons(view).all(func(b): return b.mouse_filter == Control.MOUSE_FILTER_PASS), "every node passes mouse events on to the map view")
	var before: float = view._scroll
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	view._gui_input(wheel)
	_expect(view._scroll > before, "the wheel scrolls the map (%.0f -> %.0f)" % [before, view._scroll])
	var before_map := JSON.stringify(RunManager.map_data)
	_expect(RunManager.enter_map_node(start_id)["ok"] and JSON.stringify(RunManager.map_data) == before_map, "RunManager.enter_map_node travels without changing the map")
	RunManager.state.current_node_id = ""
	RunManager.state.visited_node_ids.clear()
	RunManager.state.current_floor = 0
	map.queue_free()
	await get_tree().process_frame

	_travel(start_id)
	map = await _open(false)
	view = map.find_child("NodeMapView", true, false)
	var here: Dictionary = RunManager.get_node_by_id(RunManager.current_node_id)
	var kids: Array = Array(here.children).map(func(c): return str(c))
	kids.sort()
	_expect(_available(view) == kids, "the available nodes are the current node's children (%s vs %s)" % [_available(view), kids])
	_expect(view.node_button(RunManager.current_node_id).state == "current", "the current node is marked")

	# a second choice while one resolves is ignored
	var first := str(here.children[0])
	map._choose(first)
	if here.children.size() > 1:
		map._choose(str(here.children[1]))
	_expect(RunManager.current_node_id == first, "only the first choice travels (%s)" % RunManager.current_node_id)
	map.queue_free()
	await get_tree().process_frame

	# peek never travels
	var at: String = RunManager.current_node_id
	var peek = await _open(true)
	var pview = peek.find_child("NodeMapView", true, false)
	_expect(_buttons(pview).all(func(b): return not b.interactive), "peek nodes are not interactive")
	var options: Array = RunManager.get_node_by_id(at).children
	if not options.is_empty():
		peek._choose(str(options[0]))
	_expect(RunManager.current_node_id == at, "a peek never travels")
	peek.queue_free()
	await get_tree().process_frame

	# current node is in view
	while RunManager.current_floor < 9:
		var cur: Dictionary = RunManager.get_node_by_id(RunManager.current_node_id)
		_travel(str(cur.children[0]))
	map = await _open(false)
	view = map.find_child("NodeMapView", true, false)
	var x: float = view.node_button(RunManager.current_node_id).get_global_rect().get_center().x
	_expect(x >= 0.0 and x <= get_viewport().get_visible_rect().size.x, "the current node is in view (x %.0f)" % x)
	map.queue_free()

	RunManager.is_run_active = false
	RunManager.clear_run_save()
	if failures.is_empty():
		print("[OK] node map scene passed")
		get_tree().quit(0)
		return
	push_error("node map scene failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _travel(id: String) -> void:
	MAP_TRAVEL.enter(RunManager.state, RunManager._node_index, RunManager.get_node_by_id(id))


func _open(peek: bool):
	var map = MAP_SCENE.instantiate()
	map.peek_mode = peek
	add_child(map)
	for i in 4:
		await get_tree().process_frame
	return map


func _buttons(view) -> Array:
	return view.find_children("*", "", true, false).filter(func(n): return n.has_signal("chosen") and "state" in n)


func _available(view) -> Array:
	var out: Array = _buttons(view).filter(func(b): return b.state == "available").map(func(b): return b.node_id)
	out.sort()
	return out

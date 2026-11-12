extends Node

## The map screen shows the route (ui/map/map_scene.gd): a 12-pip floor track
## and one card per current choice, each previewing its next floor. Choosing
## is guarded: a second choice while one resolves is ignored, and a peek over
## a battle never travels.

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
	_expect(_row(map).get_child_count() == 1, "a fresh run offers the single relic card (%d)" % _row(map).get_child_count())
	_expect(_row(map).alignment == BoxContainer.ALIGNMENT_CENTER, "route choices stay centred as a three-choice row")
	_expect(_row(map).get_theme_constant("separation") == 28, "three-choice row uses a compact readable gap")
	_expect(_row(map).get_child(0).custom_minimum_size == Vector2(320, 460), "route slots reserve the wider card size")
	_expect(_cards(map)[0].get_node("ChoiceNumber/Label").text == "1", "the first route card is numbered 1")
	_expect(map.find_child("FloorTrack", true, false).get_child_count() == 12, "the floor track has 12 pips")
	_expect(map.find_child("RouteChoicesPanel", true, false) != null, "the route choices sit inside a shared presentation panel")
	_expect(map.find_child("RouteHeader", true, false) != null, "the route map labels the choice section")
	map.queue_free()

	RunManager.enter_map_node("f0")
	RunManager.enter_map_node(str(RunManager.get_node_by_id("f0").children[0]))
	var here: Dictionary = RunManager.get_node_by_id(RunManager.current_node_id)
	map = await _open_map(false)
	var cards := _cards(map)
	_expect(cards.size() == here.children.size(), "one card per choice (%d vs %d)" % [cards.size(), here.children.size()])
	for card in cards:
		var node: Dictionary = RunManager.get_node_by_id(card.node_id)
		_expect(card.get_node("%NextRow").get_child_count() == node.children.size(), "card %s previews its next floor" % card.node_id)

	# a second choice while one is pending is ignored
	var before: String = RunManager.current_node_id
	map._choose(str(here.children[0]))
	if here.children.size() > 1:
		map._choose(str(here.children[1]))
	_expect(RunManager.current_node_id == str(here.children[0]), "only the first choice travels (%s)" % RunManager.current_node_id)
	_expect(before != RunManager.current_node_id, "the first choice moved the run")
	map.queue_free()
	await get_tree().process_frame

	# peek cards ignore input
	var peek = await _open_map(true)
	var at: String = RunManager.current_node_id
	var peek_cards := _cards(peek)
	_expect(peek_cards.all(func(c): return not c.interactive), "peek cards are not interactive")
	if not peek_cards.is_empty():
		peek._choose(peek_cards[0].node_id)
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


func _row(map) -> Node:
	return map.find_child("ChoiceRow", true, false)


func _cards(map) -> Array:
	var out: Array = []
	for slot in _row(map).get_children():
		for c in slot.get_children():
			if c.has_signal("chosen"):
				out.append(c)
	return out

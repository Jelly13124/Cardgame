extends Node

## Event room (phase 9a): renders the model's options, locks a locked option,
## runs a double click once, marks the visit finished after the first option,
## and proceeds out through finish_event.

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const EVENT_POOL = preload("uid://dr3dtuxwul371")  # res://core/run/events/event_pool.gd
const EVENT_ROOM = preload("uid://cyvheo458ghoj")  # res://ui/events/event_room.gd
const MAP_SCENE = preload("uid://d3x5b8wvg2q")  # res://ui/map/map_scene.tscn
const SAVE_IO = preload("uid://seo0j510xyq1")  # res://core/save/save_io.gd
const MOD_DIR := "res://tests/fixtures/content_mod/"

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _buttons(room) -> Array:
	var out: Array = []
	for b in room.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and not b.is_queued_for_deletion():
			out.append(b)
	return out


func _run() -> void:
	MODEL_DB.inject_dir(MOD_DIR, "mymod")
	RunManager.start_new_run("base:cowboy_bill", [], 0, "EVTROOM01")
	RunManager.state.current_event = {"node_id": "n1", "event_id": "mymod:probe", "finished": false}

	var model = EVENT_POOL.instantiate("mymod:probe")
	model.begin()
	var room = EVENT_ROOM.new()
	room.model = model
	add_child(room)
	await _frames(3)
	var buttons := _buttons(room)
	_expect(buttons.size() == 2, "two option buttons, got %d" % buttons.size())
	if buttons.size() == 2:
		_expect(buttons[1].disabled, "the locked option is disabled")
		# option_click_runs_once: two presses in one frame run GO once.
		buttons[0].pressed.emit()
		buttons[0].pressed.emit()
	await _frames(2)
	_expect(model.page == "TWO" and model.go_runs == 1, "a double click runs the option once (runs %d)" % model.go_runs)
	_expect(RunManager.state.current_event.get("finished") == true, "the first resolved option finishes the visit")
	buttons = _buttons(room)
	_expect(buttons.size() == 1, "page TWO shows one button, got %d" % buttons.size())
	if buttons.size() == 1:
		buttons[0].pressed.emit()  # END
	await _frames(2)
	buttons = _buttons(room)
	_expect(model.is_finished and buttons.size() == 1, "END finishes with one proceed button")
	var resolved := [false]
	room.resolved.connect(func(): resolved[0] = true)
	if buttons.size() == 1:
		buttons[0].pressed.emit()  # proceed
	await _frames(2)
	_expect(resolved[0], "proceed emits resolved")
	_expect(RunManager.state.current_event.is_empty(), "proceed clears current_event")

	await _test_map_reopens_unfinished_event()
	await _test_map_deals_a_playable_event()
	await _test_every_resolved_option_is_saved()

	RunManager.is_run_active = false
	RunManager.clear_run_save()
	if failures.is_empty():
		print("[OK] event room contract passed")
		get_tree().quit(0)
		return
	push_error("event room contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


## map_reopens_unfinished_event: a run saved inside an event reopens it on the
## map; a finished one shows only the proceed button.
func _test_map_reopens_unfinished_event() -> void:
	for finished in [false, true]:
		RunManager.start_new_run("base:cowboy_bill", [], 0, "EVTROOM02")
		RunManager.current_node_id = str(RunManager.map_data[0]["id"])
		RunManager.state.current_event = {
			"node_id": RunManager.current_node_id, "event_id": "base:hooded_stranger", "finished": finished,
		}
		var map = MAP_SCENE.instantiate()
		add_child(map)
		await _frames(3)
		var content = map.find_child("EventContent", true, false)
		_expect(content != null, "the map reopens the event (finished=%s)" % finished)
		if content != null:
			var buttons := _buttons(content)
			if finished:
				_expect(content.model.is_finished and buttons.size() == 1, "a finished event reopens with only proceed")
			else:
				_expect(content.model.page == "INITIAL" and buttons.size() > 1, "an unfinished event reopens at INITIAL")
		map.queue_free()
		await _frames(2)


## A freshly dealt event (map → enter_event → room) shows its options.
func _test_map_deals_a_playable_event() -> void:
	RunManager.start_new_run("base:cowboy_bill", [], 0, "EVTROOM03")
	var deck: Array[String] = ["base:hooded_stranger"]
	RunManager.state.event_deck = deck
	RunManager.current_node_id = str(RunManager.map_data[0]["id"])
	var map = MAP_SCENE.instantiate()
	add_child(map)
	await _frames(2)
	map._open_event_node(0)
	await _frames(3)
	var content = map.find_child("EventContent", true, false)
	_expect(content != null, "the map opens the dealt event")
	if content != null:
		_expect(_buttons(content).size() == 3, "a dealt event shows its options, got %d" % _buttons(content).size())
	map.queue_free()
	await _frames(2)


## Every resolved option is saved, so quitting after a later page cannot undo
## its effects.
func _test_every_resolved_option_is_saved() -> void:
	RunManager.start_new_run("base:cowboy_bill", [], 0, "EVTROOM04")
	var deck: Array[String] = ["base:cursed_safe"]
	RunManager.state.event_deck = deck
	var model = RunManager.enter_event("n9")
	var room = EVENT_ROOM.new()
	room.model = model
	add_child(room)
	await _frames(2)
	var gold: int = RunManager.gold
	room._on_option_pressed(0)  # CRACK
	await _frames(1)
	room._on_option_pressed(0)  # POCKET: +40 gold and rust
	await _frames(1)
	var saved: Dictionary = SAVE_IO.read_json(RunManager._run_save_path()).get("data", {})
	var deck_saved: Array = saved.get("player_deck", [])
	_expect(deck_saved.any(func(e): return str(e.get("card_id", "")) == "base:rust"),
		"the second page's curse is in the save")
	_expect(RunManager.gold == gold + 40, "POCKET paid out")
	room.queue_free()
	await _frames(2)

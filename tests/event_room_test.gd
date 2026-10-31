extends Node

## Event room (phase 9a): renders the model's options, locks a locked option,
## runs a double click once, marks the visit finished after the first option,
## and proceeds out through finish_event.

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const EVENT_POOL = preload("uid://dr3dtuxwul371")  # res://core/run/events/event_pool.gd
const EVENT_ROOM = preload("uid://cyvheo458ghoj")  # res://ui/events/event_room.gd
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

	RunManager.is_run_active = false
	RunManager.clear_run_save()
	if failures.is_empty():
		print("[OK] event room contract passed")
		get_tree().quit(0)
		return
	push_error("event room contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)

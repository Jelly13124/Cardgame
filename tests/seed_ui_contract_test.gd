extends Node

## The home base lets the player type a run seed (empty = random; invalid text
## never starts a run) and the result screen shows the run's seed.

const HOME = preload("uid://c6bvuu6kbx0pq")  # res://run_system/ui/home_base_scene.tscn
const RESULT_SCREEN = preload("uid://bxh1x1hy6fylv")  # res://run_system/ui/result_screen.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	RunManager.is_run_active = false
	var home := HOME.instantiate()
	add_child(home)
	await get_tree().process_frame
	await get_tree().process_frame
	var field := home.find_child("SeedField", true, false) as LineEdit
	_expect(field != null, "home has a SeedField")
	if field != null:
		field.text = ""
		_expect(home.call("_resolve_seed_input") == {"ok": true, "seed": ""}, "empty seed means random")
		field.text = " testseedo1 "
		_expect(home.call("_resolve_seed_input") == {"ok": true, "seed": "TESTSEED01"}, "typed seed is canonical")
		field.text = "abc def"
		_expect(not bool(home.call("_resolve_seed_input")["ok"]), "seed with a space is invalid")
		home.call("_on_start_pressed")
		await get_tree().process_frame
		_expect(not RunManager.is_run_active, "invalid seed does not start a run")
		_expect(bool(field.get_meta("seed_invalid", false)), "invalid seed is flagged on the field")
	home.queue_free()

	RunManager.start_new_run("base:cowboy_bill", [], 0, "SEEDTEST42")
	RunManager.is_run_active = true
	RunManager.abandon_run()  # production order: teardown first, then the result screen
	var screen = RESULT_SCREEN.new()
	screen.mode = "defeat"
	add_child(screen)
	await get_tree().process_frame
	var label := screen.find_child("SeedLabel", true, false) as Label
	_expect(label != null and label.text.contains("SEEDTEST42"), "result screen shows the seed")
	screen.queue_free()
	RunManager.is_run_active = false
	RunManager.clear_run_save()

	if failures.is_empty():
		print("[OK] seed ui contract passed")
		get_tree().quit(0)
		return
	push_error("seed ui contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)

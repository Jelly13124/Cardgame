extends Node

## EventModel / EventOption contract: pages, locking, requires, luck
## determinism, will_kill and {var} formatting (phase 9a).

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const RNG = preload("uid://ds3dd0kmgq0ib")  # res://core/rng/rng.gd
const PROBE := "uid://6h7x6rgg0emy"  # res://tests/fixtures/content_mod/events/probe.gd
const LUCKY_SRC := """extends "res://core/run/events/event_model.gd"
var picked := ""
func generate_initial_options() -> Array:
	return [luck_option("ROLL", func(): picked = "win", func(): picked = "lose")]
"""

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _make(script: Script):
	var m = script.new()
	m.id = "mymod:probe"
	m.owner = RunManager
	m.rng = RNG.new(42)
	return m


func _run() -> void:
	RunManager.start_new_run("base:cowboy_bill", [], 0, "EVTMODEL1")
	var probe = _make(load(PROBE))
	probe.begin()
	_expect(probe.current_options.size() == 2, "begin gives two options")
	_expect(probe.current_options[1].is_locked(), "an option without a callable is locked")
	var emitted := [0]
	probe.state_changed.connect(func(): emitted[0] += 1)
	_expect(probe.choose(0), "choose GO returns true")
	_expect(emitted[0] == 1, "page change emits state_changed once, got %d" % emitted[0])
	_expect(probe.page == "TWO" and probe.current_options.size() == 1 and probe.current_options[0].key == "END",
		"GO moves to TWO with END")
	_expect(probe.choose(0), "choose END returns true")
	_expect(probe.is_finished and probe.page == "DONE", "END finishes on DONE")
	_expect(probe.current_options.size() == 1 and probe.current_options[0].is_proceed, "finished leaves one proceed option")
	_expect(probe.current_options[0].text_key == "UI_EVENT_CONTINUE", "proceed text key")
	_expect(not probe.choose(0), "a finished model refuses further choices")

	var locked = _make(load(PROBE))
	locked.begin()
	_expect(not locked.choose(1), "choosing a locked option returns false")
	_expect(not locked.choose(5), "out of range returns false")
	_expect(locked.option("X", func(): pass).requires({"charm": 99}).lock_reason == "Charm 99", "requires locks below threshold")
	_expect(not locked.option("X", func(): pass).requires({"charm": 0}).is_locked(), "requires unlocks at threshold")

	var lucky_script := GDScript.new()
	lucky_script.source_code = LUCKY_SRC
	lucky_script.reload()
	var picks: Array = []
	for i in 2:
		var m = _make(lucky_script)
		m.rng = RNG.new(7)
		m.begin()
		_expect(is_equal_approx(m.current_options[0].chance, RunManager.luck_check_chance()), "luck option shows the chance")
		m.choose(0)
		picks.append(m.picked)
	_expect(picks[0] != "" and picks[0] == picks[1], "luck follows the seeded stream, got %s" % [picks])

	_expect(probe.will_kill(RunManager.current_health), "will_kill at exactly current HP")
	_expect(not probe.will_kill(RunManager.current_health - 1), "will_kill below current HP is false")
	probe.dynamic_vars = {"rad": 3}
	_expect(probe.format("take {rad}") == "take 3", "format substitutes dynamic vars")
	_expect(probe.text_key("PAGE_INITIAL") == "EVENT_PROBE_PAGE_INITIAL", "text key drops the namespace")

	if failures.is_empty():
		print("[OK] event model contract passed")
		get_tree().quit(0)
		return
	push_error("event model contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)

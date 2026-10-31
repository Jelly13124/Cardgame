extends Node

## EventPool and the event lifecycle (phase 9a): per-act decks, is_allowed,
## no repeats, empty deck, and the RunManager facade with save round trip.

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const EVENT_POOL = preload("uid://dr3dtuxwul371")  # res://core/run/events/event_pool.gd
const RUN_SAVE = preload("uid://dkhd2poukjb61")  # res://core/save/run_save.gd
const RNG = preload("uid://ds3dd0kmgq0ib")  # res://core/rng/rng.gd
const RUN_STATE = preload("uid://cguglvtfurhlo")  # res://core/run/run_state.gd
const PROBE := "res://tests/fixtures/content_mod/events/probe.gd"  # path-ok: event JSON script field
const PICKY := "res://tests/fixtures/content_mod/events/picky.gd"  # path-ok: event JSON script field

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	MODEL_DB.inject("event", "mymod", "a1", {"id": "a1", "script": PROBE, "acts": [1]})
	MODEL_DB.inject("event", "mymod", "a23", {"id": "a23", "script": PROBE, "acts": [2, 3]})
	MODEL_DB.inject("event", "mymod", "shared", {"id": "shared", "script": PROBE})
	MODEL_DB.inject("event", "mymod", "picky", {"id": "picky", "script": PICKY})

	var d1: Array = EVENT_POOL.build_deck(1, [], RNG.new(5))
	_expect(d1.has("mymod:a1") and d1.has("mymod:shared") and not d1.has("mymod:a23"), "act 1 deck: %s" % [d1])
	var d3: Array = EVENT_POOL.build_deck(3, [], RNG.new(5))
	_expect(d3.has("mymod:a23") and d3.has("mymod:shared") and not d3.has("mymod:a1"), "act 3 deck: %s" % [d3])
	_expect(EVENT_POOL.build_deck(1, [], RNG.new(5)) == d1, "same seed, same deck")
	_expect(not EVENT_POOL.build_deck(1, ["mymod:shared"], RNG.new(5)).has("mymod:shared"), "excluded ids absent")

	RunManager.start_new_run("base:cowboy_bill", [], 0, "EVTSEED01")
	var state = RunManager.state
	var deck: Array[String] = ["mymod:picky", "mymod:shared"]
	state.event_deck = deck
	state.seen_event_ids.clear()
	var model = EVENT_POOL.next(state)
	_expect(model != null and model.id == "mymod:shared", "next skips a picky event")
	_expect(state.event_deck == ["mymod:picky"], "picky stays, dealt id leaves: %s" % [state.event_deck])
	_expect(state.seen_event_ids.has("mymod:shared"), "dealt id joins seen")
	_expect(EVENT_POOL.next(state) == null, "empty_deck_returns_null: only picky left")
	_expect(EVENT_POOL.next(state) == null, "empty_deck_returns_null: repeat call")

	# Lifecycle through the facade.
	var deck2: Array[String] = ["mymod:shared"]
	state.event_deck = deck2
	state.seen_event_ids.clear()
	var entered = RunManager.enter_event("n1")
	_expect(entered != null and entered.id == "mymod:shared", "enter_event deals the event")
	_expect(state.current_event.get("node_id") == "n1" and state.current_event.get("finished") == false,
		"enter_event records an unfinished event: %s" % [state.current_event])
	RunManager.event_option_resolved()
	_expect(state.current_event.get("finished") == true, "event_option_resolved marks it finished")
	var restored = RUN_STATE.new()
	RUN_SAVE.apply(restored, RUN_SAVE.to_dict(state, 0))
	_expect(restored.current_event == state.current_event, "current_event round-trips: %s" % [restored.current_event])
	_expect(restored.event_deck == state.event_deck, "event_deck round-trips")
	var resumed = RunManager.resume_event()
	_expect(resumed != null and resumed.is_finished and resumed.page == "RESUMED", "a finished event resumes finished")
	_expect(resumed.current_options.size() == 1 and resumed.current_options[0].is_proceed, "resumed shows only proceed")
	RunManager.finish_event()
	_expect(state.current_event.is_empty(), "finish_event clears current_event")
	_expect(RunManager.resume_event() == null, "nothing to resume after finishing")

	RunManager.advance_act()
	_expect(state.current_event.is_empty() and not state.event_deck.has("mymod:shared"),
		"advance_act rebuilds the deck without seen events")

	RunManager.is_run_active = false
	RunManager.clear_run_save()
	if failures.is_empty():
		print("[OK] event pool contract passed")
		get_tree().quit(0)
		return
	push_error("event pool contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)

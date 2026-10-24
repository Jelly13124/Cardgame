extends Node

## Generic hook dispatch: listeners come from a provider read on every
## dispatch, value hooks fold over `calc.value`, queries stop at the first
## true, reactions pass their arguments, and missing methods are skipped.

const COMBAT_HOOKS = preload("uid://cjb2wdqhw4j2x")  # res://core/combat/combat_hooks.gd
const HOOK_VALUE = preload("uid://npewr2krgrm6")  # res://core/combat/hook_value.gd
const LISTENER = preload("uid://bylcto31kormu")  # res://core/listeners/listener.gd

var failures: PackedStringArray = []


class AddTwo:
	extends "res://core/listeners/listener.gd"
	func modify_hand_draw(calc) -> void:
		calc.value += 2


class SaysYes:
	extends "res://core/listeners/listener.gd"
	var asked := 0
	func should_force_crit(_calc) -> bool:
		asked += 1
		return true


class Recorder:
	extends "res://core/listeners/listener.gd"
	var seen: Array = []
	func after_turn_start(side, round_number) -> void:
		seen.append([side, round_number])


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var hooks = COMBAT_HOOKS.new()
	var dynamic: Array = []
	hooks.provider = func() -> Array: return dynamic
	_expect(int(hooks.compute("modify_hand_draw", HOOK_VALUE.make(3))) == 3, "no listeners keeps the value")
	dynamic.append(AddTwo.new())
	dynamic.append(LISTENER.new())
	_expect(int(hooks.compute("modify_hand_draw", HOOK_VALUE.make(3))) == 5, "provider read on every dispatch")
	var first := SaysYes.new()
	var second := SaysYes.new()
	dynamic.append(first)
	dynamic.append(second)
	_expect(hooks.query_any("should_force_crit", null), "query_any is true when a listener says so")
	_expect(first.asked == 1 and second.asked == 0, "query_any stops at the first true")
	var rec := Recorder.new()
	dynamic.append(rec)
	await hooks.react("after_turn_start", "player", 2)
	_expect(rec.seen == [["player", 2]], "react passes both arguments")
	var calc = HOOK_VALUE.make(1, {"round": 4})
	_expect(int(calc.get_field("round")) == 4 and calc.value == 1, "hook value carries fields")

	if failures.is_empty():
		print("[OK] listener hooks contract passed")
		get_tree().quit(0)
		return
	push_error("listener hooks contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)

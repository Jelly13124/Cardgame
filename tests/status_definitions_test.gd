extends Node

## Statuses are content definitions (content/statuses) and their behaviour lives
## in per-creature listener instances created when the status gains stacks.

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const DATA_VALIDATOR = preload("uid://bdhbhkhs5p4v3")  # res://battle_scene/data_validator.gd
const STATUS_SYSTEM = preload("uid://cq4eulp4ci8is")  # res://battle_scene/status_effect_system.gd

var failures: PackedStringArray = []


class Dummy:
	extends Node
	var health := 10
	var status_system = null
	func get_status_stacks(s: String) -> int:
		return status_system.get_stacks(s)


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var ids := MODEL_DB.ids("status")
	_expect(ids.size() == 19, "19 statuses, got %d" % ids.size())
	var names: Array = DATA_VALIDATOR.allowed_status_names()
	names.sort()
	var keys: Array = ids.map(func(i): return str(i).trim_prefix("base:"))
	keys.sort()
	_expect(names == keys, "validator status names come from the definitions")
	var weak := MODEL_DB.data("status", "base:weak")
	_expect(weak.get("kind") == "debuff" and weak.get("decay") == "turn_end", "weak is a decaying debuff")
	_expect(MODEL_DB.data("status", "base:intangible").get("decay") == "opponent_turn_end", "intangible decays on the opponent's turn end")
	_expect(STATUS_SYSTEM.status_color("weak") == Color.html(str(weak["color"])), "badge colour comes from the definition")
	_expect(STATUS_SYSTEM.status_description("burn").begins_with("Take damage"), "description fallback from the definition")

	var dummy := Dummy.new()
	dummy.status_system = STATUS_SYSTEM.new()
	add_child(dummy)
	dummy.status_system.add_status("weak", 2, dummy)
	dummy.status_system.add_status("weak", 1, dummy)
	var listeners: Array = dummy.status_system.listeners()
	_expect(listeners.size() == 1 and listeners[0].owner == dummy and listeners[0].id == "weak",
		"one weak listener owned by its creature")
	dummy.status_system.add_status("stun", 1, dummy)
	_expect(dummy.status_system.listeners().size() == 1, "statuses without a script have no listener")
	dummy.status_system.spend_stacks("weak", 3, dummy)
	_expect(dummy.status_system.listeners().is_empty(), "listener dropped when stacks reach 0")
	dummy.status_system.add_status("vulnerable", 1, dummy)
	dummy.status_system.on_turn_end(dummy)
	_expect(dummy.status_system.get_stacks("vulnerable") == 0 and dummy.status_system.listeners().is_empty(),
		"turn-end decay from the definition removes the listener")
	dummy.queue_free()

	if failures.is_empty():
		print("[OK] status definitions passed")
		get_tree().quit(0)
		return
	push_error("status definitions failed: %s" % "; ".join(failures))
	get_tree().quit(1)

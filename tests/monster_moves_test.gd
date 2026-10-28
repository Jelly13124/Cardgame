extends Node

## The enemy move state machine (core/combat/monster_moves.gd) cycles its
## pattern, grows ramp attacks, and enters HP-threshold phases once each, the
## deepest crossed one first — with no enemy node.

const MONSTER_MOVES = preload("uid://bqwa1txur3b52")  # res://core/combat/monster_moves.gd
const CREATURE = preload("uid://kab2636ev63e")  # res://core/combat/creature.gd
const INTENTS = preload("uid://crt5cmvargkpn")  # res://core/combat/intents.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	_test_cycle_and_ramp()
	_test_phases()
	_test_intent_text()
	if failures.is_empty():
		print("[OK] monster moves passed")
		get_tree().quit(0)
		return
	push_error("monster moves failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _test_cycle_and_ramp() -> void:
	var m = MONSTER_MOVES.from_data({"action_pattern": [
		{"type": "attack_ramp", "amount": 3, "counter": "c"},
		{"type": "block", "amount": 5},
	]})
	var amounts: Array = []
	for _i in range(5):
		var a: Dictionary = m.consume()
		amounts.append([a["type"], int(a.get("amount", 0))])
	_expect(
		amounts == [["attack_ramp", 3], ["block", 5], ["attack_ramp", 6], ["block", 5], ["attack_ramp", 12]],
		"pattern cycles and the ramp doubles on each use: %s" % [amounts]
	)
	_expect(int(m.peek()["amount"]) == 5 and int(m.peek()["amount"]) == 5, "peek does not advance")


func _test_phases() -> void:
	var c = CREATURE.new()
	c.side = "enemy"
	c.max_health = 100
	c.health = 100
	c.moves = MONSTER_MOVES.from_data({
		"action_pattern": [{"type": "attack", "amount": 1}],
		"phases": [
			{"hp_below": 0.75, "on_enter": [{"type": "heal", "amount": 1}], "action_pattern": [{"type": "block", "amount": 2}]},
			{"hp_below": 0.4, "on_enter": [{"type": "buff_self", "status": "thorns", "stacks": 1}], "action_pattern": [{"type": "attack", "amount": 9}]},
		],
	})
	var intent_changes := [0]
	c.intent_changed.connect(func(): intent_changes[0] += 1)
	c.moves.consume()
	c.apply_damage(70)  # 30% HP: past both thresholds
	var pending: Array = c.moves.consume_pending_on_enter()
	_expect(pending.size() == 1 and pending[0]["type"] == "buff_self", "one big hit enters only the deepest phase: %s" % [pending])
	_expect(int(c.moves.peek()["amount"]) == 9, "the deepest phase's pattern starts from its first move")
	_expect(intent_changes[0] == 1, "the pattern swap announces an intent change")
	c.apply_damage(1)
	_expect(c.moves.consume_pending_on_enter().is_empty(), "entered phases never fire again")


func _test_intent_text() -> void:
	var text := INTENTS.text({"type": "attack", "amount": 9, "interruptible": true}, 12)
	_expect(text.contains("12"), "intent text shows the computed damage: %s" % text)
	_expect(
		not INTENTS.text({"type": "attack", "interruptible": true}, 12, false).contains("\n"),
		"without tips the interrupt line is left out"
	)

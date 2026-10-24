extends Node

## Contract for the top-level action queue (STS2 ActionQueueSet): card plays,
## tools and End Turn run one at a time in the order they were made, and
## ending the combat drops what has not started.

const ACTION_QUEUE = preload("uid://bseuowesln3j7")  # res://core/combat/action_queue.gd
const BATTLE_SCENE = preload("uid://dnhj5pp3c1v2l")  # res://battle_scene/battle_scene.tscn


class EventLog:
	extends RefCounted
	var events: Array[String] = []

	func after_damage_given(result) -> void:
		if result.source and result.source.is_card():
			events.append("hit:%s" % result.source.card.get_instance_id())

	func after_attack(attack: Dictionary) -> void:
		var source = attack.get("source")
		if source and source.is_card():
			events.append("done:%s" % source.card.get_instance_id())


var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	await test_queue_runs_actions_in_order()
	test_clear_pending_drops_unstarted_actions()
	await test_battle_serializes_cards_and_end_turn()
	if failures.is_empty():
		print("[OK] action queue contract passed")
		get_tree().quit(0)
		return
	push_error("action queue contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func test_queue_runs_actions_in_order() -> void:
	var queue = ACTION_QUEUE.new()
	var log: Array[String] = []
	var slow := func() -> void:
		log.append("a:start")
		await get_tree().create_timer(0.05).timeout
		log.append("a:end")
	var fast := func() -> void:
		log.append("b")
	queue.enqueue("a", slow)
	queue.enqueue("b", fast)
	_expect(queue.is_busy(), "queue is busy while an action runs")
	_expect(log == ["a:start"], "the second action waits (got %s)" % [log])
	await queue.drained
	_expect(log == ["a:start", "a:end", "b"], "actions run in enqueue order (got %s)" % [log])
	_expect(not queue.is_busy(), "queue idles when drained")


func test_clear_pending_drops_unstarted_actions() -> void:
	var queue = ACTION_QUEUE.new()
	var ran: Array[String] = []
	var blocker := func() -> void:
		ran.append("first")
		await get_tree().create_timer(0.01).timeout
	queue.enqueue("first", blocker)
	queue.enqueue("second", func() -> void: ran.append("second"))
	queue.clear_pending()
	_expect(ran == ["first"], "running action continues, unstarted one is dropped")


func test_battle_serializes_cards_and_end_turn() -> void:
	Engine.time_scale = 4.0
	var battle = BATTLE_SCENE.instantiate()
	add_child(battle)
	for _i in range(4):
		await get_tree().process_frame
	var log := EventLog.new()
	battle.combat_hooks.add_listener(log)
	var enemy: Node = battle.enemy_container.get_child(0)
	enemy.health = 999
	enemy.max_health = 999
	battle.player.energy = 10
	var attacks: Array = [
		battle.deck_manager.add_card_to_hand("base:strike"),
		battle.deck_manager.add_card_to_hand("base:strike"),
	]
	await get_tree().process_frame
	_expect(attacks[0] != null and attacks[1] != null, "two Shoot cards join the hand")
	attacks = attacks.filter(func(c) -> bool: return c != null)
	if attacks.size() >= 2:
		var turn_events: Array[String] = []
		battle.turn_manager.turn_started.connect(
			func(side: String) -> void: turn_events.append("%s@%d" % [side, log.events.size()])
		)
		battle.play_spell(attacks[0], enemy)
		battle.play_spell(attacks[1], enemy)
		battle._on_end_round_button_pressed()
		var first := "%s" % attacks[0].get_instance_id()
		var second := "%s" % attacks[1].get_instance_id()
		await _wait_until(func() -> bool: return turn_events.size() > 0, 20.0)
		_expect(
			log.events == ["hit:" + first, "done:" + first, "hit:" + second, "done:" + second],
			"second card starts after the first resolves (got %s)" % [log.events]
		)
		_expect(
			turn_events.size() > 0 and turn_events[0] == "enemy@4",
			"enemy turn starts after both queued cards resolved (got %s)" % [turn_events]
		)
	Engine.time_scale = 1.0
	battle.queue_free()
	await get_tree().process_frame


func _wait_until(condition: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline:
			return false
		await get_tree().process_frame
	return true

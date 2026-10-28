extends Node

## Regression: killing every enemy ends the battle (victory is declared) —
## by played cards, and by the debug right-click kill.

const BATTLE_SCENE = preload("uid://dnhj5pp3c1v2l")  # res://battle_scene/battle_scene.tscn

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _start_battle() -> Node:
	RunManager.start_new_run("base:cowboy_bill", [], 0, "VICTORY001")
	RunManager.current_encounter = ["base:scrap_rat", "base:hex_drone"]
	RunManager.last_battle_node_type = "enemy"
	var battle = BATTLE_SCENE.instantiate()
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	for _i in range(30):
		await get_tree().process_frame
	return battle


func _await_victory(battle: Node, won: Array) -> void:
	var deadline := Time.get_ticks_msec() + 8000
	while not won[0] and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _end(battle: Node) -> void:
	get_tree().current_scene = null
	battle.queue_free()
	await get_tree().process_frame
	RunManager.is_run_active = false
	RunManager.clear_run_save()


func _run() -> void:
	# Played Strikes, like the player does.
	var battle = await _start_battle()
	var won := [false]
	battle.combat.combat_ended.connect(func(outcome: String) -> void: won[0] = outcome == "victory")
	battle.player.energy = 10
	for enemy in battle.enemy_container.get_children():
		enemy.health = 1
	for enemy in battle.enemy_container.get_children():
		var card = battle.combat.add_card_to_hand("base:strike")
		await get_tree().process_frame
		battle.play_spell(battle.hand_view.node_of(card), enemy)
		var t := Time.get_ticks_msec() + 5000
		while is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and Time.get_ticks_msec() < t:
			await get_tree().process_frame
	await _await_victory(battle, won)
	_expect(won[0], "card kills end the battle (enemies left: %d)" % battle.enemy_container.get_child_count())
	await _end(battle)

	# Debug right-click kill, one enemy at a time.
	battle = await _start_battle()
	var won_debug := [false]
	battle.combat.combat_ended.connect(func(outcome: String) -> void: won_debug[0] = outcome == "victory")
	for enemy in battle.enemy_container.get_children():
		battle.combat.debug_kill(enemy.creature)
		await get_tree().create_timer(0.3).timeout
	await _await_victory(battle, won_debug)
	_expect(won_debug[0], "debug kills end the battle (enemies left: %d)" % battle.enemy_container.get_child_count())
	await _end(battle)

	if failures.is_empty():
		print("[OK] battle victory passed")
		get_tree().quit(0)
		return
	push_error("battle victory failed: %s" % "; ".join(failures))
	get_tree().quit(1)

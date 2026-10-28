extends Node

## Battle-flow regressions from the phase 1 review:
## - a queued enemy tool whose target dies first must not lock tool/card input;
## - tools are refused during the enemy turn and after End Turn;
## - a card that wins the fight stops running its remaining effects.

const BATTLE_SCENE = preload("uid://dnhj5pp3c1v2l")  # res://ui/battle/battle_screen.tscn
const CARD_INSTANCE = preload("uid://c50mv4hudoncd")  # res://core/combat/card_instance.gd
const ENEMY_TURN = preload("uid://d4np8yrt1ml3v")  # res://core/combat/enemy_turn.gd


var failures: PackedStringArray = []
var _saved_tools: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	_saved_tools = RunManager.tool_inventory.duplicate()
	await test_queued_tool_with_dead_target_releases_input()
	await test_tools_refused_outside_player_turn()
	await test_winning_card_stops_its_remaining_effects()
	await test_enemy_attack_hits_the_real_player()
	await test_two_full_rounds_on_the_real_battle()
	RunManager.tool_inventory.assign(_saved_tools)
	if failures.is_empty():
		print("[OK] combat flow regressions passed")
		get_tree().quit(0)
		return
	push_error("combat flow regressions failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _battle() -> Node:
	var battle = BATTLE_SCENE.instantiate()
	add_child(battle)
	for _i in range(4):
		await get_tree().process_frame
	return battle


func _free(battle: Node) -> void:
	battle.queue_free()
	await get_tree().process_frame


func test_queued_tool_with_dead_target_releases_input() -> void:
	var battle = await _battle()
	RunManager.tool_inventory.assign(["base:frag_grenade"])
	var enemy: Node = battle.enemy_container.get_child(0)
	# A card still resolving holds the queue; it kills the tool's target.
	battle.combat.action_queue.enqueue(
		"slow_card",
		func() -> void:
			await get_tree().create_timer(0.05).timeout
			enemy.creature.apply_damage(99999)
			await get_tree().create_timer(0.05).timeout
	)
	battle.call("_begin_tool_targeting", 0, "base:frag_grenade", RunManager.get_tool_data("base:frag_grenade"))
	battle.call("_confirm_tool_targeting", enemy)
	await battle.combat.action_queue.drained
	_expect(not battle.get("_tool_resolving"), "tool input is released after its target died in the queue")
	_expect(RunManager.tool_inventory == ["base:frag_grenade"], "a tool whose target died is not consumed")
	await _free(battle)


func test_tools_refused_outside_player_turn() -> void:
	var battle = await _battle()
	RunManager.tool_inventory.assign(["base:energy_cell"])
	battle.use_tool(0)
	await get_tree().process_frame
	var opened: Node = battle.find_child("ToolUseConfirm", true, false)
	_expect(opened != null, "precondition: tools open a confirmation on the player's turn")
	if opened:
		opened.queue_free()
		await get_tree().process_frame
	battle.combat.state.is_player_turn = false
	battle.use_tool(0)
	await get_tree().process_frame
	_expect(battle.find_child("ToolUseConfirm", true, false) == null, "no tool confirmation during the enemy turn")
	battle.combat.state.is_player_turn = true
	battle.combat.set("_ending_turn", true)
	battle.use_tool(0)
	await get_tree().process_frame
	_expect(battle.find_child("ToolUseConfirm", true, false) == null, "no tool confirmation after End Turn")
	battle.combat.set("_ending_turn", false)
	await _free(battle)


func test_winning_card_stops_its_remaining_effects() -> void:
	var battle = await _battle()
	for extra in battle.enemy_container.get_children().slice(1):
		extra.creature.removed = true
		extra.free()
	var enemy: Node = battle.enemy_container.get_child(0)
	var card = CARD_INSTANCE.make("test:finisher", {
		"name": "test_finisher",
		"type": "attack",
		"effects": [{"type": "deal_damage", "amount": 99999, "no_str": true}, {"type": "gain_energy", "amount": 5}],
	})
	var energy_before: int = battle.player.energy
	await battle.combat.resolve_card_effect(card, enemy.creature)
	_expect(battle.is_game_over, "killing the last enemy wins the fight")
	_expect(battle.player.energy == energy_before, "the winning card's later effects do not run (energy %d → %d)" % [energy_before, battle.player.energy])
	await _free(battle)


## The real PlayerEntity has no `is_boss`; the hit chain must not assume it.
func test_enemy_attack_hits_the_real_player() -> void:
	var battle = await _battle()
	var enemy: Node = battle.enemy_container.get_child(0)
	battle.player.block = 0
	var hp_before: int = battle.player.health
	await ENEMY_TURN.execute_action(battle.combat, enemy.creature, {"type": "attack", "amount": 3})
	_expect(battle.player.health < hp_before, "an enemy attack damages the real player (%d → %d)" % [hp_before, battle.player.health])
	await _free(battle)


## End-to-end on the real scene: play an attack, end the turn, let every enemy
## act, twice. Any script error in the enemy turn fails the runner.
func test_two_full_rounds_on_the_real_battle() -> void:
	Engine.time_scale = 4.0
	var battle = await _battle()
	for enemy in battle.enemy_container.get_children():
		enemy.health = 999
		enemy.max_health = 999
	battle.player.health = 999
	battle.player.max_health = 999
	for round_number in [2, 3]:
		var target: Node = battle.enemy_container.get_child(0)
		var shot = battle.hand_view.node_of(battle.combat.add_card_to_hand("base:strike"))
		await get_tree().process_frame
		battle.play_spell(shot, target)
		battle._on_end_round_button_pressed()
		var reached := await _wait_until(
			func() -> bool:
				return battle.combat.state.is_player_turn and battle.combat.state.current_round == round_number,
			30.0
		)
		_expect(reached, "round %d starts after the enemy turn" % round_number)
		await battle.combat.action_queue.drained if battle.combat.action_queue.is_busy() else get_tree().process_frame
	_expect(battle.player.health < 999, "enemies dealt damage to the real player during their turns")
	Engine.time_scale = 1.0
	await _free(battle)


func _wait_until(condition: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline:
			return false
		await get_tree().process_frame
	return true

extends Node

## Battle-flow regressions from the phase 1 review:
## - a queued enemy tool whose target dies first must not lock tool/card input;
## - tools are refused during the enemy turn and after End Turn;
## - a card that wins the fight stops running its remaining effects.

const BATTLE_SCENE = preload("uid://dnhj5pp3c1v2l")  # res://battle_scene/battle_scene.tscn


class FakeCard:
	extends Control
	var card_info: Dictionary = {}


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
	RunManager.tool_inventory.assign(["frag_grenade"])
	var enemy: Node = battle.enemy_container.get_child(0)
	# A card still resolving holds the queue; it kills the tool's target.
	battle.action_queue.enqueue(
		"slow_card",
		func() -> void:
			await get_tree().create_timer(0.05).timeout
			enemy.queue_free()
			await get_tree().create_timer(0.05).timeout
	)
	battle.call("_begin_tool_targeting", 0, "frag_grenade", RunManager.get_tool_data("frag_grenade"))
	battle.call("_confirm_tool_targeting", enemy)
	await battle.action_queue.drained
	_expect(not battle.get("_tool_resolving"), "tool input is released after its target died in the queue")
	_expect(RunManager.tool_inventory == ["frag_grenade"], "a tool whose target died is not consumed")
	await _free(battle)


func test_tools_refused_outside_player_turn() -> void:
	var battle = await _battle()
	RunManager.tool_inventory.assign(["energy_cell"])
	battle.use_tool(0)
	await get_tree().process_frame
	var opened: Node = battle.find_child("ToolUseConfirm", true, false)
	_expect(opened != null, "precondition: tools open a confirmation on the player's turn")
	if opened:
		opened.queue_free()
		await get_tree().process_frame
	battle.turn_manager.is_player_turn = false
	battle.use_tool(0)
	await get_tree().process_frame
	_expect(battle.find_child("ToolUseConfirm", true, false) == null, "no tool confirmation during the enemy turn")
	battle.turn_manager.is_player_turn = true
	battle.set("_ending_turn", true)
	battle.use_tool(0)
	await get_tree().process_frame
	_expect(battle.find_child("ToolUseConfirm", true, false) == null, "no tool confirmation after End Turn")
	battle.set("_ending_turn", false)
	await _free(battle)


func test_winning_card_stops_its_remaining_effects() -> void:
	var battle = await _battle()
	for extra in battle.enemy_container.get_children().slice(1):
		extra.free()
	var enemy: Node = battle.enemy_container.get_child(0)
	var card := FakeCard.new()
	card.card_info = {
		"name": "test_finisher",
		"type": "attack",
		"effects": [{"type": "deal_damage", "amount": 99999, "no_str": true}, {"type": "gain_energy", "amount": 5}],
	}
	add_child(card)
	var energy_before: int = battle.player.energy
	await battle.combat_engine.resolve_card_effect(card, enemy, battle.player)
	for _i in range(3):  # victory is declared a frame after the last death
		await get_tree().process_frame
	_expect(battle.is_game_over, "killing the last enemy wins the fight")
	_expect(battle.player.energy == energy_before, "the winning card's later effects do not run (energy %d → %d)" % [energy_before, battle.player.energy])
	card.free()
	await _free(battle)

extends Node

## Contract for the shared hit chain and its reactions: every card damage type
## gets equipment-set bonuses and on-hit effects; non-card damage does not;
## tools resolve at their printed number; an Attack card counts once toward
## "attacks played" however many Replay passes it has.

const FAKE_BATTLE = preload("uid://j25pi73kmisn")  # res://tests/support/fake_battle.gd
const EQUIPMENT_SET_SYSTEM = preload("uid://b3s8io84xovx7")  # res://battle_scene/equipment_set_system.gd
const COMBAT_SOURCE = preload("uid://jgs131055xrk")  # res://core/combat/combat_source.gd
const CARD_DIR := "res://battle_scene/card_info/player/"


class FakeCard:
	extends Control
	var card_info: Dictionary = {}


var failures: PackedStringArray = []
var battle


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	Engine.time_scale = 20.0
	_fresh()
	await test_final_salvo_gets_set_bonus_and_on_hit()
	_fresh()
	await test_kinetic_rebound_gets_set_bonus_and_on_hit()
	_fresh()
	await test_relic_damage_triggers_no_on_hit()
	_fresh()
	await test_tool_damage_is_fixed()
	_fresh()
	await test_replayed_attack_counts_once()
	_fresh()
	await test_overload_from_attack_card_triggers_on_hit()
	Engine.time_scale = 1.0
	if failures.is_empty():
		print("[OK] combat hooks contract passed")
		get_tree().quit(0)
		return
	push_error("combat hooks contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _fresh() -> void:
	if battle and is_instance_valid(battle):
		battle.free()
	battle = FAKE_BATTLE.new()
	add_child(battle)
	var sets = EQUIPMENT_SET_SYSTEM.new()
	sets.setup(battle)
	# The active tiers normally come from equipped items; set them directly.
	sets._active_effects.clear()
	sets._active_effects.append({"type": "attack_damage_bonus", "amount": 2, "set_id": "test"})
	sets._active_effects.append({"type": "attack_apply_status", "status": "weak", "stacks": 1, "set_id": "test"})
	battle.equipment_set_system = sets
	battle.setup()


func _card(card_id: String) -> FakeCard:
	var card := FakeCard.new()
	card.card_info = JSON.parse_string(FileAccess.get_file_as_string(CARD_DIR + card_id + ".json"))
	add_child(card)
	return card


func _play(card: FakeCard, target: Node) -> void:
	await battle.combat_engine.resolve_card_effect(card, target, battle.player)
	card.queue_free()


func test_final_salvo_gets_set_bonus_and_on_hit() -> void:
	var enemy = battle.add_enemy()
	battle.turn_manager.attacks_played_this_combat = 3
	await _play(_card("cascade"), enemy)
	_expect(enemy.damage_received == 10, "Final Salvo: 5 + 3 attacks + set 2 = 10 (got %d)" % enemy.damage_received)
	_expect(enemy.get_status_stacks("weak") == 1, "Final Salvo applies the set's on-hit Weak")


func test_kinetic_rebound_gets_set_bonus_and_on_hit() -> void:
	var enemy = battle.add_enemy()
	await _play(_card("rebar_wave"), enemy)
	_expect(enemy.damage_received == 8, "Kinetic Rebound: Block 6 + set 2 = 8 (got %d)" % enemy.damage_received)
	_expect(enemy.get_status_stacks("weak") == 1, "Kinetic Rebound applies the set's on-hit Weak")


func test_relic_damage_triggers_no_on_hit() -> void:
	var enemy = battle.add_enemy()
	var relic = COMBAT_SOURCE.make("relic", "player", battle.player, null, "cracked_battery")
	await battle.combat_commands.damage(relic, [enemy], 1, 0)
	_expect(enemy.damage_received == 1, "relic damage is its printed number")
	_expect(enemy.get_status_stacks("weak") == 0, "relic damage triggers no on-hit effect")


func test_tool_damage_is_fixed() -> void:
	var enemy = battle.add_enemy()
	enemy.add_status("vulnerable", 1)
	battle.player.strength = 3
	var tool = COMBAT_SOURCE.make("tool", "player", battle.player, null, "frag_grenade")
	await battle.combat_engine.execute_effect({"type": "deal_damage", "amount": 10}, enemy, tool)
	_expect(enemy.damage_received == 10, "tool damage ignores STR and Vulnerable (got %d)" % enemy.damage_received)
	_expect(enemy.get_status_stacks("weak") == 0, "tool damage triggers no on-hit effect")


func test_replayed_attack_counts_once() -> void:
	var enemy = battle.add_enemy()
	var card := FakeCard.new()
	card.card_info = {"name": "test_shot", "type": "attack", "replay": 1, "effects": [{"type": "deal_damage", "amount": 1}]}
	add_child(card)
	await _play(card, enemy)
	_expect(enemy.hits.size() == 2, "Replay 1 hits twice")
	_expect(battle.turn_manager.attacks_played_this_turn == 1, "one Attack played this turn (got %d)" % battle.turn_manager.attacks_played_this_turn)
	_expect(battle.turn_manager.attacks_played_this_combat == 1, "one Attack played this combat")


func test_overload_from_attack_card_triggers_on_hit() -> void:
	var first = battle.add_enemy()
	var second = battle.add_enemy()
	first.add_status("short_circuit", 4)
	second.add_status("short_circuit", 3)
	var card := FakeCard.new()
	card.card_info = {"name": "test_overload", "type": "attack", "effects": [{"type": "overload"}]}
	add_child(card)
	await _play(card, null)
	_expect(first.damage_received == 4 and second.damage_received == 3, "Overload discharges stored charge unmodified")
	_expect(first.get_status_stacks("weak") == 1 and second.get_status_stacks("weak") == 1, "card-sourced Overload hits trigger on-hit effects")

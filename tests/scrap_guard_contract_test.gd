extends Node

const STATUS_SYSTEM = preload("res://battle_scene/status_effect_system.gd")
const PLAY_CARD = preload("res://battle_scene/play_card.gd")

const CARD_DIR := "res://battle_scene/card_info/player/"

var failures: PackedStringArray = []


class FakePlayer:
	extends Node
	var status_system = STATUS_SYSTEM.new()

	func add_status(status: String, stacks: int) -> void:
		status_system.add_status(status, stacks, self)

	func get_status_stacks(status: String) -> int:
		return status_system.get_stacks(status)


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	_test_guard_curve()
	_test_reactive_plating()
	_test_kinetic_rebound()
	if failures.is_empty():
		print("[OK] Scrap Guard contract passed")
		get_tree().quit(0)
		return
	push_error("Scrap Guard contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _test_guard_curve() -> void:
	var defend := _load_card("defend")
	_expect(_effect_value(defend, "gain_block", "amount") == 5, "starter Defend gains 5 Block")
	var counter := _load_card("siphon")
	_expect(_effect_value(counter, "deal_damage", "amount") == 3, "Scrap Counter deals 3")
	_expect(_effect_value(counter, "gain_block", "amount") == 3, "Scrap Counter blocks 3")
	var vent := _load_card("vent_plating")
	_expect(str(vent.get("rarity", "")) == "uncommon", "Block plus draw is not common filler")
	var patch := _load_card("tape_patch")
	_expect(int(patch.get("cost", -1)) == 0, "Quick Patch is a zero-cost emergency tool")
	_expect(_has_effect(patch, "exhaust_self"), "Quick Patch does not loop forever")


func _test_reactive_plating() -> void:
	var plating := _load_card("venom_coat")
	_expect(str(plating.get("type", "")) == "ability", "Reactive Plating is an Ability")
	_expect(str(plating.get("rarity", "")) == "uncommon", "Reactive Plating is uncommon")
	_expect(
		_effect_status(plating, "apply_status_self") == "reactive_plating",
		"duplicate Thorns card became the Block-to-Thorns power"
	)
	var player := FakePlayer.new()
	add_child(player)
	player.add_status("reactive_plating", 2)
	player.status_system.on_turn_start(player)
	player.status_system.on_turn_end(player)
	_expect(player.get_status_stacks("reactive_plating") == 2, "Reactive Plating persists")
	player.free()


func _test_kinetic_rebound() -> void:
	var rebound := _load_card("rebar_wave")
	_expect(str(rebound.get("rarity", "")) == "rare", "Block payoff occupies the rare slot")
	_expect(int(rebound.get("cost", -1)) == 2, "Kinetic Rebound costs 2")
	var effects: Array = rebound.get("effects", [])
	_expect(effects.size() == 2, "Kinetic Rebound has exactly setup and payoff")
	if effects.size() == 2:
		_expect(str(effects[0].get("type", "")) == "gain_block", "Kinetic Rebound blocks first")
		_expect(
			str(effects[1].get("type", "")) == "deal_damage_block_mult",
			"Kinetic Rebound then spends the Block total as damage"
		)
	_expect(PLAY_CARD.data_requires_enemy_target(rebound), "Kinetic Rebound requests a target")


func _load_card(card_id: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CARD_DIR + card_id + ".json"))
	_expect(typeof(parsed) == TYPE_DICTIONARY, "card JSON parses: %s" % card_id)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _effect_value(card: Dictionary, effect_type: String, field: String) -> int:
	for effect in card.get("effects", []):
		if str(effect.get("type", "")) == effect_type:
			return int(effect.get(field, -1))
	return -1


func _effect_status(card: Dictionary, effect_type: String) -> String:
	for effect in card.get("effects", []):
		if str(effect.get("type", "")) == effect_type:
			return str(effect.get("status", ""))
	return ""


func _has_effect(card: Dictionary, effect_type: String) -> bool:
	for effect in card.get("effects", []):
		if str(effect.get("type", "")) == effect_type:
			return true
	return false

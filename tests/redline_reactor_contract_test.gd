extends Node

const STATUS_SYSTEM = preload("res://battle_scene/status_effect_system.gd")
const PLAY_CARD = preload("res://battle_scene/play_card.gd")
const COMBAT_ENGINE = preload("res://battle_scene/combat_engine.gd")

const CARD_DIR := "res://battle_scene/card_info/player/"
const REDLINE_IDS: Array[String] = [
	"breach_charge",
	"hot_swap",
	"hemo_drive",
	"siphon_valve",
	"bulkhead_bleed",
	"combat_stim",
	"data_dump",
	"focusing_blow",
	"adrenaline",
	"last_breath",
]

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
	_test_heat_vocabulary()
	_test_builders()
	_test_protocol_and_exhaust_support()
	_test_vent_payoffs()
	_test_no_player_facing_blood_language()
	if failures.is_empty():
		print("[OK] Redline Reactor contract passed")
		get_tree().quit(0)
		return
	push_error("Redline Reactor contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _test_heat_vocabulary() -> void:
	var player := FakePlayer.new()
	add_child(player)
	player.add_status("heat", 7)
	player.add_status("redline_protocol", 1)
	player.status_system.on_turn_start(player)
	player.status_system.on_turn_end(player)
	_expect(player.get_status_stacks("heat") == 7, "Heat persists until Vent")
	_expect(player.get_status_stacks("redline_protocol") == 1, "Redline Protocol persists")
	var engine = COMBAT_ENGINE.new()
	add_child(engine)
	_expect(engine._consume_heat(player) == 7, "Vent consumes the entire Heat pool atomically")
	_expect(player.get_status_stacks("heat") == 0, "Heat is empty after Vent")
	engine.free()
	player.free()


func _test_builders() -> void:
	var burst := _load_card("breach_charge")
	_expect(_effect_value(burst, "lose_hp", "amount") == 1, "Reactor Burst costs 1 HP")
	_expect(_status_stacks(burst, "heat") == 2, "Reactor Burst builds 2 Heat")
	_expect(_effect_value(burst, "deal_damage_all", "amount") == 6, "Reactor Burst has fixed AoE")

	var drive := _load_card("hemo_drive")
	_expect(_effect_value(drive, "lose_hp", "amount") == 2, "Redline Drive costs 2 HP")
	_expect(_status_stacks(drive, "heat") == 4, "Redline Drive builds 4 Heat")
	_expect(_effect_value(drive, "deal_damage", "amount") == 9, "Redline Drive is an efficient hit")

	var siphon := _load_card("siphon_valve")
	_expect(_status_stacks(siphon, "heat") == 5, "Fuel Siphon is the large Heat builder")
	_expect(_effect_value(siphon, "gain_energy", "amount") == 2, "Fuel Siphon gains 2 Energy")
	_expect(_has_effect(siphon, "exhaust_self"), "Fuel Siphon Exhausts")


func _test_protocol_and_exhaust_support() -> void:
	var protocol := _load_card("combat_stim")
	_expect(str(protocol.get("type", "")) == "ability", "Redline Protocol is an Ability")
	_expect(_status_stacks(protocol, "redline_protocol") == 1, "Protocol applies its persistent status")
	for card_id in ["data_dump", "adrenaline"]:
		_expect(_has_effect(_load_card(card_id), "exhaust_self"), "%s feeds the protocol" % card_id)


func _test_vent_payoffs() -> void:
	var release := _load_card("focusing_blow")
	_expect(_effect_value(release, "vent_heat_for_damage", "base") == 3, "Thermal Release has a floor")
	_expect(_effect_value(release, "vent_heat_for_damage", "mult") == 2, "Thermal Release scales 2 per Heat")
	_expect(PLAY_CARD.data_requires_enemy_target(release), "Thermal Release requests a target")

	var vent := _load_card("last_breath")
	_expect(_effect_value(vent, "vent_heat_for_block", "mult") == 2, "Emergency Vent scales 2 Block per Heat")
	_expect(_effect_value(vent, "draw_cards", "amount") == 1, "Emergency Vent cycles after releasing pressure")
	_expect(_has_effect(vent, "exhaust_self"), "Emergency Vent Exhausts")
	_expect(not PLAY_CARD.data_requires_enemy_target(vent), "Emergency Vent is self-targeted")


func _test_no_player_facing_blood_language() -> void:
	for card_id in REDLINE_IDS:
		var card := _load_card(card_id)
		var copy := (str(card.get("title", "")) + " " + str(card.get("description", ""))).to_lower()
		_expect("bleed" not in copy and "blood" not in copy, "%s has robot-first vocabulary" % card_id)


func _load_card(card_id: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CARD_DIR + card_id + ".json"))
	_expect(typeof(parsed) == TYPE_DICTIONARY, "card JSON parses: %s" % card_id)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _effect_value(card: Dictionary, effect_type: String, field: String) -> int:
	for effect in card.get("effects", []):
		if str(effect.get("type", "")) == effect_type:
			return int(effect.get(field, -1))
	return -1


func _status_stacks(card: Dictionary, status: String) -> int:
	for effect in card.get("effects", []):
		if (
			str(effect.get("type", "")) == "apply_status_self"
			and str(effect.get("status", "")) == status
		):
			return int(effect.get("stacks", -1))
	return -1


func _has_effect(card: Dictionary, effect_type: String) -> bool:
	for effect in card.get("effects", []):
		if str(effect.get("type", "")) == effect_type:
			return true
	return false

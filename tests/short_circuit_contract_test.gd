extends Node

const STATUS_SYSTEM = preload("res://battle_scene/status_effect_system.gd")
const COMBAT_ENGINE = preload("res://battle_scene/combat_engine.gd")
const PLAY_CARD = preload("res://battle_scene/play_card.gd")

const CARD_DIR := "res://battle_scene/card_info/player/"

var failures: PackedStringArray = []


class FakeEntity:
	extends Node
	var status_system = STATUS_SYSTEM.new()
	var damage_taken := 0

	func add_status(status: String, stacks: int) -> void:
		status_system.add_status(status, stacks, self)

	func get_status_stacks(status: String) -> int:
		return status_system.get_stacks(status)

	func take_damage(amount: int, _silent: bool = false, _tags: Dictionary = {}) -> void:
		damage_taken += amount


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	_test_status_timing()
	_test_overload_consumes_charge()
	_test_card_package_numbers()
	_test_data_driven_targeting()
	_test_active_data_has_no_bleed_mechanic()
	if failures.is_empty():
		print("[OK] Short Circuit contract passed")
		get_tree().quit(0)
		return
	push_error("Short Circuit contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _test_status_timing() -> void:
	var entity := FakeEntity.new()
	add_child(entity)
	entity.add_status("short_circuit", 8)
	entity.status_system.on_turn_start(entity)
	_expect(entity.damage_taken == 0, "Short Circuit deals no automatic turn-start damage")
	_expect(entity.get_status_stacks("short_circuit") == 8, "Short Circuit does not decay")
	entity.add_status("burn", 6)
	entity.status_system.on_turn_start(entity)
	_expect(entity.damage_taken == 6, "Burn preserves the enemy damage-over-time role")
	_expect(entity.get_status_stacks("burn") == 3, "Burn halves after triggering")
	entity.free()


func _test_overload_consumes_charge() -> void:
	var entity := FakeEntity.new()
	add_child(entity)
	entity.add_status("short_circuit", 9)
	var engine = COMBAT_ENGINE.new()
	add_child(engine)
	var consumed := int(engine._consume_short_circuit(entity))
	_expect(consumed == 9, "Overload reads every stored Short Circuit stack")
	_expect(entity.get_status_stacks("short_circuit") == 0, "Overload removes stored charge")
	var result: Dictionary = engine._short_circuit_overload(consumed, null)
	_expect(int(result.get("damage", 0)) == 9, "Base Overload damage equals stacks consumed")
	_expect(not bool(result.get("critical", true)), "Overload cannot Crit without the power")
	engine.free()
	entity.free()


func _test_card_package_numbers() -> void:
	var round_card := _load_card("recoil_shot")
	_expect(_effect_amount(round_card, "deal_damage") == 3, "Short-Circuit Round keeps useful immediate damage")
	_expect(
		_effect_amount(round_card, "apply_short_circuit_scaled") == 6,
		"common hybrid applies 6 delayed stacks"
	)
	var diagnosis := _load_card("dissect")
	_expect(str(diagnosis.get("type", "")) == "skill", "Circuit Diagnosis is a targeted Skill")
	_expect(
		_effect_amount(diagnosis, "apply_short_circuit_scaled") == 8,
		"uncommon pure builder starts at 8 delayed stacks"
	)
	var tear := _load_card("bone_breaker")
	_expect(
		_effect_amount(tear, "apply_short_circuit_scaled") == 10,
		"rare two-cost builder starts at 10 delayed stacks"
	)
	var overload := _load_card("limit_break")
	_expect(_has_effect(overload, "double_target_short_circuit"), "Overload doubles stored charge")
	_expect(_has_effect(overload, "overload_short_circuit"), "Overload resolves after doubling")
	var arc_flash := _load_card("arc_flash")
	_expect(_has_effect(arc_flash, "overload_short_circuit_all"), "Arc Flash is the common Overload outlet")
	_expect(str(arc_flash.get("type", "")) == "skill", "Arc Flash is a technical Skill, not another Attack")


func _test_data_driven_targeting() -> void:
	_expect(
		PLAY_CARD.data_requires_enemy_target(_load_card("limit_break")),
		"targeted Overload Skill requests an enemy target"
	)
	_expect(
		not PLAY_CARD.data_requires_enemy_target(_load_card("arc_flash")),
		"all-enemy Overload Attack does not request a single target"
	)
	_expect(
		PLAY_CARD.data_requires_enemy_target(_load_card("corrode")),
		"enemy-debuff Skill requests an enemy target"
	)
	_expect(
		not PLAY_CARD.data_requires_enemy_target(_load_card("defend")),
		"self-only Block Skill remains untargeted"
	)


func _test_active_data_has_no_bleed_mechanic() -> void:
	for folder in [
		"res://battle_scene/card_info/player/",
		"res://battle_scene/card_info/enemy/",
		"res://run_system/data/relics/",
		"res://run_system/data/tools/",
		"res://run_system/data/equipment_sets/",
	]:
		for file_name in DirAccess.get_files_at(folder):
			if not file_name.ends_with(".json"):
				continue
			var source := FileAccess.get_file_as_string(folder + file_name)
			_expect(
				not source.contains('"status": "bleed"'),
				"active data does not apply Bleed: %s" % file_name
			)
			_expect(
				not source.contains('"type": "apply_bleed_scaled"'),
				"active data does not use the old Bleed scaler: %s" % file_name
			)
			_expect(
				not source.contains('"type": "detonate_short_circuit"'),
				"active data uses Overload rather than the old detonation effect: %s" % file_name
			)


func _load_card(card_id: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CARD_DIR + card_id + ".json"))
	_expect(typeof(parsed) == TYPE_DICTIONARY, "card JSON parses: %s" % card_id)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _effect_amount(card: Dictionary, effect_type: String) -> int:
	for effect in card.get("effects", []):
		if str(effect.get("type", "")) == effect_type:
			return int(effect.get("amount", 0))
	return -1


func _has_effect(card: Dictionary, effect_type: String) -> bool:
	for effect in card.get("effects", []):
		if str(effect.get("type", "")) == effect_type:
			return true
	return false

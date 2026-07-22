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
	var health := 30
	var block := 0

	func add_status(status: String, stacks: int) -> void:
		status_system.add_status(status, stacks, self)

	func get_status_stacks(status: String) -> int:
		return status_system.get_stacks(status)

	func take_damage(amount: int, _silent: bool = false, _tags: Dictionary = {}) -> void:
		var hp_damage := maxi(0, amount - block)
		block = maxi(0, block - amount)
		hp_damage = mini(health, hp_damage)
		health -= hp_damage
		damage_taken += hp_damage


class FakePlayer:
	extends Node
	var status_system = STATUS_SYSTEM.new()
	var block := 0

	func add_status(status: String, stacks: int) -> void:
		status_system.add_status(status, stacks, self)

	func get_status_stacks(status: String) -> int:
		return status_system.get_stacks(status)

	func add_block(amount: int) -> void:
		block += amount


var enemy_container := Node.new()
var relic_effect_system = null
var equipment_set_system = null
var is_game_over := false


func _ready() -> void:
	add_child(enemy_container)
	call_deferred("_run")


func show_notification(_message: String, _color: Color) -> void:
	pass


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	_test_status_timing()
	_test_overload_consumes_charge()
	await _test_global_overload_and_charge_sink()
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


func _test_global_overload_and_charge_sink() -> void:
	var first := FakeEntity.new()
	first.health = 20
	first.block = 2
	first.add_status("short_circuit", 5)
	enemy_container.add_child(first)
	var second := FakeEntity.new()
	second.health = 4
	second.add_status("short_circuit", 7)
	enemy_container.add_child(second)
	var player := FakePlayer.new()
	add_child(player)
	var engine = COMBAT_ENGINE.new()
	add_child(engine)
	await engine._apply_effect(
		{"type": "overload", "gain_block_equal_damage": true}, null, player
	)
	_expect(first.get_status_stacks("short_circuit") == 0, "Overload clears the first enemy")
	_expect(second.get_status_stacks("short_circuit") == 0, "Overload clears every enemy")
	_expect(first.damage_taken == 3, "Overload damage respects enemy Block")
	_expect(second.damage_taken == 4, "Overload damage cannot exceed remaining HP")
	_expect(player.block == 7, "Charge Sink gains Block equal to actual Overload damage")
	engine.free()
	player.free()
	first.free()
	second.free()


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
	var overload_effect := _find_effect(overload, "overload")
	_expect(not overload_effect.is_empty(), "Overload card uses the one shared Overload effect")
	_expect(int(overload_effect.get("charge_multiplier", 1)) == 2, "rare Overload doubles discharge damage")
	var arc_flash := _load_card("arc_flash")
	_expect(_has_effect(arc_flash, "overload"), "Arc Flash uses the shared global Overload effect")
	_expect(str(arc_flash.get("type", "")) == "skill", "Arc Flash is a technical Skill, not another Attack")
	var charge_sink_effect := _find_effect(_load_card("coagulate"), "overload")
	_expect(bool(charge_sink_effect.get("gain_block_equal_damage", false)), "Charge Sink converts Overload damage into Block")


func _test_data_driven_targeting() -> void:
	_expect(
		not PLAY_CARD.data_requires_enemy_target(_load_card("limit_break")),
		"global Overload never requests a single enemy target"
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
	return not _find_effect(card, effect_type).is_empty()


func _find_effect(card: Dictionary, effect_type: String) -> Dictionary:
	for effect in card.get("effects", []):
		if str(effect.get("type", "")) == effect_type:
			return effect
	return {}

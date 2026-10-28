extends Node

const STATUS_SYSTEM = preload("uid://cq4eulp4ci8is")  # res://core/combat/status_effects.gd
const FAKE_BATTLE = preload("uid://j25pi73kmisn")  # res://tests/support/fake_battle.gd
const COMBAT_EFFECTS = preload("uid://do16of5onpg33")  # res://core/combat/combat_effects.gd
const COMBAT_SOURCE = preload("uid://jgs131055xrk")  # res://core/combat/combat_source.gd
const PLAY_CARD = preload("uid://d4f71g73780ld")  # res://ui/battle/play_card.gd

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd

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


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	_test_status_timing()
	await _test_overload_consumes_charge()
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
	var battle = FAKE_BATTLE.new()
	add_child(battle)
	battle.setup()
	battle.player.block = 0
	var first = battle.add_enemy(20)
	first.block = 2
	first.add_status("short_circuit", 5)
	var second = battle.add_enemy(4)
	second.add_status("short_circuit", 7)
	var source = COMBAT_SOURCE.make("card", "player", battle.player)
	await battle.combat_engine.execute_effect(
		{"type": "overload", "gain_block_equal_damage": true}, null, source
	)
	_expect(first.get_status_stacks("short_circuit") == 0, "Overload clears the first enemy")
	_expect(second.get_status_stacks("short_circuit") == 0, "Overload clears every enemy")
	_expect(first.hp_lost == 3, "Overload damage respects enemy Block")
	_expect(second.hp_lost == 4, "Overload damage cannot exceed remaining HP")
	_expect(battle.player.block == 7, "Charge Sink gains Block equal to actual Overload damage")
	battle.free()


func _test_overload_consumes_charge() -> void:
	var battle = FAKE_BATTLE.new()
	add_child(battle)
	battle.setup()
	var entity = battle.add_enemy()
	entity.add_status("short_circuit", 9)
	var consumed := COMBAT_EFFECTS.consume_short_circuit(entity)
	_expect(consumed == 9, "Overload reads every stored Short Circuit stack")
	_expect(entity.get_status_stacks("short_circuit") == 0, "Overload removes stored charge")
	var source = COMBAT_SOURCE.make("card", "player", battle.player)
	var results: Array = await battle.combat_commands.damage(source, [entity], consumed, 0, null, 0, {"overload": true})
	_expect(results.size() == 1 and results[0].amount == 9, "Base Overload damage equals stacks consumed")
	_expect(results.size() == 1 and not results[0].critical, "Overload cannot Crit without the power")
	battle.free()


func _test_card_package_numbers() -> void:
	var round_card := _load_card("base:recoil_shot")
	_expect(_effect_amount(round_card, "deal_damage") == 3, "Short-Circuit Round keeps useful immediate damage")
	_expect(
		_effect_amount(round_card, "apply_short_circuit_scaled") == 6,
		"common hybrid applies 6 delayed stacks"
	)
	var diagnosis := _load_card("base:dissect")
	_expect(str(diagnosis.get("type", "")) == "skill", "Circuit Diagnosis is a targeted Skill")
	_expect(
		_effect_amount(diagnosis, "apply_short_circuit_scaled") == 8,
		"uncommon pure builder starts at 8 delayed stacks"
	)
	var tear := _load_card("base:bone_breaker")
	_expect(
		_effect_amount(tear, "apply_short_circuit_scaled") == 10,
		"rare two-cost builder starts at 10 delayed stacks"
	)
	var overload := _load_card("base:limit_break")
	var overload_effect := _find_effect(overload, "overload")
	_expect(not overload_effect.is_empty(), "Overload card uses the one shared Overload effect")
	_expect(int(overload_effect.get("charge_multiplier", 1)) == 2, "rare Overload doubles discharge damage")
	var arc_flash := _load_card("base:arc_flash")
	_expect(_has_effect(arc_flash, "overload"), "Arc Flash uses the shared global Overload effect")
	_expect(str(arc_flash.get("type", "")) == "skill", "Arc Flash is a technical Skill, not another Attack")
	var charge_sink_effect := _find_effect(_load_card("base:coagulate"), "overload")
	_expect(bool(charge_sink_effect.get("gain_block_equal_damage", false)), "Charge Sink converts Overload damage into Block")


func _test_data_driven_targeting() -> void:
	_expect(
		not PLAY_CARD.data_requires_enemy_target(_load_card("base:limit_break")),
		"global Overload never requests a single enemy target"
	)
	_expect(
		not PLAY_CARD.data_requires_enemy_target(_load_card("base:arc_flash")),
		"all-enemy Overload Attack does not request a single target"
	)
	_expect(
		PLAY_CARD.data_requires_enemy_target(_load_card("base:corrode")),
		"enemy-debuff Skill requests an enemy target"
	)
	_expect(
		not PLAY_CARD.data_requires_enemy_target(_load_card("base:defend")),
		"self-only Block Skill remains untargeted"
	)


func _test_active_data_has_no_bleed_mechanic() -> void:
	for category in ["card", "monster", "relic", "tool", "equipment_set"]:
		for model in MODEL_DB.models(category):
			var file_name: String = model.id
			var source := JSON.stringify(model.data, "", false).replace('":"', '": "')
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
	var data := MODEL_DB.mutable("card", card_id)
	_expect(not data.is_empty(), "card is registered: %s" % card_id)
	return data


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

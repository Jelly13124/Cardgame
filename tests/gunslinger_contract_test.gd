extends Node

const STATUS_SYSTEM = preload("res://battle_scene/status_effect_system.gd")
const COMBAT_ENGINE = preload("res://battle_scene/combat_engine.gd")

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
	_test_loaded_resource()
	_test_starter_curve()
	_test_weak_rule()
	_test_reload_package()
	_test_strength_finishers()
	_test_crit_loop_data()
	if failures.is_empty():
		print("[OK] Gunslinger contract passed")
		get_tree().quit(0)
		return
	push_error("Gunslinger contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _test_loaded_resource() -> void:
	var player := FakePlayer.new()
	add_child(player)
	player.add_status("loaded", 4)
	player.status_system.on_turn_start(player)
	player.status_system.on_turn_end(player)
	_expect(player.get_status_stacks("loaded") == 4, "Loaded persists until Bill fires")
	var engine = COMBAT_ENGINE.new()
	add_child(engine)
	_expect(engine._consume_loaded_bonus(player) == 4, "next damage effect receives all Loaded")
	_expect(player.get_status_stacks("loaded") == 0, "firing removes all Loaded")
	_expect(engine._consume_loaded_bonus(player) == 0, "Replay cannot spend the same Loaded twice")
	engine.free()
	player.free()


func _test_starter_curve() -> void:
	var shoot := _load_card("strike")
	_expect(str(shoot.get("title", "")) == "Shoot", "starter Strike is now Shoot")
	_expect(_effect_value(shoot, "deal_damage", "amount") == 3, "Shoot deals 3 base damage")
	var weak_shot := _load_card("weak_strike")
	_expect(
		_effect_value(weak_shot, "deal_damage", "amount") == 4,
		"Weakening Shot deals 4 base damage"
	)
	_expect(
		_effect_value(weak_shot, "apply_status", "stacks") == 1,
		"Weakening Shot applies one Weak"
	)
	var piston_jab := _load_card("piston_jab")
	_expect(int(piston_jab.get("cost", -1)) == 0, "Piston Jab is the free fixed-damage jab")
	_expect(_effect_value(piston_jab, "deal_damage", "amount") == 4, "Piston Jab deals 4 fixed damage")
	_expect(
		_effect_value(piston_jab.get("upgrade", {}), "deal_damage", "amount") == 6,
		"Upgraded Piston Jab deals 6 fixed damage"
	)


func _test_weak_rule() -> void:
	var entity := FakePlayer.new()
	add_child(entity)
	entity.add_status("weak", 2)
	_expect(
		is_equal_approx(entity.status_system.get_outgoing_multiplier(), 0.5),
		"Weak reduces outgoing attack damage by 50%"
	)
	entity.status_system.on_turn_end(entity)
	_expect(
		is_equal_approx(entity.status_system.get_outgoing_multiplier(), 0.5),
		"additional Weak stacks extend duration instead of compounding the penalty"
	)
	entity.status_system.on_turn_end(entity)
	_expect(
		is_equal_approx(entity.status_system.get_outgoing_multiplier(), 1.0),
		"Weak ends after its final duration stack decays"
	)
	entity.free()


func _test_reload_package() -> void:
	var reload := _load_card("reload")
	_expect(_effect_value(reload, "apply_status_self", "stacks") == 2, "Reload grants 2 Loaded")
	_expect(_has_effect(reload, "draw_cards"), "Reload cycles one card")
	_expect(_has_effect(reload, "restore_attack_allowance"), "Reload still refreshes clip ammo")
	_expect(_has_effect(reload, "exhaust_self"), "Reload remains temporary")
	var quickdraw := _load_card("chain_link")
	_expect(str(quickdraw.get("title", "")) == "Quickdraw", "Chain Link is now Quickdraw")
	_expect(_effect_value(quickdraw, "deal_damage", "amount") == 4, "Quickdraw deals 4 base damage")
	_expect(_has_effect(quickdraw, "draw_cards"), "Quickdraw keeps the gun cycle moving")


func _test_strength_finishers() -> void:
	var charged := _load_card("charged_shot")
	_expect(_effect_value(charged, "deal_damage_str_mult", "base") == 6, "Charged Shot has a useful base")
	_expect(_effect_value(charged, "deal_damage_str_mult", "mult") == 2, "Charged Shot scales at 2x STR")
	var salvo := _load_card("cascade")
	_expect(str(salvo.get("title", "")) == "Final Salvo", "Cascade is now Final Salvo")
	_expect(_effect_value(salvo, "scale_damage_by_attacks", "base") == 5, "Final Salvo is live on turn one")
	_expect(_effect_value(salvo, "scale_damage_by_attacks", "per") == 1, "Final Salvo grows per prior Attack")


func _test_crit_loop_data() -> void:
	var deadeye := _load_card("lucky_streak")
	_expect(str(deadeye.get("title", "")) == "Deadeye", "Luck setup has a deterministic Crit identity")
	_expect(_effect_value(deadeye, "gain_luck", "amount") == 1, "Deadeye still grows Bill's Luck")
	_expect(_effect_value(deadeye, "apply_status_self", "stacks") == 1, "Deadeye guarantees the next Crit")
	var hot_streak := _load_card("hot_streak")
	_expect(_has_effect(hot_streak, "apply_status_self"), "Hot Streak remains a combat power")
	_expect(
		str(hot_streak.get("description", "")).contains("2 Loaded"),
		"Hot Streak feeds Crits back into Loaded"
	)
	var all_in := _load_card("all_in")
	_expect(
		not str(all_in.get("description", "")).contains("deal 0"),
		"All In no longer deletes non-Crit damage"
	)
	_expect(
		str(all_in.get("description", "")).contains("2 Loaded"),
		"All In turns non-Crits into setup"
	)


func _load_card(card_id: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CARD_DIR + card_id + ".json"))
	_expect(typeof(parsed) == TYPE_DICTIONARY, "card JSON parses: %s" % card_id)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _effect_value(card: Dictionary, effect_type: String, field: String) -> int:
	for effect in card.get("effects", []):
		if str(effect.get("type", "")) == effect_type:
			return int(effect.get(field, -1))
	return -1


func _has_effect(card: Dictionary, effect_type: String) -> bool:
	for effect in card.get("effects", []):
		if str(effect.get("type", "")) == effect_type:
			return true
	return false

extends Node

const CONTROLLER_PATH := "res://battle_scene/combat_feedback_controller.gd"
const BATTLE_SCENE_PATH := "res://battle_scene/battle_scene.gd"
const COMBAT_ENGINE_PATH := "res://battle_scene/combat_engine.gd"
const ENEMY_ENTITY_PATH := "res://battle_scene/enemy_entity.gd"
const PLAYER_PATH := "res://battle_scene/player.gd"
const ENEMY_AI_PATH := "res://battle_scene/enemy_ai.gd"
const EXPECTED_PROFILES := ["blocked", "heavy", "kill", "normal"]

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	await _test_reusable_feedback_controller()
	_test_damage_path_integration()

	if failures.is_empty():
		print("[OK] Combat feedback contract passed")
		get_tree().quit(0)
		return
	push_error("Combat feedback contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _test_reusable_feedback_controller() -> void:
	_expect(
		ResourceLoader.exists(CONTROLLER_PATH),
		"combat feedback has one reusable controller"
	)
	if not ResourceLoader.exists(CONTROLLER_PATH):
		return

	var controller_script := load(CONTROLLER_PATH) as Script
	_expect(controller_script != null, "combat feedback controller parses as a Script")
	if controller_script == null:
		return

	var constants := controller_script.get_script_constant_map()
	for constant_name in [
		"PROFILE_NORMAL", "PROFILE_BLOCKED", "PROFILE_HEAVY", "PROFILE_KILL"
	]:
		_expect(constants.has(constant_name), "controller exposes %s" % constant_name)

	var profiles: Dictionary = constants.get("PROFILES", {})
	var profile_names: Array = profiles.keys()
	profile_names.sort()
	_expect(
		profile_names == EXPECTED_PROFILES,
		"controller defines exactly normal, blocked, heavy, and kill profiles"
	)
	for profile_name in EXPECTED_PROFILES:
		var profile: Dictionary = profiles.get(profile_name, {})
		_expect(
			profile.has("hitstop_seconds"),
			"%s profile configures hitstop" % profile_name
		)
		_expect(
			profile.has("shake_intensity"),
			"%s profile configures camera shake" % profile_name
		)
		_expect(
			profile.has("damage_number_scale"),
			"%s profile configures damage-number emphasis" % profile_name
		)
		_expect(
			profile.has("reaction_strength"),
			"%s profile configures target reaction" % profile_name
		)
		_expect(
			profile.has("impact_size"),
			"%s profile configures local impact size" % profile_name
		)
	_expect(
		float(profiles["normal"]["shake_intensity"]) == 0.0
		and float(profiles["blocked"]["shake_intensity"]) == 0.0
		and float(profiles["heavy"]["shake_intensity"]) == 0.0,
		"ordinary, blocked, and heavy hits do not shake the whole battlefield"
	)
	_expect(
		float(profiles["kill"]["shake_intensity"]) > 0.0,
		"lethal feedback alone retains a restrained battlefield jolt"
	)
	_expect(
		float(profiles["normal"]["impact_size"]) < float(profiles["heavy"]["impact_size"])
		and float(profiles["heavy"]["impact_size"]) <= float(profiles["kill"]["impact_size"]),
		"impact size increases without introducing another feedback tier"
	)

	var controller = controller_script.new()
	_expect(controller is Node, "combat feedback controller is a reusable Node")
	if not controller is Node:
		if controller is RefCounted:
			controller = null
		return
	add_child(controller)

	_expect(controller.has_method("profile_for_hit"), "controller centralizes profile selection")
	_expect(controller.has_method("play_hit"), "controller exposes the ordered hit sequence")
	for hook_name in [
		"_play_hitstop", "_play_camera_shake", "_spawn_damage_number", "_play_target_reaction"
	]:
		_expect(controller.has_method(hook_name), "controller exposes %s hook" % hook_name)
	_expect(controller.has_signal("feedback_started"), "controller signals feedback start")
	_expect(controller.has_signal("health_applied"), "controller signals the HP-apply boundary")

	if controller.has_method("profile_for_hit"):
		_expect(
			controller.call("profile_for_hit", 5, 0, false, false, false) == "normal",
			"ordinary damage selects the normal profile"
		)
		_expect(
			controller.call("profile_for_hit", 0, 5, false, false, false) == "blocked",
			"fully absorbed damage selects the blocked profile"
		)
		var explicit_heavy = controller.call(
			"profile_for_hit", 12, 0, false, true, false
		)
		var critical = controller.call("profile_for_hit", 12, 0, false, false, true)
		_expect(explicit_heavy == "heavy", "explicit heavy damage selects the heavy profile")
		_expect(critical == explicit_heavy, "critical and heavy share the same feedback profile")
		_expect(
			controller.call("profile_for_hit", 99, 0, true, true, true) == "kill",
			"a lethal hit promotes every other hit type to the kill profile"
		)

	if (
		controller.has_method("play_hit")
		and controller.has_signal("feedback_started")
		and controller.has_signal("health_applied")
	):
		var order: Array[String] = []
		controller.connect("feedback_started", func(_profile: String) -> void: order.append("feedback"))
		controller.connect("health_applied", func(_profile: String) -> void: order.append("health_applied"))
		var target := Node2D.new()
		add_child(target)
		var apply_health := func() -> void: order.append("health_mutation")
		await controller.call(
			"play_hit", self, target, Vector2.ZERO, 5, 0, "normal", apply_health
		)
		_expect(
			order == ["feedback", "health_mutation", "health_applied"],
			"feedback begins before HP mutation and reports the apply boundary afterward"
		)
		target.queue_free()

	controller.queue_free()


func _test_damage_path_integration() -> void:
	var battle_source := FileAccess.get_file_as_string(BATTLE_SCENE_PATH)
	var engine_source := FileAccess.get_file_as_string(COMBAT_ENGINE_PATH)
	var enemy_source := FileAccess.get_file_as_string(ENEMY_ENTITY_PATH)
	var player_source := FileAccess.get_file_as_string(PLAYER_PATH)
	var enemy_ai_source := FileAccess.get_file_as_string(ENEMY_AI_PATH)

	_expect(
		engine_source.contains("feedback_tags"),
		"player-card damage builds explicit feedback tags"
	)
	_expect(
		engine_source.contains('"critical"') and engine_source.contains('"heavy"'),
		"player-card damage forwards both critical and explicit-heavy context"
	)
	_expect(
		engine_source.contains("await target.take_damage"),
		"player-card resolution waits for the ordered target feedback"
	)
	_expect(
		engine_source.contains("source_card")
		and not engine_source.contains("main.current_resolving_card")
		and not battle_source.contains("current_resolving_card"),
		"parallel cards carry their own equipment context through awaits"
	)

	for entity_contract in [
		[enemy_source, "enemy"],
		[player_source, "player"],
	]:
		var source: String = entity_contract[0]
		var label: String = entity_contract[1]
		_expect(
			source.contains("combat_feedback_controller.gd"),
			"%s damage path reuses the combat feedback controller" % label
		)
		_expect(
			source.contains("await") and source.contains("play_hit"),
			"%s HP mutation is sequenced through play_hit" % label
		)

	_expect(
		enemy_ai_source.contains("await main.player.take_damage"),
		"enemy attacks wait for player hit feedback before continuing"
	)
	_expect(
		enemy_ai_source.contains('"source": "enemy"'),
		"enemy attacks mark their feedback source explicitly"
	)

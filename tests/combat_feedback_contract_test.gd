extends Node

const CONTROLLER_PATH := "uid://po237gnjpbo0"  # res://ui/battle/combat_feedback_controller.gd
const BATTLE_SCENE_PATH := "res://ui/battle/battle_screen.gd"  # path-ok: reads source text
const COMBAT_ENGINE_PATH := "res://core/combat/combat_manager.gd"  # path-ok: reads source text
const COMBAT_EFFECTS_PATH := "res://core/combat/combat_effects.gd"  # path-ok: reads source text
const COMBAT_COMMANDS_PATH := "res://core/combat/combat_commands.gd"  # path-ok: reads source text
const ENEMY_ENTITY_PATH := "res://ui/battle/enemy_view.gd"  # path-ok: reads source text
const PLAYER_PATH := "res://ui/battle/player_view.gd"  # path-ok: reads source text
const ENEMY_AI_PATH := "res://core/combat/enemy_turn.gd"  # path-ok: reads source text
const EXPECTED_PROFILES := ["blocked", "heavy", "kill", "normal"]
const COMBAT_FX = preload("uid://dx2h4lk8uoasg")  # res://ui/battle/combat_fx.gd
const DAMAGE_NUMBER = preload("uid://clps6my10jkri")  # res://ui/battle/damage_number_vfx.gd
const HIT_SPARK = preload("uid://c81e6d5uadhem")  # res://ui/battle/hit_spark_vfx.gd

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
	_test_shake_tiers()
	_test_punch_envelope()
	await _test_punch_moves_whole_scene()
	_test_hit_spark_kinds()
	_test_hit_spark_layers()
	await _test_damage_number_flight()

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
	# STS2 freezes time only for big moments: ordinary and blocked hits must
	# not stall card flights.
	_expect(
		float(profiles["normal"]["hitstop_seconds"]) == 0.0
		and float(profiles["blocked"]["hitstop_seconds"]) == 0.0,
		"ordinary and blocked hits have no hit stop"
	)
	_expect(
		float(profiles["heavy"]["hitstop_seconds"]) > 0.0
		and float(profiles["kill"]["hitstop_seconds"]) > 0.0,
		"heavy hits and kills keep their hit stop"
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


## shake_tiers: STS2 ShakeStrength by HP taken; blocked weak, lethal strong.
func _test_shake_tiers() -> void:
	var controller = load(CONTROLLER_PATH).new()
	var cases := [
		[1, "normal", 5.0], [5, "normal", 5.0], [6, "normal", 20.0], [10, "heavy", 20.0],
		[11, "heavy", 40.0], [30, "heavy", 40.0], [0, "blocked", 5.0], [2, "kill", 40.0],
	]
	for c in cases:
		var got: float = controller.shake_for_hit(c[0], c[1])
		_expect(is_equal_approx(got, c[2]), "%d HP (%s) punches %s px, got %s" % [c[0], c[1], c[2], got])
	controller.free()


## punch_envelope: cos(remaining x 60) x strength x CubicOut(remaining / duration).
func _test_punch_envelope() -> void:
	_expect(is_equal_approx(COMBAT_FX.punch_offset(40.0, 0.3, 0.3), 40.0 * cos(18.0)), "the punch starts at full strength")
	_expect(COMBAT_FX.punch_offset(40.0, 0.0, 0.3) == 0.0, "the punch ends at rest")
	var envelope := func(remaining: float) -> float: return 1.0 - pow(1.0 - remaining / 0.3, 3.0)
	_expect(envelope.call(0.05) < envelope.call(0.15) and envelope.call(0.15) < envelope.call(0.3), "the punch decays")
	_expect(absf(COMBAT_FX.punch_offset(40.0, 0.15, 0.3)) <= 40.0 * envelope.call(0.15) + 0.001, "the swing stays inside its envelope")


## punch_moves_whole_scene: like STS2's SceneContainer shake, the punch moves the
## background, the player and the enemies by one shared offset along the given
## angle, so the camera seems to shake instead of the hero sliding on a still
## backdrop; everything returns to rest.
func _test_punch_moves_whole_scene() -> void:
	var script := GDScript.new()
	script.source_code = "extends Node
var player
var enemy_container
"
	script.reload()
	var scene := Node.new()
	scene.set_script(script)
	add_child(scene)
	var background := TextureRect.new()
	background.name = "BattleBackground"
	background.position = Vector2(-48, -48)
	scene.add_child(background)
	var player := Node2D.new()
	player.position = Vector2(400, 600)
	scene.add_child(player)
	var enemies := Node2D.new()
	enemies.position = Vector2(1400, 600)
	scene.add_child(enemies)
	scene.set("player", player)
	scene.set("enemy_container", enemies)
	COMBAT_FX.punch_screen(scene, 40.0, 0.3, 90.0)
	# Sample every frame: a stalled headless frame can skip past the whole swing.
	var largest := 0.0
	var together := true
	var vertical := true
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 450:
		await get_tree().process_frame
		var bg_offset: Vector2 = background.position - Vector2(-48, -48)
		largest = maxf(largest, bg_offset.length())
		together = together and (player.position - Vector2(400, 600)).distance_to(bg_offset) < 0.01 and (enemies.position - Vector2(1400, 600)).distance_to(bg_offset) < 0.01
		vertical = vertical and absf(bg_offset.x) < 0.01
	_expect(largest > 1.0, "the punch moves the background")
	_expect(together, "background, player and enemies move together")
	_expect(vertical, "a 90 degree punch moves straight up and down")
	_expect(background.position.is_equal_approx(Vector2(-48, -48)) and player.position.is_equal_approx(Vector2(400, 600)), "everything settles back at rest")
	scene.queue_free()


## hit_spark_kinds: each hit kind lands its own impact star; unknown kinds are
## shots; emphasis lands a bigger star.
func _test_hit_spark_kinds() -> void:
	var shot = HIT_SPARK.spawn(self, Vector2.ZERO, "shot")
	var blast = HIT_SPARK.spawn(self, Vector2.ZERO, "blast")
	var shock = HIT_SPARK.spawn(self, Vector2.ZERO, "shock")
	var unknown = HIT_SPARK.spawn(self, Vector2.ZERO, "laser")
	var heavy = HIT_SPARK.spawn(self, Vector2.ZERO, "shot", 1.5)
	_expect(String(shot.get_parent().name).begins_with("CombatHitSpark_shot"), "a shot names its layer")
	_expect(float(blast.get_meta("radius")) > float(shot.get_meta("radius")), "a blast lands a bigger star than a shot")
	_expect(blast.get_node("Fill").polygon.size() > shot.get_node("Fill").polygon.size(), "a blast star has more spikes")
	_expect(shock.get_node("Fill").color != shot.get_node("Fill").color, "a shock has its own colour")
	_expect(unknown.get_node("Fill").color == shot.get_node("Fill").color
		and is_equal_approx(float(unknown.get_meta("radius")), float(shot.get_meta("radius"))), "an unknown kind falls back to a shot")
	_expect(float(heavy.get_meta("radius")) > float(shot.get_meta("radius")), "emphasis lands a bigger star")
	for star in [shot, blast, shock, unknown, heavy]:
		star.get_parent().queue_free()


## hit_spark_layers: the impact is a flat comic star in the roster style: an
## ink-outlined fill star, an accent star and ink speed marks, drawn without
## additive glow, sitting on the contact point.
func _test_hit_spark_layers() -> void:
	var star = HIT_SPARK.spawn(self, Vector2(300, 300), "shot")
	var layer: Node = star.get_parent()
	_expect(star.position == Vector2(300, 300), "the star sits on the contact point")
	for part in ["Fill", "FillOutline", "Accent", "AccentOutline", "Mark0"]:
		var node := star.get_node_or_null(part) as CanvasItem
		_expect(node != null, "the star has a %s part" % part)
		if node != null:
			_expect(node.material == null, "the %s part is flat, not additive" % part)
	var outline := star.get_node_or_null("FillOutline") as Line2D
	_expect(outline != null and outline.default_color == HIT_SPARK.INK and outline.closed, "the star has a closed ink outline")
	_expect(layer.get_children().filter(func(c): return c is CPUParticles2D or c is GPUParticles2D).is_empty(), "no particle sparks")
	layer.queue_free()

## damage_number_flight: pops in red at 2.5x, launches up, falls, turns cream,
## frees itself (STS2 vfx_damage_num).
func _test_damage_number_flight() -> void:
	var number = DAMAGE_NUMBER.spawn(self, Vector2(500, 500), 17, 1.2)
	_expect(number != null, "a damage number spawns")
	if number == null:
		return
	var layer: Node = number.get_parent()
	var label: Label = number.get_node("Label")
	_expect(label.text == "17", "the number shows the damage")
	_expect(label.modulate.is_equal_approx(DAMAGE_NUMBER.DAMAGE_RED), "it pops in red")
	_expect(label.get_theme_color("font_color") == DAMAGE_NUMBER.CREAM, "the glyphs are cream")
	_expect(label.get_theme_constant("outline_size") == 20, "STS2's heavy outline")
	_expect(number.scale.is_equal_approx(Vector2.ONE * 2.5), "the number pops in at 2.5x")
	_expect(number.velocity.y >= -800.0 and number.velocity.y <= -700.0, "it launches up at 700-800 px/s")
	_expect(absf(number.velocity.x) <= 100.0, "it drifts sideways at most 100 px/s")
	_expect(absf(number.rotation_degrees) <= 5.0, "it tilts at most 5 degrees")
	_expect(label.get_theme_font_size("font_size") == roundi(64 * 1.2), "emphasis scales the 64 px font")
	var start_y: float = number.position.y
	await get_tree().create_timer(0.2).timeout
	_expect(number.position.y < start_y, "it rises first")
	await get_tree().create_timer(0.8).timeout
	_expect(number.position.y > start_y, "then gravity brings it down")
	_expect(label.modulate.is_equal_approx(DAMAGE_NUMBER.CREAM), "it has turned cream")
	await get_tree().create_timer(1.2).timeout
	_expect(not is_instance_valid(layer), "it frees itself after fading")

	var blocked = DAMAGE_NUMBER.spawn_blocked(self, Vector2(500, 500))
	var blocked_label: Label = blocked.get_node("Label")
	_expect(blocked_label.text == tr("UI_COMBAT_BLOCKED") and blocked_label.text != "UI_COMBAT_BLOCKED", "a full block reads BLOCKED")
	_expect(blocked_label.modulate.is_equal_approx(DAMAGE_NUMBER.BLOCKED_BLUE), "BLOCKED starts blue")
	_expect(blocked.velocity == Vector2.ZERO, "BLOCKED drifts, it does not fly")
	var heal = DAMAGE_NUMBER.spawn_heal(self, Vector2(500, 500), 6)
	_expect(heal.get_node("Label").text == "6" and heal.get_node("Label").modulate.is_equal_approx(DAMAGE_NUMBER.HEAL_GREEN), "a heal shows a green number")
	blocked.get_parent().queue_free()
	heal.get_parent().queue_free()


func _test_damage_path_integration() -> void:
	var battle_source := FileAccess.get_file_as_string(BATTLE_SCENE_PATH)
	var engine_source := FileAccess.get_file_as_string(COMBAT_ENGINE_PATH)
	var commands_source := FileAccess.get_file_as_string(COMBAT_COMMANDS_PATH)
	var effects_source := FileAccess.get_file_as_string(COMBAT_EFFECTS_PATH)
	var enemy_source := FileAccess.get_file_as_string(ENEMY_ENTITY_PATH)
	var player_source := FileAccess.get_file_as_string(PLAYER_PATH)
	var enemy_ai_source := FileAccess.get_file_as_string(ENEMY_AI_PATH)

	_expect(
		commands_source.contains("func _feedback("),
		"player-card damage builds explicit feedback tags"
	)
	_expect(
		commands_source.contains('"critical"') and commands_source.contains('"heavy"'),
		"player-card damage forwards both critical and explicit-heavy context"
	)
	_expect(
		commands_source.contains("await _presenter().hit(target, result, feedback)"),
		"player-card resolution waits for the ordered target feedback"
	)
	_expect(
		engine_source.contains("CARD_PLAY.new()")
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
		enemy_ai_source.contains("await combat.effect_registry.execute")
		and effects_source.contains("await services.combat_commands.damage("),
		"enemy attacks wait for player hit feedback before continuing"
	)
	_expect(
		commands_source.contains('"enemy": "enemy"'),
		"enemy attacks mark their feedback source explicitly"
	)

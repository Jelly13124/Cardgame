## Shared, profile-driven combat hit feedback.
##
## Damage owners pass their already-calculated result plus a Callable that performs
## the actual HP mutation.  Keeping that mutation inside `play_hit()` guarantees a
## single readable cadence everywhere: contact + HP -> micro-pause -> number /
## camera response.  The controller deliberately owns presentation only; damage and
## block rules remain with Player / EnemyEntity.
extends Node
class_name CombatFeedbackController

const COMBAT_FX = preload("res://battle_scene/combat_fx.gd")
const IMPACT_ROOT := "res://battle_scene/assets/images/fx/combat_feedback/"
const CONTROLLER_NODE_NAME := "CombatFeedbackController"

const PROFILE_NORMAL := "normal"
const PROFILE_BLOCKED := "blocked"
const PROFILE_HEAVY := "heavy"
const PROFILE_KILL := "kill"

## Exactly four shared feedback tiers.  Critical hits intentionally do not have a
## fifth profile: `profile_for_hit()` maps both critical and explicit heavy attacks
## to PROFILE_HEAVY.
const PROFILES := {
	PROFILE_NORMAL: {
		"hitstop_seconds": 0.014,
		"shake_intensity": 0.0,
		"damage_number_scale": 1.0,
		"reaction_strength": 2.4,
		"reaction_seconds": 0.095,
		"flash_seconds": 0.075,
		"impact_size": 96.0,
		"impact_fps": 28.0,
	},
	PROFILE_BLOCKED: {
		"hitstop_seconds": 0.010,
		"shake_intensity": 0.0,
		"damage_number_scale": 0.9,
		"reaction_strength": 1.2,
		"reaction_seconds": 0.08,
		"flash_seconds": 0.065,
		"impact_size": 100.0,
		"impact_fps": 28.0,
	},
	PROFILE_HEAVY: {
		"hitstop_seconds": 0.034,
		"shake_intensity": 0.0,
		"damage_number_scale": 1.22,
		"reaction_strength": 5.2,
		"reaction_seconds": 0.14,
		"flash_seconds": 0.10,
		"impact_size": 118.0,
		"impact_fps": 24.0,
	},
	PROFILE_KILL: {
		"hitstop_seconds": 0.048,
		"shake_intensity": 2.6,
		"damage_number_scale": 1.36,
		"reaction_strength": 6.8,
		"reaction_seconds": 0.17,
		"flash_seconds": 0.12,
		"impact_size": 126.0,
		"impact_fps": 24.0,
	},
}

signal feedback_started(profile: String)
signal health_applied(profile: String)
signal feedback_finished(profile: String)

const _FLASH_REST_META := "_combat_feedback_flash_rest"
const _FLASH_TWEEN_META := "_combat_feedback_flash_tween"
const _LAST_SCREEN_SHAKE_META := "_combat_feedback_last_screen_shake_msec"
const _SCREEN_SHAKE_THROTTLE_MSEC := 58
const _HITSTOP_TIME_SCALE := 0.10

static var _active_hitstops: int = 0
static var _time_scale_before_hitstop: float = 1.0

var _impact_frames: Dictionary = {}
var _owned_hitstops: int = 0


func _exit_tree() -> void:
	# A scene transition can free the controller while a real-time hitstop timer is
	# still pending. Never let that leave the next scene at the frozen time scale.
	if _owned_hitstops > 0:
		_active_hitstops = maxi(0, _active_hitstops - _owned_hitstops)
		_owned_hitstops = 0
		if _active_hitstops == 0 and Engine.time_scale <= _HITSTOP_TIME_SCALE + 0.001:
			Engine.time_scale = _time_scale_before_hitstop


## Return the one presentation controller owned by a battle scene.  Damage can
## originate from cards, enemies, statuses, or relics; resolving them through the
## same node keeps hitstop depth and screen-shake throttling coherent.
static func ensure(scene_root: Node) -> Node:
	if not is_instance_valid(scene_root):
		return null
	var existing := scene_root.get_node_or_null(CONTROLLER_NODE_NAME)
	if existing:
		return existing
	var controller := CombatFeedbackController.new()
	controller.name = CONTROLLER_NODE_NAME
	controller.process_mode = Node.PROCESS_MODE_ALWAYS
	scene_root.add_child(controller)
	return controller


static func scene_root_for(origin: Node) -> Node:
	var cursor := origin
	while is_instance_valid(cursor):
		var script := cursor.get_script() as Script
		if script and script.resource_path == "res://battle_scene/battle_scene.gd":
			return cursor
		cursor = cursor.get_parent()
	if is_instance_valid(origin) and origin.get_tree():
		return origin.get_tree().current_scene
	return null


## Select a visual tier from an already-resolved hit.  Precedence matters: lethal
## feedback wins over heavy/critical, while a fully absorbed hit reads as Block.
func profile_for_hit(
	damage_after_block: int,
	blocked_amount: int,
	will_kill: bool,
	is_heavy: bool = false,
	is_critical: bool = false
) -> String:
	if will_kill:
		return PROFILE_KILL
	if damage_after_block <= 0 and blocked_amount > 0:
		return PROFILE_BLOCKED
	if is_heavy or is_critical or damage_after_block >= 10:
		return PROFILE_HEAVY
	return PROFILE_NORMAL


## Run one complete hit beat. `apply_health_change` is invoked exactly once at the
## contact boundary, before the real-time hitstop yields, so gameplay state remains
## synchronous while numbers and broader battlefield response follow the pause.
func play_hit(
	scene_root: Node,
	target: Node2D,
	world_pos: Vector2,
	amount: int,
	blocked: int,
	profile: String,
	apply_health_change: Callable
) -> void:
	var resolved_profile := profile if PROFILES.has(profile) else PROFILE_NORMAL
	var settings: Dictionary = PROFILES[resolved_profile]

	feedback_started.emit(resolved_profile)
	_spawn_impact_sequence(scene_root, world_pos, resolved_profile, settings)
	_play_target_reaction(target, resolved_profile, settings)
	# _play_hitstop invokes this boundary before its first await.  That keeps
	# logical HP/block changes synchronous even when a DoT, relic, or thorns
	# caller intentionally does not await the presentation coroutine.
	var apply_boundary := func() -> void:
		if apply_health_change.is_valid():
			apply_health_change.call()
		health_applied.emit(resolved_profile)
	await _play_hitstop(scene_root, float(settings["hitstop_seconds"]), apply_boundary)

	_spawn_damage_number(scene_root, world_pos, amount, blocked, resolved_profile, settings)
	_play_camera_shake(scene_root, resolved_profile, settings)
	feedback_finished.emit(resolved_profile)


## Brief global slow-down.  The timer ignores time scale, so the real-time pause is
## the configured 18-82 ms rather than several seconds.  A depth counter prevents
## overlapping hits from restoring Engine.time_scale out of order.
func _play_hitstop(
	scene_root: Node, seconds: float, apply_boundary: Callable = Callable()
) -> void:
	if seconds <= 0.0 or not is_instance_valid(scene_root) or scene_root.get_tree() == null:
		if apply_boundary.is_valid():
			apply_boundary.call()
		return
	if _active_hitstops == 0:
		_time_scale_before_hitstop = Engine.time_scale
	_active_hitstops += 1
	_owned_hitstops += 1
	Engine.time_scale = minf(Engine.time_scale, _HITSTOP_TIME_SCALE)
	if apply_boundary.is_valid():
		apply_boundary.call()

	await scene_root.get_tree().create_timer(seconds, true, false, true).timeout

	if _owned_hitstops <= 0:
		return
	_owned_hitstops -= 1
	_active_hitstops = maxi(0, _active_hitstops - 1)
	if _active_hitstops == 0 and Engine.time_scale <= _HITSTOP_TIME_SCALE + 0.001:
		Engine.time_scale = _time_scale_before_hitstop


## Target-local reaction: one short outward recoil plus a one-beat comic flash.
## The old random six-step shake made ordinary hits read as continuous wobbling.
func _play_target_reaction(target: Node2D, profile: String, settings: Dictionary) -> void:
	if not is_instance_valid(target):
		return
	var strength := float(settings.get("reaction_strength", 4.0))
	var duration := float(settings.get("reaction_seconds", 0.14))
	COMBAT_FX.recoil(target, strength, duration)

	var rest_color: Color
	if target.has_meta(_FLASH_REST_META):
		rest_color = target.get_meta(_FLASH_REST_META)
	else:
		rest_color = target.modulate
		target.set_meta(_FLASH_REST_META, rest_color)
	if target.has_meta(_FLASH_TWEEN_META):
		var previous = target.get_meta(_FLASH_TWEEN_META)
		if previous is Tween and previous.is_valid():
			previous.kill()

	var flash_color := _flash_color(profile)
	target.modulate = flash_color
	var tween := target.create_tween()
	target.set_meta(_FLASH_TWEEN_META, tween)
	var flash_seconds := float(settings.get("flash_seconds", duration))
	tween.tween_property(target, "modulate", rest_color, flash_seconds).set_trans(Tween.TRANS_QUAD)


## Whole-battlefield response, throttled so multi-hit cards read as a rhythmic burst
## rather than turning the playfield into continuous vibration.
func _play_camera_shake(scene_root: Node, _profile: String, settings: Dictionary) -> void:
	if not is_instance_valid(scene_root):
		return
	var intensity := float(settings.get("shake_intensity", 0.0))
	if intensity <= 0.0:
		return
	var now := Time.get_ticks_msec()
	var last := int(scene_root.get_meta(_LAST_SCREEN_SHAKE_META, -1000000))
	if now - last < _SCREEN_SHAKE_THROTTLE_MSEC:
		return
	scene_root.set_meta(_LAST_SCREEN_SHAKE_META, now)

	# CombatFX's shared helper uses the scripted battle scene's player and
	# enemy_container properties.  Guard those properties here so this controller is
	# also safe in isolated previews and contract tests.
	if _has_property(scene_root, "player") or _has_property(scene_root, "enemy_container"):
		COMBAT_FX.shake_screen(
			scene_root,
			intensity,
			clampf(0.13 + intensity * 0.008, 0.14, 0.24)
		)


## Profile-aware result number.  It is deliberately spawned after HP changes so the
## eye first reads contact, then the numerical outcome.
func _spawn_damage_number(
	scene_root: Node,
	world_pos: Vector2,
	amount: int,
	blocked: int,
	profile: String,
	settings: Dictionary
) -> void:
	if not is_instance_valid(scene_root) or scene_root.get_tree() == null:
		return
	if amount <= 0 and blocked <= 0:
		return

	var layer := CanvasLayer.new()
	layer.name = "CombatDamageNumber"
	layer.layer = 51
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	scene_root.add_child(layer)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A fully absorbed hit must not display the absorbed amount as HP damage.
	label.text = "0" if profile == PROFILE_BLOCKED else str(amount)
	var emphasis := float(settings.get("damage_number_scale", 1.0))
	label.add_theme_font_size_override("font_size", roundi(30.0 * emphasis))
	label.add_theme_color_override("font_color", _number_color(profile))
	label.add_theme_color_override("font_outline_color", Color(0.055, 0.045, 0.035, 0.98))
	label.add_theme_constant_override("outline_size", 5 if profile in [PROFILE_HEAVY, PROFILE_KILL] else 3)
	layer.add_child(label)

	label.size = label.get_minimum_size()
	label.pivot_offset = label.size * 0.5
	label.position = world_pos - Vector2(label.size.x * 0.5, label.size.y * 0.62)
	label.scale = Vector2.ONE * (1.16 if profile in [PROFILE_HEAVY, PROFILE_KILL] else 1.06)

	var rise := 46.0 if profile in [PROFILE_HEAVY, PROFILE_KILL] else 34.0
	var life := 0.62 if profile == PROFILE_KILL else 0.52
	var tween := scene_root.create_tween().set_parallel(true)
	(
		tween
		. tween_property(label, "position:y", label.position.y - rise, life)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(label, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "modulate:a", 0.0, life * 0.55).set_delay(life * 0.45)
	tween.chain().tween_callback(layer.queue_free)


## Spawn the four-frame, transparent comic impact sequence for this profile.
func _spawn_impact_sequence(
	scene_root: Node, world_pos: Vector2, profile: String, settings: Dictionary
) -> void:
	if not is_instance_valid(scene_root) or scene_root.get_tree() == null:
		return
	var frames := _frames_for(profile)
	if frames.is_empty():
		return

	var sprite_frames := SpriteFrames.new()
	sprite_frames.set_animation_loop("default", false)
	sprite_frames.set_animation_speed("default", float(settings.get("impact_fps", 24.0)))
	for texture in frames:
		sprite_frames.add_frame("default", texture)

	var layer := CanvasLayer.new()
	layer.name = "CombatImpact_%s" % profile.capitalize()
	layer.layer = 49
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	scene_root.add_child(layer)

	var impact := AnimatedSprite2D.new()
	impact.sprite_frames = sprite_frames
	impact.position = world_pos
	impact.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	impact.centered = true
	var first: Texture2D = frames[0]
	var source_extent := maxf(float(first.get_width()), float(first.get_height()))
	if source_extent > 0.0:
		impact.scale = Vector2.ONE * (float(settings.get("impact_size", 180.0)) / source_extent)
	layer.add_child(impact)
	impact.animation_finished.connect(layer.queue_free)
	impact.play("default")


func _frames_for(profile: String) -> Array[Texture2D]:
	if _impact_frames.has(profile):
		return _impact_frames[profile]
	var loaded: Array[Texture2D] = []
	for frame_index in range(1, 5):
		var path := "%s%s/impact_%s-%d.png" % [IMPACT_ROOT, profile, profile, frame_index]
		var texture := _load_texture(path)
		if texture:
			loaded.append(texture)
	_impact_frames[profile] = loaded
	return loaded


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	return ImageTexture.create_from_image(image) if image else null


func _has_property(object: Object, property_name: StringName) -> bool:
	for entry in object.get_property_list():
		if StringName(entry.get("name", "")) == property_name:
			return true
	return false


func _flash_color(profile: String) -> Color:
	match profile:
		PROFILE_BLOCKED:
			return Color(0.62, 0.88, 1.0, 1.0)
		PROFILE_HEAVY:
			return Color(1.0, 0.86, 0.62, 1.0)
		PROFILE_KILL:
			return Color(1.0, 0.98, 0.88, 1.0)
		_:
			return Color(1.0, 0.91, 0.82, 1.0)


func _number_color(profile: String) -> Color:
	match profile:
		PROFILE_BLOCKED:
			return Color(0.45, 0.92, 1.0, 1.0)
		PROFILE_HEAVY:
			return Color(1.0, 0.68, 0.18, 1.0)
		PROFILE_KILL:
			return Color(1.0, 0.28, 0.16, 1.0)
		_:
			return Color(0.96, 0.84, 0.62, 1.0)

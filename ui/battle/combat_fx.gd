## Lightweight combat feedback helpers — feedback text, recoil and the battlefield punch.
## Static methods so callers don't need an instance. Spawned nodes
## self-destroy after their tween finishes.
extends RefCounted
class_name CombatFX


## Spawn a compact local feedback label near a combatant. This is intentionally
## not the old center-screen yellow notification: equipment/status triggers stay
## attached to the character they belong to and fade without blocking play.
static func spawn_feedback_text(
	scene_root: Node, world_pos: Vector2, text: String, color: Color
) -> void:
	if not is_instance_valid(scene_root) or scene_root.get_tree() == null or text == "":
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	var layer := CanvasLayer.new()
	layer.layer = 51
	scene_root.add_child(layer)
	layer.add_child(label)
	label.size = label.get_minimum_size()
	label.position = world_pos - Vector2(label.size.x * 0.5, 0)
	var tween := scene_root.create_tween()
	tween.set_parallel(true)
	(
		tween
		. tween_property(label, "position:y", world_pos.y - 38.0, 0.75)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(label, "modulate:a", 0.0, 0.75).set_delay(0.18)
	tween.chain().tween_callback(layer.queue_free)


## One readable outward recoil for a hit. The previous six-step random shake made
## ordinary attacks look like continuous idle wobble, so all paths now share this
## contact -> tiny over-correction -> rest motion.
const _SHAKE_ORIGIN_META := "_combatfx_shake_origin"
const _SHAKE_TWEEN_META := "_combatfx_shake_tween"
const _PUNCH_TWEEN_META := "_combatfx_punch_tween"


static func recoil(target: Node2D, intensity: float = 4.0, duration: float = 0.12) -> void:
	if not is_instance_valid(target):
		return

	var origin := _prepare_position_tween(target)
	var viewport_center_x := target.get_viewport_rect().size.x * 0.5
	var outward_sign := -1.0 if target.global_position.x < viewport_center_x else 1.0
	var contact_offset := Vector2(outward_sign * intensity, -intensity * 0.12)
	var tween := target.create_tween()
	target.set_meta(_SHAKE_TWEEN_META, tween)
	(
		tween
		. tween_property(target, "position", origin + contact_offset, duration * 0.34)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(
		target, "position", origin - contact_offset * 0.16, duration * 0.20
	)
	(
		tween
		. tween_property(target, "position", origin, duration * 0.46)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)


static func shake(target: Node2D, intensity: float = 4.0, duration: float = 0.12) -> void:
	recoil(target, intensity, duration)


## Battlefield punch (STS2 ScreenPunchInstance on the combat SceneContainer): the
## background, the player and the enemies swing together along one line at
## `angle_deg` (random when negative, as in STS2), by
## cos(remaining x 60) x `strength` x CubicOut(remaining / duration), and settle
## back on their rest positions. Moving the backdrop with the creatures makes it
## read as the camera shaking; punching the creatures alone made the hero look
## as if it slid left and right on a still background. The hand and the HUD stay
## put, as in STS2.
static func punch_screen(scene: Node, strength: float, duration: float = 0.3, angle_deg: float = -1.0) -> void:
	if scene == null or not is_instance_valid(scene):
		return
	var angle := deg_to_rad(angle_deg if angle_deg >= 0.0 else randf() * 360.0)
	var direction := Vector2.RIGHT.rotated(angle)
	var targets: Array = []
	for n in [scene.get_node_or_null("BattleBackground"), scene.get("player"), scene.get("enemy_container")]:
		if (n is Node2D or n is Control) and is_instance_valid(n):
			targets.append(n)
	if targets.is_empty():
		return
	# One tween drives every target, so the backdrop and the creatures never
	# drift a frame apart.
	# The punch tween is kept on the scene, not on the targets, so a recoil that
	# starts mid-punch cannot kill it and strand the backdrop off its rest spot.
	if scene.has_meta(_PUNCH_TWEEN_META):
		var prior = scene.get_meta(_PUNCH_TWEEN_META)
		if prior is Tween and prior.is_valid():
			prior.kill()
	var origins: Array = targets.map(func(t): return _prepare_position_tween(t))
	var tween := scene.create_tween()
	scene.set_meta(_PUNCH_TWEEN_META, tween)
	var place := func(offset: Vector2) -> void:
		for i in targets.size():
			if is_instance_valid(targets[i]):
				targets[i].set("position", origins[i] + offset)
	tween.tween_method(
		func(remaining: float) -> void: place.call(direction * punch_offset(strength, remaining, duration)),
		duration, 0.0, duration
	)
	tween.tween_callback(place.bind(Vector2.ZERO))


static func punch_offset(strength: float, remaining: float, duration: float) -> float:
	if remaining <= 0.0 or duration <= 0.0:
		return 0.0
	var t := remaining / duration
	var ease_out := 1.0 - pow(1.0 - t, 3.0)
	return cos(remaining * 60.0) * strength * ease_out


static func _prepare_position_tween(target: CanvasItem) -> Vector2:
	var origin: Vector2
	if target.has_meta(_SHAKE_ORIGIN_META):
		origin = target.get_meta(_SHAKE_ORIGIN_META)
	else:
		origin = target.get("position")
		target.set_meta(_SHAKE_ORIGIN_META, origin)
	if target.has_meta(_SHAKE_TWEEN_META):
		var prior = target.get_meta(_SHAKE_TWEEN_META)
		if prior is Tween and prior.is_valid():
			prior.kill()
	target.set("position", origin)
	return origin

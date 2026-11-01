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


## Battlefield punch (STS2 ScreenPunchInstance): both sides swing horizontally,
## cos(remaining x 60) x `strength` x CubicOut(remaining / duration), and settle
## back on their rest positions together.
static func punch_screen(scene: Node, strength: float, duration: float = 0.3) -> void:
	if scene == null or not is_instance_valid(scene):
		return
	for prop in ["player", "enemy_container"]:
		var n = scene.get(prop)
		if n is Node2D and is_instance_valid(n):
			_punch(n, strength, duration)


static func punch_offset(strength: float, remaining: float, duration: float) -> float:
	if remaining <= 0.0 or duration <= 0.0:
		return 0.0
	var t := remaining / duration
	var ease_out := 1.0 - pow(1.0 - t, 3.0)
	return cos(remaining * 60.0) * strength * ease_out


static func _punch(target: Node2D, strength: float, duration: float) -> void:
	var origin := _prepare_position_tween(target)
	var tween := target.create_tween()
	target.set_meta(_SHAKE_TWEEN_META, tween)
	tween.tween_method(
		func(remaining: float) -> void:
			if is_instance_valid(target):
				target.position = origin + Vector2(punch_offset(strength, remaining, duration), 0.0),
		duration, 0.0, duration
	)
	tween.tween_callback(func() -> void:
		if is_instance_valid(target):
			target.position = origin)


static func _prepare_position_tween(target: Node2D) -> Vector2:
	var origin: Vector2
	if target.has_meta(_SHAKE_ORIGIN_META):
		origin = target.get_meta(_SHAKE_ORIGIN_META)
	else:
		origin = target.position
		target.set_meta(_SHAKE_ORIGIN_META, origin)
	if target.has_meta(_SHAKE_TWEEN_META):
		var prior = target.get_meta(_SHAKE_TWEEN_META)
		if prior is Tween and prior.is_valid():
			prior.kill()
	target.position = origin
	return origin

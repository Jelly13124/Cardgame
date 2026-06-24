## Lightweight combat feedback helpers — damage numbers + screen shake.
## Static methods so callers don't need an instance. Spawned nodes
## self-destroy after their tween finishes.
extends RefCounted
class_name CombatFX


## Spawn a floating damage number at `world_pos`. The label rises and
## fades over ~0.7s, then queue_frees. Color tints by context:
##   - blocked > 0  → grey-blue ("absorbed")
##   - amount  >= 10 → bright red ("big hit")
##   - default      → light red
static func spawn_damage_number(
	scene_root: Node, world_pos: Vector2, amount: int, blocked: int = 0
) -> void:
	if not is_instance_valid(scene_root) or scene_root.get_tree() == null:
		return
	if amount <= 0 and blocked <= 0:
		return

	var label := Label.new()
	label.text = str(amount) if blocked == 0 else "%d (-%d blocked)" % [amount, blocked]
	label.add_theme_font_size_override("font_size", 28 if amount >= 10 else 22)
	label.add_theme_color_override("font_color", _color_for_hit(amount, blocked))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)

	# Use a CanvasLayer so the label always draws on top of the battlefield
	# and isn't clipped by container bounds.
	var layer := CanvasLayer.new()
	layer.layer = 50
	scene_root.add_child(layer)
	layer.add_child(label)

	# Center on the spawn point. label.get_minimum_size() forces a
	# synchronous text-measurement (Label normally only measures on next
	# layout pass). Assigning that to label.size lets us subtract half-
	# width in the SAME frame, so the first rendered frame is already
	# centered — no deferred-callable lag or first-frame mis-position.
	label.size = label.get_minimum_size()
	label.position = world_pos - Vector2(label.size.x * 0.5, 0)

	var tween := scene_root.create_tween()
	tween.set_parallel(true)
	(
		tween
		. tween_property(label, "position:y", world_pos.y - 56, 0.7)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.15)
	tween.chain().tween_callback(layer.queue_free)


## Briefly translate `target` (Node2D) on a decaying sine to simulate impact.
## Overlapping shakes (e.g. double_tap multi-hit) used to sample origin from
## a mid-shake offset and "restore" to the wrong position, accumulating drift.
## Now: cache the true rest position in target.meta on first call, kill any
## prior tween, and always restore to the cached origin.
const _SHAKE_ORIGIN_META := "_combatfx_shake_origin"
const _SHAKE_TWEEN_META := "_combatfx_shake_tween"


static func shake(target: Node2D, intensity: float = 8.0, duration: float = 0.18) -> void:
	if not is_instance_valid(target):
		return

	# Capture origin ONCE per target — never re-sample mid-shake.
	var origin: Vector2
	if target.has_meta(_SHAKE_ORIGIN_META):
		origin = target.get_meta(_SHAKE_ORIGIN_META)
	else:
		origin = target.position
		target.set_meta(_SHAKE_ORIGIN_META, origin)

	# Kill any in-flight shake on the same target so we don't stack tweens.
	if target.has_meta(_SHAKE_TWEEN_META):
		var prior = target.get_meta(_SHAKE_TWEEN_META)
		if prior is Tween and prior.is_valid():
			prior.kill()

	var tween := target.create_tween()
	target.set_meta(_SHAKE_TWEEN_META, tween)
	var steps := 6
	for i in range(steps):
		var t := float(i + 1) / float(steps)
		var falloff := 1.0 - t
		var offset := Vector2(
			randf_range(-intensity, intensity) * falloff,
			randf_range(-intensity, intensity) * falloff,
		)
		tween.tween_property(target, "position", origin + offset, duration / float(steps))
	tween.tween_property(target, "position", origin, duration / float(steps))


## Whole-battlefield "screen shake": jolt the player + enemy container together so a
## big hit or crit reads as a screen impact. Reuses the origin-cached shake() above, so
## there's no positional drift. A brief HUD wobble during the ~0.2s jolt is intentional.
static func shake_screen(scene: Node, intensity: float = 6.0, duration: float = 0.22) -> void:
	if scene == null or not is_instance_valid(scene):
		return
	for prop in ["player", "enemy_container"]:
		var n = scene.get(prop)
		if n is Node2D and is_instance_valid(n):
			shake(n, intensity, duration)


static func _color_for_hit(amount: int, blocked: int) -> Color:
	if blocked > 0 and amount == 0:
		return Color(0.65, 0.85, 1.0)  # fully absorbed — cool blue-grey
	if amount >= 10:
		return Color(1.0, 0.35, 0.25)  # big hit — saturated red
	return Color(1.0, 0.65, 0.55)  # normal — pinkish red

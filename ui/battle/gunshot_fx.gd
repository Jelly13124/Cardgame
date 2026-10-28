extends RefCounted

## The player's gunshot before an attack card resolves: attack pose, wind-up,
## muzzle flash and a bullet flying to the target. Contact is the hit feedback
## the presenter plays next.

const MUZZLE_FLASH_TEX = preload("res://battle_scene/assets/images/fx/gunshot/muzzle_flash.png")
const BULLET_TEX = preload("res://battle_scene/assets/images/fx/gunshot/bullet.png")
const PLAYER_GUNSHOT_WINDUP_SECONDS := 0.22


static func play(screen: Node, shooter: Node, target: Node) -> void:
	if shooter and shooter.has_method("play_attack"):
		shooter.play_attack()
	await screen.get_tree().create_timer(PLAYER_GUNSHOT_WINDUP_SECONDS).timeout
	# The target view can be freed during the wind-up: nothing left to shoot at.
	if not is_instance_valid(target) or target.is_queued_for_deletion() or not is_instance_valid(screen):
		return
	var origin := _muzzle_position(shooter)
	var hit := _hit_position(target)
	var shot_vector := hit - origin
	var direction := Vector2.RIGHT
	if shot_vector.length_squared() > 0.001:
		direction = shot_vector.normalized()

	var muzzle = _make_fx_sprite(screen, MUZZLE_FLASH_TEX, origin, Vector2(0.62, 0.62))
	muzzle.rotation = direction.angle()
	var bullet = _make_fx_sprite(screen, BULLET_TEX, origin + direction * 18.0, Vector2(0.42, 0.42))
	bullet.rotation = direction.angle()

	await screen.get_tree().create_timer(0.05).timeout
	if is_instance_valid(muzzle):
		muzzle.queue_free()

	var flight = screen.create_tween().set_parallel(true)
	(
		flight
		. tween_property(bullet, "global_position", hit, 0.16)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	flight.tween_property(bullet, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	await flight.finished
	if is_instance_valid(bullet):
		bullet.queue_free()


static func _muzzle_position(shooter: Node) -> Vector2:
	if shooter and shooter.has_method("get_muzzle_global_position"):
		return shooter.get_muzzle_global_position()
	if shooter:
		return shooter.global_position + Vector2(98, -104)
	return Vector2.ZERO


static func _hit_position(target: Node) -> Vector2:
	if target and target.has_method("get_hit_global_position"):
		return target.get_hit_global_position()
	if target:
		return target.global_position + Vector2(-60, -100)
	return Vector2.ZERO


static func _make_fx_sprite(screen: Node, texture: Texture2D, pos: Vector2, sprite_scale: Vector2) -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.global_position = pos
	sprite.scale = sprite_scale
	sprite.z_index = 80
	screen.add_child(sprite)
	return sprite

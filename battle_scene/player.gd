extends Node2D
class_name PlayerEntity

@export var max_health: int = 100
@export var health: int = 100
@export var max_energy: int = 3
@export var energy: int = 3
@export var block: int = 0

@export var strength: int = 3
@export var constitution: int = 3
@export var intelligence: int = 3
@export var luck: int = 3
@export var charm: int = 3

signal health_changed(new_amount)
signal energy_changed(new_amount)
signal block_changed(new_amount)
signal stats_changed
signal status_changed
signal died

const HUD_SCRIPT = preload("res://battle_scene/ui/character_hud.gd")
const STATUS_SYS = preload("res://battle_scene/status_effect_system.gd")
const COMBAT_FX = preload("res://battle_scene/combat_fx.gd")
const HERO_DIR = "res://battle_scene/assets/images/heroes/"
const HERO_ID = "cowboy_bill"
const TARGET_DISPLAY_HEIGHT := 256.0
const MUZZLE_NATIVE_POSITION := Vector2(241, 73)

var _sprite: AnimatedSprite2D
var _fallback_sprite: Sprite2D
var _hud: Node
var status_system = STATUS_SYS.new()


func _ready() -> void:
	_build_visual()


func _build_visual() -> void:
	if _has_animation_frames():
		_build_animated_visual()
	else:
		_build_fallback_visual()

	_hud = HUD_SCRIPT.new()
	_hud.max_health = max_health
	_hud.current_health = health
	_hud.current_block = block
	_hud.bar_width = 180
	_hud.position = Vector2(-90, 28)
	add_child(_hud)


func _has_animation_frames() -> bool:
	var dir = HERO_DIR + HERO_ID + "/"
	return _asset_exists(dir + "attack/%s_attack_0.png" % HERO_ID)


func _build_animated_visual() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE
	_sprite.position = Vector2(0, -120)
	_sprite.flip_h = false

	var frames = SpriteFrames.new()
	_sprite.sprite_frames = frames
	_add_animation_frames(frames, "attack", false, 9.0)
	_apply_display_scale(frames)
	add_child(_sprite)
	_show_rest_pose()


func _build_fallback_visual() -> void:
	var tex_path = HERO_DIR + HERO_ID + "/cowboy_bill_block_0.png"
	_fallback_sprite = Sprite2D.new()
	_fallback_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fallback_sprite.scale = Vector2.ONE
	_fallback_sprite.position = Vector2(0, -96)
	_fallback_sprite.flip_h = true
	if ResourceLoader.exists(tex_path):
		_fallback_sprite.texture = load(tex_path) as Texture2D
		_apply_fallback_display_scale()
	else:
		push_warning("PlayerEntity: missing sprite '%s'" % tex_path)
	add_child(_fallback_sprite)


func _add_animation_frames(frames: SpriteFrames, anim_name: String, loops: bool, speed: float) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_loop(anim_name, loops)
	frames.set_animation_speed(anim_name, speed)

	# Hero frames live in per-animation subfolders:
	#   heroes/{hero_id}/{anim}/{hero_id}_{anim}_N.png
	var dir = HERO_DIR + HERO_ID + "/"
	for idx in range(4):
		var tex = _load_texture(dir + "%s/%s_%s_%d.png" % [anim_name, HERO_ID, anim_name, idx])
		if tex:
			frames.add_frame(anim_name, tex)


func _apply_display_scale(frames: SpriteFrames) -> void:
	var tex := _first_frame_texture(frames)
	if not tex:
		return
	var height := float(tex.get_height())
	if height <= 0.0:
		return
	var display_scale := TARGET_DISPLAY_HEIGHT / height
	_sprite.scale = Vector2(display_scale, display_scale)
	_sprite.position = Vector2(0, -TARGET_DISPLAY_HEIGHT * 0.5)


func _apply_fallback_display_scale() -> void:
	if not _fallback_sprite.texture:
		return
	var height := float(_fallback_sprite.texture.get_height())
	if height <= 0.0:
		return
	var display_scale := TARGET_DISPLAY_HEIGHT / height
	_fallback_sprite.scale = Vector2(display_scale, display_scale)
	_fallback_sprite.position = Vector2(0, -TARGET_DISPLAY_HEIGHT * 0.5)


func _first_frame_texture(frames: SpriteFrames) -> Texture2D:
	if frames.has_animation("attack") and frames.get_frame_count("attack") > 0:
		return frames.get_frame_texture("attack", 0)
	return null


func _asset_exists(path: String) -> bool:
	if ResourceLoader.exists(path):
		return true
	if path.begins_with("res://"):
		return FileAccess.file_exists(ProjectSettings.globalize_path(path))
	return FileAccess.file_exists(path)


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D

	var file_path = path
	if path.begins_with("res://"):
		file_path = ProjectSettings.globalize_path(path)

	var image = Image.new()
	if image.load(file_path) == OK:
		return ImageTexture.create_from_image(image)

	push_warning("PlayerEntity: missing frame '%s'" % path)
	return null


func _show_rest_pose() -> void:
	if not _sprite or not is_instance_valid(_sprite):
		return
	var frames = _sprite.sprite_frames
	if frames and frames.has_animation("attack") and frames.get_frame_count("attack") > 0:
		_sprite.play("attack")
		_sprite.pause()
		_sprite.frame = 0


func play_attack() -> void:
	if not _sprite or not is_instance_valid(_sprite):
		return
	var frames = _sprite.sprite_frames
	if not frames or not frames.has_animation("attack") or frames.get_frame_count("attack") == 0:
		return
	if not _sprite.animation_finished.is_connected(_on_attack_finished):
		_sprite.animation_finished.connect(_on_attack_finished, CONNECT_ONE_SHOT)
	_sprite.play("attack")


func _on_attack_finished() -> void:
	_show_rest_pose()


func get_muzzle_global_position() -> Vector2:
	var tex := _current_sprite_texture()
	if _sprite and is_instance_valid(_sprite) and tex:
		var native_origin := Vector2(tex.get_width(), tex.get_height()) * 0.5
		return _sprite.to_global(MUZZLE_NATIVE_POSITION - native_origin)
	if _fallback_sprite and is_instance_valid(_fallback_sprite) and _fallback_sprite.texture:
		var native_origin := Vector2(_fallback_sprite.texture.get_width(), _fallback_sprite.texture.get_height()) * 0.5
		return _fallback_sprite.to_global(MUZZLE_NATIVE_POSITION - native_origin)
	return global_position + Vector2(98, -104)


func _current_sprite_texture() -> Texture2D:
	if not _sprite or not is_instance_valid(_sprite):
		return null
	var frames := _sprite.sprite_frames
	if not frames:
		return null
	var anim := _sprite.animation
	if anim == "" or not frames.has_animation(anim) or frames.get_frame_count(anim) == 0:
		anim = "attack"
	if not frames.has_animation(anim) or frames.get_frame_count(anim) == 0:
		return null
	var frame_idx = clampi(_sprite.frame, 0, frames.get_frame_count(anim) - 1)
	return frames.get_frame_texture(anim, frame_idx)


func notify_stats_changed() -> void:
	stats_changed.emit()


func notify_status_changed() -> void:
	status_changed.emit()


func take_damage(amount: int, silent: bool = false) -> void:
	var dmg_after_block = max(0, amount - block)
	var blocked_amount = min(block, amount)
	block = max(0, block - amount)
	health -= dmg_after_block
	health = max(0, health)
	block_changed.emit(block)
	health_changed.emit(health)
	_refresh_hud()

	# Floating damage number + shake. silent=true skips both — DoT ticks
	# (poison/burn) already produce a "POISON N" / "BURN N" notification
	# from status_effect_system, so showing a floating number too would
	# stack two damage callouts on every tick.
	if not silent:
		var scene := get_tree().current_scene
		if scene:
			var spawn_pos: Vector2 = global_position + Vector2(0, -TARGET_DISPLAY_HEIGHT * 0.5)
			COMBAT_FX.spawn_damage_number(scene, spawn_pos, dmg_after_block, blocked_amount)
			# Shake the sprite only (not `self`) so the HUD / status badges
			# that are children of this entity don't wobble with it.
			if dmg_after_block >= 10 and _sprite and is_instance_valid(_sprite):
				COMBAT_FX.shake(_sprite, 8.0, 0.22)

	if health <= 0:
		died.emit()


func heal(amount: int) -> void:
	health = min(health + amount, max_health)
	health_changed.emit(health)
	_refresh_hud()


func add_block(amount: int) -> void:
	block += amount
	block_changed.emit(block)
	_refresh_hud()


func start_turn() -> void:
	status_system.on_turn_start(self)
	if health <= 0:
		return
	energy = max_energy
	block = 0
	energy_changed.emit(energy)
	block_changed.emit(block)
	_refresh_hud()


func end_turn() -> void:
	status_system.on_turn_end(self)
	_refresh_hud()


func pay_energy(cost: int) -> bool:
	if energy >= cost:
		energy -= cost
		energy_changed.emit(energy)
		return true
	return false


func _refresh_hud() -> void:
	if _hud and is_instance_valid(_hud):
		_hud.update_stats(health, max_health, block)


func add_status(status_name: String, stacks: int) -> void:
	status_system.add_status(status_name, stacks, self)


func get_status_stacks(status_name: String) -> int:
	return status_system.get_stacks(status_name)


func get_outgoing_multiplier() -> float:
	return status_system.get_outgoing_multiplier()


func get_incoming_attack_multiplier() -> float:
	return status_system.get_incoming_attack_multiplier()

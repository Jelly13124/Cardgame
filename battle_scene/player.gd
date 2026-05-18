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
const HERO_DIR = "res://battle_scene/assets/images/heroes/"
const HERO_ID = "cowboy_bill"

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
	_hud.character_name = "COWBOY BILL"
	_hud.max_health = max_health
	_hud.current_health = health
	_hud.current_block = block
	_hud.bar_width = 140
	_hud.position = Vector2(-70, 10)
	add_child(_hud)


func _has_animation_frames() -> bool:
	var dir = HERO_DIR + HERO_ID + "/"
	return ResourceLoader.exists(dir + "%s_idle_0.png" % HERO_ID) or ResourceLoader.exists(dir + "%s_attack_0.png" % HERO_ID)


func _build_animated_visual() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(2.25, 2.25)
	_sprite.position = Vector2(0, -120)
	_sprite.flip_h = false

	var frames = SpriteFrames.new()
	_sprite.sprite_frames = frames
	_add_animation_frames(frames, "idle", true, 5.0)
	_add_animation_frames(frames, "attack", false, 9.0)
	add_child(_sprite)
	play_idle()


func _build_fallback_visual() -> void:
	var tex_path = HERO_DIR + HERO_ID + "/cowboy_bill_block_0.png"
	_fallback_sprite = Sprite2D.new()
	_fallback_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fallback_sprite.scale = Vector2(3.0, 3.0)
	_fallback_sprite.position = Vector2(0, -96)
	_fallback_sprite.flip_h = true
	if ResourceLoader.exists(tex_path):
		_fallback_sprite.texture = load(tex_path) as Texture2D
	else:
		push_warning("PlayerEntity: missing sprite '%s'" % tex_path)
	add_child(_fallback_sprite)


func _add_animation_frames(frames: SpriteFrames, anim_name: String, loops: bool, speed: float) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_loop(anim_name, loops)
	frames.set_animation_speed(anim_name, speed)

	var dir = HERO_DIR + HERO_ID + "/"
	for idx in range(4):
		var tex = _load_texture(dir + "%s_%s_%d.png" % [HERO_ID, anim_name, idx])
		if tex:
			frames.add_frame(anim_name, tex)


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


func play_idle() -> void:
	if not _sprite or not is_instance_valid(_sprite):
		return
	var frames = _sprite.sprite_frames
	if frames and frames.has_animation("idle") and frames.get_frame_count("idle") > 0:
		_sprite.play("idle")
	elif frames and frames.has_animation("attack") and frames.get_frame_count("attack") > 0:
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
	play_idle()


func notify_stats_changed() -> void:
	stats_changed.emit()


func notify_status_changed() -> void:
	status_changed.emit()


func take_damage(amount: int) -> void:
	var dmg_after_block = max(0, amount - block)
	block = max(0, block - amount)
	health -= dmg_after_block
	health = max(0, health)
	block_changed.emit(block)
	health_changed.emit(health)
	_refresh_hud()
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

extends Node2D
class_name PlayerEntity

@export var max_health: int = 100
@export var health: int = 100
@export var max_energy: int = 3
@export var energy: int = 3
@export var block: int = 0

# RPG Attributes
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

## Hero sprite assets — each hero has its own subfolder under heroes/
const HERO_DIR = "res://battle_scene/assets/images/heroes/"
const HERO_ID  = "cowboy_bill"

var _sprite: Sprite2D
var _hud: Node

## Composed status effect system
var status_system = STATUS_SYS.new()

func _ready() -> void:
	_build_visual()

func _build_visual() -> void:
	# ── Static sprite (block_0 is the permanent rest pose) ────────────────────
	var tex_path = HERO_DIR + HERO_ID + "/cowboy_bill_block_0.png"
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(3.0, 3.0)  # 64px → 192px display
	_sprite.position = Vector2(0, -96) # anchor at feet
	_sprite.flip_h = true              # face left
	if ResourceLoader.exists(tex_path):
		_sprite.texture = load(tex_path) as Texture2D
	else:
		push_warning("PlayerEntity: missing sprite '%s'" % tex_path)
	add_child(_sprite)

	# ── HUD below sprite ──────────────────────────────────────────────────────
	_hud = HUD_SCRIPT.new()
	_hud.character_name = "COWBOY BILL"
	_hud.max_health = max_health
	_hud.current_health = health
	_hud.current_block = block
	_hud.bar_width = 140
	_hud.position = Vector2(-70, 10)  # aligned below feet at y=10
	add_child(_hud)

## Called externally when an attack card is played — no animation, already at rest pose
func play_attack() -> void:
	pass

## Called externally when a block/armor card is played — no animation, display is static
func play_block() -> void:
	pass

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
	# Tick status effects BEFORE energy/block reset so player sees poison hit
	status_system.tick(self )
	energy = max_energy
	block = 0
	energy_changed.emit(energy)
	block_changed.emit(block)
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

## Delegate to StatusEffectSystem
func add_status(status_name: String, stacks: int) -> void:
	status_system.add_status(status_name, stacks, self )

func get_status_stacks(status_name: String) -> int:
	return status_system.get_stacks(status_name)

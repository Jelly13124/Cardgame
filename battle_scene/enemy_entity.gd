## EnemyEntity — loads its stats and action pattern from a JSON data file.
## Spawn via: EnemyEntity.create("trash_robot")
## The action_pattern cycles each turn. Intent is shown above the HUD.
extends Node2D
class_name EnemyEntity

const HUD_SCRIPT = preload("res://battle_scene/ui/character_hud.gd")
const ENEMY_DATA_DIR = "res://battle_scene/card_info/enemy/"
const STATUS_SYS = preload("res://battle_scene/status_effect_system.gd")

# ─── Stats ────────────────────────────────────────────────────────────────────
var enemy_id: String = ""
var enemy_name: String = "ENEMY"
var max_health: int = 30
var health: int = 30
var block: int = 0
## ID used to locate sprite frames: e.g. "trash_robot" → trash_robot_idle_0.png
var sprite_id: String = ""

## Composed status effect system
var status_system = STATUS_SYS.new()

# ─── Action Pattern ───────────────────────────────────────────────────────────
## Array of { type, amount, label } dicts that cycle each turn.
var action_pattern: Array = []
var _action_index: int = 0

signal died()

# ─── Internal Nodes ───────────────────────────────────────────────────────────
var _hud: Node
## Reference to the animated sprite (replaces old ColorRect body)
var _sprite: AnimatedSprite2D
var _intent_label: Label
var _intent_bg: Panel   # Colored pill background for intent badge

## Base path for enemy sprite assets — each enemy gets its own subfolder: {ENEMIES_DIR}{sprite_id}/
const ENEMIES_DIR = "res://battle_scene/assets/images/enemies/"

# ─── Factory ──────────────────────────────────────────────────────────────────

## Create and return a fully initialized EnemyEntity from a JSON id.
static func create(id: String) -> EnemyEntity:
	var entity = EnemyEntity.new()
	entity.enemy_id = id
	var path = ENEMY_DATA_DIR + id + ".json"
	if ResourceLoader.exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var data: Dictionary = JSON.parse_string(file.get_as_text())
			file.close()
			if data:
				entity.enemy_name  = data.get("name",      id.to_upper())
				entity.max_health  = int(data.get("max_health", 30))
				entity.health      = entity.max_health
				entity.action_pattern = data.get("action_pattern", [])
				entity.sprite_id   = data.get("sprite_id", "")
	else:
		push_warning("EnemyEntity: JSON not found for id '%s', using defaults." % id)
	return entity

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_visual()
	_update_intent_display()

func _build_visual() -> void:
	if sprite_id != "":
		_build_sprite_visual(sprite_id)
	else:
		_build_placeholder_visual()

## Build an AnimatedSprite2D from PixelLab-generated frames.
## Frame files must be: {SPRITE_DIR}{sid}_idle_N.png and {sid}_attack_N.png
func _build_sprite_visual(sid: String) -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(3.0, 3.0)      # 64px frames → 192px display
	_sprite.position = Vector2(0, -96)     # anchor at feet (same as player)
	_sprite.flip_h = false                 # face right

	var frames = SpriteFrames.new()
	_sprite.sprite_frames = frames

	var _load_tex = func(path: String) -> Texture2D:
		if ResourceLoader.exists(path):
			return load(path)
		push_warning("EnemyEntity: missing frame '%s'" % path)
		return null

	# Per-enemy subfolder: enemies/{sprite_id}/{sprite_id}_attack_N.png
	var dir = ENEMIES_DIR + sid + "/"

	# ── Attack (one-shot, non-looping) ─────────────────────────────────────────
	frames.add_animation("attack")
	frames.set_animation_loop("attack", false)
	frames.set_animation_speed("attack", 8.0)
	for idx in range(4):
		var tex = _load_tex.call(dir + "%s_attack_%d.png" % [sid, idx])
		if tex:
			frames.add_frame("attack", tex)

	add_child(_sprite)
	# Show frame 0 of attack as static rest pose
	if frames.has_animation("attack") and frames.get_frame_count("attack") > 0:
		_sprite.play("attack")
		_sprite.pause()
		_sprite.frame = 0

	# Sprite anchored at feet (0, -96): 192x192, top=-192, bottom=0
	_build_intent_badge(Vector2(-60, -232))  # 40px above sprite top
	_build_health_bar(Vector2(-70, 10))      # 10px below feet (centered with bar_width 140)

## Fallback: procedural colored rectangle for enemies without pixel art yet.
func _build_placeholder_visual() -> void:
	var body = ColorRect.new()
	body.color = Color(0.7, 0.15, 0.15)
	body.size = Vector2(140, 190)         # bigger placeholder too
	body.position = Vector2(-70, -190)
	add_child(body)
	# Placeholder: 140×190, top y=-190, bottom y=0
	_build_intent_badge(Vector2(-90, -228))  # above placeholder
	_build_health_bar(Vector2(-94, 8))       # below placeholder

## Builds a colored pill badge above the sprite showing the next intent.
## intent_pos: top-left of the 120×30 pill in entity-local space.
func _build_intent_badge(intent_pos: Vector2) -> void:
	# Pill background panel
	var pill_style = StyleBoxFlat.new()
	pill_style.bg_color = Color(0.6, 0.1, 0.1, 0.88)  # default: attack red
	pill_style.corner_radius_top_left    = 10
	pill_style.corner_radius_top_right   = 10
	pill_style.corner_radius_bottom_left = 10
	pill_style.corner_radius_bottom_right = 10
	pill_style.border_width_left   = 1
	pill_style.border_width_right  = 1
	pill_style.border_width_top    = 1
	pill_style.border_width_bottom = 1
	pill_style.border_color = Color(1.0, 0.4, 0.4, 0.9)

	_intent_bg = Panel.new()
	_intent_bg.size = Vector2(120, 30)
	_intent_bg.position = intent_pos
	_intent_bg.add_theme_stylebox_override("panel", pill_style)
	add_child(_intent_bg)

	# Text label inside the pill
	_intent_label = Label.new()
	_intent_label.add_theme_font_size_override("font_size", 15)
	_intent_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_intent_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_intent_label.add_theme_constant_override("shadow_offset_x", 1)
	_intent_label.add_theme_constant_override("shadow_offset_y", 1)
	_intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intent_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_intent_label.size = Vector2(120, 30)
	_intent_label.position = Vector2.ZERO
	_intent_bg.add_child(_intent_label)

## Builds the health bar (CharacterHUD) positioned below the sprite.
## hud_pos: top-left of the HUD in entity-local space.
func _build_health_bar(hud_pos: Vector2) -> void:
	_hud = HUD_SCRIPT.new()
	_hud.character_name = enemy_name
	_hud.max_health = max_health
	_hud.current_health = health
	_hud.current_block = block
	_hud.bar_width = 140
	_hud.position = hud_pos
	add_child(_hud)

# ─── Action Pattern ───────────────────────────────────────────────────────────

## Returns the current action without advancing the index.
func peek_next_action() -> Dictionary:
	if action_pattern.is_empty():
		return {"type": "attack", "amount": 6, "label": "⚔ 6"}
	return action_pattern[_action_index % action_pattern.size()]

## Returns the current action AND advances to the next one.
func consume_next_action() -> Dictionary:
	var a = peek_next_action()
	_action_index = (_action_index + 1) % max(1, action_pattern.size())
	_update_intent_display()
	return a

## Refreshes the intent badge to show what this enemy will do NEXT turn.
func _update_intent_display() -> void:
	if not _intent_label: return
	var next = peek_next_action()
	_intent_label.text = next.get("label", "?")

	# Update pill background + border colour to match intent type
	if not _intent_bg: return
	var pill = StyleBoxFlat.new()
	pill.corner_radius_top_left     = 10
	pill.corner_radius_top_right    = 10
	pill.corner_radius_bottom_left  = 10
	pill.corner_radius_bottom_right = 10
	pill.border_width_left   = 1
	pill.border_width_right  = 1
	pill.border_width_top    = 1
	pill.border_width_bottom = 1
	match next.get("type", ""):
		"attack":
			pill.bg_color     = Color(0.55, 0.08, 0.08, 0.88)
			pill.border_color = Color(1.0, 0.4, 0.4, 0.9)
		"block":
			pill.bg_color     = Color(0.08, 0.25, 0.55, 0.88)
			pill.border_color = Color(0.4, 0.65, 1.0, 0.9)
		"heal":
			pill.bg_color     = Color(0.08, 0.40, 0.12, 0.88)
			pill.border_color = Color(0.3, 1.0, 0.4, 0.9)
		_:
			pill.bg_color     = Color(0.25, 0.25, 0.25, 0.85)
			pill.border_color = Color(0.7, 0.7, 0.7, 0.9)
	_intent_bg.add_theme_stylebox_override("panel", pill)

# ─── Combat ───────────────────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	var dmg_after_block = max(0, amount - block)
	block = max(0, block - amount)
	health -= dmg_after_block
	health = max(0, health)
	_refresh_hud()
	if health <= 0:
		died.emit()
		queue_free()

func add_block(amount: int) -> void:
	block += amount
	_refresh_hud()

func heal(amount: int) -> void:
	health = min(health + amount, max_health)
	_refresh_hud()

func start_turn() -> void:
	# Tick status effects before block reset so enemy sees the full state
	status_system.tick(self )
	block = 0
	_refresh_hud()

func _refresh_hud() -> void:
	if _hud and is_instance_valid(_hud):
		_hud.update_stats(health, max_health, block)

## Delegate to StatusEffectSystem
func add_status(status_name: String, stacks: int) -> void:
	status_system.add_status(status_name, stacks, self )

func get_status_stacks(status_name: String) -> int:
	return status_system.get_stacks(status_name)

# ─── Animation Helpers ────────────────────────────────────────────────────────

## Play the attack animation once, then return to idle.
func play_attack() -> void:
	if not _sprite or not is_instance_valid(_sprite):
		return
	if not _sprite.animation_finished.is_connected(_on_attack_finished):
		_sprite.animation_finished.connect(_on_attack_finished, CONNECT_ONE_SHOT)
	_sprite.play("attack")

func _on_attack_finished() -> void:
	# Stay on last frame as rest pose — no idle loop
	if _sprite and is_instance_valid(_sprite):
		_sprite.pause()

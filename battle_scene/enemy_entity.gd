## EnemyEntity — loads its stats and action pattern from a JSON data file.
## Spawn via: EnemyEntity.create("trash_robot")
## The action_pattern cycles each turn. Intent is shown above the HUD.
extends Node2D
class_name EnemyEntity

const HUD_SCRIPT = preload("res://battle_scene/ui/character_hud.gd")
const ENEMY_DATA_DIR = "res://battle_scene/card_info/enemy/"
const STATUS_SYS = preload("res://battle_scene/status_effect_system.gd")

# Intent badge icon textures — preloaded once instead of `load()`-ing on every
# intent refresh (which can fire frequently as enemy / player status changes).
const INTENT_ICON_ATTACK = preload("res://battle_scene/assets/images/ui/intent_attack.png")
const INTENT_ICON_BLOCK  = preload("res://battle_scene/assets/images/ui/intent_block.png")
const INTENT_ICON_BUFF   = preload("res://battle_scene/assets/images/ui/intent_buff.png")
const INTENT_ICON_CHARGE = preload("res://battle_scene/assets/images/ui/intent_charge.png")
const NORMAL_DISPLAY_HEIGHT := 192.0
const BOSS_DISPLAY_HEIGHT := 288.0
const INTENT_BADGE_WIDTH := 104.0
const INTENT_BADGE_HEIGHT := 36.0

# ─── Stats ────────────────────────────────────────────────────────────────────
var enemy_id: String = ""
var enemy_name: String = "ENEMY"
var max_health: int = 30
var health: int = 30
var block: int = 0
## ID used to locate sprite frames: e.g. "trash_robot" -> trash_robot_attack_0.png
var sprite_id: String = ""

## Composed status effect system
var status_system = STATUS_SYS.new()

## Short labels used inside the intent badge ("⚔ 5 +Weak" etc.).
const _STATUS_SHORT_NAMES = {
	"weak":          "Weak",
	"vulnerable":    "Vuln",
	"burn":          "Burn",
	"poison":        "Pois",
	"shock":         "Shock",
	"strength_up":   "Str+",
	"double_damage": "Dbl",
}

# ─── Action Pattern ───────────────────────────────────────────────────────────
## Array of { type, amount, label } dicts that cycle each turn.
var action_pattern: Array = []
var _action_index: int = 0

signal died()
signal status_changed

# ─── Internal Nodes ───────────────────────────────────────────────────────────
var _hud: Node
## Reference to the animated sprite (replaces old ColorRect body)
var _sprite: AnimatedSprite2D
var _intent_label: Label
var _intent_icon: TextureRect
var _intent_bg: Control
var _intent_tween: Tween

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
		push_error("EnemyEntity: JSON not found for id '%s' at '%s'. Encounter will spawn a placeholder enemy." % [id, path])
		assert(false, "EnemyEntity: JSON not found for id '%s'" % id)
	return entity

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_visual()
	_update_intent_display()
	_start_intent_float_anim()
	# Refresh intent whenever this enemy's own status changes (e.g. shock /
	# weak landed). Player-status changes (e.g. vulnerable applied to player)
	# are broadcast by BattleScene to every enemy via update_intent_display().
	status_changed.connect(_update_intent_display)

func _build_visual() -> void:
	if sprite_id != "":
		_build_sprite_visual(sprite_id)
	else:
		_build_placeholder_visual()

## Build an AnimatedSprite2D from generated attack frames.
## Frame files must be: enemies/{sid}/attack/{sid}_attack_N.png
func _build_sprite_visual(sid: String) -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE
	_sprite.position = Vector2(0, -96)
	_sprite.flip_h = false                 # enemy PNGs already face left toward the player

	var frames = SpriteFrames.new()
	_sprite.sprite_frames = frames

	var _load_tex = func(path: String, warn_missing: bool) -> Texture2D:
		if ResourceLoader.exists(path):
			return load(path)
		if FileAccess.file_exists(path):
			var image := Image.load_from_file(path)
			if image:
				return ImageTexture.create_from_image(image)
		if warn_missing:
			push_warning("EnemyEntity: missing frame '%s'" % path)
		return null

	# Per-enemy subfolder, animations live in attack/ subfolders
	# (and charge/ for bosses with a telegraph wind-up animation):
	#   enemies/{sprite_id}/attack/{sprite_id}_attack_N.png
	#   enemies/{sprite_id}/charge/{sprite_id}_charge_N.png  (optional)
	var dir = ENEMIES_DIR + sid + "/"

	# ── Attack (one-shot, non-looping) ────────────────────────────────────────
	frames.add_animation("attack")
	frames.set_animation_loop("attack", false)
	frames.set_animation_speed("attack", 8.0)
	for idx in range(4):
		var tex = _load_tex.call(dir + "attack/%s_attack_%d.png" % [sid, idx], true)
		if tex:
			frames.add_frame("attack", tex)

	# ── Charge (optional, one-shot — used by boss telegraph) ─────────────────
	var charge_frames: Array[Texture2D] = []
	for idx in range(4):
		var tex = _load_tex.call(dir + "charge/%s_charge_%d.png" % [sid, idx], false)
		if tex:
			charge_frames.append(tex)
	if not charge_frames.is_empty():
		frames.add_animation("charge")
		frames.set_animation_loop("charge", false)
		frames.set_animation_speed("charge", 6.0)
		for tex in charge_frames:
			frames.add_frame("charge", tex)

	var display_height := _apply_display_scale(frames)
	add_child(_sprite)
	_show_rest_pose()

	_build_intent_badge(Vector2(-INTENT_BADGE_WIDTH * 0.5, -display_height - 48.0))
	_build_health_bar(Vector2(-90, 28))      # below feet (centered with bar_width 180)


## Scales the sprite to a target display height and returns the **content** height
## from the entity baseline (feet at y=0) to the topmost visible (non-transparent)
## pixel. This is what callers should use for placing the intent badge — basing
## it on the raw canvas height makes the badge "float" above small enemies
## (e.g. scrap_rat) whose content fills only the bottom of the canvas.
func _apply_display_scale(frames: SpriteFrames) -> float:
	var tex := _first_frame_texture(frames)
	if not tex:
		return NORMAL_DISPLAY_HEIGHT
	var native_height := float(tex.get_height())
	if native_height <= 0.0:
		return NORMAL_DISPLAY_HEIGHT
	var target_height := BOSS_DISPLAY_HEIGHT if native_height >= 160.0 else NORMAL_DISPLAY_HEIGHT
	var display_scale := target_height / native_height
	_sprite.scale = Vector2(display_scale, display_scale)
	_sprite.position = Vector2(0, -target_height * 0.5)

	# Detect where the actual sprite content starts (vs how big the canvas is).
	# get_used_rect returns the bounding box of non-transparent pixels in
	# native pixel coordinates. Multiply by display_scale to convert to the
	# displayed dimension. If the sprite fills the whole canvas (e.g. a tall
	# humanoid), top_offset_displayed is 0 and content_height == target_height
	# (no behavioral change vs the old version).
	var top_offset_displayed := 0.0
	var img := tex.get_image()
	if img:
		var used := img.get_used_rect()
		top_offset_displayed = float(used.position.y) * display_scale
	return target_height - top_offset_displayed


func _first_frame_texture(frames: SpriteFrames) -> Texture2D:
	for anim_name in ["attack", "charge"]:
		if frames.has_animation(anim_name) and frames.get_frame_count(anim_name) > 0:
			return frames.get_frame_texture(anim_name, 0)
	return null


func get_hit_global_position() -> Vector2:
	if not _sprite or not is_instance_valid(_sprite):
		return global_position + Vector2(-60, -100)
	var tex := _first_frame_texture(_sprite.sprite_frames)
	if not tex:
		return global_position + Vector2(-60, -100)
	var native_origin := Vector2(tex.get_width(), tex.get_height()) * 0.5
	var native_hit := Vector2(tex.get_width() * 0.34, tex.get_height() * 0.48)
	return _sprite.to_global(native_hit - native_origin)


## Fallback: procedural colored rectangle for enemies without sprite art yet.
func _build_placeholder_visual() -> void:
	var body = ColorRect.new()
	body.color = Color(0.7, 0.15, 0.15)
	body.size = Vector2(140, 190)         # bigger placeholder too
	body.position = Vector2(-70, -190)
	add_child(body)
	# Placeholder: 140×190, top y=-190, bottom y=0
	_build_intent_badge(Vector2(-INTENT_BADGE_WIDTH * 0.5, -232))  # above placeholder
	_build_health_bar(Vector2(-114, 26))     # below placeholder

## Builds a compact icon + text intent readout above the sprite.
## intent_pos is the top-left position in entity-local space.
func _build_intent_badge(intent_pos: Vector2) -> void:
	_intent_bg = Control.new()
	_intent_bg.size = Vector2(INTENT_BADGE_WIDTH, INTENT_BADGE_HEIGHT)
	_intent_bg.position = intent_pos
	_intent_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intent_bg.z_index = 20
	add_child(_intent_bg)

	_intent_icon = TextureRect.new()
	_intent_icon.size = Vector2(34, 34)
	_intent_icon.position = Vector2(0, 1)
	_intent_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_intent_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_intent_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_intent_bg.add_child(_intent_icon)

	_intent_label = Label.new()
	_intent_label.add_theme_font_size_override("font_size", 22)
	_intent_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.64))
	_intent_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	_intent_label.add_theme_constant_override("shadow_offset_x", 2)
	_intent_label.add_theme_constant_override("shadow_offset_y", 2)
	_intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_intent_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_intent_label.size = Vector2(70, INTENT_BADGE_HEIGHT)
	_intent_label.position = Vector2(38, -1)
	_intent_bg.add_child(_intent_label)

## Builds the health bar (CharacterHUD) positioned below the sprite.
## hud_pos: top-left of the HUD in entity-local space.
func _build_health_bar(hud_pos: Vector2) -> void:
	_hud = HUD_SCRIPT.new()
	_hud.max_health = max_health
	_hud.current_health = health
	_hud.current_block = block
	_hud.bar_width = 180
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
## Public — called by BattleScene to broadcast player-status changes
## (e.g. vulnerable applied to player) to every enemy.
func update_intent_display() -> void:
	_update_intent_display()


## Computes the actual damage that will be displayed in the intent badge for
## this enemy's next attack, taking enemy's own weak and player's vulnerable
## into account. Mirrors combat_engine.calculate_attack_damage() but without
## side effects.
func _compute_display_attack(base_amount: int) -> int:
	var outgoing := status_system.get_outgoing_multiplier()
	var incoming := 1.0
	var battle = get_tree().current_scene if get_tree() else null
	if battle and "player" in battle and is_instance_valid(battle.player):
		var p = battle.player
		if p.has_method("get_incoming_attack_multiplier"):
			incoming = p.get_incoming_attack_multiplier()
	return int(round(float(base_amount) * outgoing * incoming))


func _update_intent_display() -> void:
	if not _intent_label: return
	var next = peek_next_action()
	var action_type = str(next.get("type", ""))

	# For attack-like actions, rebuild the label using the *actual* damage
	# after weak / vulnerable — so the intent badge stays accurate as the
	# player applies debuffs. JSON `label` is only honored for non-attack
	# actions (block / heal / telegraph).
	var label_text: String
	if action_type in ["attack", "attack_status", "attack_all"]:
		var base = int(next.get("amount", 0))
		var display_dmg = _compute_display_attack(base)
		label_text = str(display_dmg)
		if action_type == "attack_status":
			var status = str(next.get("status", ""))
			var stacks = int(next.get("stacks", 1))
			var status_short = _STATUS_SHORT_NAMES.get(status, status.capitalize())
			if stacks > 1:
				label_text += " %s%d" % [status_short, stacks]
			else:
				label_text += " %s" % status_short
	elif action_type == "block":
		label_text = str(int(next.get("amount", 0)))
	elif action_type in ["heal", "buff"]:
		var amount = int(next.get("amount", 0))
		label_text = str(amount) if amount > 0 else "BUFF"
	elif action_type == "telegraph":
		label_text = "CHARGE"
	else:
		label_text = str(next.get("label", "?"))

	# Hint the player they can interrupt this attack with a shock card
	if bool(next.get("interruptible", false)):
		label_text += " !"
	_intent_label.text = label_text

	if not _intent_bg: return
	var type = next.get("type", "")
	var label_color := Color(1.0, 0.9, 0.64)
	match type:
		"attack", "attack_status", "attack_all":
			_intent_icon.texture = INTENT_ICON_ATTACK
			label_color = Color(1.0, 0.78, 0.62)
		"block":
			_intent_icon.texture = INTENT_ICON_BLOCK
			label_color = Color(0.65, 0.86, 1.0)
		"heal", "buff":
			_intent_icon.texture = INTENT_ICON_BUFF
			label_color = Color(0.72, 1.0, 0.62)
		"telegraph":
			_intent_icon.texture = INTENT_ICON_CHARGE
			label_color = Color(1.0, 0.86, 0.42)
		_:
			_intent_icon.texture = INTENT_ICON_BUFF
	if bool(next.get("interruptible", false)):
		label_color = Color(1.0, 0.94, 0.28)
	_intent_label.add_theme_color_override("font_color", label_color)

func _start_intent_float_anim() -> void:
	if not _intent_bg: return
	var start_y = _intent_bg.position.y
	_intent_tween = create_tween().set_loops()
	_intent_tween.tween_property(_intent_bg, "position:y", start_y - 6, 1.5).set_trans(Tween.TRANS_SINE)
	_intent_tween.tween_property(_intent_bg, "position:y", start_y, 1.5).set_trans(Tween.TRANS_SINE)

# ─── Combat ───────────────────────────────────────────────────────────────────

func notify_status_changed() -> void:
	status_changed.emit()


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
	status_system.on_turn_start(self)
	if health <= 0:
		return
	block = 0
	_refresh_hud()

func end_turn() -> void:
	status_system.on_turn_end(self)
	_refresh_hud()

func _refresh_hud() -> void:
	if _hud and is_instance_valid(_hud):
		_hud.update_stats(health, max_health, block)

## Delegate to StatusEffectSystem
func add_status(status_name: String, stacks: int) -> void:
	status_system.add_status(status_name, stacks, self )

func get_status_stacks(status_name: String) -> int:
	return status_system.get_stacks(status_name)

## Returns true if a shock stack was consumed (action should be skipped/cancelled).
func consume_shock_if_present() -> bool:
	return status_system.consume_shock(self)

func get_outgoing_multiplier() -> float:
	return status_system.get_outgoing_multiplier()

func get_incoming_attack_multiplier() -> float:
	return status_system.get_incoming_attack_multiplier()

# ─── Animation Helpers ────────────────────────────────────────────────────────

## Play the attack animation once, then return to the static rest pose.
func play_attack() -> void:
	if not _sprite or not is_instance_valid(_sprite):
		return
	if not _sprite.sprite_frames.has_animation("attack") or _sprite.sprite_frames.get_frame_count("attack") == 0:
		return
	if not _sprite.animation_finished.is_connected(_on_attack_finished):
		_sprite.animation_finished.connect(_on_attack_finished, CONNECT_ONE_SHOT)
	_sprite.play("attack")

func _on_attack_finished() -> void:
	_show_rest_pose()


func _show_rest_pose() -> void:
	if not _sprite or not is_instance_valid(_sprite):
		return
	if not _sprite.sprite_frames.has_animation("attack") or _sprite.sprite_frames.get_frame_count("attack") == 0:
		return
	_sprite.play("attack")
	_sprite.pause()
	_sprite.frame = 0

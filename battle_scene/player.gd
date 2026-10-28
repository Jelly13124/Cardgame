extends Node2D
class_name PlayerEntity

## Combat state lives in the creature (core/combat/creature.gd); this node
## shows it and plays the hero's animations.
var creature = _new_creature()

var max_health: int:
	get:
		return creature.max_health
	set(value):
		creature.max_health = value
		_refresh_hud()
var health: int:
	get:
		return creature.health
	set(value):
		creature.health = value
		_refresh_hud()
var max_energy: int:
	get:
		return creature.max_energy
	set(value):
		creature.max_energy = value
var energy: int:
	get:
		return creature.energy
	set(value):
		creature.energy = value
var block: int:
	get:
		return creature.block
	set(value):
		creature.block = value

var strength: int:
	get:
		return creature.strength
	set(value):
		creature.strength = value
var constitution: int:
	get:
		return creature.constitution
	set(value):
		creature.constitution = value
var intelligence: int:
	get:
		return creature.intelligence
	set(value):
		creature.intelligence = value
var luck: int:
	get:
		return creature.luck
	set(value):
		creature.luck = value
var charm: int:
	get:
		return creature.charm
	set(value):
		creature.charm = value

signal health_changed(new_amount)
signal energy_changed(new_amount)
signal block_changed(new_amount)
signal stats_changed
signal status_changed
signal died

const HUD_SCRIPT = preload("uid://dqn0nfitycf2d")  # res://battle_scene/ui/character_hud.gd
const COMBAT_SOURCE = preload("uid://jgs131055xrk")  # res://core/combat/combat_source.gd
const CREATURE = preload("uid://kab2636ev63e")  # res://core/combat/creature.gd (res://core/combat/creature.gd)
const COMBAT_FX = preload("uid://dx2h4lk8uoasg")  # res://battle_scene/combat_fx.gd
const COMBAT_FEEDBACK_CONTROLLER = preload("uid://po237gnjpbo0")  # res://battle_scene/combat_feedback_controller.gd
const HERO_DIR = "res://battle_scene/assets/images/heroes/"
const DEFAULT_HERO_SPRITE_ID = "cowboy_bill"  # fallback when no hero data loaded  # bare-ok: sprite id
const TARGET_DISPLAY_HEIGHT := 256.0
const PLAYER_HUD_SIZE := Vector2i(200, 10)
const MUZZLE_NATIVE_POSITION := Vector2(224, 94)
const MAX_ANIMATION_FRAMES := 16

var _sprite: AnimatedSprite2D
var _fallback_sprite: Sprite2D
var _hud: Node
var status_system:
	get:
		return creature.status_system
	set(value):
		creature.status_system = value
var _death_resolving: bool = false
var _death_settled: bool = false

# ─── Yin/Yang polarity (Feng Shui Master hero) ────────────────────────────────
## Rules in core/combat/creature.gd; these forward to the creature.
var current_polarity: String:
	get:
		return creature.current_polarity
var harmony_active: bool:
	get:
		return creature.harmony_active


func reset_polarity_turn(p: String) -> void:
	creature.reset_polarity_turn(p)


func set_polarity(p: String) -> void:
	creature.set_polarity(p)


func flip_polarity() -> void:
	creature.flip_polarity()


func is_card_matched(polarity: String) -> bool:
	return creature.is_card_matched(polarity)


# ──────────────────────────────────────────────────────────────────────────────


## Sprite folder id for the current run's hero. Falls back to cowboy_bill
## if no hero data is loaded (e.g. battle scene opened standalone in editor).
func _hero_sprite_id() -> String:
	if RunManager.current_hero_data.has("sprite_id"):
		return str(RunManager.current_hero_data["sprite_id"])
	return DEFAULT_HERO_SPRITE_ID


## Modulate tint to apply to the sprite. Hero JSON's `tint` is a hex
## string like "#dd5555" — invalid / missing → white (no tint).
func _hero_tint() -> Color:
	if not RunManager.current_hero_data.has("tint"):
		return Color.WHITE
	var hex := str(RunManager.current_hero_data["tint"])
	if hex == "" or not hex.begins_with("#"):
		return Color.WHITE
	return Color.html(hex) if Color.html_is_valid(hex) else Color.WHITE


## Hero definitions can opt out of a looping rest animation. Cowboy Bill is
## intentionally static while waiting so the combat board stays visually calm;
## future heroes keep animation enabled unless their data says otherwise.
func _should_animate_idle() -> bool:
	if RunManager.current_hero_data.has("animate_idle"):
		return bool(RunManager.current_hero_data["animate_idle"])
	return _hero_sprite_id() != DEFAULT_HERO_SPRITE_ID


static func _new_creature() -> RefCounted:
	var c = CREATURE.player(100, 100)
	for attr in ["strength", "constitution", "intelligence", "luck", "charm"]:
		c.set(attr, 3)
	return c


func _init() -> void:
	creature.host = self
	creature.health_changed.connect(func(v): health_changed.emit(v))
	creature.block_changed.connect(func(v): block_changed.emit(v))
	creature.energy_changed.connect(func(v): energy_changed.emit(v))
	creature.stats_changed.connect(func(): stats_changed.emit())
	creature.status_changed.connect(func(): status_changed.emit())
	creature.pulse_requested.connect(
		func(kind: String):
			if kind == "block":
				play_block_pulse()
	)


func _ready() -> void:
	# Tag the player so per-entity combat systems can distinguish the hero from enemies.
	add_to_group("player_entity")
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
	_hud.is_player_hud = true
	_hud.bar_width = PLAYER_HUD_SIZE.x
	_hud.bar_height = PLAYER_HUD_SIZE.y
	_hud.position = Vector2(-float(PLAYER_HUD_SIZE.x) * 0.5, 28)
	_hud.bind(creature)
	add_child(_hud)


func _has_animation_frames() -> bool:
	var dir = HERO_DIR + _hero_sprite_id() + "/"
	return (
		_asset_exists(dir + "idle/%s_idle_0.png" % _hero_sprite_id())
		or _asset_exists(dir + "attack/%s_attack_0.png" % _hero_sprite_id())
	)


func _build_animated_visual() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.scale = Vector2.ONE
	_sprite.position = Vector2(0, -120)
	_sprite.flip_h = false

	var frames = SpriteFrames.new()
	_sprite.sprite_frames = frames
	_add_animation_frames(frames, "idle", _should_animate_idle(), 6.0)
	_add_animation_frames(frames, "attack", false, 18.0)
	_apply_display_scale(frames)
	_sprite.modulate = _hero_tint()
	add_child(_sprite)
	_show_rest_pose()


func _build_fallback_visual() -> void:
	var sid := _hero_sprite_id()
	# Try hero-specific block sprite first, then fall back to bill's so
	# new heroes without dedicated frames still render something visible.
	var tex_path = HERO_DIR + sid + "/%s_block_0.png" % sid
	if not ResourceLoader.exists(tex_path):
		tex_path = HERO_DIR + DEFAULT_HERO_SPRITE_ID + "/cowboy_bill_block_0.png"
	_fallback_sprite = Sprite2D.new()
	_fallback_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_fallback_sprite.scale = Vector2.ONE
	_fallback_sprite.position = Vector2(0, -96)
	_fallback_sprite.flip_h = true
	if ResourceLoader.exists(tex_path):
		_fallback_sprite.texture = load(tex_path) as Texture2D
		_apply_fallback_display_scale()
	else:
		push_warning("PlayerEntity: missing sprite '%s'" % tex_path)
	_fallback_sprite.modulate = _hero_tint()
	add_child(_fallback_sprite)


func _add_animation_frames(
	frames: SpriteFrames, anim_name: String, loops: bool, speed: float
) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_loop(anim_name, loops)
	frames.set_animation_speed(anim_name, speed)

	# Hero frames live in per-animation subfolders:
	#   heroes/{hero_id}/{anim}/{hero_id}_{anim}_N.png
	var dir = HERO_DIR + _hero_sprite_id() + "/"
	for idx in range(MAX_ANIMATION_FRAMES):
		var path = dir + "%s/%s_%s_%d.png" % [anim_name, _hero_sprite_id(), anim_name, idx]
		if not _asset_exists(path):
			break
		var tex = _load_texture(path)
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
	if frames.has_animation("idle") and frames.get_frame_count("idle") > 0:
		return frames.get_frame_texture("idle", 0)
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
	if frames and frames.has_animation("idle") and frames.get_frame_count("idle") > 0:
		_sprite.play("idle")
		_sprite.frame = 0
		if not _should_animate_idle():
			_sprite.pause()
		return
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
	_sprite.frame = 0


func _on_attack_finished() -> void:
	_show_rest_pose()


func get_muzzle_global_position() -> Vector2:
	var tex := _current_sprite_texture()
	if _sprite and is_instance_valid(_sprite) and tex:
		var native_origin := Vector2(tex.get_width(), tex.get_height()) * 0.5
		return _sprite.to_global(MUZZLE_NATIVE_POSITION - native_origin)
	if _fallback_sprite and is_instance_valid(_fallback_sprite) and _fallback_sprite.texture:
		var native_origin := (
			Vector2(_fallback_sprite.texture.get_width(), _fallback_sprite.texture.get_height())
			* 0.5
		)
		return _fallback_sprite.to_global(MUZZLE_NATIVE_POSITION - native_origin)
	return global_position + Vector2(TARGET_DISPLAY_HEIGHT * 0.38, -TARGET_DISPLAY_HEIGHT * 0.41)


func get_hit_global_position() -> Vector2:
	return global_position + Vector2(0, -TARGET_DISPLAY_HEIGHT * 0.44)


## Returns whichever sprite is actually visible right now: the AnimatedSprite2D
## if it has playable frames, otherwise the fallback Sprite2D. The feedback
## controller reacts on this art node so the HUD and status badges stay steady.
func _visible_sprite() -> Node2D:
	if _current_sprite_texture():
		return _sprite
	if _fallback_sprite and is_instance_valid(_fallback_sprite) and _fallback_sprite.texture:
		return _fallback_sprite
	return null


func _current_sprite_texture() -> Texture2D:
	if not _sprite or not is_instance_valid(_sprite):
		return null
	var frames := _sprite.sprite_frames
	if not frames:
		return null
	var anim := _sprite.animation
	if anim == "" or not frames.has_animation(anim) or frames.get_frame_count(anim) == 0:
		anim = "idle"
	if not frames.has_animation(anim) or frames.get_frame_count(anim) == 0:
		anim = "attack"
	if not frames.has_animation(anim) or frames.get_frame_count(anim) == 0:
		return null
	var frame_idx = clampi(_sprite.frame, 0, frames.get_frame_count(anim) - 1)
	return frames.get_frame_texture(anim, frame_idx)


func notify_stats_changed() -> void:
	stats_changed.emit()


func notify_status_changed() -> void:
	creature.notify_status_changed()


func take_damage(
	amount: int, silent: bool = false, feedback_tags: Dictionary = {}
) -> void:
	if _death_resolving or amount <= 0:
		return

	var dmg_after_block := maxi(0, amount - block)
	var blocked_amount := mini(block, amount)
	var remaining_health := maxi(0, health - dmg_after_block)
	var will_kill := remaining_health <= 0 and health > 0
	var apply_health_change := func() -> void:
		self.creature.apply_damage(amount)
		if self.creature.health <= 0:
			self._death_resolving = true

	if silent:
		apply_health_change.call()
	else:
		var scene := COMBAT_FEEDBACK_CONTROLLER.scene_root_for(self)
		var controller: Node = COMBAT_FEEDBACK_CONTROLLER.ensure(scene)
		if controller:
			var profile := str(
				controller.call(
					"profile_for_hit",
					dmg_after_block,
					blocked_amount,
					will_kill,
					bool(feedback_tags.get("heavy", false)),
					bool(feedback_tags.get("critical", false))
				)
			)
			_play_hit_audio(profile, feedback_tags)
			var reaction_target: Node2D = _visible_sprite()
			if reaction_target == null:
				reaction_target = self
			var play_args := [
				scene,
				reaction_target,
				get_hit_global_position(),
				dmg_after_block,
				blocked_amount,
				profile,
				apply_health_change,
			]
			if _uses_detached_feedback(feedback_tags):
				controller.callv("play_hit", play_args)
			else:
				await controller.callv("play_hit", play_args)
		else:
			apply_health_change.call()

	if will_kill:
		_settle_death_once()


func _play_hit_audio(profile: String, feedback_tags: Dictionary) -> void:
	if str(feedback_tags.get("source", "")) == "status":
		return
	if profile == "blocked":
		AudioManager.play_sfx("block_gain", -3.0, 1.12, 0.03)
		return
	var pitch := 0.84 if profile in ["heavy", "kill"] else 1.0
	AudioManager.play_sfx("player_hurt", 0.0, pitch, 0.04)


func _uses_detached_feedback(feedback_tags: Dictionary) -> bool:
	return str(feedback_tags.get("source", "")) in COMBAT_SOURCE.DETACHED_FEEDBACK_KINDS


## Red flash on the rendered sprite when hit — mirrors EnemyEntity._hit_flash. Tweens
## back to the hero tint (not pure white) so the character's colour is preserved.
func _hit_flash() -> void:
	var spr: Node2D = _visible_sprite()
	if spr == null or not is_instance_valid(spr):
		return
	spr.modulate = Color(1.7, 0.55, 0.5)
	var tw := create_tween()
	tw.tween_property(spr, "modulate", _hero_tint(), 0.22).set_trans(Tween.TRANS_QUAD)


func heal(amount: int) -> void:
	if creature.heal(amount) > 0:
		AudioManager.play_sfx("heal")


## Direct HP loss used by cards, events, and curses. Shows a floating damage
## number like take_damage but ignores Block (Intangible caps it upstream).
func lose_hp(amount: int) -> void:
	if amount <= 0 or _death_resolving:
		return
	var will_kill := health > 0 and health - amount <= 0
	creature.lose_hp(amount)
	_hit_flash()
	var scene := get_tree().current_scene
	if scene:
		var spawn_pos: Vector2 = global_position + Vector2(0, -TARGET_DISPLAY_HEIGHT * 0.5)
		COMBAT_FX.spawn_damage_number(scene, spawn_pos, amount, 0)
	if will_kill:
		_settle_death_once()


func _settle_death_once() -> void:
	if _death_settled:
		return
	_death_resolving = true
	_death_settled = true
	died.emit()


func add_block(amount: int) -> void:
	creature.add_block(amount)


## Quick scale pulse when gaining block — mirrors the enemy's block-action pulse
## (enemy_ai "block"). Killed/reset if it overlaps so scale always lands at 1.
var _block_pulse_tween: Tween


func play_block_pulse() -> void:
	if _block_pulse_tween and _block_pulse_tween.is_valid():
		_block_pulse_tween.kill()
	scale = Vector2.ONE
	_block_pulse_tween = create_tween()
	_block_pulse_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	_block_pulse_tween.tween_property(self, "scale", Vector2.ONE, 0.1)


func start_turn() -> void:
	creature.start_turn()


func end_turn() -> void:
	creature.end_turn()


## Grant Strength that lasts only until end of turn (kinetic_hammer).
func gain_temp_strength(n: int) -> void:
	creature.gain_temp_strength(n)


func gain_energy(amount: int) -> void:
	creature.gain_energy(amount)


func pay_energy(cost: int) -> bool:
	return creature.pay_energy(cost)


func _refresh_hud() -> void:
	if _hud and is_instance_valid(_hud):
		_hud.update_stats(health, max_health, block)


func add_status(status_name: String, stacks: int) -> void:
	creature.add_status(status_name, stacks)


func get_status_stacks(status_name: String) -> int:
	return status_system.get_stacks(status_name)


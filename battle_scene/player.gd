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
const COMBAT_FEEDBACK_CONTROLLER = preload("res://battle_scene/combat_feedback_controller.gd")
const HERO_DIR = "res://battle_scene/assets/images/heroes/"
const DEFAULT_HERO_SPRITE_ID = "cowboy_bill"  # fallback when no hero data loaded
const TARGET_DISPLAY_HEIGHT := 256.0
const PLAYER_HUD_SIZE := Vector2i(200, 10)
const MUZZLE_NATIVE_POSITION := Vector2(224, 94)
const MAX_ANIMATION_FRAMES := 16

var _sprite: AnimatedSprite2D
var _fallback_sprite: Sprite2D
var _hud: Node
var status_system = STATUS_SYS.new()
var _death_resolving: bool = false
var _death_settled: bool = false

# ─── Yin/Yang polarity (Feng Shui Master hero) ────────────────────────────────
## Per-battle polarity state. A polarity hero's deck is split into Yin (阴) and
## Yang (阳) cards; the starting relic alternates `current_polarity` each turn.
## A card whose polarity matches the active state resolves its `matched_bonus`.
## `flip_polarity` cards switch the active polarity mid-turn — reaching BOTH
## polarities in one turn triggers Yin-Yang Harmony (`harmony_active`), which
## lasts to end of turn and makes BOTH polarities count as matched.
##
## `current_polarity == ""` means a non-polarity hero (e.g. Cowboy Bill); the
## whole mechanic stays dormant for them.
var current_polarity: String = ""  # "yin"/"yang"/"" (empty = non-polarity hero)
var _polarities_seen: Array = []  # polarities active this turn
var harmony_active: bool = false


## Start-of-turn reset, driven by the starting relic. `p` is the turn's polarity.
func reset_polarity_turn(p: String) -> void:
	current_polarity = p
	_polarities_seen = [p]
	harmony_active = false


## Set the active polarity, tracking newly-seen polarities and (re)checking for
## Yin-Yang Harmony.
func set_polarity(p: String) -> void:
	current_polarity = p
	if not p in _polarities_seen:
		_polarities_seen.append(p)
	_check_harmony()


## Flip yin↔yang. No-op for a non-polarity hero (current_polarity == "").
func flip_polarity() -> void:
	if current_polarity == "yin":
		set_polarity("yang")
	elif current_polarity == "yang":
		set_polarity("yin")


## Returns true the first time both Yin and Yang have been active this turn
## (so the caller can grant the Harmony entry reward exactly once).
func _check_harmony() -> bool:
	if not harmony_active and ("yin" in _polarities_seen) and ("yang" in _polarities_seen):
		harmony_active = true
		return true
	return false


## Does a card of the given polarity count as "matched" right now? Harmony makes
## everything match; otherwise the card's polarity must equal the active one
## (neutral/empty polarities never match).
func is_card_matched(polarity: String) -> bool:
	return (
		harmony_active
		or (polarity != "" and polarity != "neutral" and polarity == current_polarity)
	)


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
	status_changed.emit()


func take_damage(
	amount: int, silent: bool = false, feedback_tags: Dictionary = {}
) -> void:
	if _death_resolving or amount <= 0:
		return

	var dmg_after_block := maxi(0, amount - block)
	var blocked_amount := mini(block, amount)
	var remaining_block := maxi(0, block - amount)
	var remaining_health := maxi(0, health - dmg_after_block)
	var will_kill := remaining_health <= 0 and health > 0
	var apply_health_change := func() -> void:
		self.block = remaining_block
		self.health = remaining_health
		if self.health <= 0:
			self._death_resolving = true
		self.block_changed.emit(self.block)
		self.health_changed.emit(self.health)
		self._refresh_hud()

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
	return str(feedback_tags.get("source", "")) in ["status", "relic", "thorns", "debug"]


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
	var before: int = health
	health = min(health + amount, max_health)
	if health > before:
		AudioManager.play_sfx("heal")
	health_changed.emit(health)
	_refresh_hud()


## Direct HP loss used by cards, events, and curses. Shows a floating damage
## number like take_damage but ignores Block and Dodge.
func lose_hp(amount: int) -> void:
	if amount <= 0 or _death_resolving:
		return
	var will_kill := health > 0 and health - amount <= 0
	health = max(0, health - amount)
	health_changed.emit(health)
	_refresh_hud()
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
	block += amount
	block_changed.emit(block)
	_refresh_hud()


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
	status_system.on_turn_start(self)
	if health <= 0:
		return
	energy = max_energy
	block = 0
	energy_changed.emit(energy)
	block_changed.emit(block)
	# Power upkeep that must run AFTER the block reset, else it gets wiped:
	#  - metallicize: gain Block each turn (Plating Loop)
	var mtl: int = status_system.get_stacks("metallicize")
	if mtl > 0:
		add_block(mtl)
	_refresh_hud()


func end_turn() -> void:
	status_system.on_turn_end(self)
	# Temporary Strength (kinetic_hammer) fades at end of turn.
	if _temp_strength > 0:
		strength = max(0, strength - _temp_strength)
		_temp_strength = 0
		notify_stats_changed()
	_refresh_hud()


## Temporary Strength granted this turn (relic gain_temp_strength). Removed in
## end_turn so the buff lasts a single turn.
var _temp_strength: int = 0


## Grant Strength that lasts only until end of turn (kinetic_hammer).
func gain_temp_strength(n: int) -> void:
	if n <= 0:
		return
	strength += n
	_temp_strength += n
	notify_stats_changed()


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

## EnemyEntity — loads its stats and action pattern from a JSON data file.
## Spawn via: EnemyEntity.create("trash_robot")
## The action_pattern cycles each turn. Intent is shown above the HUD.
extends Node2D
class_name EnemyEntity

const HUD_SCRIPT = preload("uid://dqn0nfitycf2d")  # res://battle_scene/ui/character_hud.gd
const COMBAT_SOURCE = preload("uid://jgs131055xrk")  # res://core/combat/combat_source.gd
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const MODEL_ID = preload("uid://ddtqasxna3kbq")  # res://core/content/model_id.gd
const STATUS_SYS = preload("uid://cq4eulp4ci8is")  # res://core/combat/status_effects.gd
const MONSTER_MOVES = preload("uid://bqwa1txur3b52")  # res://core/combat/monster_moves.gd
const INTENTS = preload("uid://crt5cmvargkpn")  # res://core/combat/intents.gd
const CREATURE = preload("uid://kab2636ev63e")  # res://core/combat/creature.gd
const SELECTION_RETICLE = preload("uid://c6dicaops28n6")  # res://battle_scene/ui/selection_reticle.gd
const COMBAT_EFFECTS = preload("uid://do16of5onpg33")  # res://battle_scene/combat/combat_effects.gd
const COMBAT_FEEDBACK_CONTROLLER = preload("uid://po237gnjpbo0")  # res://battle_scene/combat_feedback_controller.gd

# Intent badge icon textures — preloaded once instead of `load()`-ing on every
# intent refresh (which can fire frequently as enemy / player status changes).
const INTENT_ICON_ATTACK = preload("res://battle_scene/assets/images/ui/intent_attack.png")
const INTENT_ICON_BLOCK = preload("res://battle_scene/assets/images/ui/intent_block.png")
const INTENT_ICON_BUFF = preload("res://battle_scene/assets/images/ui/intent_buff.png")
const INTENT_ICON_CHARGE = preload("res://battle_scene/assets/images/ui/intent_charge.png")
const INTENT_ICON_DEBUFF = preload("res://battle_scene/assets/images/ui/intent_debuff.png")
const NORMAL_DISPLAY_HEIGHT := 256.0
const ELITE_DISPLAY_HEIGHT := 320.0
const BOSS_DISPLAY_HEIGHT := 384.0
const NORMAL_HUD_SIZE := Vector2i(200, 10)
const ELITE_HUD_SIZE := Vector2i(200, 10)
const BOSS_HUD_SIZE := Vector2i(200, 10)
const MAX_ANIMATION_FRAMES := 16
const INTENT_BADGE_WIDTH := 104.0
const INTENT_BADGE_HEIGHT := 36.0
const INTENT_CELL_ICON_SIZE := Vector2(34.0, 34.0)

# ─── Stats ────────────────────────────────────────────────────────────────────
## Combat state lives in the creature (core/combat/creature.gd); this node
## shows it, its intent and its animations.
var creature = CREATURE.new()

var enemy_id: String:
	get:
		return creature.enemy_id
	set(value):
		creature.enemy_id = value
var enemy_name: String:
	get:
		return creature.enemy_name
	set(value):
		creature.enemy_name = value
var is_elite: bool:
	get:
		return creature.is_elite
	set(value):
		creature.is_elite = value
## True for act bosses (spec A3). A boss dying ends the fight even if summoned
## adds remain (enemy_ai._on_enemy_died frees the rest + declares victory).
## Bosses are always solo-spawned at the act top, so "a boss died" = "the act
## boss died". Summoned adds are never bosses.
var is_boss: bool:
	get:
		return creature.is_boss
	set(value):
		creature.is_boss = value
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
var block: int:
	get:
		return creature.block
	set(value):
		creature.block = value
		_refresh_hud()
var _death_resolving: bool = false
var _death_settled: bool = false
## ID used to locate sprite frames: e.g. "trash_robot" -> trash_robot_attack_0.png
var sprite_id: String = ""

## Composed status effect system
var status_system:
	get:
		return creature.status_system
	set(value):
		creature.status_system = value
## Battle this enemy fights in; set by combat_commands.attach().
var battle: Node = null

# ─── Moves ────────────────────────────────────────────────────────────────────
## The move state machine lives on the creature (core/combat/monster_moves.gd).
var action_pattern: Array:
	get:
		return creature.moves.action_pattern
	set(value):
		creature.moves.action_pattern = value
var phases: Array:
	get:
		return creature.moves.phases
	set(value):
		creature.moves.phases = value

signal died
signal status_changed
signal attack_animation_finished

# ─── Internal Nodes ───────────────────────────────────────────────────────────
var _hud: Node
## Reference to the animated sprite (replaces old ColorRect body)
var _sprite: AnimatedSprite2D
var _intent_cells: HBoxContainer
var _intent_bg: Control
var _intent_tween: Tween
var _intent_tooltip: String = ""
var _display_size := Vector2(NORMAL_DISPLAY_HEIGHT, NORMAL_DISPLAY_HEIGHT)
var _content_height := NORMAL_DISPLAY_HEIGHT

## Base path for enemy sprite assets — each enemy gets its own subfolder: {ENEMIES_DIR}{sprite_id}/
const ENEMIES_DIR = "res://battle_scene/assets/images/enemies/"

# ─── Factory ──────────────────────────────────────────────────────────────────


## Create and return a fully initialized EnemyEntity from a JSON id.
static func create(id: String) -> EnemyEntity:
	var entity = EnemyEntity.new()
	entity.enemy_id = id
	entity.is_elite = id in RunManager.ELITE_ROSTER
	entity.is_boss = id in RunManager.ACT_BOSSES
	# Writable copy: action patterns and phases are per-instance runtime state.
	var data: Dictionary = MODEL_DB.mutable("monster", id)
	if not data.is_empty():
		# Display name routes through the content-translation table; the
		# English JSON `name` is the source/fallback (content agents own
		# the ENEMY_<id>_NAME rows in content_enemies.csv).
		entity.enemy_name = Settings.t(
			"ENEMY_%s_NAME" % MODEL_ID.key_entry(id), str(data.get("name", MODEL_ID.key_entry(id).to_upper()))
		)
		entity.max_health = int(data.get("max_health", 30))
		# Tough enemies: HP scales by a percentage per ascension level.
		if RunManager.has_ascension("base:a1_tough_enemies"):
			var pct := float(RunManager.ascension_param("base:a1_tough_enemies", "hp_pct_per_level", 10))
			entity.max_health = int(
				round(entity.max_health * (1.0 + pct / 100.0 * RunManager.ascension))
			)
		# Per-act scaling (bosses exempt — see RunManager.scale_enemy_hp).
		entity.max_health = RunManager.scale_enemy_hp(entity.max_health, id)
		entity.health = entity.max_health
		entity.creature.moves = MONSTER_MOVES.from_data(data)
		entity.sprite_id = data.get("sprite_id", "")
	else:
		push_error(
			(
				"EnemyEntity: unknown monster '%s'. Encounter will spawn a placeholder enemy."
				% id
			)
		)
		assert(false, "EnemyEntity: unknown monster '%s'" % id)
	return entity


# ─── Lifecycle ────────────────────────────────────────────────────────────────


func _init() -> void:
	creature.side = "enemy"
	creature.max_health = 30
	creature.health = 30
	creature.host = self
	creature.moves = MONSTER_MOVES.new()
	creature.status_changed.connect(func(): status_changed.emit())
	creature.intent_changed.connect(_update_intent_display)


func _ready() -> void:
	_build_visual()
	_update_intent_display()
	_start_intent_float_anim()
	# Refresh intent whenever this enemy's own status changes (e.g. stun /
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
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.scale = Vector2.ONE
	_sprite.position = Vector2(0, -96)
	_sprite.flip_h = false  # enemy PNGs already face left toward the player

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
	frames.set_animation_speed("attack", 12.0)
	for idx in range(MAX_ANIMATION_FRAMES):
		var tex = _load_tex.call(dir + "attack/%s_attack_%d.png" % [sid, idx], idx == 0)
		if tex:
			frames.add_frame("attack", tex)
		elif idx > 0:
			break

	# ── Charge (optional, one-shot — used by boss telegraph) ─────────────────
	var charge_frames: Array[Texture2D] = []
	for idx in range(MAX_ANIMATION_FRAMES):
		var tex = _load_tex.call(dir + "charge/%s_charge_%d.png" % [sid, idx], false)
		if tex:
			charge_frames.append(tex)
		elif idx > 0:
			break
	if not charge_frames.is_empty():
		frames.add_animation("charge")
		frames.set_animation_loop("charge", false)
		frames.set_animation_speed("charge", 6.0)
		for tex in charge_frames:
			frames.add_frame("charge", tex)

	# Hurt frames are no longer used — hit feedback is a red flash (see _hit_flash).

	var display_height := _apply_display_scale(frames)
	add_child(_sprite)
	_show_rest_pose()

	_build_intent_badge(Vector2(-INTENT_BADGE_WIDTH * 0.5, -display_height - 48.0))
	_build_health_bar(Vector2(-112.5, 28))


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
	var target_height := NORMAL_DISPLAY_HEIGHT
	if is_boss:
		target_height = BOSS_DISPLAY_HEIGHT
	elif is_elite:
		target_height = ELITE_DISPLAY_HEIGHT
	var display_scale := target_height / native_height
	_sprite.scale = Vector2(display_scale, display_scale)
	_sprite.position = Vector2(0, -target_height * 0.5)
	_display_size = Vector2(float(tex.get_width()) * display_scale, target_height)

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
	_content_height = target_height - top_offset_displayed
	return _content_height


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
	var native_hit := Vector2(tex.get_width() * 0.34, tex.get_height() * 0.54)
	return _sprite.to_global(native_hit - native_origin)


## Target reticle (STS2 NSelectionReticle) around the targeting rect; created
## on first use so its rect matches the built sprite.
var _reticle: Node2D


func show_reticle() -> void:
	if _reticle == null:
		_reticle = SELECTION_RETICLE.new()
		add_child(_reticle)
	var rect := get_targeting_rect()
	var local_rect := Rect2(rect.position - global_position, rect.size)
	if global_scale != Vector2.ZERO:
		local_rect = Rect2(local_rect.position / global_scale, local_rect.size / global_scale)
	_reticle.set_rect(local_rect)
	_reticle.show_reticle()


func hide_reticle() -> void:
	if _reticle:
		_reticle.hide_reticle()


func reticle_shown() -> bool:
	return _reticle != null and _reticle.is_shown()


func get_targeting_rect() -> Rect2:
	var width: float = _display_size.x * 0.75
	if width < 84.0:
		width = 84.0
	var height: float = _content_height
	if height < 84.0:
		height = 84.0
	return Rect2(global_position.x - width * 0.5, global_position.y - height, width, height)


## Fallback: procedural colored rectangle for enemies without sprite art yet.
func _build_placeholder_visual() -> void:
	var body = ColorRect.new()
	body.color = Color(0.7, 0.15, 0.15)
	body.size = Vector2(256, 256)
	body.position = Vector2(-128, -256)
	add_child(body)
	_display_size = body.size
	_content_height = body.size.y
	_build_intent_badge(Vector2(-INTENT_BADGE_WIDTH * 0.5, -304))
	_build_health_bar(Vector2(-112.5, 28))


## Builds a compact STS2-style category-intent group above the sprite.
## intent_pos is the top-left position in entity-local space.
func _build_intent_badge(intent_pos: Vector2) -> void:
	_intent_bg = Control.new()
	_intent_bg.size = Vector2(INTENT_BADGE_WIDTH, INTENT_BADGE_HEIGHT)
	_intent_bg.position = intent_pos
	# STOP (not IGNORE) so the badge can detect hover for its tooltip.
	_intent_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_intent_bg.z_index = 20
	add_child(_intent_bg)
	# Tooltip on hover: a plain-language read of what the enemy will do next.
	# Same stale-guard pattern as the status badges.
	var bg_ref: Control = _intent_bg
	var bg_id: int = _intent_bg.get_instance_id()
	_intent_bg.mouse_entered.connect(
		func():
			if not is_instance_valid(bg_ref) or _intent_tooltip == "":
				return
			Tooltip.show(
				_intent_tooltip, bg_ref.global_position + Vector2(bg_ref.size.x * 0.5, 0), bg_id
			)
	)
	_intent_bg.mouse_exited.connect(Tooltip.hide_if_owner.bind(bg_id))
	_intent_bg.tree_exited.connect(Tooltip.hide_if_owner.bind(bg_id))

	_intent_cells = HBoxContainer.new()
	_intent_cells.name = "IntentCells"
	_intent_cells.alignment = BoxContainer.ALIGNMENT_CENTER
	_intent_cells.add_theme_constant_override("separation", 7)
	_intent_cells.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intent_cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intent_bg.add_child(_intent_cells)


## Builds the health bar (CharacterHUD) below the sprite. Every enemy uses the
## same lightweight 200x10 footprint as the player; encounter weight stays in
## sprite scale and intent presentation rather than HUD chrome.
func _build_health_bar(hud_pos: Vector2) -> void:
	var hud_size := _health_bar_size()
	_hud = HUD_SCRIPT.new()
	_hud.max_health = max_health
	_hud.current_health = health
	_hud.current_block = block
	_hud.bar_width = hud_size.x
	_hud.bar_height = hud_size.y
	_hud.position = Vector2(-float(hud_size.x) * 0.5, hud_pos.y)
	_hud.bind(creature)
	add_child(_hud)


func _health_bar_size() -> Vector2i:
	if is_boss:
		return BOSS_HUD_SIZE
	if is_elite:
		return ELITE_HUD_SIZE
	return NORMAL_HUD_SIZE


# ─── Action Pattern ───────────────────────────────────────────────────────────


## Returns the current action without advancing the index.
func peek_next_action() -> Dictionary:
	return creature.moves.peek()


## Returns the current action AND advances to the next one.
func consume_next_action() -> Dictionary:
	var a: Dictionary = creature.moves.consume()
	_update_intent_display()
	return a


## Refreshes the intent badge to show what this enemy will do NEXT turn.
## Public — called by BattleScene to broadcast player-status changes
## (e.g. vulnerable applied to player) to every enemy.
func update_intent_display() -> void:
	_update_intent_display()


## Damage the player would take from `action` right now, computed by the
## shared pipeline in preview mode (the same calculation the attack uses).
## Before the battle attaches this enemy, the move's printed amount.
func intent_attack_damage(action: Dictionary) -> int:
	if battle and is_instance_valid(battle) and battle.get("combat_commands"):
		return COMBAT_EFFECTS.preview_enemy_attack(battle, self, action)
	return int(action.get("amount", 0))


func _add_intent_cell(
	kind: String, texture: Texture2D, value: String, color: Color
) -> Control:
	var cell := HBoxContainer.new()
	cell.name = "Intent%s" % kind
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_theme_constant_override("separation", 2)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = INTENT_CELL_ICON_SIZE
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(icon)

	if value != "":
		var label := Label.new()
		label.name = "IntentValue"
		label.text = value
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", color)
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(label)

	_intent_cells.add_child(cell)
	return cell


func _update_intent_display() -> void:
	if not _intent_cells:
		return
	for child in _intent_cells.get_children():
		_intent_cells.remove_child(child)
		child.queue_free()

	var next := peek_next_action()
	var action_type := str(next.get("type", ""))
	match action_type:
		"attack", "attack_ramp", "attack_all":
			_add_intent_cell(
				"Attack",
				INTENT_ICON_ATTACK,
				str(intent_attack_damage(next)),
				Color("#ffc69e")
			)
		"attack_status":
			_add_intent_cell(
				"Attack",
				INTENT_ICON_ATTACK,
				str(intent_attack_damage(next)),
				Color("#ffc69e")
			)
			_add_intent_cell("Debuff", INTENT_ICON_DEBUFF, "", Color.WHITE)
		"block", "breakable_block":
			_add_intent_cell(
				"Block",
				INTENT_ICON_BLOCK,
				str(int(next.get("amount", 0))),
				Color("#a6dbff")
			)
		"reflective_plating":
			_add_intent_cell(
				"Block",
				INTENT_ICON_BLOCK,
				str(int(next.get("amount", 0))),
				Color("#a6dbff")
			)
			_add_intent_cell(
				"Buff",
				INTENT_ICON_BUFF,
				str(int(next.get("thorns", 0))),
				Color("#b8ff9e")
			)
		"heal", "buff", "buff_self":
			var amount := int(next.get("amount", next.get("stacks", 0)))
			_add_intent_cell(
				"Buff",
				INTENT_ICON_BUFF,
				str(amount) if amount > 0 else "",
				Color("#b8ff9e")
			)
		"add_curse":
			_add_intent_cell("Debuff", INTENT_ICON_DEBUFF, "", Color.WHITE)
		"telegraph", "summon":
			_add_intent_cell("Charge", INTENT_ICON_CHARGE, "", Color("#ffdb6b"))
		_:
			_add_intent_cell("Buff", INTENT_ICON_BUFF, "", Color("#b8ff9e"))
	_intent_tooltip = intent_text(next)


## Plain-language description of an action (the intent tooltip, and the
## interrupt message): core/combat/intents.gd with this enemy's attack damage.
func intent_text(next: Dictionary, with_tips: bool = true) -> String:
	return INTENTS.text(next, intent_attack_damage(next), with_tips)


func _start_intent_float_anim() -> void:
	if not _intent_bg:
		return
	var start_y = _intent_bg.position.y
	_intent_tween = create_tween().set_loops()
	_intent_tween.tween_property(_intent_bg, "position:y", start_y - 6, 1.5).set_trans(
		Tween.TRANS_SINE
	)
	_intent_tween.tween_property(_intent_bg, "position:y", start_y, 1.5).set_trans(Tween.TRANS_SINE)


# ─── Combat ───────────────────────────────────────────────────────────────────


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
	var applied: Array = [{}]
	var from_player := str(feedback_tags.get("source", "")) == "player"
	var apply_health_change := func() -> void:
		applied[0] = self.creature.apply_damage(amount, from_player)
		if self.creature.health <= 0:
			self._death_resolving = true

	# Status ticks stay quiet because their status banner is already the readable
	# result. Direct attacks all use the shared four-tier feedback controller.
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
			var reaction_target: Node2D = _sprite if is_instance_valid(_sprite) else self
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
		if _death_settled:
			return
		_death_settled = true
		AudioManager.play_sfx("enemy_death")
		# Per-kill gold drop, scaled by toughness (elites pay double). Keeps the purse
		# flowing between the flat per-fight loot gold so the shop stays affordable
		# across the run. max_health is already act/ascension-scaled, so deeper
		# fights naturally pay more.
		var kill_gold := clampi(2 + max_health / 30, 1, 9)
		if is_elite:
			kill_gold *= 2
		RunManager.add_gold(kill_gold)
		# Bounty: one kill event per death (this branch is the single death gate —
		# it pays kill gold + emits `died` exactly once; _live_target guards
		# upstream keep dead enemies from re-entering take_damage).
		RunManager.enemy_killed(self)
		died.emit()
		queue_free()
		return

	if bool(applied[0].get("armor_broken", false)):
		_play_armor_break_reaction()



## Arms the Block gained this move as breakable armor: player damage that
## removes all of it exposes this enemy. Re-arming replaces the previous
## exposure payload rather than stacking traps.
func arm_breakable_armor(status: String, stacks: int) -> void:
	creature.arm_breakable_armor(status, stacks)


func _play_armor_break_reaction() -> void:
	if not _sprite or not is_instance_valid(_sprite):
		return
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(1.5, 0.62, 0.38), 0.08)
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.18)


func _play_hit_audio(profile: String, feedback_tags: Dictionary) -> void:
	if str(feedback_tags.get("source", "")) == "status":
		return
	if profile == "blocked":
		AudioManager.play_sfx("block_gain", -3.0, 1.18, 0.03)
		return
	var pitch := 0.84 if profile in ["heavy", "kill"] else 1.0
	AudioManager.play_sfx("attack_hit", 0.0, pitch, 0.04)
	if bool(feedback_tags.get("critical", false)):
		AudioManager.play_sfx("crit", -1.5, 1.0, 0.0)


func _uses_detached_feedback(feedback_tags: Dictionary) -> bool:
	return str(feedback_tags.get("source", "")) in COMBAT_SOURCE.DETACHED_FEEDBACK_KINDS


## Drains queued on_enter actions from a just-entered phase (run by enemy_ai at
## the start of this enemy's turn).
func consume_pending_on_enter() -> Array:
	return creature.moves.consume_pending_on_enter()


func add_block(amount: int) -> void:
	creature.add_block(amount)


func heal(amount: int) -> void:
	creature.heal(amount)


func start_turn() -> void:
	creature.start_turn()


func end_turn() -> void:
	creature.end_turn()


func _refresh_hud() -> void:
	if _hud and is_instance_valid(_hud):
		_hud.update_stats(health, max_health, block)


## Delegate to StatusEffectSystem
func add_status(status_name: String, stacks: int) -> void:
	creature.add_status(status_name, stacks)


func get_status_stacks(status_name: String) -> int:
	return status_system.get_stacks(status_name)


## Returns true if a stun stack was consumed (action should be skipped/cancelled).
func consume_stun_if_present() -> bool:
	return creature.consume_stun_if_present()


# ─── Animation Helpers ────────────────────────────────────────────────────────


func has_attack_animation() -> bool:
	return (
		_sprite
		and is_instance_valid(_sprite)
		and _sprite.sprite_frames.has_animation("attack")
		and _sprite.sprite_frames.get_frame_count("attack") > 0
	)


## Play the attack animation once, then return to the static rest pose.
func play_attack() -> void:
	if not has_attack_animation():
		emit_signal("attack_animation_finished")
		return
	if not _sprite.animation_finished.is_connected(_on_attack_finished):
		_sprite.animation_finished.connect(_on_attack_finished, CONNECT_ONE_SHOT)
	_sprite.stop()
	_sprite.animation = "attack"
	_sprite.frame = 0
	_sprite.frame_progress = 0.0
	_sprite.play("attack")


func _on_attack_finished() -> void:
	_show_rest_pose()
	emit_signal("attack_animation_finished")


func _show_rest_pose() -> void:
	if not _sprite or not is_instance_valid(_sprite):
		return
	if (
		not _sprite.sprite_frames.has_animation("attack")
		or _sprite.sprite_frames.get_frame_count("attack") == 0
	):
		return
	_sprite.play("attack")
	_sprite.pause()
	_sprite.frame = 0

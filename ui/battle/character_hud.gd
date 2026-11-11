## CharacterHUD — independently readable HP, delayed damage, Block and statuses.
extends Control
class_name CharacterHUD

const HP_FRAME_TEXTURE = preload("uid://b2u0iqtxuidao")  # res://battle_scene/assets/images/ui/combat/hp_frame.png
const HP_TRACK_TEXTURE = preload("uid://gv1jempqnjx")  # res://battle_scene/assets/images/ui/combat/hp_track.png
const HP_FILL_TEXTURE = preload("uid://d2155rjnybhx8")  # res://battle_scene/assets/images/ui/combat/hp_fill.png
const HP_LOSS_TEXTURE = preload("uid://dhfm1ghrfe5f2")  # res://battle_scene/assets/images/ui/combat/hp_loss.png
const BLOCK_BADGE_TEXTURE = preload("uid://ca643u7b4lt6h")  # res://battle_scene/assets/images/ui/block_badge.png
const T = preload("uid://dfcqloc58bvde")  # res://ui/common/theme/wasteland_theme.gd
const STATUS_BADGES_VIEW = preload("uid://3i0uuprky2dc")  # res://ui/battle/status_badges_view.gd
const HP_SIZE := Vector2(250, 16)
const BLOCK_SIZE := Vector2(42, 49)
const BLOCK_POSITION := Vector2(-21, -21)
const HP_LOSS_HOLD_SECONDS := 1.0
const HP_ECHO_SECONDS := 1.0


class HealthValueText:
	extends Control

	var text := "":
		set(value):
			text = value
			queue_redraw()
	var font_size := 24
	var font_color: Color
	var outline_color: Color
	var outline_size := 16
	var display_font: Font

	func _draw() -> void:
		var font := display_font if display_font != null else get_theme_default_font()
		var text_size := font.get_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size
		)
		var line_height := font.get_height(font_size)
		var origin := Vector2(
			(size.x - text_size.x) * 0.5,
			(size.y - line_height) * 0.5 + font.get_ascent(font_size)
		)
		draw_string_outline(
			font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			font_size, outline_size, outline_color
		)
		draw_string(
			font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, font_color
		)


@export var max_health: int = 100
@export var current_health: int = 100
@export var current_block: int = 0
# Retained for callers which position this HUD from its dimensions.
@export var bar_width: int = 250
@export var bar_height: int = 16
@export var is_player_hud: bool = false

var _hp_bar: TextureProgressBar
var _hp_loss: TextureProgressBar
var _hp_label: HealthValueText
var _block_badge: TextureRect
var _block_label: Label
var _block_break: Control
var _status_badges: HFlowContainer
var _creature: Object = null
var _has_initialized_stats := false
# Store HP rather than a fraction so changing maximum HP cannot leave a tween
# heading towards a fraction calculated for the previous maximum.
var _hp_echo_health := 0.0
var _hp_fill_health := 0.0
var _hp_echo_tween: Tween
var _hp_fill_tween: Tween
var _block_appear_tween: Tween
var _block_break_tween: Tween


func _ready() -> void:
	_build_ui()
	update_stats(current_health, max_health, current_block)
	_on_creature_status_changed()


func _build_ui() -> void:
	bar_width = int(HP_SIZE.x)
	bar_height = int(HP_SIZE.y)
	size = HP_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frame := _texture_rect("HpFrame", HP_FRAME_TEXTURE, HP_SIZE)
	add_child(frame)

	var track := _texture_rect("HpTrack", HP_TRACK_TEXTURE, HP_SIZE)
	track.show_behind_parent = true
	frame.add_child(track)

	_hp_loss = _health_fill("HpLoss", HP_LOSS_TEXTURE)
	frame.add_child(_hp_loss)
	_hp_bar = _health_fill("HpBar", HP_FILL_TEXTURE)
	frame.add_child(_hp_bar)

	_hp_label = HealthValueText.new()
	_hp_label.name = "HpLabel"
	_hp_label.position = Vector2(0, -12)
	_hp_label.size = Vector2(HP_SIZE.x, 40)
	_hp_label.font_color = T.COMBAT_HP_TEXT
	_hp_label.outline_color = T.COMBAT_HP_OUTLINE
	_hp_label.display_font = T.combat_font(700)
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_hp_label)

	_block_badge = TextureRect.new()
	_block_badge.name = "BlockBadge"
	var cropped_badge := AtlasTexture.new()
	cropped_badge.atlas = BLOCK_BADGE_TEXTURE
	cropped_badge.region = Rect2(9, 5, 46, 54)
	_block_badge.texture = cropped_badge
	_block_badge.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_block_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_block_badge.position = BLOCK_POSITION
	_block_badge.custom_minimum_size = Vector2.ZERO
	_block_badge.size = BLOCK_SIZE
	_block_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block_badge.visible = false
	add_child(_block_badge)

	_block_label = Label.new()
	_block_label.name = "BlockLabel"
	_block_label.position = Vector2(0, -3)
	_block_label.size = BLOCK_SIZE
	_block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_block_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_block_label.add_theme_font_size_override("font_size", 25)
	_block_label.add_theme_color_override("font_color", Color.WHITE)
	_block_label.add_theme_color_override("font_outline_color", Color("#10283b"))
	_block_label.add_theme_constant_override("outline_size", 2)
	_block_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block_badge.add_child(_block_label)

	_status_badges = HFlowContainer.new()
	_status_badges.name = "StatusBadges"
	_status_badges.position = Vector2(0, 30)
	_status_badges.size = Vector2(HP_SIZE.x, 40)
	_status_badges.alignment = FlowContainer.ALIGNMENT_CENTER
	_status_badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_badges.add_theme_constant_override("h_separation", 0)
	_status_badges.add_theme_constant_override("v_separation", 4)
	add_child(_status_badges)


func _texture_rect(node_name: String, texture: Texture2D, dimensions: Vector2) -> TextureRect:
	var image := TextureRect.new()
	image.name = node_name
	image.texture = texture
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.size = dimensions
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image


func _health_fill(node_name: String, texture: Texture2D) -> TextureProgressBar:
	var fill := TextureProgressBar.new()
	fill.name = node_name
	fill.texture_progress = texture
	fill.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fill.step = 0.0
	fill.size = HP_SIZE
	fill.show_behind_parent = true
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return fill


## Follow `creature` (core/combat/creature.gd): HP, Block and status badges
## refresh when it announces a change.
func bind(creature: Object) -> void:
	_creature = creature
	creature.health_changed.connect(_on_creature_changed.unbind(1))
	creature.block_changed.connect(_on_creature_changed.unbind(1))
	creature.status_changed.connect(_on_creature_status_changed)
	_on_creature_status_changed()


func _on_creature_changed() -> void:
	if _creature != null:
		update_stats(_creature.health, _creature.max_health, _creature.block)


func _on_creature_status_changed() -> void:
	if _creature != null and _status_badges != null:
		STATUS_BADGES_VIEW.rebuild(_status_badges, _creature.status_system.snapshot())


## Synchronize a newly restored combat state without presenting it as damage,
## healing or Block feedback. Subsequent update_stats calls animate normally.
func snap_stats(hp: int, max_hp: int, blk: int) -> void:
	current_health = maxi(0, hp)
	max_health = maxi(1, max_hp)
	current_block = maxi(0, blk)
	if not _hp_bar:
		return
	for transition in [_hp_fill_tween, _hp_echo_tween, _block_appear_tween]:
		if transition != null:
			transition.kill()
	_hp_fill_tween = null
	_hp_echo_tween = null
	_block_appear_tween = null
	_cancel_block_break()
	_set_fill_health(float(current_health))
	_set_echo_health(float(current_health))
	_hp_label.text = "%d/%d" % [current_health, max_health]
	_block_label.text = str(current_block)
	_block_badge.position = BLOCK_POSITION
	_block_badge.modulate.a = 1.0
	_block_badge.visible = current_block > 0
	_has_initialized_stats = true


func update_stats(hp: int, max_hp: int, blk: int) -> void:
	var previous_health := current_health
	var previous_block := current_block
	current_health = maxi(0, hp)
	max_health = maxi(1, max_hp)
	current_block = maxi(0, blk)
	if not _hp_bar:
		return
	_hp_label.text = "%d/%d" % [current_health, max_health]
	_block_label.text = str(current_block)
	if not _has_initialized_stats:
		snap_stats(current_health, max_health, current_block)
		return

	# Maximum-only and Block-only updates reproject the displayed absolute HP
	# without completing or restarting either transition.
	_set_fill_health(_hp_fill_health)
	_set_echo_health(_hp_echo_health)
	if current_health != previous_health:
		var is_damage := current_health < previous_health
		_refresh_health_fill(is_damage)
		_refresh_health_echo(is_damage)
	_refresh_block(previous_block)


func _set_fill_health(value: float) -> void:
	_hp_fill_health = value
	_hp_bar.ratio = value / float(max_health)


func _refresh_health_fill(is_damage: bool) -> void:
	if _hp_fill_tween != null:
		_hp_fill_tween.kill()
		_hp_fill_tween = null
	if is_damage:
		_set_fill_health(float(current_health))
		return
	_hp_fill_tween = create_tween()
	_hp_fill_tween.tween_method(
		_set_fill_health, _hp_fill_health, float(current_health), HP_ECHO_SECONDS
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_hp_fill_tween.tween_callback(func(): _hp_fill_tween = null)


func _set_echo_health(value: float) -> void:
	_hp_echo_health = value
	_hp_loss.ratio = value / float(max_health)


func _refresh_health_echo(is_damage: bool) -> void:
	if _hp_echo_tween != null:
		_hp_echo_tween.kill()
	# Healing may be interrupted while the echo is below the real fill. Keep
	# damage echoes outside the current fill without resetting an existing loss.
	if is_damage:
		_set_echo_health(maxf(_hp_echo_health, float(current_health)))
	_hp_echo_tween = create_tween()
	if is_damage:
		_hp_echo_tween.tween_interval(HP_LOSS_HOLD_SECONDS)
	_hp_echo_tween.tween_method(
		_set_echo_health, _hp_echo_health, float(current_health), HP_ECHO_SECONDS
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_hp_echo_tween.tween_callback(func(): _hp_echo_tween = null)


func _refresh_block(previous_block: int) -> void:
	if current_block > 0:
		_block_badge.visible = true
		if previous_block <= 0:
			_appear_block()
	elif previous_block > 0:
		if _block_appear_tween != null:
			_block_appear_tween.kill()
			_block_appear_tween = null
		_block_badge.visible = false


func _appear_block() -> void:
	if _block_appear_tween != null:
		_block_appear_tween.kill()
	_block_badge.position = BLOCK_POSITION + Vector2(0, 12)
	_block_badge.modulate.a = 0.0
	_block_appear_tween = create_tween().set_parallel()
	_block_appear_tween.tween_property(
		_block_badge, "modulate:a", 1.0, 0.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_block_appear_tween.tween_property(
		_block_badge, "position", BLOCK_POSITION, 0.5
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _cancel_block_break() -> void:
	_block_break_tween = null
	_block_break = null

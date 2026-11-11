## CharacterHUD — separate health and Block readouts.
extends Control
class_name CharacterHUD

const HP_FRAME_TEXTURE = preload("res://battle_scene/assets/images/ui/hp_bar_frame.png")
const HP_FILL_TEXTURE = preload("res://battle_scene/assets/images/ui/hp_bar_fill.png")
const BLOCK_BADGE_TEXTURE = preload("res://battle_scene/assets/images/ui/block_badge.png")
const T = preload("uid://dfcqloc58bvde")  # res://ui/common/theme/wasteland_theme.gd
const STATUS_BADGES_VIEW = preload("uid://3i0uuprky2dc")  # res://ui/battle/status_badges_view.gd


class HealthValueText:
	extends Control

	var text := "":
		set(value):
			text = value
			queue_redraw()
	var font_size := 30
	var font_color := Color("#fff8e8")
	var outline_color := Color("#071018")
	var outline_size := 3
	var accent_outline_color := Color("#6a1718")
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
			font,
			origin + Vector2(0, 1),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			outline_size + 1,
			Color(0, 0, 0, 0.65)
		)
		draw_string_outline(
			font,
			origin,
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			outline_size,
			outline_color
		)
		draw_string_outline(
			font,
			origin,
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			1,
			accent_outline_color
		)
		draw_string(
			font,
			origin,
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			font_color
		)

@export var max_health: int = 100
@export var current_health: int = 100
@export var current_block: int = 0
@export var bar_width: int = 200
@export var bar_height: int = 10
@export var is_player_hud: bool = false

var _hp_bar: TextureProgressBar
var _hp_label: HealthValueText
var _block_badge: TextureRect
var _block_label: Label
var _status_badges: HBoxContainer
var _creature: Object = null


func _ready() -> void:
	_build_ui()
	update_stats(current_health, max_health, current_block)
	_on_creature_status_changed()


func _build_ui() -> void:
	size = Vector2(bar_width, bar_height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frame_height := HP_FRAME_TEXTURE.get_height()
	var frame := NinePatchRect.new()
	frame.name = "HpFrame"
	frame.texture = HP_FRAME_TEXTURE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	frame.patch_margin_left = 8
	frame.patch_margin_right = 8
	frame.patch_margin_top = 5
	frame.patch_margin_bottom = 5
	frame.position = Vector2(0, (bar_height - frame_height) * 0.5 - 1)
	frame.size = Vector2(bar_width, frame_height)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	var track := ColorRect.new()
	track.color = T.COMBAT_TRACK_BG
	track.position = Vector2(6, 5)
	track.size = Vector2(bar_width - 12, frame_height - 10)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(track)

	_hp_bar = TextureProgressBar.new()
	_hp_bar.name = "HpBar"
	_hp_bar.texture_progress = HP_FILL_TEXTURE
	_hp_bar.nine_patch_stretch = true
	_hp_bar.stretch_margin_left = 1
	_hp_bar.stretch_margin_right = 1
	_hp_bar.stretch_margin_top = 1
	_hp_bar.stretch_margin_bottom = 1
	_hp_bar.step = 0.0
	_hp_bar.position = track.position
	_hp_bar.size = track.size
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_hp_bar)

	_hp_label = HealthValueText.new()
	_hp_label.name = "HpLabel"
	_hp_label.position = Vector2(0, (frame_height - 34) * 0.5)
	_hp_label.size = Vector2(bar_width, 34)
	_hp_label.font_size = 26
	_hp_label.display_font = T.display_font(600)
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_hp_label)

	# Original shield icon only; there is no shield bar or secondary fill.
	_block_badge = TextureRect.new()
	_block_badge.name = "BlockBadge"
	var cropped_badge := AtlasTexture.new()
	cropped_badge.atlas = BLOCK_BADGE_TEXTURE
	cropped_badge.region = Rect2(9, 5, 46, 54)
	_block_badge.texture = cropped_badge
	_block_badge.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_block_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_block_badge.position = Vector2(-21, -21)
	_block_badge.custom_minimum_size = Vector2.ZERO
	_block_badge.size = Vector2(42, 49)
	_block_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block_badge.visible = false
	add_child(_block_badge)

	_block_label = Label.new()
	_block_label.name = "BlockLabel"
	_block_label.position = Vector2(0, -3)
	_block_label.size = _block_badge.size
	_block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_block_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_block_label.add_theme_font_size_override("font_size", 25)
	_block_label.add_theme_color_override("font_color", Color.WHITE)
	_block_label.add_theme_color_override("font_outline_color", Color("#10283b"))
	_block_label.add_theme_constant_override("outline_size", 2)
	_block_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block_badge.add_child(_block_label)

	_status_badges = HBoxContainer.new()
	_status_badges.name = "StatusBadges"
	_status_badges.position = Vector2(0, 30)
	_status_badges.size = Vector2(bar_width, 32)
	_status_badges.alignment = BoxContainer.ALIGNMENT_CENTER
	_status_badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_badges.add_theme_constant_override("separation", 6)
	add_child(_status_badges)


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


func update_stats(hp: int, max_hp: int, blk: int) -> void:
	current_health = maxi(0, hp)
	max_health = maxi(1, max_hp)
	current_block = maxi(0, blk)
	if not _hp_bar:
		return
	_hp_bar.ratio = float(current_health) / float(max_health)
	_hp_label.text = "%d/%d" % [current_health, max_health]
	_block_badge.visible = current_block > 0
	_block_label.text = str(current_block)

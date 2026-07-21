## CharacterHUD — smooth comic health bar with the original block shield.
extends Control
class_name CharacterHUD

const BLOCK_BADGE_TEXTURE = preload("res://battle_scene/assets/images/ui/block_badge.png")
const T = preload("res://run_system/ui/theme/wasteland_theme.gd")


class SmoothHealthBar:
	extends Control

	var ratio: float = 1.0:
		set(value):
			ratio = clampf(value, 0.0, 1.0)
			queue_redraw()
	var fill_color := Color.WHITE
	var track_color := Color("#131a16")
	var edge_color := Color("#ef7047")
	var fill_shadow_color := Color("#5f100c")

	func _rounded_style(color: Color, radius: int) -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(radius)
		style.anti_aliasing = true
		return style

	func _draw() -> void:
		# One dark recessed trough only. The previous black shell + steel keyline
		# added an unwanted second frame around this already tiny HUD element.
		var trough_rect := Rect2(Vector2.ZERO, size)
		var trough_radius := roundi(trough_rect.size.y * 0.5)
		draw_style_box(_rounded_style(track_color, trough_radius), trough_rect)
		# A quiet inner bevel adds depth without becoming another outside border.
		draw_line(
			trough_rect.position + Vector2(5.0, 1.0),
			Vector2(trough_rect.end.x - 5.0, trough_rect.position.y + 1.0),
			Color("#272d27"),
			1.0
		)
		if ratio <= 0.0:
			return
		var core_height := minf(4.0, size.y - 4.0)
		var core_rect := Rect2(
			Vector2(4.0, (size.y - core_height) * 0.5),
			Vector2(size.x - 8.0, core_height)
		)
		var fill_width := core_rect.size.x * ratio
		if fill_width <= 0.5:
			return
		var fill_rect := Rect2(core_rect.position, Vector2(fill_width, core_rect.size.y))
		var fill_radius := mini(roundi(core_height * 0.5), roundi(fill_width * 0.5))
		draw_style_box(_rounded_style(fill_color, fill_radius), fill_rect)
		if fill_width < 7.0 or core_rect.size.y < 3.0:
			return
		var detail_width := fill_width - 3.0
		# Painted inner core: a restrained top catchlight and a dark lower lip.
		draw_line(
			fill_rect.position + Vector2(1.5, 0.0),
			Vector2(fill_rect.position.x + detail_width, fill_rect.position.y),
			edge_color,
			1.0
		)
		draw_line(
			fill_rect.position + Vector2(1.5, fill_rect.size.y - 1.0),
			Vector2(
				fill_rect.position.x + detail_width,
				fill_rect.position.y + fill_rect.size.y - 1.0
			),
			fill_shadow_color,
			1.0
		)
		# Sparse ink nicks stop the bar reading as a perfectly smooth neon tube.
		for fraction in [0.23, 0.57, 0.82]:
			var nick_x := fill_rect.position.x + floorf(fill_width * fraction)
			if nick_x < fill_rect.end.x - 2.0:
				draw_line(
					Vector2(nick_x, fill_rect.position.y + 1.0),
					Vector2(nick_x + 1.0, fill_rect.position.y + 1.0),
					Color(0.18, 0.02, 0.025, 0.38),
					1.0
				)


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

var _hp_frame: Control
var _hp_bar: SmoothHealthBar
var _hp_label: HealthValueText
var _block_badge: TextureRect
var _block_label: Label
var _status_badges: HBoxContainer


func _ready() -> void:
	_build_ui()
	update_stats(current_health, max_health, current_block)


func _build_ui() -> void:
	size = Vector2(bar_width, bar_height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_hp_frame = Control.new()
	_hp_frame.name = "HpFrame"
	_hp_frame.position = Vector2(0, -1)
	_hp_frame.size = Vector2(bar_width, bar_height)
	_hp_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp_frame)

	_hp_bar = SmoothHealthBar.new()
	_hp_bar.name = "HpBar"
	_hp_bar.size = Vector2(bar_width, bar_height)
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar.fill_color = Color("#c73a25")
	_hp_bar.edge_color = Color("#ef7047")
	_hp_bar.fill_shadow_color = Color("#5f100c")
	_hp_frame.add_child(_hp_bar)

	_hp_label = HealthValueText.new()
	_hp_label.name = "HpLabel"
	_hp_label.position = Vector2(0, -12)
	_hp_label.size = Vector2(bar_width, 34)
	_hp_label.font_size = 26
	_hp_label.display_font = T.display_font(600)
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_frame.add_child(_hp_label)

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


func update_stats(hp: int, max_hp: int, blk: int) -> void:
	current_health = maxi(0, hp)
	max_health = maxi(1, max_hp)
	current_block = maxi(0, blk)
	if not _hp_bar:
		return
	var shielded := current_block > 0
	_hp_bar.fill_color = Color("#3f8fb6") if shielded else Color("#c73a25")
	_hp_bar.edge_color = Color("#91d5ed") if shielded else Color("#ef7047")
	_hp_bar.fill_shadow_color = Color("#153d55") if shielded else Color("#5f100c")
	_hp_bar.ratio = 1.0 if shielded else float(current_health) / float(max_health)
	_hp_label.text = "%d/%d" % [current_health, max_health]
	_block_badge.visible = current_block > 0
	_block_label.text = str(current_block)

## CharacterHUD — shows health bar + STS2-style block badge.
## Attach this to any character node. Call update_stats() to refresh.
extends Control
class_name CharacterHUD

@export var character_name: String = "?"
@export var max_health: int = 100
@export var current_health: int = 100
@export var current_block: int = 0
@export var bar_width: int = 140
@export var bar_height: int = 18

# Internal nodes
var _name_label: Label
var _hp_bar_bg: Panel
var _hp_bar_fill: Panel
var _hp_label: Label
var _block_badge: Panel
var _block_icon: Label
var _block_label: Label

func _ready() -> void:
	_build_ui()
	update_stats(current_health, max_health, current_block)

func _build_ui() -> void:
	# ---- Name Label ----
	_name_label = Label.new()
	_name_label.text = character_name
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.size = Vector2(bar_width, 18)
	_name_label.position = Vector2(0, 0)
	add_child(_name_label)

	# ---- HP Bar BG ----
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.05, 0.05)
	bg_style.corner_radius_top_left = 6
	bg_style.corner_radius_top_right = 6
	bg_style.corner_radius_bottom_right = 6
	bg_style.corner_radius_bottom_left = 6
	_hp_bar_bg = Panel.new()
	_hp_bar_bg.size = Vector2(bar_width, bar_height)
	_hp_bar_bg.position = Vector2(0, 20)
	_hp_bar_bg.add_theme_stylebox_override("panel", bg_style)
	add_child(_hp_bar_bg)

	# ---- HP Bar Fill ----
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.75, 0.25)
	fill_style.corner_radius_top_left = 6
	fill_style.corner_radius_top_right = 6
	fill_style.corner_radius_bottom_right = 6
	fill_style.corner_radius_bottom_left = 6
	_hp_bar_fill = Panel.new()
	_hp_bar_fill.size = Vector2(bar_width, bar_height)
	_hp_bar_fill.position = Vector2(0, 20)
	_hp_bar_fill.add_theme_stylebox_override("panel", fill_style)
	add_child(_hp_bar_fill)

	# ---- HP Text ----
	_hp_label = Label.new()
	_hp_label.size = Vector2(bar_width, bar_height)
	_hp_label.position = Vector2(0, 20)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 11)
	_hp_label.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(_hp_label)

	# ---- Block Badge (hidden by default) ----
	var badge_style = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.2, 0.5, 0.95)
	badge_style.corner_radius_top_left = 12
	badge_style.corner_radius_top_right = 12
	badge_style.corner_radius_bottom_right = 12
	badge_style.corner_radius_bottom_left = 12
	badge_style.border_width_left = 2
	badge_style.border_width_top = 2
	badge_style.border_width_right = 2
	badge_style.border_width_bottom = 2
	badge_style.border_color = Color(0.6, 0.8, 1.0)

	_block_badge = Panel.new()
	_block_badge.size = Vector2(52, 24)
	_block_badge.position = Vector2(bar_width + 6, 18)
	_block_badge.add_theme_stylebox_override("panel", badge_style)
	_block_badge.visible = false
	add_child(_block_badge)

	# Shield icon emoji + number inside badge
	_block_icon = Label.new()
	_block_icon.text = "🛡"
	_block_icon.add_theme_font_size_override("font_size", 11)
	_block_icon.add_theme_color_override("font_color", Color(1, 1, 1))
	_block_icon.position = Vector2(2, 4)
	_block_badge.add_child(_block_icon)

	_block_label = Label.new()
	_block_label.text = "0"
	_block_label.add_theme_font_size_override("font_size", 12)
	_block_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_block_label.position = Vector2(22, 4)
	_block_badge.add_child(_block_label)

## Call this whenever stats change to refresh all visuals.
func update_stats(hp: int, max_hp: int, blk: int) -> void:
	current_health = hp
	max_health = max_hp
	current_block = blk
	
	# HP bar fill
	var ratio = float(max(0, hp)) / float(max(1, max_hp))
	_hp_bar_fill.size.x = bar_width * ratio
	_hp_label.text = "%d / %d" % [max(0, hp), max_hp]
	
	# Colour the bar (green -> yellow -> red)
	var fill_style = StyleBoxFlat.new()
	if ratio > 0.5:
		fill_style.bg_color = Color(0.2, 0.75, 0.25)
	elif ratio > 0.25:
		fill_style.bg_color = Color(0.85, 0.65, 0.1)
	else:
		fill_style.bg_color = Color(0.85, 0.15, 0.15)
	fill_style.corner_radius_top_left = 6
	fill_style.corner_radius_top_right = 6
	fill_style.corner_radius_bottom_right = 6
	fill_style.corner_radius_bottom_left = 6
	_hp_bar_fill.add_theme_stylebox_override("panel", fill_style)
	
	# Block badge
	_block_badge.visible = blk > 0
	_block_label.text = str(blk)

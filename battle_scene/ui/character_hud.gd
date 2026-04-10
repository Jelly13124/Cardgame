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
var _hp_frame: NinePatchRect
var _hp_bar: TextureProgressBar
var _hp_label: Label
var _block_badge: TextureRect
var _block_label: Label

const UI_PATH = "res://battle_scene/assets/images/ui/"

func _ready() -> void:
	_build_ui()
	update_stats(current_health, max_health, current_block)

func _build_ui() -> void:
	# ---- Name Label ----
	_name_label = Label.new()
	_name_label.text = character_name
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.size = Vector2(bar_width, 18)
	_name_label.position = Vector2(0, -2)
	add_child(_name_label)

	# ---- HP Frame (NinePatch) ----
	_hp_frame = NinePatchRect.new()
	_hp_frame.texture = load(UI_PATH + "hp_bar_frame.png")
	_hp_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hp_frame.patch_margin_left = 4
	_hp_frame.patch_margin_top = 4
	_hp_frame.patch_margin_right = 4
	_hp_frame.patch_margin_bottom = 4
	_hp_frame.size = Vector2(bar_width, bar_height)
	_hp_frame.position = Vector2(0, 18)
	add_child(_hp_frame)

	# ---- HP Bar (ProgressBar) ----
	_hp_bar = TextureProgressBar.new()
	_hp_bar.texture_progress = load(UI_PATH + "hp_bar_fill.png")
	_hp_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hp_bar.nine_patch_stretch = true
	_hp_bar.stretch_margin_left = 2
	_hp_bar.stretch_margin_top = 2
	_hp_bar.stretch_margin_right = 2
	_hp_bar.stretch_margin_bottom = 2
	# Inset slightly inside frame
	_hp_bar.size = Vector2(bar_width - 4, bar_height - 4)
	_hp_bar.position = Vector2(2, 2)
	_hp_frame.add_child(_hp_bar)

	# ---- HP Text ----
	_hp_label = Label.new()
	_hp_label.size = _hp_frame.size
	_hp_label.position = Vector2.ZERO
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 10)
	_hp_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_hp_label.add_theme_color_override("font_shadow_color", Color(0,0,0,0.8))
	_hp_frame.add_child(_hp_label)

	# ---- Block Badge (Shield) ----
	_block_badge = TextureRect.new()
	_block_badge.texture = load(UI_PATH + "block_badge.png")
	_block_badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_block_badge.size = Vector2(32, 32)
	# Center on the left side of the HP bar
	_block_badge.position = Vector2(-16, 11)
	_block_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_block_badge.visible = false
	add_child(_block_badge)

	_block_label = Label.new()
	_block_label.size = _block_badge.size
	_block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_block_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_block_label.add_theme_font_size_override("font_size", 12)
	_block_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_block_label.position = Vector2(0, -1) # adjust padding inside shield
	_block_badge.add_child(_block_label)

## Call this whenever stats change to refresh all visuals.
func update_stats(hp: int, max_hp: int, blk: int) -> void:
	current_health = hp
	max_health = max_hp
	current_block = blk
	
	if not _hp_bar: return

	# HP bar update
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_label.text = "%d / %d" % [max(0, hp), max_hp]
	
	# Color grading based on health %
	var ratio = float(hp) / float(max(1, max_hp))
	if ratio > 0.5:
		_hp_bar.tint_progress = Color(0.2, 0.8, 0.3) # Fresh green
	elif ratio > 0.25:
		_hp_bar.tint_progress = Color(0.9, 0.7, 0.1) # Wounded yellow
	else:
		_hp_bar.tint_progress = Color(0.9, 0.1, 0.1) # Critical red
	
	# Block badge visibility
	_block_badge.visible = blk > 0
	_block_label.text = str(blk)

## CharacterHUD — shows health bar + STS2-style block badge.
## Attach this to any character node. Call update_stats() to refresh.
extends Control
class_name CharacterHUD

@export var max_health: int = 100
@export var current_health: int = 100
@export var current_block: int = 0
@export var bar_width: int = 180
@export var bar_height: int = 18

# Internal nodes
var _hp_frame: NinePatchRect
var _hp_bar: TextureProgressBar
var _hp_label: Label
var _block_badge: TextureRect
var _block_label: Label
var _status_badges: HBoxContainer

const UI_PATH = "res://battle_scene/assets/images/ui/"

func _ready() -> void:
	_build_ui()
	update_stats(current_health, max_health, current_block)

func _build_ui() -> void:
	# ---- HP Frame (NinePatch) ----
	_hp_frame = NinePatchRect.new()
	_hp_frame.texture = load(UI_PATH + "hp_bar_frame.png")
	_hp_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hp_frame.patch_margin_left = 4
	_hp_frame.patch_margin_top = 4
	_hp_frame.patch_margin_right = 4
	_hp_frame.patch_margin_bottom = 4
	_hp_frame.size = Vector2(bar_width, bar_height)
	_hp_frame.position = Vector2(0, 0)
	add_child(_hp_frame)

	# ---- HP Bar (ProgressBar) ----
	_hp_bar = TextureProgressBar.new()
	_hp_bar.texture_progress = load(UI_PATH + "hp_bar_fill.png")
	_hp_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hp_bar.nine_patch_stretch = true
	_hp_bar.stretch_margin_left = 4
	_hp_bar.stretch_margin_top = 1
	_hp_bar.stretch_margin_right = 4
	_hp_bar.stretch_margin_bottom = 1
	_hp_bar.size = Vector2(bar_width - 8, bar_height - 4)
	_hp_bar.position = Vector2(4, 2)
	_hp_frame.add_child(_hp_bar)

	# ---- HP Text ----
	_hp_label = Label.new()
	_hp_label.size = _hp_frame.size
	_hp_label.position = Vector2.ZERO
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 12)
	_hp_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_hp_label.add_theme_color_override("font_shadow_color", Color(0,0,0,0.8))
	_hp_frame.add_child(_hp_label)

	# ---- Block Badge (Shield) ----
	_block_badge = TextureRect.new()
	_block_badge.texture = load(UI_PATH + "block_badge.png")
	_block_badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_block_badge.size = Vector2(40, 40)
	_block_badge.position = Vector2(-20, -11)
	_block_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_block_badge.visible = false
	add_child(_block_badge)

	_block_label = Label.new()
	_block_label.size = _block_badge.size
	_block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_block_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_block_label.add_theme_font_size_override("font_size", 16)
	_block_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_block_label.position = Vector2(0, -1) # adjust padding inside shield
	_block_badge.add_child(_block_label)

	# ---- Status Badges (positioned below HP bar, centered, supports stacking) ----
	_status_badges = HBoxContainer.new()
	_status_badges.name = "StatusBadges"
	_status_badges.position = Vector2(0, bar_height + 6)
	_status_badges.size = Vector2(bar_width, 24)
	_status_badges.alignment = BoxContainer.ALIGNMENT_CENTER
	_status_badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_badges.add_theme_constant_override("separation", 4)
	add_child(_status_badges)

func get_status_badge_container() -> HBoxContainer:
	return _status_badges

## Call this whenever stats change to refresh all visuals.
func update_stats(hp: int, max_hp: int, blk: int) -> void:
	current_health = hp
	max_health = max_hp
	current_block = blk
	
	if not _hp_bar: return

	# HP bar update — fixed tint regardless of HP. (HP-based color grading was
	# removed because the green→yellow→red transition felt jarring.)
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_label.text = "%d / %d" % [max(0, hp), max_hp]

	# Block badge visibility
	_block_badge.visible = blk > 0
	_block_label.text = str(blk)

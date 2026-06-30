## Reusable equipment icon. Pass slot + item_name (used to derive a 1-2 letter
## label). If sprite_path resolves to a real file, renders that instead.
extends Panel
class_name EquipmentIcon

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")

## Per-rarity FILL colors (dark, used as the cell background). Cells tint by RARITY
## ONLY now — slot identity reads from the icon, not the background color (owner
## request: too many colors). The brighter RARITY_COLORS stays on the border.
const RARITY_BG_COLORS := {
	"common": Color(0.28, 0.28, 0.31, 1.0),  # neutral graphite
	"uncommon": Color(0.16, 0.27, 0.42, 1.0),  # dark steel blue
	"rare": Color(0.40, 0.31, 0.12, 1.0),  # dark gold-brown
	"set": Color(0.16, 0.34, 0.20, 1.0),  # dark green — set pieces
	"cursed": Color(0.38, 0.14, 0.15, 1.0),  # dark red — cursed gear
}
const SLOT_LETTERS := {
	"head": "H",
	"chest": "C",
	"weapon": "W",
	"hands": "Hd",
	"accessory": "Ac",
}
const SLOT_ICON_PATHS := {
	"head": "res://battle_scene/assets/images/ui/slots/head.png",
	"chest": "res://battle_scene/assets/images/ui/slots/chest.png",
	"weapon": "res://battle_scene/assets/images/ui/slots/weapon.png",
	"hands": "res://battle_scene/assets/images/ui/slots/hands.png",
	"accessory": "res://battle_scene/assets/images/ui/slots/accessory.png",
}
## Rarity border colors — white / blue / gold (matches the card frames).
const RARITY_COLORS := {
	"common": Color(0.95, 0.96, 0.98),  # white
	"uncommon": Color(0.31, 0.69, 1.0),  # blue
	"rare": Color(1.0, 0.81, 0.27),  # gold
	"set": Color(0.42, 0.85, 0.46),  # green — set pieces
	"cursed": Color(0.86, 0.32, 0.34),  # red — cursed gear
}

var _label: Label
var _texture_rect: TextureRect
var _tooltip_text: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)
	if not _label:
		_build()
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
		# Force-hide on tree exit so a freed icon (panel rebuild, scene
		# change) can never leave its tooltip stranded.
		tree_exited.connect(_on_mouse_exited)


func _build() -> void:
	if _label:
		return  # Already built (lazy-init path beat _ready)
	# Shared reward-style icon frame.
	add_theme_stylebox_override("panel", T.icon_frame_style())

	# Label fallback for missing equipment art.
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_label)

	# Texture (hidden until set)
	_texture_rect = TextureRect.new()
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texture_rect.offset_left = 4
	_texture_rect.offset_top = 4
	_texture_rect.offset_right = -4
	_texture_rect.offset_bottom = -4
	_texture_rect.visible = false
	add_child(_texture_rect)


## Set the rich tooltip text shown on mouse hover. Use BBCode for emphasis.
## Empty string disables the tooltip for this icon. (Named to avoid
## conflict with Control.set_tooltip_text — Godot's built-in tooltip.)
func set_hover_tooltip(text: String) -> void:
	_tooltip_text = text


func _on_mouse_entered() -> void:
	if _tooltip_text != "" and is_inside_tree():
		Tooltip.show(_tooltip_text, global_position + Vector2(size.x * 0.5, 0), get_instance_id())


func _on_mouse_exited() -> void:
	# hide_if_owner so a sibling icon's freshly-opened tooltip can't get
	# clobbered by THIS icon's tree_exited fire during a panel rebuild.
	Tooltip.hide_if_owner(get_instance_id())


## Populate the icon. Safe to call before the node enters the scene tree.
## lazy-builds children if _ready hasn't fired yet.
func set_equipment(
	slot: String, item_name: String, sprite_path: String = "", rarity: String = "common"
) -> void:
	if not _label:
		_build()
	# Slot-tinted fill + a rarity-colored border (white/blue/gold).
	add_theme_stylebox_override("panel", _equip_style(slot, rarity, 0.72))

	# Label = SLOT_LETTERS preferred, else first char of item name
	_label.text = str(SLOT_LETTERS.get(slot, item_name.substr(0, 1).to_upper()))
	_label.modulate = Color(1, 1, 1, 1)
	_label.visible = true
	_texture_rect.visible = false

	# Try to load the real texture (fallback to placeholder if missing)
	if sprite_path != "":
		var full_path = "res://battle_scene/assets/images/" + sprite_path
		if ResourceLoader.exists(full_path):
			var tex = load(full_path) as Texture2D
			if tex:
				_texture_rect.texture = tex
				_texture_rect.modulate = Color.WHITE
				_texture_rect.visible = true
				_label.visible = false
				return
	_try_show_slot_icon(slot, Color(1, 1, 1, 0.75))


## Slot-colored fill with a rarity-colored border, single-sourcing the equipment
## icon look so rarity (white/blue/gold) is readable at a glance.
func _equip_style(_slot: String, rarity: String, alpha: float) -> StyleBoxFlat:
	# Background tints by RARITY only — slot identity reads from the icon (owner request).
	var bg: Color = RARITY_BG_COLORS.get(rarity, RARITY_BG_COLORS["common"])
	bg.a = alpha
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = RARITY_COLORS.get(rarity, RARITY_COLORS["common"])
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(2)
	return style


## Render an "empty slot" appearance. Safe to call before _ready fires.
func set_empty(slot: String) -> void:
	if not _label:
		_build()
	_apply_slot_placeholder_style(slot, 0.26)
	_label.text = str(SLOT_LETTERS.get(slot, "?"))
	_label.modulate = Color(1, 1, 1, 0.4)
	_label.visible = true
	_texture_rect.visible = false
	_try_show_slot_icon(slot, Color(1, 1, 1, 0.62))


func _try_show_slot_icon(slot: String, modulate_color: Color) -> void:
	var icon_path := str(SLOT_ICON_PATHS.get(slot, ""))
	if icon_path == "" or not ResourceLoader.exists(icon_path):
		return
	var tex = load(icon_path) as Texture2D
	if tex == null:
		return
	_texture_rect.texture = tex
	_texture_rect.modulate = modulate_color
	_texture_rect.visible = true
	_label.visible = false


func _apply_slot_placeholder_style(_slot: String, alpha: float) -> void:
	# Neutral fill — no per-slot color (owner request); the slot icon carries category.
	var color: Color = Color(0.20, 0.20, 0.23, alpha)
	var style := T.panel_with_shadow(color, T.PANEL_BORDER, 2, 3)
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	add_theme_stylebox_override("panel", style)

## Reusable equipment icon. Pass slot + item_name (used to derive a 1-2 letter
## label). If sprite_path resolves to a real file, renders that instead.
extends Panel
class_name EquipmentIcon

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")

const SLOT_COLORS := {
	"head":      Color(0.66, 0.20, 0.20, 1.0),  # rust red
	"chest":     Color(0.17, 0.35, 0.54, 1.0),  # steel blue
	"weapon":    Color(0.76, 0.66, 0.23, 1.0),  # brass yellow
	"hands":     Color(0.24, 0.48, 0.24, 1.0),  # olive green
	"accessory": Color(0.48, 0.23, 0.56, 1.0),  # faded violet
}
const SLOT_LETTERS := {
	"head": "H",
	"chest": "C",
	"weapon": "W",
	"hands": "Hd",
	"accessory": "Ac",
}

var _label: Label
var _texture_rect: TextureRect


func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)
	if not _label:
		_build()


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


## Populate the icon. Safe to call before the node enters the scene tree.
## lazy-builds children if _ready hasn't fired yet.
func set_equipment(slot: String, item_name: String, sprite_path: String = "") -> void:
	if not _label:
		_build()
	add_theme_stylebox_override("panel", T.icon_frame_style())

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
				_texture_rect.visible = true
				_label.visible = false
				return

	_apply_slot_placeholder_style(slot, 0.72)


## Render an "empty slot" appearance. Safe to call before _ready fires.
func set_empty(slot: String) -> void:
	if not _label:
		_build()
	_apply_slot_placeholder_style(slot, 0.26)
	_label.text = str(SLOT_LETTERS.get(slot, "?"))
	_label.modulate = Color(1, 1, 1, 0.4)
	_label.visible = true
	_texture_rect.visible = false


func _apply_slot_placeholder_style(slot: String, alpha: float) -> void:
	var color: Color = SLOT_COLORS.get(slot, T.DUSTY_TAUPE)
	color.a = alpha
	var style := T.panel_with_shadow(color, T.PANEL_BORDER, 2, 3)
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	add_theme_stylebox_override("panel", style)

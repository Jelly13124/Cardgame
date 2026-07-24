## BottomHudBar — the home-base bottom HUD bar as its own CanvasLayer: ONE
## full-width strip along the BOTTOM screen edge (T.ui_bottom_bar chrome, 96px
## tall) holding the two permanent-currency chips (Caps / Scrap) on
## the LEFT, and exposing `center_box` / `right_box` containers the host scene
## fills with its own controls (giant START + difficulty stack in the centre —
## allowed to protrude above the bar's top edge per the approved mockup — and
## the Stash / Character image buttons on the right). (Filename keeps the
## historical "top_bar" name to avoid preload churn.) Sits on layer 70 — above
## the WindowLayer (60) — so the bar stays readable while floating windows are
## open (still below fullscreen popups: RulesLayer 140 / DifficultyPopup 150 /
## TierConfirm 155).
##
## Architecture: the bar owns ONLY chrome + chips; interactive controls stay
## owned/wired by the host scene, which parents them into the exposed boxes.
## The whole structure is built in _init() so the boxes exist the moment the
## host calls .new(). The bar root is anchor-based (bottom-full-width, grow
## up); the left/right contents live in a full-rect MarginContainer + HBox row
## (chips | stretch spacer | buttons) so they stay vertically centered, while
## center_box is its own bottom-anchored overlay (it protrudes above the bar).
##
## Labels track MetaProgress.caps/scrap_changed; the bar is freed with its
## host scene, which drops the connections.
##
## NO class_name (project convention). Usage:
##   var bar = preload("res://run_system/ui/window/currency_top_bar.gd").new()
##   host_scene.add_child(bar)
##   bar.center_box.add_child(start_button)  # host fills the exposed boxes
extends CanvasLayer

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")

## Above WindowLayer's 60 so the bar stays readable over floating windows.
const BAR_LAYER := 70
const BAR_HEIGHT := 96.0
## The centre stack's bottom edge sits this far above the screen bottom (the
## giant START button hugs the screen edge and pokes above the bar top).
const CENTER_BOTTOM_MARGIN := 10.0
## Left/right inset of the chip row and the right-side button row.
const EDGE_MARGIN := 16.0
## Gap between the right-side buttons.
const ITEM_GAP := 10
## Gap BETWEEN currency chips.
const CHIP_GAP := 24
## Currency icon square size inside a chip.
const CHIP_ICON_SIZE := 24
## Gap between a chip's icon and its number.
const CHIP_ICON_TEXT_GAP := 6
## Chip number typography: warm off-white on a 2px-ish dark outline so the
## figure sits on the textured bar art.
const CHIP_FONT_SIZE := 22
const CHIP_NUM_COLOR := Color("#e8d5a8")
const CHIP_OUTLINE_COLOR := Color("#1a120a")
const CHIP_OUTLINE_SIZE := 4

## Where the Codex currency icons live (caps / scrap PNGs).
const _CURRENCY_ICON_DIR := "res://run_system/assets/images/home/currency/"

## Containers the host scene fills. left_box is chip-owned; center_box stacks
## the host's difficulty button above its START button; right_box holds the
## host's image buttons (vertically centered in the bar).
var left_box: HBoxContainer
var center_box: VBoxContainer
var right_box: HBoxContainer

var _caps_label: Label
var _scrap_label: Label


func _init() -> void:
	layer = BAR_LAYER

	var bar_root := Control.new()
	bar_root.name = "BottomBar"
	# Bottom-full-width anchor (0,1 → 1,1), growing 96px up from the edge.
	bar_root.anchor_left = 0.0
	bar_root.anchor_top = 1.0
	bar_root.anchor_right = 1.0
	bar_root.anchor_bottom = 1.0
	bar_root.offset_left = 0
	bar_root.offset_top = -BAR_HEIGHT
	bar_root.offset_right = 0
	bar_root.offset_bottom = 0
	bar_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar_root.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_root)

	# Bar body chrome — kit panel_bottom_bar.png 9-slice when delivered, flat
	# dark strip with a brass top edge until then. STOP so clicks on the bar
	# never leak through to the scene beneath.
	var body := Panel.new()
	body.name = "BarBody"
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.add_theme_stylebox_override("panel", T.ui_bottom_bar())
	body.mouse_filter = Control.MOUSE_FILTER_STOP
	bar_root.add_child(body)

	# LEFT + RIGHT content: one full-rect MarginContainer (16px side / 8px
	# top-bottom insets) holding a single HBox row — chips left, stretch spacer,
	# image buttons right. Every child SHRINK_CENTERs vertically so the row
	# contents sit dead-centre in the 96px bar. (Replaces the old zero-width
	# anchor math, which mis-centered and let the chips clip at the screen edge.)
	var content_frame := MarginContainer.new()
	content_frame.name = "ContentFrame"
	content_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_frame.add_theme_constant_override("margin_left", int(EDGE_MARGIN))
	content_frame.add_theme_constant_override("margin_right", int(EDGE_MARGIN))
	content_frame.add_theme_constant_override("margin_top", 8)
	content_frame.add_theme_constant_override("margin_bottom", 8)
	bar_root.add_child(content_frame)

	var content_row := HBoxContainer.new()
	content_row.name = "ContentRow"
	content_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	content_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_frame.add_child(content_row)

	left_box = HBoxContainer.new()
	left_box.name = "LeftBox"
	left_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_box.add_theme_constant_override("separation", CHIP_GAP)
	left_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content_row.add_child(left_box)

	# Stretch spacer pushes right_box to the far edge of the row.
	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content_row.add_child(spacer)

	right_box = HBoxContainer.new()
	right_box.name = "RightBox"
	right_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_box.add_theme_constant_override("separation", ITEM_GAP)
	right_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content_row.add_child(right_box)

	# CENTER: separately-positioned overlay (NOT in the content row — the START
	# stack is taller than the bar and protrudes above the bar top, the approved
	# mockup look). Bottom-center anchored, growing UP from CENTER_BOTTOM_MARGIN
	# above the screen edge; ALIGNMENT_END + no expanding children keeps the
	# difficulty pill docked exactly `separation` (6px) above START.
	center_box = VBoxContainer.new()
	center_box.name = "CenterBox"
	center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_box.alignment = BoxContainer.ALIGNMENT_END
	center_box.add_theme_constant_override("separation", 6)
	center_box.anchor_left = 0.5
	center_box.anchor_top = 1.0
	center_box.anchor_right = 0.5
	center_box.anchor_bottom = 1.0
	center_box.offset_top = -CENTER_BOTTOM_MARGIN
	center_box.offset_bottom = -CENTER_BOTTOM_MARGIN
	center_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar_root.add_child(center_box)

	_caps_label = _make_currency_chip(left_box, "caps")
	_scrap_label = _make_currency_chip(left_box, "scrap")


func _ready() -> void:
	MetaProgress.caps_changed.connect(func(_v): _refresh_caps())
	MetaProgress.scrap_changed.connect(func(_v): _refresh_scrap())
	_refresh_caps()
	_refresh_scrap()


## Currency chip: [icon 24px][6px gap][number], left-aligned, sat bare on the
## bar (no per-chip frame — the bar body IS the frame). The chip is a plain
## shrink-to-content HBox — NO fixed min width and NO expand flags, so the
## icon and number always sit tight together (the old 134px panel + EXPAND_FILL
## label floated them apart). The number uses the Oswald display font with a
## dark outline so it reads on the textured bar art. If the icon PNG is
## missing, a dim currency-word label takes its place so the counter never
## degrades to a bare number. Returns the number Label for _refresh_*.
func _make_currency_chip(parent: Control, icon_id: String) -> Label:
	var row := HBoxContainer.new()
	row.name = icon_id.capitalize() + "Chip"
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", CHIP_ICON_TEXT_GAP)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)

	var icon_path := "%s%s.png" % [_CURRENCY_ICON_DIR, icon_id]
	var icon_tex: Texture2D = null
	if ResourceLoader.exists(icon_path):
		var loaded = load(icon_path)
		if loaded is Texture2D:
			icon_tex = loaded
	if icon_tex != null:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(CHIP_ICON_SIZE, CHIP_ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	else:
		# Missing-art fallback: a small currency-word label keeps the number readable.
		var word := Label.new()
		word.text = icon_id
		word.add_theme_font_size_override("font_size", CHIP_FONT_SIZE - 6)
		word.add_theme_color_override("font_color", T.TEXT_SECONDARY)
		word.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(word)

	var label := Label.new()
	label.text = "0"
	label.add_theme_font_override("font", T.display_font(700))
	label.add_theme_font_size_override("font_size", CHIP_FONT_SIZE)
	label.add_theme_color_override("font_color", CHIP_NUM_COLOR)
	label.add_theme_color_override("font_outline_color", CHIP_OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", CHIP_OUTLINE_SIZE)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return label


func _refresh_caps() -> void:
	if is_instance_valid(_caps_label):
		_caps_label.text = str(MetaProgress.caps)


func _refresh_scrap() -> void:
	if is_instance_valid(_scrap_label):
		_scrap_label.text = str(MetaProgress.scrap)

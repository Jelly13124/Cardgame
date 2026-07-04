## BottomHudBar — the home-base bottom HUD bar as its own CanvasLayer: ONE
## full-width strip along the BOTTOM screen edge (T.ui_bottom_bar chrome, 96px
## tall) holding the three permanent-currency chips (Core / Caps / Scrap) on
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
## host calls .new(); everything is anchor-based (bottom-full-width, grow up),
## so it survives window resizes without fixed 1920-canvas rects.
##
## Labels track MetaProgress.core/caps/scrap_changed; the bar is freed with its
## host scene, which drops the connections.
##
## NO class_name (ADR-0006). Usage:
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
## Gap between chips / between the right-side buttons.
const ITEM_GAP := 10

## Containers the host scene fills. left_box is chip-owned; center_box stacks
## the host's difficulty button above its START button; right_box holds the
## host's image buttons (vertically centered in the bar).
var left_box: HBoxContainer
var center_box: VBoxContainer
var right_box: HBoxContainer

var _core_label: Label
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

	# LEFT: currency chips, vertically centered, EDGE_MARGIN from the left.
	# Zero-width anchor rect + grow END → the row sizes itself rightward.
	left_box = HBoxContainer.new()
	left_box.name = "LeftBox"
	left_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_box.add_theme_constant_override("separation", ITEM_GAP)
	left_box.anchor_left = 0.0
	left_box.anchor_top = 0.0
	left_box.anchor_right = 0.0
	left_box.anchor_bottom = 1.0
	left_box.offset_left = EDGE_MARGIN
	left_box.offset_right = EDGE_MARGIN
	left_box.grow_horizontal = Control.GROW_DIRECTION_END
	bar_root.add_child(left_box)

	# CENTER: bottom-center anchored stack that grows UP from
	# CENTER_BOTTOM_MARGIN above the screen edge — its content (START +
	# difficulty) is taller than the bar and protrudes above the bar top,
	# which is the approved mockup look (no clipping: plain child overflow).
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

	# RIGHT: image buttons row, EDGE_MARGIN from the right, growing leftward.
	right_box = HBoxContainer.new()
	right_box.name = "RightBox"
	right_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_box.add_theme_constant_override("separation", ITEM_GAP)
	right_box.anchor_left = 1.0
	right_box.anchor_top = 0.0
	right_box.anchor_right = 1.0
	right_box.anchor_bottom = 1.0
	right_box.offset_left = -EDGE_MARGIN
	right_box.offset_right = -EDGE_MARGIN
	right_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar_root.add_child(right_box)

	_core_label = _make_currency_chip(left_box, "core")
	_caps_label = _make_currency_chip(left_box, "caps")
	_scrap_label = _make_currency_chip(left_box, "scrap")


func _ready() -> void:
	MetaProgress.core_changed.connect(func(_v): _refresh_core())
	MetaProgress.caps_changed.connect(func(_v): _refresh_caps())
	MetaProgress.scrap_changed.connect(func(_v): _refresh_scrap())
	_refresh_core()
	_refresh_caps()
	_refresh_scrap()


## Currency chip: a big number + the Codex currency icon (T.currency_row), sat
## bare on the bar (no per-chip frame — the bar body IS the frame now). If the
## icon PNG is missing, currency_row falls back to a small currency-word label
## so the counter stays readable even if the art regresses. SHRINK_CENTER keeps
## the 64px chip vertically centered inside the 96px bar instead of stretching.
func _make_currency_chip(parent: Control, icon_id: String) -> Label:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(134, 64)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var row := T.currency_row(0, icon_id, 31, 40)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)

	# Style the row's amount Label to match the prior big/bright HUD look and hand
	# it back so _refresh_* can update it.
	var label := row.get_meta("amount_label") as Label
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.78))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.5))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _refresh_core() -> void:
	if is_instance_valid(_core_label):
		_core_label.text = str(MetaProgress.core)


func _refresh_caps() -> void:
	if is_instance_valid(_caps_label):
		_caps_label.text = str(MetaProgress.caps)


func _refresh_scrap() -> void:
	if is_instance_valid(_scrap_label):
		_scrap_label.text = str(MetaProgress.scrap)

## Global tooltip overlay. Single instance lives on a high-priority
## CanvasLayer so it always renders above scene UI.
##
## Usage from a widget:
##   func _ready():
##       mouse_entered.connect(func(): Tooltip.show("My helpful text", global_position))
##       mouse_exited.connect(func(): Tooltip.hide())
##
## For per-item tooltips, just call show(text, pos) again with new args
## — the panel re-renders in place.
extends Node

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const MAX_WIDTH := 320.0
const PADDING := 10
const OFFSET_FROM_ANCHOR := Vector2(0, -12)  # lift above anchor

var _layer: CanvasLayer
var _panel: PanelContainer
var _label: RichTextLabel
var _visible: bool = false
var _follow_mouse: bool = false
var _last_scene: Node = null  # tracked so we can auto-hide on scene change


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 1000
	add_child(_layer)

	# Auto-hide on scene change so a hovered tooltip can't leak past the
	# scene that owned the widget. Without this, a freed widget never fires
	# mouse_exited and the panel stays floating on top of the new scene.
	# Track current_scene via tree_changed; the check is O(1) and only
	# actually hides when the scene reference moves.
	_last_scene = get_tree().current_scene
	get_tree().tree_changed.connect(_on_tree_changed)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", T.panel_with_shadow(Color(0.06, 0.05, 0.04, 0.96), Color(0.55, 0.42, 0.20, 1.0), 4, 2))
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # never block clicks
	_panel.z_index = 4096
	_layer.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", PADDING)
	margin.add_theme_constant_override("margin_right", PADDING)
	margin.add_theme_constant_override("margin_top", PADDING - 2)
	margin.add_theme_constant_override("margin_bottom", PADDING - 2)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(margin)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.custom_minimum_size = Vector2(0, 0)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.add_theme_color_override("default_color", Color(0.95, 0.92, 0.82))
	_label.add_theme_font_size_override("normal_font_size", 16)
	_label.add_theme_font_size_override("bold_font_size", 16)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_label)


func _process(_dt: float) -> void:
	if _visible and _follow_mouse:
		_position_panel(_layer.get_viewport().get_mouse_position())


func _on_tree_changed() -> void:
	# Cheap scene-change detector. tree_changed fires often during gameplay
	# (every add/remove), but the current_scene reference only changes on
	# an actual change_scene_to_*. Hide once when it flips.
	# Guard against shutdown firing this with no tree.
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	var current: Node = tree.current_scene
	if current != _last_scene:
		_last_scene = current
		if _visible:
			hide()


## Show tooltip with `text`. If `anchor_global_pos` is Vector2.ZERO the
## tooltip follows the mouse; otherwise it anchors above that position.
func show(text: String, anchor_global_pos: Vector2 = Vector2.ZERO) -> void:
	if not _panel:
		return
	_label.text = text
	_label.custom_minimum_size = Vector2(min(MAX_WIDTH, _measure_text_width(text)), 0)
	_panel.visible = true
	_visible = true
	_follow_mouse = anchor_global_pos == Vector2.ZERO
	# Defer first position so RichTextLabel has time to measure fit_content height.
	if _follow_mouse:
		_position_panel(_layer.get_viewport().get_mouse_position())
	else:
		_position_panel(anchor_global_pos)


func hide() -> void:
	if not _panel:
		return
	_panel.visible = false
	_visible = false


func _position_panel(anchor: Vector2) -> void:
	_panel.reset_size()
	var size: Vector2 = _panel.size
	var viewport_size: Vector2 = _layer.get_viewport().get_visible_rect().size
	# Place ABOVE the anchor by default; flip below if it would clip off the top.
	var pos := anchor + OFFSET_FROM_ANCHOR - Vector2(size.x * 0.5, size.y)
	if pos.y < 4:
		pos.y = anchor.y - OFFSET_FROM_ANCHOR.y
	# Clamp horizontally inside the viewport.
	pos.x = clampf(pos.x, 4, viewport_size.x - size.x - 4)
	_panel.position = pos


func _measure_text_width(text: String) -> float:
	# Approximate — RichTextLabel's fit_content handles real wrapping.
	var longest_line := 0
	for line in text.split("\n"):
		var stripped := line.replace("[b]", "").replace("[/b]", "").replace("[i]", "").replace("[/i]", "")
		if stripped.length() > longest_line:
			longest_line = stripped.length()
	return float(longest_line) * 8.5  # rough px-per-char at 16pt

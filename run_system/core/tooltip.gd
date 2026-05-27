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
## Instance id of whoever called show() last. Used to prevent stale hide()
## calls (e.g. a queue_freed badge whose tree_exited fires AFTER a sibling
## already opened a new tooltip) from clobbering the current overlay.
var _owner_id: int = 0


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 1000
	add_child(_layer)

	# Auto-hide on scene change so a hovered tooltip can't leak past the
	# scene that owned the widget. The scene-change check happens inside
	# _process and ONLY when the tooltip is currently visible — when no
	# tooltip is shown there's nothing to hide and we can skip the work.
	# Old version connected tree_changed (fires per-add-remove, dozens/sec
	# in battle), which was wasteful when the tooltip wasn't visible.
	_last_scene = get_tree().current_scene

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
	if not _visible:
		return  # idle: skip per-frame work entirely
	if _follow_mouse:
		_position_panel(_layer.get_viewport().get_mouse_position())
	# Scene-change check only runs while tooltip is visible — no point
	# hiding what isn't shown. Compare current_scene against the cached
	# pointer; flip = scene actually changed → hide stale tooltip.
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	var current: Node = tree.current_scene
	if current != _last_scene:
		_last_scene = current
		hide()


## Show tooltip with `text`. If `anchor_global_pos` is Vector2.ZERO the
## tooltip follows the mouse; otherwise it anchors above that position.
## `owner_id` is the calling node's instance_id — pass it so hide_if_owner
## can avoid clobbering this tooltip from a sibling widget's stale callback.
func show(text: String, anchor_global_pos: Vector2 = Vector2.ZERO, owner_id: int = 0) -> void:
	if not _panel:
		return
	_owner_id = owner_id
	# Snapshot current scene so the scene-change detector in _process
	# uses NOW as its baseline (otherwise a stale _last_scene from before
	# the previous hide would immediately re-fire hide on this show).
	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			_last_scene = tree.current_scene
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
	_owner_id = 0


## Conditional hide — only hides if the caller's owner_id matches the one
## that opened the current tooltip. Use this from tree_exited / mouse_exited
## callbacks so a stale fire from a freed widget can't clobber a sibling's
## freshly-opened tooltip.
func hide_if_owner(owner_id: int) -> void:
	if owner_id == _owner_id:
		hide()


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

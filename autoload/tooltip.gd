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

const T = preload("uid://dfcqloc58bvde")  # res://ui/common/theme/wasteland_theme.gd
const MAX_WIDTH := 333.0
const OFFSET_FROM_ANCHOR := Vector2(0, -12)  # lift above anchor
const TOOLTIP_TEXT_META := &"global_tooltip_text"
const TOOLTIP_BOUND_META := &"global_tooltip_bound"

var _layer: CanvasLayer
var _panel: PanelContainer
var _shadow: NinePatchRect
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

	_shadow = NinePatchRect.new()
	_shadow.name = "TooltipShadow"
	_shadow.texture = T.kit_tex("tooltip_shadow_9slice")
	var patches: Vector4 = T.KIT_PATCH_MARGINS["tooltip_shadow_9slice"]
	_shadow.patch_margin_left = int(patches.x)
	_shadow.patch_margin_top = int(patches.y)
	_shadow.patch_margin_right = int(patches.z)
	_shadow.patch_margin_bottom = int(patches.w)
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow.visible = false
	_layer.add_child(_shadow)

	_panel = PanelContainer.new()
	_panel.name = "TooltipPanel"
	_panel.custom_minimum_size = T.TOOLTIP_BASE_SIZE
	_panel.add_theme_stylebox_override("panel", T.kit_box("tooltip_panel_9slice"))
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_panel)

	var margin := MarginContainer.new()
	margin.name = "ContentMargins"
	margin.add_theme_constant_override("margin_left", int(T.TOOLTIP_CONTENT_MARGINS.x))
	margin.add_theme_constant_override("margin_top", int(T.TOOLTIP_CONTENT_MARGINS.y))
	margin.add_theme_constant_override("margin_right", int(T.TOOLTIP_CONTENT_MARGINS.z))
	margin.add_theme_constant_override("margin_bottom", int(T.TOOLTIP_CONTENT_MARGINS.w))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(margin)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.custom_minimum_size = Vector2.ZERO
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_override("normal_font", T.display_font(600))
	_label.add_theme_font_override("bold_font", T.display_font(700))
	_label.add_theme_color_override("default_color", T.TEXT_MAIN)
	_label.add_theme_font_size_override("normal_font_size", T.TOOLTIP_FONT_SIZE)
	_label.add_theme_font_size_override("bold_font_size", T.TOOLTIP_FONT_SIZE)
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


## Bind one Control to this project-owned rich tooltip. This deliberately clears
## Control.tooltip_text so Godot's native black tooltip can never appear on top
## of the lightline UI. Rebinding only updates the text; signal hooks are added
## once. owner_id keeps stale mouse/tree exits from hiding a newer tooltip.
func bind_hover(control: Control, text: String) -> void:
	if control == null:
		return
	var previous_text := str(control.get_meta(TOOLTIP_TEXT_META, ""))
	control.tooltip_text = ""
	control.set_meta(TOOLTIP_TEXT_META, text)
	var owner_id := control.get_instance_id()
	if _visible and _owner_id == owner_id and previous_text != text:
		if text.is_empty():
			hide_if_owner(owner_id)
		elif control.is_inside_tree():
			show(text, control.global_position + Vector2(control.size.x * 0.5, 0), owner_id)
	if bool(control.get_meta(TOOLTIP_BOUND_META, false)):
		return
	control.set_meta(TOOLTIP_BOUND_META, true)
	control.mouse_entered.connect(_show_bound_hover.bind(weakref(control), owner_id))
	control.mouse_exited.connect(hide_if_owner.bind(owner_id))
	control.tree_exited.connect(hide_if_owner.bind(owner_id))


func _show_bound_hover(control_ref: WeakRef, owner_id: int) -> void:
	var control := control_ref.get_ref() as Control
	if control == null or not control.is_inside_tree():
		return
	var text := str(control.get_meta(TOOLTIP_TEXT_META, ""))
	if text.is_empty():
		return
	show(text, control.global_position + Vector2(control.size.x * 0.5, 0), owner_id)


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
	_shadow.visible = true
	_visible = true
	_follow_mouse = anchor_global_pos == Vector2.ZERO
	# Defer first position so RichTextLabel has time to measure fit_content height.
	if _follow_mouse:
		_position_panel(_layer.get_viewport().get_mouse_position())
	else:
		# The rich label needs one layout pass before the panel reports its real
		# height. Positioning immediately used the previous/zero size and could
		# place a card glossary directly over the hovered card.
		call_deferred("_position_panel", anchor_global_pos)


func hide() -> void:
	if not _panel:
		return
	_panel.visible = false
	_shadow.visible = false
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
	pos.x = clampf(pos.x, 4, maxf(4, viewport_size.x - size.x - 4))
	pos.y = clampf(pos.y, 4, maxf(4, viewport_size.y - size.y - 4))
	_panel.position = pos
	_shadow.position = pos + Vector2(3, 2)
	_shadow.size = size


func _measure_text_width(text: String) -> float:
	var widest := 0.0
	var font := _label.get_theme_font("normal_font")
	var bbcode_pattern := RegEx.new()
	bbcode_pattern.compile("\\[[^\\]]+\\]")
	for line in text.split("\n"):
		var stripped := bbcode_pattern.sub(line, "", true)
		widest = maxf(
			widest, font.get_string_size(stripped, HORIZONTAL_ALIGNMENT_LEFT, -1, T.TOOLTIP_FONT_SIZE).x
		)
	return widest

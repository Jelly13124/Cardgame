## Reusable full-rect overlay screen for ONE base building (Phase-1 shell).
## Configured with a `building_id` (one of MetaProgress.BUILDING_DEFS). Renders the
## building name, its current tier badge, an unlock/upgrade button driven entirely
## by the F0a MetaProgress building API, and a `content` VBox that subclasses fill
## via `_build_content()`. Phase-1 building screens subclass this and override that
## single hook; the base shows a "functions coming soon" placeholder.
##
## NO class_name (ADR-0006: preload these instead). Instantiate with `.new()`,
## set `building_id`, then add as a child — `_ready()` builds the UI.
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")

## Which building this screen represents. Set before adding the node to the tree.
var building_id: String = ""

## Callback the host (home base) sets so the back button can close the overlay.
## When unset, the screen frees itself.
var on_close: Callable = Callable()

## Per-building accent color (header tint), mirrors the selector tile accent.
var accent: Color = Color(0.86, 0.78, 0.52)

var _tier_badge: Label
var _action_btn: Button
var _content_box: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	MetaProgress.buildings_changed.connect(_refresh)
	MetaProgress.core_changed.connect(func(_v): _refresh())
	MetaProgress.caps_changed.connect(func(_v): _refresh())
	MetaProgress.scrap_changed.connect(func(_v): _refresh())


func _build() -> void:
	# Dim backdrop that also eats clicks so the base behind stays inert.
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.72)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 620)
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# Header: building name + tier badge + close button.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	vbox.add_child(header)

	var name_lbl := Label.new()
	name_lbl.text = tr("UI_BUILD_%s_NAME" % building_id.to_upper())
	_style_label(name_lbl, 34, accent, 3)
	header.add_child(name_lbl)

	_tier_badge = Label.new()
	_style_label(_tier_badge, 26, Color(0.90, 0.90, 0.86), 2)
	header.add_child(_tier_badge)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(56, 48)
	close_btn.add_theme_font_size_override("font_size", 22)
	T.apply_button_theme(close_btn)
	close_btn.pressed.connect(_close)
	header.add_child(close_btn)

	vbox.add_child(HSeparator.new())

	# Unlock / upgrade action button (driven by F0a API on refresh).
	_action_btn = Button.new()
	_action_btn.custom_minimum_size = Vector2(360, 46)
	_action_btn.add_theme_font_size_override("font_size", 20)
	T.apply_button_theme(_action_btn)
	_action_btn.add_theme_color_override("font_disabled_color", Color(0.72, 0.64, 0.50, 0.92))
	_action_btn.pressed.connect(_on_action_pressed)
	vbox.add_child(_action_btn)

	vbox.add_child(HSeparator.new())

	# Content area: subclasses populate this; base shows the placeholder.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 360)
	vbox.add_child(scroll)

	_content_box = VBoxContainer.new()
	_content_box.add_theme_constant_override("separation", 10)
	_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content_box)

	_build_content(_content_box)
	_refresh()


## Extension point. Subclasses override to fill the content VBox with their
## tier-gated functions. The base implementation shows a placeholder label.
func _build_content(container: VBoxContainer) -> void:
	var placeholder := Label.new()
	placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	placeholder.text = tr("UI_BUILD_COMING")
	_style_label(placeholder, 20, Color(0.8, 0.74, 0.6), 1)
	container.add_child(placeholder)


## Update the tier badge + action button to the current building state. Safe to
## call repeatedly (wired to buildings/currency change signals).
func _refresh() -> void:
	if not is_instance_valid(_tier_badge) or not is_instance_valid(_action_btn):
		return
	var tier := MetaProgress.get_building_tier(building_id)
	if tier <= 0:
		_tier_badge.text = tr("UI_BUILD_LOCKED")
	else:
		_tier_badge.text = "T%d" % tier

	var cost := MetaProgress.next_building_cost(building_id)
	if tier <= 0:
		# Locked → unlock button.
		_action_btn.visible = true
		_action_btn.text = tr("UI_BUILD_UNLOCK").format({"n": cost})
		_action_btn.disabled = cost < 0 or MetaProgress.core < cost
	elif tier < MetaProgress.MAX_BUILDING_TIER and cost >= 0:
		# Unlocked, not maxed → upgrade button.
		_action_btn.visible = true
		_action_btn.text = tr("UI_BUILD_UPGRADE").format({"n": tier + 1, "c": cost})
		_action_btn.disabled = MetaProgress.core < cost
	else:
		# Maxed.
		_action_btn.visible = true
		_action_btn.text = tr("UI_BUILD_MAX")
		_action_btn.disabled = true


func _on_action_pressed() -> void:
	var tier := MetaProgress.get_building_tier(building_id)
	if tier <= 0:
		MetaProgress.unlock_building(building_id)
	elif tier < MetaProgress.MAX_BUILDING_TIER:
		MetaProgress.upgrade_building(building_id)
	# buildings_changed → _refresh() repaints the badge/button.


func _close() -> void:
	if on_close.is_valid():
		on_close.call()
	else:
		queue_free()


func _style_label(label: Label, font_size: int, color: Color, outline_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.90))
	label.add_theme_constant_override("outline_size", outline_size)

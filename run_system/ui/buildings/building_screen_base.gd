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
var _core_label: Label

## Placeholder per-building background path (Codex art swaps these in later).
const _BG_DIR := "res://run_system/assets/images/buildings/"


func _ready() -> void:
	# STOP so this full-rect overlay blocks the home base behind it.
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	MetaProgress.buildings_changed.connect(_refresh)
	MetaProgress.core_changed.connect(func(_v): _refresh())
	MetaProgress.caps_changed.connect(func(_v): _refresh())
	MetaProgress.scrap_changed.connect(func(_v): _refresh())


func _build() -> void:
	# Full-screen, merchant-style framing: a per-building (or fallback) background,
	# a dark readability shade, then a large centered framed panel.
	_add_scene_background()

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# The big framed board. Accent tints the border so each building reads distinct.
	var board := PanelContainer.new()
	board.custom_minimum_size = Vector2(1100, 720)
	var border := accent
	border.a = 1.0
	board.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(Color(0.055, 0.045, 0.038, 0.96), border, 6, 3)
	)
	center.add_child(board)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 36)
	for side in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	board.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# --- Title bar: big building name + tier badge + Core balance + close ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	vbox.add_child(header)

	var name_lbl := Label.new()
	name_lbl.text = tr("UI_BUILD_%s_NAME" % building_id.to_upper())
	_style_label(name_lbl, 40, accent, 3)
	header.add_child(name_lbl)

	_tier_badge = Label.new()
	_style_label(_tier_badge, 26, Color(0.90, 0.90, 0.86), 2)
	header.add_child(_tier_badge)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	# Core balance chip — the currency that unlocks/upgrades buildings.
	_core_label = Label.new()
	_style_label(_core_label, 26, Color(0.64, 0.90, 1.0), 2)
	header.add_child(_core_label)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(56, 48)
	close_btn.add_theme_font_size_override("font_size", 22)
	T.apply_button_theme(close_btn)
	close_btn.pressed.connect(_close)
	header.add_child(close_btn)

	vbox.add_child(HSeparator.new())

	# --- Unlock / upgrade action button row (driven by F0a API on refresh) ---
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 12)
	vbox.add_child(action_row)

	_action_btn = Button.new()
	_action_btn.custom_minimum_size = Vector2(420, 48)
	_action_btn.add_theme_font_size_override("font_size", 20)
	T.apply_button_theme(_action_btn)
	_action_btn.add_theme_color_override("font_disabled_color", Color(0.72, 0.64, 0.50, 0.92))
	_action_btn.pressed.connect(_on_action_pressed)
	action_row.add_child(_action_btn)

	vbox.add_child(HSeparator.new())

	# --- Scrollable content area: subclasses populate this; base shows placeholder.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	# Inner margin so content doesn't crowd the frame edge / scrollbar.
	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 6)
	content_margin.add_theme_constant_override("margin_right", 16)
	content_margin.add_theme_constant_override("margin_top", 4)
	content_margin.add_theme_constant_override("margin_bottom", 4)
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_margin)

	_content_box = VBoxContainer.new()
	_content_box.add_theme_constant_override("separation", 10)
	_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_child(_content_box)

	# --- Bottom bar: prominent LEAVE / back button (bottom-right).
	vbox.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	vbox.add_child(footer)
	var foot_spacer := Control.new()
	foot_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(foot_spacer)
	var leave_btn := Button.new()
	leave_btn.text = tr("UI_BUILD_LEAVE")
	leave_btn.custom_minimum_size = Vector2(200, 48)
	leave_btn.add_theme_font_size_override("font_size", 20)
	T.apply_button_theme(leave_btn)
	leave_btn.pressed.connect(_close)
	footer.add_child(leave_btn)

	_build_content(_content_box)
	_refresh()


## Full-rect background: a per-building placeholder image if Codex has delivered
## one, else a dark ColorRect tinted toward `accent`. Always topped with a dark
## shade for label readability (mirrors home_base / shop framing).
func _add_scene_background() -> void:
	var bg_path := "%s%s_bg.png" % [_BG_DIR, building_id]
	if ResourceLoader.exists(bg_path):
		var bg := TextureRect.new()
		bg.texture = load(bg_path)
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
	else:
		# Dark base tinted a touch toward the building accent so the 5 screens
		# feel distinct even without final art.
		var tint := accent
		var bg := ColorRect.new()
		bg.color = Color(tint.r * 0.10 + 0.02, tint.g * 0.10 + 0.02, tint.b * 0.10 + 0.02, 1.0)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)


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
	if is_instance_valid(_core_label):
		_core_label.text = tr("UI_HOME_CORE").format({"n": MetaProgress.core})
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

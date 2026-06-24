## Reusable full-rect overlay screen for ONE base building. Configured with a
## `building_id` (one of MetaProgress.BUILDING_DEFS). Renders a layered detail page:
## an icon + name + flavour header, a prominent ACTION CARD (unlock/upgrade with its
## effect, cost, and — when locked — a preview of what the building does so a locked
## page still sells its value), and a scrollable `content` VBox that subclasses fill
## via `_build_content()`.
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
var _content_box: VBoxContainer
var _core_label: Label
## Inner VBox of the action card; rebuilt by `_refresh()` for the current state.
var _action_card_body: VBoxContainer

## Per-building header art (the same home-base runtime sprites).
const _ICON_DIR := "res://run_system/assets/images/home/buildings_runtime/"
## Placeholder per-building background path (Codex art swaps these in later).
const _BG_DIR := "res://run_system/assets/images/buildings/"


func _ready() -> void:
	# STOP so this full-rect overlay blocks the home base behind it.
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	T.fade_in(self)  # soft entrance instead of a hard pop-in
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
	board.custom_minimum_size = Vector2(1120, 740)
	var border := accent
	border.a = 1.0
	board.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(Color(0.055, 0.045, 0.038, 0.96), border, 6, 3)
	)
	center.add_child(board)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 34)
	for side in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	board.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# --- Header band: building icon + name/flavour, then tier + Core + close ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	vbox.add_child(header)

	var icon_frame := PanelContainer.new()
	icon_frame.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(icon_frame)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(104, 104)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_path := "%s%s.png" % [_ICON_DIR, building_id]
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	icon_frame.add_child(icon)

	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 3)
	title_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(title_box)
	var name_lbl := Label.new()
	name_lbl.text = tr("UI_BUILD_%s_NAME" % building_id.to_upper())
	_style_label(name_lbl, 40, accent, 3)
	title_box.add_child(name_lbl)
	var flavour_lbl := Label.new()
	flavour_lbl.text = _flavour_text()
	flavour_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flavour_lbl.custom_minimum_size = Vector2(560, 0)
	_style_label(flavour_lbl, 17, Color(0.82, 0.76, 0.62), 1)
	title_box.add_child(flavour_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var right_box := VBoxContainer.new()
	right_box.alignment = BoxContainer.ALIGNMENT_CENTER
	right_box.add_theme_constant_override("separation", 6)
	header.add_child(right_box)
	_tier_badge = Label.new()
	_tier_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_label(_tier_badge, 24, Color(0.90, 0.90, 0.86), 2)
	right_box.add_child(_tier_badge)
	_core_label = Label.new()
	_core_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_label(_core_label, 22, Color(0.64, 0.90, 1.0), 2)
	right_box.add_child(_core_label)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(56, 48)
	close_btn.add_theme_font_size_override("font_size", 22)
	T.apply_button_theme(close_btn)
	close_btn.pressed.connect(_close)
	header.add_child(close_btn)

	vbox.add_child(HSeparator.new())

	# --- Action card: prominent unlock/upgrade (effect + cost + button, plus a
	# preview of the building's functions while it is still locked). ---
	var card := PanelContainer.new()
	var card_border := accent
	card_border.a = 0.85
	card.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(Color(0.10, 0.085, 0.07, 0.96), card_border, 4, 2)
	)
	vbox.add_child(card)
	var card_margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		card_margin.add_theme_constant_override(side, 16)
	card.add_child(card_margin)
	_action_card_body = VBoxContainer.new()
	_action_card_body.add_theme_constant_override("separation", 8)
	card_margin.add_child(_action_card_body)

	# --- Scrollable content area: subclasses populate this; base shows placeholder.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 384)
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
	leave_btn.pressed.connect(func() -> void: AudioManager.play_sfx("ui_back"))
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


# --- Per-building copy (translation-driven; subclasses may override) ---------


## One-line tagline shown under the building name. CSV: UI_BUILD_<ID>_FLAVOUR.
func _flavour_text() -> String:
	return tr("UI_BUILD_%s_FLAVOUR" % building_id.to_upper())


## What unlocking grants — shown in the action card while locked.
## CSV: UI_BUILD_<ID>_UNLOCK_DESC.
func _unlock_desc() -> String:
	return tr("UI_BUILD_%s_UNLOCK_DESC" % building_id.to_upper())


## Multi-line "what this building does" preview (locked state).
## CSV: UI_BUILD_<ID>_PREVIEW.
func _preview_text() -> String:
	return tr("UI_BUILD_%s_PREVIEW" % building_id.to_upper())


# --- State refresh ----------------------------------------------------------


## Update the tier badge, Core chip, and action card to the current building state.
## Safe to call repeatedly (wired to buildings/currency change signals).
func _refresh() -> void:
	if not is_instance_valid(_action_card_body):
		return
	if is_instance_valid(_core_label):
		_core_label.text = tr("UI_HOME_CORE").format({"n": MetaProgress.core})
	var tier := MetaProgress.get_building_tier(building_id)
	if is_instance_valid(_tier_badge):
		_tier_badge.text = tr("UI_BUILD_LOCKED") if tier <= 0 else "T%d" % tier

	# Rebuild the action card body for the current state (remove immediately so the
	# freed nodes never briefly double-draw).
	for c in _action_card_body.get_children():
		_action_card_body.remove_child(c)
		c.queue_free()

	var cost := MetaProgress.next_building_cost(building_id)
	if tier <= 0:
		_fill_action_card_locked(cost)
	elif tier < MetaProgress.MAX_BUILDING_TIER and cost >= 0:
		_fill_action_card_upgrade(tier, cost)
	else:
		_fill_action_card_max()


func _fill_action_card_locked(cost: int) -> void:
	var head := Label.new()
	_style_label(head, 24, Color(1.0, 0.86, 0.5), 2)
	head.text = tr("UI_BUILD_ACTION_LOCKED_HEAD")
	_action_card_body.add_child(head)

	var desc := Label.new()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(desc, 18, Color(0.92, 0.88, 0.76), 1)
	desc.text = _unlock_desc()
	_action_card_body.add_child(desc)

	# Preview of what the building does once unlocked, so a locked page still sells it.
	var prev_head := Label.new()
	_style_label(prev_head, 17, accent, 1)
	prev_head.text = tr("UI_BUILD_PREVIEW_HEAD")
	_action_card_body.add_child(prev_head)
	var prev := Label.new()
	prev.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(prev, 16, Color(0.80, 0.84, 0.74), 1)
	prev.text = _preview_text()
	_action_card_body.add_child(prev)

	var enabled := cost >= 0 and MetaProgress.core >= cost
	_action_card_body.add_child(
		_make_action_button(tr("UI_BUILD_UNLOCK").format({"n": cost}), enabled)
	)


func _fill_action_card_upgrade(tier: int, cost: int) -> void:
	var head := Label.new()
	_style_label(head, 22, Color(1.0, 0.86, 0.5), 2)
	head.text = tr("UI_BUILD_ACTION_UPGRADE_HEAD").format({"n": tier + 1})
	_action_card_body.add_child(head)

	var desc := Label.new()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(desc, 17, Color(0.92, 0.88, 0.76), 1)
	desc.text = tr("UI_BUILD_UPGRADE_GENERIC")
	_action_card_body.add_child(desc)

	_action_card_body.add_child(
		_make_action_button(
			tr("UI_BUILD_UPGRADE").format({"n": tier + 1, "c": cost}), MetaProgress.core >= cost
		)
	)


func _fill_action_card_max() -> void:
	var head := Label.new()
	_style_label(head, 22, Color(0.7, 0.92, 0.7), 2)
	head.text = tr("UI_BUILD_MAX")
	_action_card_body.add_child(head)
	var desc := Label.new()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(desc, 17, Color(0.86, 0.84, 0.74), 1)
	desc.text = tr("UI_BUILD_MAX_DESC")
	_action_card_body.add_child(desc)


func _make_action_button(text: String, enabled: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(440, 50)
	btn.add_theme_font_size_override("font_size", 21)
	T.apply_button_theme(btn)
	btn.add_theme_color_override("font_disabled_color", Color(0.72, 0.64, 0.50, 0.92))
	btn.disabled = not enabled
	btn.pressed.connect(_on_action_pressed)
	return btn


func _on_action_pressed() -> void:
	var tier := MetaProgress.get_building_tier(building_id)
	var ok := false
	if tier <= 0:
		ok = MetaProgress.unlock_building(building_id)
	elif tier < MetaProgress.MAX_BUILDING_TIER:
		ok = MetaProgress.upgrade_building(building_id)
	# Meaty confirmation on a successful unlock / tier-up; soft error cue otherwise.
	AudioManager.play_sfx("reward" if ok else "error")
	# buildings_changed → _refresh() repaints the badge/card.


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

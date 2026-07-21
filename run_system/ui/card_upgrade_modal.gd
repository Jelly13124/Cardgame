## STS2-style in-run card-upgrade picker.
##
## The complete deck remains visible as a dim grid. Selecting one upgradeable
## card opens a large base -> upgraded comparison above the grid; the upgrade is
## only committed by the right-edge check button. This keeps the existing deck
## mutation contract while matching the accepted UI07 concept hierarchy.
## No `class_name` (ADR-0006).
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const CARD_FACTORY_SCENE = preload("res://battle_scene/my_card_factory.tscn")
const CARD_UPGRADE = preload("res://run_system/core/card_upgrade.gd")
const RUN_TOP_BAR = preload("res://run_system/ui/run_top_bar.gd")

signal upgraded
signal cancelled

const TOP_BAR_CLEARANCE := RUN_TOP_BAR.BAR_HEIGHT
const GRID_CARD_SCALE := 0.88
const PREVIEW_CARD_SCALE := 1.38
const PREVIEW_FRAME_SIZE := Vector2(276, 380)
# PlayCard carries transparent visual inset inside its root Control. Pull that
# inset back so the comparison outline reads as 4-8 px around the visible card.
const PREVIEW_CARD_VISUAL_OFFSET := Vector2(-5, -4)

var _card_factory: Node
var _selected_entry: Dictionary = {}
var _selected_info: Dictionary = {}
var _grid: GridContainer
var _preview_layer: Control
var _confirm_button: Button
var _view_upgrades: CheckBox


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_card_factory = CARD_FACTORY_SCENE.instantiate()
	add_child(_card_factory)
	_card_factory.card_size = Vector2(208, 286)
	_build()


func _fit_to_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _build() -> void:
	var bg := ColorRect.new()
	bg.name = "UpgradeBackdrop"
	bg.color = Color(0.018, 0.026, 0.032, 0.985)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_top = RUN_TOP_BAR.PAGE_ART_TOP
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# The deck is always present behind the active comparison, as in STS2.
	var scroll := ScrollContainer.new()
	scroll.name = "DeckScroll"
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 126.0
	scroll.offset_top = TOP_BAR_CLEARANCE + 30.0
	scroll.offset_right = -126.0
	scroll.offset_bottom = -118.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.custom_minimum_size.x = 1560.0
	scroll.add_child(center)

	_grid = GridContainer.new()
	_grid.name = "CardGrid"
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 28)
	_grid.add_theme_constant_override("v_separation", 24)
	center.add_child(_grid)

	var first_selectable: Dictionary = {}
	for entry in RunManager.player_deck:
		if typeof(entry) != TYPE_DICTIONARY or str(entry.get("card_id", "")) == "":
			continue
		var slot := _make_card_slot(entry)
		_grid.add_child(slot)
		if first_selectable.is_empty() and bool(slot.get_meta("selectable", false)):
			first_selectable = entry

	_build_bottom_controls()
	_build_side_controls()

	_preview_layer = Control.new()
	_preview_layer.name = "UpgradeComparison"
	_preview_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_preview_layer)
	# Comparison sits above the deck, but below the bottom controls and side tabs.
	move_child(_preview_layer, 3)

	# Keep the screen immediately legible on controller/keyboard and mirror the
	# accepted concept screenshot with one card already in focus.
	if not first_selectable.is_empty():
		_select_entry(first_selectable)


func _build_bottom_controls() -> void:
	_view_upgrades = CheckBox.new()
	_view_upgrades.name = "ViewUpgrades"
	_view_upgrades.text = tr("UI_UPGRADE_MODAL_VIEW_UPGRADES")
	if _view_upgrades.text == "UI_UPGRADE_MODAL_VIEW_UPGRADES":
		_view_upgrades.text = "查看升级"
	_view_upgrades.anchor_top = 1.0
	_view_upgrades.anchor_bottom = 1.0
	_view_upgrades.offset_left = 42.0
	_view_upgrades.offset_top = -82.0
	_view_upgrades.offset_right = 250.0
	_view_upgrades.offset_bottom = -28.0
	_view_upgrades.focus_mode = Control.FOCUS_NONE
	_view_upgrades.add_theme_font_override("font", T.display_font(600))
	_view_upgrades.add_theme_font_size_override("font_size", 20)
	_view_upgrades.add_theme_color_override("font_color", Color(0.94, 0.80, 0.52))
	_view_upgrades.toggled.connect(_on_view_upgrades_toggled)
	add_child(_view_upgrades)

	var hint := Label.new()
	hint.name = "UpgradeHint"
	hint.text = tr("UI_UPGRADE_MODAL_HINT")
	if hint.text == "UI_UPGRADE_MODAL_HINT":
		hint.text = "选择一张卡牌进行升级"
	hint.anchor_left = 0.25
	hint.anchor_right = 0.75
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -76.0
	hint.offset_bottom = -24.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", T.display_font(600))
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.96, 0.85, 0.62))
	add_child(hint)


func _build_side_controls() -> void:
	var back := Button.new()
	back.name = "BackButton"
	back.text = "↶"
	back.anchor_top = 0.5
	back.anchor_bottom = 0.5
	back.offset_left = -8.0
	back.offset_top = -50.0
	back.offset_right = 118.0
	back.offset_bottom = 50.0
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_override("font", T.display_font(700))
	back.add_theme_font_size_override("font_size", 48)
	_style_side_button(back, Color(0.90, 0.64, 0.24))
	back.pressed.connect(_cancel)
	add_child(back)

	_confirm_button = Button.new()
	_confirm_button.name = "ConfirmButton"
	_confirm_button.text = "✓"
	_confirm_button.anchor_left = 1.0
	_confirm_button.anchor_right = 1.0
	_confirm_button.anchor_top = 0.5
	_confirm_button.anchor_bottom = 0.5
	_confirm_button.offset_left = -118.0
	_confirm_button.offset_top = -50.0
	_confirm_button.offset_right = 8.0
	_confirm_button.offset_bottom = 50.0
	_confirm_button.focus_mode = Control.FOCUS_NONE
	_confirm_button.add_theme_font_override("font", T.display_font(700))
	_confirm_button.add_theme_font_size_override("font_size", 48)
	_style_side_button(_confirm_button, Color(0.20, 0.88, 0.96))
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(_confirm_upgrade)
	add_child(_confirm_button)


func _style_side_button(button: Button, accent: Color) -> void:
	for state in ["normal", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.055, 0.072, 0.080, 0.97)
		style.border_color = accent if state != "disabled" else Color(0.3, 0.32, 0.33, 0.7)
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		button.add_theme_stylebox_override(state, style)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.09, 0.12, 0.13, 0.99)
	hover.border_color = accent.lightened(0.18)
	hover.set_border_width_all(3)
	hover.set_corner_radius_all(8)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(0.96, 0.91, 0.80))
	button.add_theme_color_override("font_hover_color", Color.WHITE)


func _make_card_slot(entry: Dictionary) -> Control:
	var card_id := str(entry.get("card_id", ""))
	var card: Variant = _create_card(card_id, false)
	var base_info: Dictionary = card.card_info if card and "card_info" in card else {}
	var selectable := not bool(entry.get("upgraded", false)) and CARD_UPGRADE.is_upgradeable(base_info)

	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(204, 286)
	wrapper.set_meta("entry", entry)
	wrapper.set_meta("base_info", base_info)
	wrapper.set_meta("card_node", card)
	wrapper.set_meta("selectable", selectable)

	var outline := Panel.new()
	outline.name = "SelectionOutline"
	outline.set_anchors_preset(Control.PRESET_FULL_RECT)
	outline.add_theme_stylebox_override("panel", _slot_style(false))
	wrapper.add_child(outline)

	if card:
		card.can_be_interacted_with = false
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.position = Vector2(10, 16)
		card.pivot_offset = Vector2.ZERO
		card.scale = Vector2.ONE * GRID_CARD_SCALE
		wrapper.add_child(card)

	var pick := Button.new()
	pick.flat = true
	pick.focus_mode = Control.FOCUS_NONE
	pick.set_anchors_preset(Control.PRESET_FULL_RECT)
	pick.disabled = not selectable
	if selectable:
		pick.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pick.pressed.connect(_select_entry.bind(entry))
		pick.mouse_entered.connect(func(): outline.add_theme_stylebox_override("panel", _slot_style(true)))
		pick.mouse_exited.connect(func(): _refresh_slot_outline(wrapper))
	wrapper.add_child(pick)

	if not selectable:
		wrapper.modulate = Color(0.38, 0.38, 0.38, 0.82)
	return wrapper


func _slot_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.026, 0.03, 0.12)
	style.border_color = Color(0.20, 0.86, 0.96, 0.95) if active else Color(0.40, 0.31, 0.18, 0.42)
	style.set_border_width_all(3 if active else 1)
	style.set_corner_radius_all(8)
	return style


func _refresh_slot_outline(wrapper: Control) -> void:
	var outline := wrapper.get_node_or_null("SelectionOutline") as Panel
	if not outline:
		return
	var entry: Dictionary = wrapper.get_meta("entry", {})
	outline.add_theme_stylebox_override("panel", _slot_style(entry == _selected_entry))


func _select_entry(entry: Dictionary) -> void:
	_selected_entry = entry
	_selected_info = {}
	for wrapper in _grid.get_children():
		if wrapper is Control:
			_refresh_slot_outline(wrapper)
			if wrapper.get_meta("entry", {}) == entry:
				_selected_info = wrapper.get_meta("base_info", {})
	_confirm_button.disabled = _selected_info.is_empty()
	_rebuild_preview()


func _rebuild_preview() -> void:
	for child in _preview_layer.get_children():
		child.queue_free()
	if _selected_info.is_empty():
		return

	var scrim := ColorRect.new()
	scrim.color = Color(0.0, 0.0, 0.0, 0.66)
	scrim.anchor_right = 1.0
	scrim.anchor_bottom = 1.0
	scrim.offset_top = RUN_TOP_BAR.PAGE_ART_TOP
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_layer.add_child(scrim)

	var pair := HBoxContainer.new()
	pair.anchor_left = 0.5
	pair.anchor_right = 0.5
	pair.anchor_top = 0.5
	pair.anchor_bottom = 0.5
	pair.offset_left = -365.0
	pair.offset_top = -205.0
	pair.offset_right = 365.0
	pair.offset_bottom = 205.0
	pair.alignment = BoxContainer.ALIGNMENT_CENTER
	pair.add_theme_constant_override("separation", 40)
	_preview_layer.add_child(pair)

	pair.add_child(_make_preview_card(false))

	var arrows := Label.new()
	arrows.text = "▶▶▶"
	arrows.custom_minimum_size = Vector2(82, PREVIEW_FRAME_SIZE.y)
	arrows.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrows.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrows.add_theme_font_override("font", T.display_font(700))
	arrows.add_theme_font_size_override("font_size", 30)
	arrows.add_theme_color_override("font_color", Color(0.98, 0.70, 0.20))
	pair.add_child(arrows)

	pair.add_child(_make_preview_card(true))


func _make_preview_card(upgrade_preview: bool) -> Control:
	var holder := Control.new()
	holder.name = "UpgradePreviewFrameUpgraded" if upgrade_preview else "UpgradePreviewFrameBase"
	holder.custom_minimum_size = PREVIEW_FRAME_SIZE
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	var accent := Color(0.18, 0.90, 0.98) if upgrade_preview else Color(0.78, 0.50, 0.20)
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	var outline := Panel.new()
	outline.name = "UpgradePreviewHoverOutline"
	outline.set_anchors_preset(Control.PRESET_FULL_RECT)
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.z_index = 2
	outline.visible = false
	outline.add_theme_stylebox_override("panel", style)
	holder.add_child(outline)
	holder.mouse_entered.connect(func() -> void: outline.visible = true)
	holder.mouse_exited.connect(func() -> void: outline.visible = false)

	var card_id := str(_selected_entry.get("card_id", ""))
	var card: Variant = _create_card(card_id, upgrade_preview)
	if card:
		card.can_be_interacted_with = false
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.position = PREVIEW_CARD_VISUAL_OFFSET
		card.pivot_offset = Vector2.ZERO
		card.scale = Vector2.ONE * PREVIEW_CARD_SCALE
		holder.add_child(card)
	return holder


func _create_card(card_id: String, upgrade_preview: bool) -> Variant:
	var card: Variant = _card_factory.create_card(card_id, null)
	if not card:
		return null
	if card.get_parent():
		card.get_parent().remove_child(card)
	if upgrade_preview and "card_info" in card:
		# play_card builds dynamic descriptions through get_tree(); keep the card in
		# this live modal while applying its preview data, then hand it to the holder.
		add_child(card)
		var upgraded_info: Dictionary = CARD_UPGRADE.resolve(card.card_info)
		card.set_card_data(upgraded_info)
		if "name_label" in card and is_instance_valid(card.name_label):
			card.name_label.text += "+"
		remove_child(card)
	return card


func _on_view_upgrades_toggled(enabled: bool) -> void:
	for wrapper in _grid.get_children():
		if not (wrapper is Control):
			continue
		var card = wrapper.get_meta("card_node", null)
		var base_info: Dictionary = wrapper.get_meta("base_info", {})
		if not is_instance_valid(card) or base_info.is_empty():
			continue
		var data := CARD_UPGRADE.resolve(base_info) if enabled and CARD_UPGRADE.is_upgradeable(base_info) else base_info
		card.set_card_data(data)
		if enabled and CARD_UPGRADE.is_upgradeable(base_info) and "name_label" in card:
			card.name_label.text += "+"


func _confirm_upgrade() -> void:
	if _selected_entry.is_empty() or _selected_info.is_empty():
		return
	_selected_entry["upgraded"] = true
	RunManager.bounty_event("upgrade_cards")
	AudioManager.play_sfx("ui_click")
	upgraded.emit()
	queue_free()


func _cancel() -> void:
	cancelled.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()

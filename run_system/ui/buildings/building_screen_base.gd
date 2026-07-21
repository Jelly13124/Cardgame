## Shared full-screen shell for Clinic, Market and Outpost.
##
## The approved hierarchy lives entirely in the top bar: Upgrade + Caps on the
## left, the simple building badge and name in the exact centre, and close on the
## right. Building-specific service content starts immediately below it.
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const BUILDING_UPGRADE_POPOVER = preload(
	"res://run_system/ui/buildings/building_upgrade_popover.gd"
)

var building_id := ""
var on_close: Callable = Callable()
var accent := Color(0.86, 0.78, 0.52)

var _content_box: VBoxContainer
var _services_scroll: ScrollContainer
var _upgrade_button: Button
var _caps_host: HBoxContainer
var _upgrade_popover: Control

const _BADGE_DIR := "res://run_system/assets/images/home/base_hud/"
const _BG_DIR := "res://run_system/assets/images/buildings/"
const _MARKET_INTERIOR_BG := "res://run_system/assets/images/ui/market/market_interior_bg.png"
const _TOPBAR_SIDE_WIDTH := 330.0
const _POPOVER_SIZE := Vector2(384, 288)
const _POPOVER_POINTER_X := 88.0

# Shared building-content tokens retained for the concrete screen subclasses.
const TOK_PANEL_BG := Color(0.11, 0.08, 0.06, 0.92)
const TOK_PANEL_BG_DARK := Color(0.075, 0.055, 0.040, 0.94)
const TOK_LINE := Color(0.34, 0.28, 0.20, 0.85)
const TOK_GOLD := Color(1.0, 0.86, 0.40)
const TOK_TEXT := Color(0.92, 0.88, 0.76)
const TOK_TEXT_DIM := Color(0.74, 0.68, 0.56)
const TOK_FONT_SECTION := 21
const TOK_FONT_BODY := 17
const TOK_FONT_DIM := 14
const TOK_RADIUS := 6
const TOK_MARGIN_OUTER := 14
const TOK_MARGIN_INNER := 10
const TOK_ROW_SEP := 10


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	T.fade_in(self)
	MetaProgress.buildings_changed.connect(_refresh)
	MetaProgress.caps_changed.connect(_on_caps_changed)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	AudioManager.play_sfx("ui_back")
	if is_instance_valid(_upgrade_popover):
		_dismiss_upgrade_popover()
	else:
		_close()


func _build() -> void:
	_add_scene_background()

	var outer := MarginContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		outer.add_theme_constant_override(side, 40)
	# The accepted Market mockup uses the service stack down to y≈1044 at
	# 1920x1080. Keep the shared top/side geometry, but give that one screen its
	# measured 36px bottom breathing room (20 outer + 16 board margin).
	if building_id == "market":
		outer.add_theme_constant_override("margin_bottom", 20)
	add_child(outer)

	var board := PanelContainer.new()
	board.name = "BuildingBoard"
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# The accepted building concepts use independently floating top/service
	# panels over a visible room, not one opaque full-screen slab. Keep the stable
	# BuildingBoard hook as a pure layout container.
	board.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	outer.add_child(board)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	board.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0 if building_id == "market" else 12)
	margin.add_child(vbox)
	vbox.add_child(_build_top_bar())

	_services_scroll = ScrollContainer.new()
	_services_scroll.name = "BuildingServicesScroll"
	_services_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_services_scroll.custom_minimum_size = Vector2(0, 420)
	_services_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_services_scroll)

	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 8)
	# The accepted Market stack reaches x≈1849 at 1920px; its generated frame
	# has its own right inset, so reserve only 7px here. Other buildings keep the
	# shared 16px service gutter.
	content_margin.add_theme_constant_override("margin_right", 7 if building_id == "market" else 16)
	content_margin.add_theme_constant_override("margin_top", 0 if building_id == "market" else 8)
	content_margin.add_theme_constant_override("margin_bottom", 0 if building_id == "market" else 8)
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_services_scroll.add_child(content_margin)

	_content_box = VBoxContainer.new()
	_content_box.name = "BuildingServicesContent"
	_content_box.add_theme_constant_override("separation", 10)
	_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_child(_content_box)

	_build_content(_content_box)


func _build_top_bar() -> Control:
	var bar := PanelContainer.new()
	bar.name = "BuildingTopBar"
	bar.custom_minimum_size = Vector2(0, 86)
	bar.add_theme_stylebox_override("panel", T.ll_titlebar())

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_right", 14)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	bar.add_child(pad)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	pad.add_child(row)

	var left := HBoxContainer.new()
	left.name = "BuildingTopBarLeft"
	left.custom_minimum_size = Vector2(_TOPBAR_SIDE_WIDTH, 0)
	left.add_theme_constant_override("separation", 14)
	left.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(left)

	_upgrade_button = Button.new()
	_upgrade_button.name = "BuildingUpgradeButton"
	_upgrade_button.text = _local_text("升级", "UPGRADE")
	_upgrade_button.custom_minimum_size = Vector2(132, 54)
	_upgrade_button.focus_mode = Control.FOCUS_NONE
	_upgrade_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_upgrade_button.add_theme_font_override("font", T.display_font(700))
	_upgrade_button.add_theme_font_size_override("font_size", 19)
	_upgrade_button.add_theme_constant_override("icon_max_width", 24)
	_upgrade_button.add_theme_color_override("font_color", Color(1.0, 0.91, 0.72))
	_upgrade_button.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.84))
	_upgrade_button.icon = T.lightline_tex("icon_uparrow")
	_upgrade_button.expand_icon = true
	for state in ["normal", "hover", "pressed", "disabled"]:
		_upgrade_button.add_theme_stylebox_override(state, T.ll_button(state))
	_upgrade_button.pressed.connect(_toggle_upgrade_popover)
	left.add_child(_upgrade_button)

	_caps_host = HBoxContainer.new()
	_caps_host.name = "BuildingCapsBalance"
	_caps_host.alignment = BoxContainer.ALIGNMENT_CENTER
	_caps_host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_child(_caps_host)
	_rebuild_caps_row()

	var centre := CenterContainer.new()
	centre.name = "BuildingTopBarCentre"
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(centre)

	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 12)
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(identity)

	var badge := TextureRect.new()
	badge.name = "BuildingTopBarBadge"
	badge.custom_minimum_size = Vector2(54, 54)
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_path := "%sbadge_%s.png" % [_BADGE_DIR, building_id]
	if ResourceLoader.exists(badge_path):
		badge.texture = load(badge_path)
	identity.add_child(badge)

	var name_label := Label.new()
	name_label.name = "BuildingTopBarTitle"
	name_label.text = tr("UI_BUILD_%s_NAME" % building_id.to_upper())
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", T.display_font(700))
	name_label.add_theme_font_size_override("font_size", 34)
	name_label.add_theme_color_override("font_color", T.UI_HEADER_GOLD)
	name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	name_label.add_theme_constant_override("outline_size", 2)
	identity.add_child(name_label)

	var right := HBoxContainer.new()
	right.name = "BuildingTopBarRight"
	right.custom_minimum_size = Vector2(_TOPBAR_SIDE_WIDTH, 0)
	right.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(right)

	var close_btn := T.ll_close_button(52.0)
	close_btn.name = "BuildingCloseButton"
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_on_close_pressed)
	right.add_child(close_btn)
	return bar


func _add_scene_background() -> void:
	var bg_path := "%s%s_bg.png" % [_BG_DIR, building_id]
	# The accepted Market composition is an indoor mutant bazaar. Preserve the
	# legacy outdoor building background on disk for compatibility, but prefer the
	# purpose-built clean interior whenever the new asset is available.
	if building_id == "market" and ResourceLoader.exists(_MARKET_INTERIOR_BG):
		bg_path = _MARKET_INTERIOR_BG
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
		var tint := accent
		var bg := ColorRect.new()
		bg.color = Color(
			tint.r * 0.10 + 0.02,
			tint.g * 0.10 + 0.02,
			tint.b * 0.10 + 0.02,
			1.0,
		)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)

	var shade := ColorRect.new()
	# The regenerated interiors already reserve a quiet centre for the service UI.
	# Keep only a light veil on Clinic/Outpost; the former 50% shade erased the
	# flat cel colors and made the rooms look like gritty dark-fantasy scenes.
	shade.color = Color(0.0, 0.0, 0.0, 0.0 if building_id == "market" else 0.16)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)


func _build_content(container: VBoxContainer) -> void:
	var placeholder := Label.new()
	placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	placeholder.text = tr("UI_BUILD_COMING")
	_style_label(placeholder, 20, Color(0.8, 0.74, 0.6), 1)
	container.add_child(placeholder)


func _flavour_text() -> String:
	return tr("UI_BUILD_%s_FLAVOUR" % building_id.to_upper())


func _toggle_upgrade_popover() -> void:
	if is_instance_valid(_upgrade_popover):
		_dismiss_upgrade_popover()
		return
	AudioManager.play_sfx("ui_click")
	_upgrade_popover = BUILDING_UPGRADE_POPOVER.new()
	_upgrade_popover.setup(building_id)
	_upgrade_popover.state_changed.connect(_on_upgrade_state_changed)
	_upgrade_popover.dismissed.connect(_dismiss_upgrade_popover)
	add_child(_upgrade_popover)
	call_deferred("_position_upgrade_popover")


func _position_upgrade_popover() -> void:
	if not is_instance_valid(_upgrade_popover) or not is_instance_valid(_upgrade_button):
		return
	var button_anchor_global := _upgrade_button.global_position + Vector2(
		_upgrade_button.size.x * 0.5,
		_upgrade_button.size.y - 3.0,
	)
	var local_anchor := button_anchor_global - global_position
	var x := local_anchor.x - _POPOVER_POINTER_X
	x = clampf(x, 8.0, maxf(8.0, size.x - _POPOVER_SIZE.x - 8.0))
	var y := minf(local_anchor.y, size.y - _POPOVER_SIZE.y - 8.0)
	_upgrade_popover.position = Vector2(x, y)


func _dismiss_upgrade_popover() -> void:
	if not is_instance_valid(_upgrade_popover):
		_upgrade_popover = null
		return
	var popover := _upgrade_popover
	_upgrade_popover = null
	popover.queue_free()


func _on_upgrade_state_changed(_id: String, _tier: int) -> void:
	_refresh()


func _on_caps_changed(_value: int) -> void:
	_rebuild_caps_row()


func _rebuild_caps_row() -> void:
	if not is_instance_valid(_caps_host):
		return
	for child in _caps_host.get_children():
		_caps_host.remove_child(child)
		child.queue_free()
	var row := T.currency_row(MetaProgress.caps, "caps", 23, 27)
	_move_currency_icon_first(row)
	var amount_label := row.get_meta("amount_label") as Label
	if is_instance_valid(amount_label):
		amount_label.add_theme_font_override("font", T.display_font(700))
		amount_label.add_theme_color_override("font_color", Color(0.94, 0.86, 0.68))
	_caps_host.add_child(row)


func _move_currency_icon_first(row: HBoxContainer) -> void:
	for child in row.get_children():
		if child is TextureRect:
			row.move_child(child, 0)
			return


func _refresh() -> void:
	_rebuild_caps_row()
	var tier := MetaProgress.get_building_tier(building_id)
	if is_instance_valid(_services_scroll):
		_services_scroll.visible = tier > 0
	if is_instance_valid(_upgrade_button):
		var maxed := tier >= MetaProgress.MAX_BUILDING_TIER
		_upgrade_button.disabled = maxed
		_upgrade_button.modulate = Color.WHITE if not maxed else Color(0.58, 0.58, 0.58, 0.88)
		_upgrade_button.tooltip_text = tr("UI_BUILD_MAX") if maxed else ""


func _on_close_pressed() -> void:
	AudioManager.play_sfx("ui_back")
	_close()


func _close() -> void:
	_dismiss_upgrade_popover()
	if on_close.is_valid():
		on_close.call()
	else:
		queue_free()


func _local_text(zh: String, en: String) -> String:
	return zh if Settings.language == "zh" else en


func _style_label(label: Label, font_size: int, color: Color, outline_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.90))
	label.add_theme_constant_override("outline_size", outline_size)


## Frameless character-art stage shared by the three full-screen buildings.
## The approved concepts place the NPC directly over the darkened building
## dressing; adding a second portrait card would create the unwanted nested-box
## look.  The transparent asset therefore owns the silhouette and floor shadow,
## while this node only reserves composition space.  A quiet building glyph is
## kept as a warn-free fallback until Godot has imported a newly delivered PNG.
func _build_npc_art_stage(
	texture_path: String,
	node_name: String,
	minimum_size: Vector2,
	fallback_icon: String,
) -> Control:
	var stage := Control.new()
	stage.name = node_name
	stage.custom_minimum_size = minimum_size
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tex: Texture2D = null
	if ResourceLoader.exists(texture_path):
		tex = load(texture_path) as Texture2D
	if tex != null:
		var art := TextureRect.new()
		art.name = "%sArt" % node_name
		art.texture = tex
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stage.add_child(art)
		return stage

	var fallback := CenterContainer.new()
	fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(fallback)
	var fallback_tex := T.lightline_tex(fallback_icon)
	if fallback_tex != null:
		var icon := TextureRect.new()
		icon.texture = fallback_tex
		icon.custom_minimum_size = Vector2(128, 128)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Color(1.0, 1.0, 1.0, 0.42)
		fallback.add_child(icon)
	return stage


func _section_header(text: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(HSeparator.new())
	var label := Label.new()
	label.text = text.to_upper()
	_style_label(label, TOK_FONT_SECTION, TOK_GOLD, 2)
	box.add_child(label)
	return box


func _styled_panel(dark: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = TOK_PANEL_BG_DARK if dark else TOK_PANEL_BG
	style.border_color = TOK_LINE
	style.set_border_width_all(1)
	style.set_corner_radius_all(TOK_RADIUS)
	style.content_margin_left = TOK_MARGIN_INNER
	style.content_margin_right = TOK_MARGIN_INNER
	style.content_margin_top = TOK_MARGIN_INNER
	style.content_margin_bottom = TOK_MARGIN_INNER
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _row_panel() -> HBoxContainer:
	var panel := _styled_panel(false)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, TOK_MARGIN_INNER)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.set_meta("_panel", panel)
	margin.add_child(row)
	return row


func _body_label(text: String, dim: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(
		label,
		TOK_FONT_DIM if dim else TOK_FONT_BODY,
		TOK_TEXT_DIM if dim else TOK_TEXT,
		1,
	)
	return label

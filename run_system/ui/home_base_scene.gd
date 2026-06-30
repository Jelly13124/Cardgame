## Home base scene — the boot scene + post-run return point.
## Shows the Core/Caps/Scrap balance bar, the 5 building selector tiles, the
## stash/loadout button, START NEW RUN, and the recent-runs panel. The base's
## actual functions now live in the per-building screens (run_system/ui/buildings/).
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const MAP_PACKED = preload("res://run_system/ui/map_scene.tscn")
const SETTINGS_PANEL = preload("res://run_system/ui/settings_panel.gd")
const PAUSE_PANEL = preload("res://run_system/ui/pause_panel.gd")
## Fallback hero when no Warehouse selection has been made — the base hero, always
## available. Keeps START NEW RUN robust (a run never begins with an empty hero).
const DEFAULT_HERO_ID := "cowboy_bill"
const EQUIPMENT_ICON = preload("res://run_system/ui/equipment_icon.gd")
const BUILDING_SCREEN_BASE = preload("res://run_system/ui/buildings/building_screen_base.gd")
## Building selector order + per-building accent color. The tile art lives under
## run_system/assets/images/home/buildings/.
const BUILDING_ORDER := ["forge", "clinic", "market", "outpost", "warehouse"]
## Entry-screen arrangement: two flank columns + a centre column. The centre
## column stacks the Warehouse tile above the START "door", so the layout reads
## as "2 buildings left / 2 right / depart-door centre" (warehouse = loadout prep,
## naturally the thing you touch last before leaving).
const LEFT_BUILDINGS := ["forge", "clinic"]
const RIGHT_BUILDINGS := ["market", "outpost"]
const BUILDING_IMAGE_DIR := "res://run_system/assets/images/home/buildings_runtime/"
const BUILDING_ACCENTS := {
	"forge": Color(0.92, 0.55, 0.32),
	"clinic": Color(0.46, 0.86, 0.78),
	"market": Color(0.95, 0.82, 0.40),
	"outpost": Color(0.62, 0.78, 0.96),
	"warehouse": Color(0.78, 0.72, 0.60),
}
const HOME_BACKGROUND_PATH := "res://run_system/assets/images/home/home_base_empty_bg.png"
const MAP_CANVAS_SIZE := Vector2(1920, 1080)

var _core_label: Label
var _caps_label: Label
var _scrap_label: Label
var _difficulty_buttons: Array[Button] = []
## Three-column building area (left flank / centre door / right flank), rebuilt
## on buildings_changed.
var _building_area: HBoxContainer
## Container holding the interactive building sprites + plaques (lock / tier badges).
## Freed + rebuilt on buildings_changed so unlock / tier-up repaints live.
var _buildings_root: Control
## Stash indices the player has marked to carry into the next run (rebuilt into
## RunManager.pending_loadout on every toggle). Reset when the scene reloads.
var _stash_selected: Array[int] = []
var _stash_rebuild: Callable = Callable()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	AudioManager.play_music("home")
	_build()
	MetaProgress.core_changed.connect(func(_v): _refresh_core())
	MetaProgress.caps_changed.connect(func(_v): _refresh_caps())
	# Building selector: top-bar Scrap + lock/tier badges track these.
	MetaProgress.scrap_changed.connect(func(_v): _refresh_scrap())
	# Repaint the building sprites (lock → unlocked, tier badges) the moment a building
	# changes — previously wired to the inert _rebuild_building_tiles, so the lock only
	# cleared on a scene reload (the "must restart to see it unlocked" bug).
	MetaProgress.buildings_changed.connect(_add_building_sprites)


func _build() -> void:
	_add_background()
	_add_building_sprites()
	_add_depart_controls()
	_add_currency_hud()


## Open the How-to-Play panel (loaded at runtime; same pattern as map_scene._open_rules_panel).
func _open_rules_panel() -> void:
	var path := "res://run_system/ui/rules_panel.gd"
	if not ResourceLoader.exists(path):
		return
	var script = load(path)
	if script == null:
		return
	var layer := CanvasLayer.new()
	layer.name = "RulesLayer"
	layer.layer = 140
	add_child(layer)
	var panel = script.new()
	panel.tree_exited.connect(layer.queue_free)
	layer.add_child(panel)


func _build_legacy() -> void:
	_add_background()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	margin.add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	vbox.add_child(header)
	var title := Label.new()
	title.text = tr("UI_HOME_TITLE")
	_style_readable_label(title, 42, Color(1, 0.92, 0.55), 3)
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_core_label = Label.new()
	_style_readable_label(_core_label, 32, Color(0.64, 0.90, 1.0), 3)
	header.add_child(_core_label)
	_refresh_core()

	_caps_label = Label.new()
	# Caps icon is a Codex deliverable; the "🔩" glyph is a placeholder prefix.
	_style_readable_label(_caps_label, 32, Color(1.0, 0.82, 0.45), 3)
	header.add_child(_caps_label)
	_refresh_caps()

	_scrap_label = Label.new()
	_style_readable_label(_scrap_label, 32, Color(0.78, 0.86, 0.62), 3)
	header.add_child(_scrap_label)
	_refresh_scrap()

	var settings_btn := Button.new()
	settings_btn.text = "⚙ " + TranslationServer.translate("SETTINGS_BUTTON")
	settings_btn.custom_minimum_size = Vector2(136, 48)
	settings_btn.add_theme_font_size_override("font_size", 18)
	T.apply_button_theme(settings_btn)
	settings_btn.pressed.connect(_open_pause)
	header.add_child(settings_btn)

	# "?" How-to-Play — the base is the systems hub (tools/relics/equipment/upgrades),
	# so surface the rules here too (previously only on the title + map pause).
	var help_btn := Button.new()
	help_btn.text = "?"
	help_btn.custom_minimum_size = Vector2(48, 48)
	help_btn.focus_mode = Control.FOCUS_NONE
	help_btn.tooltip_text = tr("MENU_HOWTO")
	help_btn.add_theme_font_size_override("font_size", 22)
	T.apply_button_theme(help_btn)
	help_btn.pressed.connect(_open_rules_panel)
	header.add_child(help_btn)

	# (Stash/loadout button + header START removed — START now lives in the centre
	# "door" of the building layout below; the Warehouse owns hero + loadout.)

	# Building selector — the primary view. Three columns: two flank buildings left,
	# two right, and a centre column with the Warehouse above the START door.
	var buildings_label := Label.new()
	buildings_label.text = tr("UI_HOME_BUILDINGS")
	_style_readable_label(buildings_label, 24, Color(1, 0.92, 0.55), 2)
	vbox.add_child(buildings_label)

	_building_area = HBoxContainer.new()
	_building_area.alignment = BoxContainer.ALIGNMENT_CENTER
	_building_area.add_theme_constant_override("separation", 28)
	vbox.add_child(_building_area)
	_rebuild_building_tiles()

	# Recent runs panel — last 5 entries from MetaProgress.run_history.
	var history_label := Label.new()
	history_label.text = tr("UI_HOME_RECENT_RUNS")
	_style_readable_label(history_label, 22, Color(1, 0.92, 0.55), 2)
	vbox.add_child(history_label)
	var history_panel := _build_recent_runs_panel()
	vbox.add_child(history_panel)


func _add_background() -> void:
	if ResourceLoader.exists(HOME_BACKGROUND_PATH):
		var bg := TextureRect.new()
		bg.texture = load(HOME_BACKGROUND_PATH)
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
	else:
		var bg := ColorRect.new()
		bg.color = Color(0.08, 0.07, 0.05, 1.0)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)


func _add_currency_hud() -> void:
	var row := HBoxContainer.new()
	row.name = "CurrencyHud"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	row.anchor_left = 0.0
	row.anchor_top = 0.0
	row.anchor_right = 0.0
	row.anchor_bottom = 0.0
	row.offset_left = 22
	row.offset_top = 28
	row.offset_right = 530
	row.offset_bottom = 92
	add_child(row)

	_core_label = _make_currency_chip(row, "core", Color(0.28, 0.90, 1.0))
	_caps_label = _make_currency_chip(row, "caps", Color(1.0, 0.62, 0.34))
	_scrap_label = _make_currency_chip(row, "scrap", Color(0.86, 0.80, 0.62))
	_refresh_core()
	_refresh_caps()
	_refresh_scrap()


func _add_building_sprites() -> void:
	# Re-entrant: also fires on buildings_changed. Free the prior visuals (immediately,
	# so there's no one-frame double-draw) and rebuild under a single root container.
	if is_instance_valid(_buildings_root):
		remove_child(_buildings_root)
		_buildings_root.queue_free()
	_buildings_root = Control.new()
	_buildings_root.name = "BuildingsRoot"
	_buildings_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_buildings_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_buildings_root)
	# Keep the buildings just above the background (below the HUD / depart / help button)
	# even when re-added last on a rebuild.
	move_child(_buildings_root, 1)
	_add_interactive_building(
		"forge",
		Rect2(55, 300, 360, 360),
		tr("UI_BUILD_FORGE_NAME"),
		func() -> void: _open_building_screen("forge")
	)
	_add_interactive_building(
		"clinic",
		Rect2(410, 300, 360, 360),
		tr("UI_BUILD_CLINIC_NAME"),
		func() -> void: _open_building_screen("clinic")
	)
	_add_interactive_building(
		"market",
		Rect2(780, 300, 360, 360),
		tr("UI_BUILD_MARKET_NAME"),
		func() -> void: _open_building_screen("market")
	)
	_add_interactive_building(
		"outpost",
		Rect2(1145, 300, 360, 360),
		tr("UI_BUILD_OUTPOST_NAME"),
		func() -> void: _open_building_screen("outpost")
	)
	_add_interactive_building(
		"warehouse",
		Rect2(1510, 300, 360, 360),
		tr("UI_BUILD_WAREHOUSE_NAME"),
		func() -> void: _open_building_screen("warehouse")
	)

	_add_building_plaque("forge", Rect2(128, 218, 215, 78), tr("UI_BUILD_FORGE_NAME"))
	_add_building_plaque("clinic", Rect2(482, 218, 215, 78), tr("UI_BUILD_CLINIC_NAME"))
	_add_building_plaque("market", Rect2(852, 218, 215, 78), tr("UI_BUILD_MARKET_NAME"))
	_add_building_plaque("outpost", Rect2(1218, 218, 215, 78), tr("UI_BUILD_OUTPOST_NAME"))
	_add_building_plaque("warehouse", Rect2(1582, 218, 215, 78), tr("UI_BUILD_WAREHOUSE_NAME"))


func _add_depart_controls() -> void:
	var button := Button.new()
	button.name = "StartRunButton"
	button.text = TranslationServer.translate("UI_HOME_START_RUN")
	button.custom_minimum_size = Vector2(320, 62)
	button.add_theme_font_size_override("font_size", 26)
	T.apply_button_theme(button)
	button.add_theme_color_override("font_color", Color(1.0, 0.88, 0.50))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.70))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	button.pressed.connect(_on_start_pressed)
	_set_map_rect(button, Rect2(800, 812, 320, 64))
	add_child(button)

	_add_difficulty_bar(Rect2(650, 886, 620, 82))


func _add_difficulty_bar(rect: Rect2) -> void:
	var panel := PanelContainer.new()
	panel.name = "DifficultyBar"
	panel.add_theme_stylebox_override(
		"panel",
		T.panel_with_shadow(Color(0.085, 0.055, 0.035, 0.94), Color(0.78, 0.45, 0.18), 6, 3)
	)
	_set_map_rect(panel, rect)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var title := Label.new()
	title.custom_minimum_size = Vector2(72, 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = tr("UI_OUTPOST_SECT_DIFFICULTY")
	_style_readable_label(title, 20, Color(1.0, 0.86, 0.54), 3)
	row.add_child(title)

	_difficulty_buttons.clear()
	var max_unlocked: int = clampi(int(MetaProgress.max_ascension), 0, 5)
	var pending: int = RunManager.pending_ascension if RunManager.pending_ascension >= 0 else 0
	var current: int = clampi(pending, 0, max_unlocked)
	RunManager.pending_ascension = current
	for value in range(6):
		var btn := Button.new()
		btn.toggle_mode = true
		btn.text = "A%d" % value
		btn.custom_minimum_size = Vector2(58, 42)
		btn.add_theme_font_size_override("font_size", 17)
		btn.disabled = value > max_unlocked
		btn.button_pressed = value == current
		_style_difficulty_button(btn, btn.button_pressed, btn.disabled)
		var asc := value
		btn.pressed.connect(func() -> void: _on_home_difficulty_chosen(asc))
		row.add_child(btn)
		_difficulty_buttons.append(btn)


func _on_home_difficulty_chosen(value: int) -> void:
	var max_unlocked: int = clampi(int(MetaProgress.max_ascension), 0, 5)
	RunManager.pending_ascension = clampi(value, 0, max_unlocked)
	for i in range(_difficulty_buttons.size()):
		var btn := _difficulty_buttons[i]
		if is_instance_valid(btn):
			btn.button_pressed = i == RunManager.pending_ascension
			_style_difficulty_button(btn, btn.button_pressed, btn.disabled)


func _style_difficulty_button(button: Button, selected: bool, disabled: bool) -> void:
	var bg := Color(0.13, 0.10, 0.075, 0.96)
	var border := Color(0.55, 0.36, 0.18, 1.0)
	var text := Color(0.86, 0.76, 0.58, 1.0)
	if selected:
		bg = Color(0.30, 0.17, 0.065, 0.98)
		border = Color(1.0, 0.72, 0.28, 1.0)
		text = Color(1.0, 0.90, 0.55, 1.0)
	elif disabled:
		bg = Color(0.07, 0.06, 0.052, 0.78)
		border = Color(0.25, 0.20, 0.16, 0.75)
		text = Color(0.42, 0.36, 0.28, 0.85)
	button.add_theme_stylebox_override("normal", T.rounded_button(bg, border, 5, 2))
	button.add_theme_stylebox_override(
		"hover", T.rounded_button(bg.lightened(0.10), Color(0.35, 0.88, 1.0, 1.0), 5, 2)
	)
	button.add_theme_stylebox_override("pressed", T.rounded_button(bg.darkened(0.10), border, 5, 2))
	button.add_theme_stylebox_override("disabled", T.rounded_button(bg, border, 5, 2))
	button.add_theme_color_override("font_color", text)
	button.add_theme_color_override("font_hover_color", text.lightened(0.15))
	button.add_theme_color_override("font_pressed_color", text)
	button.add_theme_color_override("font_disabled_color", text)
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	button.add_theme_constant_override("outline_size", 1)


func _add_interactive_building(
	asset_id: String, rect: Rect2, tooltip: String, callback: Callable
) -> void:
	var normal_tex := _load_home_texture("%s%s.png" % [BUILDING_IMAGE_DIR, asset_id])
	var hover_tex := _load_home_texture("%s%s_hover.png" % [BUILDING_IMAGE_DIR, asset_id])
	var pressed_tex := _load_home_texture("%s%s_pressed.png" % [BUILDING_IMAGE_DIR, asset_id])
	var button := TextureButton.new()
	button.name = "Building_%s" % asset_id
	button.texture_normal = normal_tex
	button.texture_hover = hover_tex if hover_tex is Texture2D else normal_tex
	button.texture_pressed = pressed_tex if pressed_tex is Texture2D else button.texture_hover
	button.texture_click_mask = _make_click_mask(normal_tex)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_set_map_rect(button, rect)
	# The building sprites already swap to a hover texture, but were silent — add the
	# hover tick + click so the boot screen feels responsive (sound connected before
	# the callback so it still fires when the callback opens a building overlay).
	button.mouse_entered.connect(func() -> void: AudioManager.play_sfx("ui_hover"))
	button.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	button.pressed.connect(callback)
	_buildings_root.add_child(button)
	# Locked buildings (not yet unlocked with Core) render dimmed with a lock badge so
	# it reads at a glance which ones aren't available. Still clickable — the building
	# screen is where you spend Core to unlock.
	if MetaProgress.get_building_tier(asset_id) <= 0:
		button.modulate = Color(0.5, 0.5, 0.55)
		var lock := Label.new()
		lock.text = "🔒"
		lock.add_theme_font_size_override("font_size", 76)
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_map_rect(lock, rect)
		_buildings_root.add_child(lock)


func _make_click_mask(texture: Texture2D) -> BitMap:
	if not texture:
		return null
	var image := texture.get_image()
	if image == null:
		return null
	var mask := BitMap.new()
	mask.create_from_image_alpha(image, 0.1)
	return mask


## Floating building label: "Lv<tier>  <name>", centered, no box, gentle up-down bob.
func _add_building_plaque(building_id: String, rect: Rect2, title: String) -> void:
	var label := Label.new()
	label.name = "Plaque_%s" % building_id
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if building_id == "depart_gate":
		label.text = title
	elif MetaProgress.get_building_tier(building_id) <= 0:
		label.text = title  # locked: name only (the 🔒 sits on the sprite)
	else:
		label.text = "Lv%d  %s" % [MetaProgress.get_building_tier(building_id), title]
	label.add_theme_font_size_override("font_size", 33)
	label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.68))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 9)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 5)
	_set_map_rect(label, rect)
	_buildings_root.add_child(label)
	# Gentle bob; duration varies a touch per building so they drift out of lockstep.
	var base_y := label.position.y
	var dur := 1.7 + fmod(rect.position.x * 0.0017, 1.0) * 0.6
	var tw := label.create_tween().set_loops()
	tw.tween_property(label, "position:y", base_y - 7.0, dur).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	tw.tween_property(label, "position:y", base_y, dur).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	# Unlock / upgrade action lives here on the overview now (moved off the detail page).
	if building_id != "depart_gate":
		_add_tier_button(building_id, rect)
	return


## Unlock / upgrade button under a building's floating label — confirms before spending Core.
## Hidden at max tier. Rebuilt with the plaques on buildings_changed so it stays live.
func _add_tier_button(building_id: String, plaque_rect: Rect2) -> void:
	var tier := MetaProgress.get_building_tier(building_id)
	var cost := MetaProgress.next_building_cost(building_id)
	if cost < 0:
		return  # maxed (or no unlock cost) → no button
	var zh := Settings.language == "zh"
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 17)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	T.apply_button_theme(btn)
	if tier <= 0:
		btn.text = ("解锁  %d 核心" if zh else "Unlock  %d Core") % cost
	else:
		btn.text = ("升级  %d 核心" if zh else "Upgrade  %d Core") % cost
	btn.disabled = cost < 0 or MetaProgress.core < cost
	btn.pressed.connect(
		func() -> void:
			AudioManager.play_sfx("ui_click")
			_show_tier_confirm(building_id)
	)
	var bw := 196.0
	var br := Rect2(
		plaque_rect.position.x + plaque_rect.size.x * 0.5 - bw * 0.5,
		plaque_rect.position.y + plaque_rect.size.y - 4,
		bw,
		40
	)
	_set_map_rect(btn, br)
	_buildings_root.add_child(btn)


## Confirmation popup for an unlock/upgrade. Confirm spends Core via MetaProgress
## (→ buildings_changed → the overview rebuilds with the new tier).
func _show_tier_confirm(building_id: String) -> void:
	if get_node_or_null("TierConfirm") != null:
		return  # a confirm popup is already open
	var tier := MetaProgress.get_building_tier(building_id)
	var cost := MetaProgress.next_building_cost(building_id)
	if cost < 0 or MetaProgress.core < cost:
		return
	var zh := Settings.language == "zh"
	var is_unlock := tier <= 0
	var bname := tr("UI_BUILD_%s_NAME" % building_id.to_upper())

	var layer := CanvasLayer.new()
	layer.name = "TierConfirm"
	layer.layer = 155
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(470, 0)
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	center.add_child(panel)
	var m := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(s, 28)
	panel.add_child(m)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	m.add_child(box)

	var msg := Label.new()
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_unlock:
		msg.text = ("解锁「%s」?\n花费 %d 核心" if zh else 'Unlock "%s"?\nCost %d Core') % [bname, cost]
	else:
		var t2 := tier + 1
		msg.text = (
			("把「%s」升级到 T%d?\n花费 %d 核心" if zh else 'Upgrade "%s" to T%d?\nCost %d Core')
			% [bname, t2, cost]
		)
	msg.add_theme_font_size_override("font_size", 22)
	msg.add_theme_color_override("font_color", Color(1.0, 0.93, 0.78))
	box.add_child(msg)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var yes := Button.new()
	yes.text = "确认" if zh else "Confirm"
	yes.custom_minimum_size = Vector2(150, 46)
	yes.focus_mode = Control.FOCUS_NONE
	T.apply_button_theme(yes)
	yes.pressed.connect(
		func() -> void:
			AudioManager.play_sfx("reward")
			if is_unlock:
				MetaProgress.unlock_building(building_id)
			else:
				MetaProgress.upgrade_building(building_id)
			layer.queue_free()
	)
	row.add_child(yes)
	var no := Button.new()
	no.text = "取消" if zh else "Cancel"
	no.custom_minimum_size = Vector2(150, 46)
	no.focus_mode = Control.FOCUS_NONE
	T.apply_button_theme(no)
	no.pressed.connect(
		func() -> void:
			AudioManager.play_sfx("ui_back")
			layer.queue_free()
	)
	row.add_child(no)


## Superseded by the floating-label version above; unused, kept for reference.
func _add_building_plaque_OLD(building_id: String, rect: Rect2, title: String) -> void:
	var tier := 1
	if building_id != "depart_gate":
		tier = MetaProgress.get_building_tier(building_id)
	var accent: Color = BUILDING_ACCENTS.get(building_id, Color(0.86, 0.60, 0.30))
	var panel := PanelContainer.new()
	panel.name = "Plaque_%s" % building_id
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(Color(0.075, 0.050, 0.034, 0.94), accent.darkened(0.10), 6, 2)
	)
	_set_map_rect(panel, rect)
	_buildings_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var title_label := Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.54))
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title_label.add_theme_constant_override("outline_size", 3)
	row.add_child(title_label)

	if building_id != "depart_gate":
		var tier_badge := PanelContainer.new()
		tier_badge.custom_minimum_size = Vector2(52, 44)
		tier_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tier_badge.add_theme_stylebox_override(
			"panel", T.rounded_button(Color(0.13, 0.095, 0.055, 0.96), accent.lightened(0.10), 5, 2)
		)
		row.add_child(tier_badge)

		var badge_margin := MarginContainer.new()
		badge_margin.add_theme_constant_override("margin_left", 4)
		badge_margin.add_theme_constant_override("margin_right", 4)
		badge_margin.add_theme_constant_override("margin_top", 3)
		badge_margin.add_theme_constant_override("margin_bottom", 3)
		tier_badge.add_child(badge_margin)

		var tier_label := Label.new()
		tier_label.text = "T%d" % tier
		tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tier_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tier_label.add_theme_font_size_override("font_size", 19)
		tier_label.add_theme_color_override("font_color", Color(0.82, 1.0, 0.72))
		tier_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		tier_label.add_theme_constant_override("outline_size", 3)
		badge_margin.add_child(tier_label)


func _set_map_rect(control: Control, rect: Rect2) -> void:
	control.anchor_left = rect.position.x / MAP_CANVAS_SIZE.x
	control.anchor_top = rect.position.y / MAP_CANVAS_SIZE.y
	control.anchor_right = (rect.position.x + rect.size.x) / MAP_CANVAS_SIZE.x
	control.anchor_bottom = (rect.position.y + rect.size.y) / MAP_CANVAS_SIZE.y
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0


func _load_home_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			return tex
	return null


## Currency chip: the Codex currency icon + the live value. If the icon PNG is
## missing, the chip falls back to a small accent-tinted name label so the counter
## stays readable on the home-base background.
func _make_currency_chip(parent: Control, _icon_id: String, accent: Color) -> Label:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(134, 64)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# No background frame — the icon + number sit bare on the scene (owner request).
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)

	# The currency NAME label — shown only as the missing-art fallback: when the icon
	# PNG loads (below) the name is hidden and the icon takes its slot. Keeps the chip
	# readable if the art ever regresses.
	var zh := Settings.language == "zh"
	var cname := "核心" if zh else "Core"
	if _icon_id == "caps":
		cname = "瓶盖" if zh else "Caps"
	elif _icon_id == "scrap":
		cname = "废料" if zh else "Scrap"
	# Hierarchy: the NAME is a small muted accent label, the NUMBER dominates (bigger,
	# brighter). Keeps the frameless look (owner request). The accent-tinted name
	# doubles as the per-currency color cue on the missing-art fallback path.
	var tag := Label.new()
	tag.text = cname
	tag.add_theme_font_size_override("font_size", 15)
	tag.add_theme_color_override("font_color", accent.lerp(Color(0.86, 0.82, 0.72), 0.35))
	tag.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	tag.add_theme_constant_override("outline_size", 4)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tag)

	var icon_path := "res://run_system/assets/images/home/currency/%s.png" % _icon_id
	var icon_tex := _load_home_texture(icon_path)
	if icon_tex:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(54, 54)
		icon.texture = icon_tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		row.move_child(icon, tag.get_index())
		tag.visible = false

	var label := Label.new()
	label.text = "0"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 31)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.78))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.5))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return label


func _style_readable_label(label: Label, font_size: int, color: Color, outline_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.90))
	label.add_theme_constant_override("outline_size", outline_size)


## Settings overlay (Language / Fullscreen / Volume). Language change reloads
## the home base so all labels pick up the new locale.
## Open the unified pause panel (the ⚙ gear). No run is active at the base, so the
## Abandon option auto-hides (PAUSE_PANEL.open is passed is_run_active = false here).
func _open_pause() -> void:
	PAUSE_PANEL.open(self, RunManager.is_run_active)


## Superseded by _open_pause; no longer wired. Kept for reference, safe to delete later.
func _open_settings() -> void:
	if get_node_or_null("SettingsOverlay") != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "SettingsOverlay"
	layer.layer = 130
	add_child(layer)

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 380)
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.text = TranslationServer.translate("SETTINGS_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48))
	box.add_child(title)

	SETTINGS_PANEL.add_controls(box, func() -> void: get_tree().reload_current_scene(), false)
	SETTINGS_PANEL.add_key_controls(box)

	box.add_child(HSeparator.new())

	var close_btn := Button.new()
	close_btn.text = TranslationServer.translate("SETTINGS_RESUME")
	close_btn.custom_minimum_size = Vector2(300, 44)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(layer.queue_free)
	box.add_child(close_btn)


func _refresh_core() -> void:
	if _core_label:
		_core_label.text = str(MetaProgress.core)


func _refresh_caps() -> void:
	if _caps_label:
		_caps_label.text = str(MetaProgress.caps)


func _refresh_scrap() -> void:
	if _scrap_label:
		_scrap_label.text = str(MetaProgress.scrap)


## Rebuild the three-column building area: left flank (Forge/Clinic), centre
## column (Warehouse tile + START door), right flank (Market/Outpost). Called on
## build and on every buildings_changed so lock→unlock / tier-up repaint live.
func _rebuild_building_tiles() -> void:
	if not is_instance_valid(_building_area):
		return
	for c in _building_area.get_children():
		c.queue_free()
	_building_area.add_child(_make_building_column(LEFT_BUILDINGS))
	_building_area.add_child(_make_center_column())
	_building_area.add_child(_make_building_column(RIGHT_BUILDINGS))


## A flank column: stacked building tiles.
func _make_building_column(building_ids: Array) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	for building_id in building_ids:
		col.add_child(_make_building_tile(str(building_id)))
	return col


## The centre column: the Warehouse tile sits directly above the START "door".
func _make_center_column() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_make_building_tile("warehouse"))
	col.add_child(_make_start_door())
	return col


## The START "door": a tall, golden, clickable tile that launches the run. Visually
## distinct from the building tiles (warm gradient + DEPART label) so it reads as
## the way out, not another building.
func _make_start_door() -> Control:
	var accent := Color(1.0, 0.82, 0.36)
	var door := PanelContainer.new()
	door.custom_minimum_size = Vector2(300, 196)
	door.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(Color(0.16, 0.12, 0.05, 0.97), accent, 6, 4)
	)
	door.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	door.add_child(box)

	var glyph := Label.new()
	glyph.text = "🚪"
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", 64)
	box.add_child(glyph)

	var label := Label.new()
	label.text = TranslationServer.translate("UI_HOME_START_RUN")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_readable_label(label, 28, Color(1.0, 0.92, 0.55), 3)
	box.add_child(label)

	door.gui_input.connect(
		func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_on_start_pressed()
	)
	return door


func _make_building_tile(building_id: String) -> Control:
	var accent: Color = BUILDING_ACCENTS.get(building_id, Color(0.86, 0.78, 0.52))
	var tier := MetaProgress.get_building_tier(building_id)

	# Big, intentional tile: accent border, generated building art, and lock/tier badge.
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(300, 220)
	var border := accent
	border.a = 1.0
	tile.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(Color(0.075, 0.060, 0.048, 0.96), border, 6, 3)
	)
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	tile.add_child(box)

	# Accent header strip across the top with the building name (prominent, distinct).
	var header_strip := PanelContainer.new()
	header_strip.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(Color(accent.r, accent.g, accent.b, 0.92), border, 4, 0)
	)
	box.add_child(header_strip)
	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 12)
	header_margin.add_theme_constant_override("margin_right", 12)
	header_margin.add_theme_constant_override("margin_top", 8)
	header_margin.add_theme_constant_override("margin_bottom", 8)
	header_strip.add_child(header_margin)
	var name_lbl := Label.new()
	name_lbl.text = tr("UI_BUILD_%s_NAME" % building_id.to_upper())
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Dark text on the bright accent strip reads cleanly.
	_style_readable_label(name_lbl, 24, Color(0.10, 0.08, 0.06), 0)
	header_margin.add_child(name_lbl)

	var body_margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		body_margin.add_theme_constant_override(side, 14)
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body_margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body_margin.add_child(body)

	var art := TextureRect.new()
	art.texture = _load_building_texture(building_id)
	art.custom_minimum_size = Vector2(0, 112)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(art)

	var badge := Label.new()
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if tier <= 0:
		badge.text = "🔒 " + tr("UI_BUILD_LOCKED")
		_style_readable_label(badge, 20, Color(0.86, 0.62, 0.56), 1)
	else:
		badge.text = "T%d" % tier
		_style_readable_label(badge, 20, Color(0.7, 0.92, 0.7), 1)
	body.add_child(badge)

	tile.gui_input.connect(
		func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_open_building_screen(building_id)
	)
	return tile


func _load_building_texture(building_id: String) -> Texture2D:
	var path := "%s%s.png" % [BUILDING_IMAGE_DIR, building_id]
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			return tex
	return null


## Open a building's screen as a full-rect overlay child. Phase 1 swaps in
## per-building subclasses of BUILDING_SCREEN_BASE; for now every tile opens the
## shared base screen (real unlock/upgrade buttons, placeholder content).
func _open_building_screen(building_id: String) -> void:
	if get_node_or_null("BuildingOverlay") != null:
		return
	if MetaProgress.get_building_tier(building_id) <= 0:
		# Locked: the unlock action moved to the overview — show its confirm popup
		# instead of opening an empty services page.
		_show_tier_confirm(building_id)
		return
	# Convention: load run_system/ui/buildings/<id>_screen.gd (a BUILDING_SCREEN_BASE
	# subclass) if it exists, else fall back to the shared base (placeholder content).
	# This lets each building screen be added as its own isolated file.
	var script_path := "res://run_system/ui/buildings/%s_screen.gd" % building_id
	var screen = (
		load(script_path).new()
		if ResourceLoader.exists(script_path)
		else BUILDING_SCREEN_BASE.new()
	)
	screen.name = "BuildingOverlay"
	screen.building_id = building_id
	screen.accent = BUILDING_ACCENTS.get(building_id, Color(0.86, 0.78, 0.52))
	screen.on_close = func() -> void:
		if is_instance_valid(screen):
			screen.queue_free()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen)


## Stash & loadout overlay: shows the permanent equipment stash; left-click an
## item to mark it for the next run (rebuilt into RunManager.pending_loadout).
func _open_stash() -> void:
	if get_node_or_null("StashOverlay") != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "StashOverlay"
	layer.layer = 130
	add_child(layer)

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.66)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(940, 620)
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title := Label.new()
	title.text = TranslationServer.translate("UI_HOME_STASH")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48))
	box.add_child(title)

	var hint := Label.new()
	hint.text = TranslationServer.translate("UI_HOME_STASH_HINT")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.8, 0.74, 0.6))
	box.add_child(hint)

	var count_lbl := Label.new()
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	box.add_child(count_lbl)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 380)
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	_stash_rebuild = func() -> void:
		if not is_instance_valid(grid) or not is_instance_valid(count_lbl):
			return
		for c in grid.get_children():
			c.queue_free()
		var st: Array = MetaProgress.stash
		if st.is_empty():
			var empty := Label.new()
			empty.text = TranslationServer.translate("UI_HOME_STASH_EMPTY")
			empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			grid.add_child(empty)
		else:
			for i in range(st.size()):
				# Stash entries may be instances or legacy strings; resolve the
				# display base id tolerantly.
				grid.add_child(_make_stash_cell(int(i), RunManager.equip_base(st[i])))
		count_lbl.text = TranslationServer.translate("UI_HOME_STASH_SELECTED").format(
			{"n": _stash_selected.size()}
		)
	_stash_rebuild.call()

	var close := Button.new()
	close.text = TranslationServer.translate("SETTINGS_RESUME")
	close.custom_minimum_size = Vector2(300, 44)
	close.pressed.connect(layer.queue_free)
	box.add_child(close)


func _make_stash_cell(index: int, item_id: String) -> Control:
	var data = RunManager.get_equipment_data(item_id)
	var slot := str(data.get("slot", "head"))
	var item_name := Settings.t("EQUIP_%s_NAME" % item_id, str(data.get("name", item_id)))
	var icon := EQUIPMENT_ICON.new()
	icon.custom_minimum_size = Vector2(76, 76)
	icon.set_equipment(
		slot, item_name, str(data.get("sprite", "")), str(data.get("rarity", "common"))
	)
	icon.set_hover_tooltip("[b]%s[/b]" % item_name)
	icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if index in _stash_selected:
		icon.modulate = Color(0.5, 1.0, 0.5)
	icon.gui_input.connect(
		func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_toggle_stash_select(index)
	)
	return icon


## Toggle whether stash item `index` is carried into the next run, keeping
## RunManager.pending_loadout in sync. Capped at the usable backpack size.
func _toggle_stash_select(index: int) -> void:
	if index in _stash_selected:
		_stash_selected.erase(index)
	elif _stash_selected.size() < RunManager.effective_backpack_size():
		_stash_selected.append(index)
	RunManager.pending_loadout.clear()
	for i in _stash_selected:
		if i < MetaProgress.stash.size():
			# Push the actual stash entry (instance dict, or legacy string) so
			# its rolled affixes travel into the run intact.
			RunManager.pending_loadout.append(MetaProgress.stash[i])
	if _stash_rebuild.is_valid():
		_stash_rebuild.call()


## START NEW RUN launches the run directly (the hero-select screen was removed).
## Hero + ascension come from the pending intent set by the Warehouse (hero) and
## Outpost (difficulty) building screens; both fall back to safe defaults so a run
## never starts with an empty hero. start_new_run also resolves these pending
## values internally — passing them explicitly here keeps the behavior obvious.
func _on_start_pressed() -> void:
	var hero: String = (
		RunManager.pending_hero_id if RunManager.pending_hero_id != "" else DEFAULT_HERO_ID
	)
	var asc: int = RunManager.pending_ascension if RunManager.pending_ascension >= 0 else 0
	RunManager.start_new_run(hero, [], asc)
	SceneTransition.change_to_packed(MAP_PACKED)


func _build_recent_runs_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var history: Array = MetaProgress.run_history
	if history.is_empty():
		var none := Label.new()
		none.text = tr("UI_HOME_NO_RUNS")
		none.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		vbox.add_child(none)
		return panel

	# Show newest first, max 5 entries.
	var slice_start: int = max(0, history.size() - 5)
	var to_show: Array = history.slice(slice_start)
	to_show.reverse()
	for entry in to_show:
		vbox.add_child(_build_history_row(entry))
	return panel


func _build_history_row(entry: Dictionary) -> Label:
	var outcome: String = str(entry.get("outcome", "?"))
	var icon: String = "✓" if outcome == "victory" else ("⤴" if outcome == "extracted" else "✗")
	var color: Color = (
		{
			"victory": Color(0.4, 1.0, 0.5),
			"extracted": Color(1.0, 0.9, 0.4),
		}
		. get(outcome, Color(1.0, 0.4, 0.4))
	)

	var hero: String = _humanize_hero_id(str(entry.get("hero_id", "?")))
	var floor_index: int = int(entry.get("floor", 0))
	var act: int = int(entry.get("act", 1))  # legacy summaries predate `act`
	var core_earned: int = int(entry.get("core_earned", 0))

	var row := Label.new()
	row.text = (tr("UI_HOME_RUN_ROW").format(
		{"icon": icon, "hero": hero, "act": act, "floor": floor_index + 1, "core": core_earned}
	))
	row.add_theme_color_override("font_color", color)
	return row


func _humanize_hero_id(hero_id: String) -> String:
	# Quick lookup table — covers the two heroes we ship. These are compact
	# run-history nicknames (not the canonical hero name), so they are local UI
	# labels owned by ui_home, not the HERO_<id>_NAME content key.
	var names := {
		"cowboy_bill": tr("UI_HOME_HERO_BILL"),
	}
	if names.has(hero_id):
		return names[hero_id]
	return hero_id.replace("_", " ").capitalize()

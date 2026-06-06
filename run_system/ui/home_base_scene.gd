## Home base scene — the boot scene + post-run return point.
## Shows the Core/Caps/Scrap balance bar, the 5 building selector tiles, the
## stash/loadout button, START NEW RUN, and the recent-runs panel. The base's
## actual functions now live in the per-building screens (run_system/ui/buildings/).
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const HERO_SELECT_PACKED = preload("res://run_system/ui/hero_select.tscn")
const SETTINGS_PANEL = preload("res://run_system/ui/settings_panel.gd")
const EQUIPMENT_ICON = preload("res://run_system/ui/equipment_icon.gd")
const BUILDING_SCREEN_BASE = preload("res://run_system/ui/buildings/building_screen_base.gd")
## Building selector order + per-building placeholder accent (Codex art swaps the
## tile sprite later; the accent keeps the 5 tiles visually distinct meanwhile).
const BUILDING_ORDER := ["forge", "clinic", "market", "outpost", "warehouse"]
const BUILDING_ACCENTS := {
	"forge": Color(0.92, 0.55, 0.32),
	"clinic": Color(0.46, 0.86, 0.78),
	"market": Color(0.95, 0.82, 0.40),
	"outpost": Color(0.62, 0.78, 0.96),
	"warehouse": Color(0.78, 0.72, 0.60),
}
const HOME_BACKGROUND_PATH := "res://run_system/assets/images/home/home_base_bg.png"

var _core_label: Label
var _caps_label: Label
var _scrap_label: Label
## Building selector tiles, keyed by building_id, rebuilt on buildings_changed.
var _building_grid: GridContainer
## Stash indices the player has marked to carry into the next run (rebuilt into
## RunManager.pending_loadout on every toggle). Reset when the scene reloads.
var _stash_selected: Array[int] = []
var _stash_rebuild: Callable = Callable()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	MetaProgress.core_changed.connect(func(_v): _refresh_core())
	MetaProgress.caps_changed.connect(func(_v): _refresh_caps())
	# Building selector: top-bar Scrap + tile lock/tier badges track these.
	MetaProgress.scrap_changed.connect(func(_v): _refresh_scrap())
	MetaProgress.buildings_changed.connect(_rebuild_building_tiles)


func _build() -> void:
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
	settings_btn.pressed.connect(_open_settings)
	header.add_child(settings_btn)

	var stash_btn := Button.new()
	stash_btn.text = "⚒ " + TranslationServer.translate("UI_HOME_STASH_BTN")
	stash_btn.custom_minimum_size = Vector2(150, 48)
	stash_btn.add_theme_font_size_override("font_size", 18)
	T.apply_button_theme(stash_btn)
	stash_btn.pressed.connect(_open_stash)
	header.add_child(stash_btn)

	var start_btn := Button.new()
	start_btn.text = TranslationServer.translate("UI_HOME_START_RUN")
	start_btn.custom_minimum_size = Vector2(220, 52)
	start_btn.add_theme_font_size_override("font_size", 22)
	T.apply_button_theme(start_btn)
	start_btn.pressed.connect(_on_start_pressed)
	header.add_child(start_btn)

	# Building selector — the primary view (5 clickable tiles). Each tile opens its
	# building screen, which surfaces that building's functions.
	var buildings_label := Label.new()
	buildings_label.text = tr("UI_HOME_BUILDINGS")
	_style_readable_label(buildings_label, 24, Color(1, 0.92, 0.55), 2)
	vbox.add_child(buildings_label)

	_building_grid = GridContainer.new()
	_building_grid.columns = 5
	_building_grid.add_theme_constant_override("h_separation", 18)
	_building_grid.add_theme_constant_override("v_separation", 18)
	vbox.add_child(_building_grid)
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
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	shade.color = Color(0.0, 0.0, 0.0, 0.36)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)


func _style_readable_label(label: Label, font_size: int, color: Color, outline_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.90))
	label.add_theme_constant_override("outline_size", outline_size)


## Settings overlay (Language / Fullscreen / Volume). Language change reloads
## the home base so all labels pick up the new locale.
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

	box.add_child(HSeparator.new())

	var close_btn := Button.new()
	close_btn.text = TranslationServer.translate("SETTINGS_RESUME")
	close_btn.custom_minimum_size = Vector2(300, 44)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(layer.queue_free)
	box.add_child(close_btn)


func _refresh_core() -> void:
	if _core_label:
		_core_label.text = tr("UI_HOME_CORE").format({"n": MetaProgress.core})


func _refresh_caps() -> void:
	if _caps_label:
		_caps_label.text = tr("UI_HOME_CAPS").format({"n": MetaProgress.caps})


func _refresh_scrap() -> void:
	if _scrap_label:
		_scrap_label.text = tr("UI_HOME_SCRAP").format({"n": MetaProgress.scrap})


## Rebuild the 5 building selector tiles (placeholder: a themed Panel with an
## accent strip + name + lock/tier badge). Called on build and on every
## buildings_changed so locked→unlocked / tier-up transitions repaint live.
func _rebuild_building_tiles() -> void:
	if not is_instance_valid(_building_grid):
		return
	for c in _building_grid.get_children():
		c.queue_free()
	for building_id in BUILDING_ORDER:
		_building_grid.add_child(_make_building_tile(str(building_id)))


func _make_building_tile(building_id: String) -> Control:
	var accent: Color = BUILDING_ACCENTS.get(building_id, Color(0.86, 0.78, 0.52))
	var tier := MetaProgress.get_building_tier(building_id)

	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(180, 150)
	tile.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	tile.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	# Placeholder "sprite": a flat accent-colored block (Codex art swaps this).
	var accent_block := ColorRect.new()
	accent_block.color = accent
	accent_block.custom_minimum_size = Vector2(0, 56)
	accent_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(accent_block)

	var name_lbl := Label.new()
	name_lbl.text = tr("UI_BUILD_%s_NAME" % building_id.to_upper())
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_readable_label(name_lbl, 18, Color(1, 0.92, 0.55), 1)
	box.add_child(name_lbl)

	var badge := Label.new()
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if tier <= 0:
		badge.text = "🔒"
		_style_readable_label(badge, 18, Color(0.82, 0.6, 0.55), 1)
	else:
		badge.text = "T%d" % tier
		_style_readable_label(badge, 18, Color(0.7, 0.92, 0.7), 1)
	box.add_child(badge)

	tile.gui_input.connect(
		func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_open_building_screen(building_id)
	)
	return tile


## Open a building's screen as a full-rect overlay child. Phase 1 swaps in
## per-building subclasses of BUILDING_SCREEN_BASE; for now every tile opens the
## shared base screen (real unlock/upgrade buttons, placeholder content).
func _open_building_screen(building_id: String) -> void:
	if get_node_or_null("BuildingOverlay") != null:
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
	icon.set_equipment(slot, item_name, str(data.get("sprite", "")))
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
## RunManager.pending_loadout in sync. Capped at MAX_INVENTORY items.
func _toggle_stash_select(index: int) -> void:
	if index in _stash_selected:
		_stash_selected.erase(index)
	elif _stash_selected.size() < RunManager.MAX_INVENTORY:
		_stash_selected.append(index)
	RunManager.pending_loadout.clear()
	for i in _stash_selected:
		if i < MetaProgress.stash.size():
			# Push the actual stash entry (instance dict, or legacy string) so
			# its rolled affixes travel into the run intact.
			RunManager.pending_loadout.append(MetaProgress.stash[i])
	if _stash_rebuild.is_valid():
		_stash_rebuild.call()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_packed(HERO_SELECT_PACKED)


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
		"hero_fengshui_master": tr("UI_HOME_HERO_FENGSHUI"),
	}
	if names.has(hero_id):
		return names[hero_id]
	return hero_id.replace("_", " ").capitalize()

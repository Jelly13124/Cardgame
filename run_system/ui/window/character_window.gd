## CharacterWindow — the character / equipment / backpack page as a floating
## DraggableWindow (replaces the old fullscreen equipment_panel.gd for map and
## battle). v2-mockup layout shared by all three modes:
##   TITLE   drag + ✕; base mode adds a 仓库 (Stash) toggle icon button
##   MIDDLE  the D4 zone — equip slots flanking the paper-doll inset well:
##           LEFT head / chest / hands · CENTER doll (+ hero switcher) · RIGHT
##           weapon / accessory + the tool-slot row
##   BOTTOM  the fixed 20-cell backpack grid (10×2) — cells beyond the unlocked
##           capacity render LOCKED with a flat padlock in every mode
## Modes:
##   MODE_MAP    — in-run map: RunManager.backpack, full editable (drag/drop/click)
##   MODE_BATTLE — in battle: the same layout, read-only (cells locked)
##   MODE_BASE   — home base: the grid shows RunManager.pending_loadout (the gear
##                 carried into the next run's backpack). D4 container model: the
##                 permanent stash lives in its OWN window (stash_window.gd);
##                 stash → backpack by drag, backpack → slot by drag
##                 (pending_equipped). Equip slots NEVER accept a raw stash
##                 payload — gear must pass through the backpack first.
## Listens to RunManager / MetaProgress state signals for live refresh; the
## window is freed on close, which drops the connections.
extends "res://run_system/ui/window/draggable_window.gd"

const EQUIPMENT_ICON = preload("res://run_system/ui/equipment_icon.gd")
const BACKPACK_CELL = preload("res://run_system/ui/backpack_cell.gd")
const AFFIX_POOL = preload("res://run_system/core/affix_pool.gd")
const EQUIP_TOOLTIP = preload("res://run_system/ui/equip_tooltip.gd")
const HERO_SPRITE_DIR := "res://battle_scene/assets/images/heroes/"
const HERO_DIR := "res://run_system/data/heroes/"
const HOME_HUD_ICON_DIR := "res://run_system/assets/images/home/base_hud/"
const BASE_OUTER_FRAME_TEX = preload(
	"res://run_system/assets/images/ui/window_frames_v2/stash_outer_frame.png"
)
const BASE_FOCUS_FRAME_TEX = preload(
	"res://run_system/assets/images/ui/character_panels_v2/character_focus_frame.png"
)
const BASE_BACKPACK_FRAME_TEX = preload(
	"res://run_system/assets/images/ui/character_panels_v2/character_backpack_frame.png"
)
const BASE_TITLE_PLAQUE_TEX = preload(
	"res://run_system/assets/images/ui/concept_dark_panel/title_plaque.png"
)

const MODE_BASE := "base"
const MODE_MAP := "map"
const MODE_BATTLE := "battle"

## Run window keeps the compact map/battle footprint; base mode uses the taller
## concept-layout character sheet with backpack, attributes and tabs.
const WIN_SIZE := Vector2(700, 840)
# 1000: portrait + attrs + backpack grid + return button; the draggable_window
# viewport cap + content scroll absorb anything beyond the screen
# (2026-07-08 overflow fix).
const BASE_WIN_SIZE := Vector2(680, 1000)
const GRID_COLUMNS := 10
const BASE_BACKPACK_GRID_COLUMNS := 7
const BASE_BACKPACK_DISPLAY_CELLS := 21
## The backpack grid ALWAYS renders 20 cells (10×2); cells at index >=
## RunManager.effective_backpack_size() are locked (Outpost upgrades unlock them).
const BACKPACK_DISPLAY_CELLS := 20
const SLOT_CELL_SIZE := Vector2(76, 76)  # equipment slots + tool cells
const BASE_SLOT_CELL_SIZE := Vector2(66, 66)
const GRID_CELL_SIZE := Vector2(56, 56)  # backpack grid cells
const BASE_GRID_CELL_SIZE := Vector2(68, 68)
const DOLL_SIZE := Vector2(220, 320)  # center paper-doll portrait
const BASE_DOLL_SIZE := Vector2(220, 300)
const SLOT_LETTERS := {"head": "H", "chest": "C", "weapon": "W", "hands": "Hd", "accessory": "Ac"}
const ATTR_ORDER: Array[String] = ["strength", "constitution", "intelligence", "luck", "charm"]
const ATTR_ICON_PATHS := {
	"strength": "res://battle_scene/assets/images/ui/attributes/strength.png",
	"constitution": "res://battle_scene/assets/images/ui/attributes/constitution.png",
	"intelligence": "res://battle_scene/assets/images/ui/attributes/intelligence.png",
	"luck": "res://battle_scene/assets/images/ui/attributes/luck.png",
	"charm": "res://battle_scene/assets/images/ui/attributes/charm.png",
}
const ATTR_LABEL_KEYS := {
	"strength": "UI_EQUIP_ATTR_SHORT_STRENGTH",
	"constitution": "UI_EQUIP_ATTR_SHORT_CONSTITUTION",
	"intelligence": "UI_EQUIP_ATTR_SHORT_INTELLIGENCE",
	"luck": "UI_EQUIP_ATTR_SHORT_LUCK",
	"charm": "UI_EQUIP_ATTR_SHORT_CHARM",
}
## D4 split: slots flank the doll (left column / right column).
const LEFT_SLOTS: Array[String] = ["head", "chest", "hands"]
const RIGHT_SLOTS: Array[String] = ["weapon", "accessory"]

var mode: String = MODE_MAP

var _read_only := false
var _slot_icons: Dictionary = {}  # slot → EquipmentIcon
var _slot_cells: Dictionary = {}  # slot → BackpackCell (drag/drop wrapper)
var _slot_labels: Dictionary = {}  # slot → Label (slot/item name)
var _slot_parts: Dictionary = {}  # slot → {placeholder, icon, dot} (v2 layers)
var _grid: GridContainer
var _tool_row: HBoxContainer  # equipped tool slots (tools are held in the backpack)
var _portrait_rect: TextureRect
var _attrs_label: Label
var _vitals_label: Label
var _inv_title: Label
var _sets_container: VBoxContainer
var _relics_container: HFlowContainer
var _status_label: Label

# --- base-mode state ---
## Body VBox of the base page, rebuilt wholesale on every _refresh_base.
var _base_box: VBoxContainer


## Toggle-open the character window on `host`'s WindowLayer: if one is already
## open, close it and return null (so the `i` key toggles); otherwise create,
## open (centered) and return it.
static func open_window(host: Node, p_mode: String) -> Control:
	var wl = load("res://run_system/ui/window/window_layer.gd").ensure(host)
	var existing = wl.get_node_or_null("CharacterWindow")
	if existing and not existing.is_queued_for_deletion():
		existing.close()
		return null
	var win = load("res://run_system/ui/window/character_window.gd").new()
	win.name = "CharacterWindow"
	win.mode = p_mode
	wl.open(win)
	return win


func _ready() -> void:
	var is_base_mode := mode == MODE_BASE
	init_window(
		tr("UI_EQUIP_TITLE_CHARACTER"),
		BASE_WIN_SIZE if is_base_mode else WIN_SIZE,
		not is_base_mode
	)
	if is_base_mode:
		add_theme_stylebox_override("panel", _base_window_style())
	_read_only = mode == MODE_BATTLE
	match mode:
		MODE_BASE:
			_build_base()
			# Stash / building mutations surface through these MetaProgress signals
			# (there is no dedicated stash_changed signal; the forge mutates the
			# stash and emits scrap_changed). Guarded against duplicate connects;
			# queue_free on close drops them automatically.
			if not MetaProgress.buildings_changed.is_connected(_refresh_base):
				MetaProgress.buildings_changed.connect(_refresh_base)
			if not MetaProgress.caps_changed.is_connected(_on_meta_currency_changed):
				MetaProgress.caps_changed.connect(_on_meta_currency_changed)
			if not MetaProgress.scrap_changed.is_connected(_on_meta_currency_changed):
				MetaProgress.scrap_changed.connect(_on_meta_currency_changed)
		_:
			_build_map_battle()
			# Guarded connects: _ready runs once per window, but keep it re-entry
			# safe. queue_free on close drops these automatically.
			if not RunManager.equipment_changed.is_connected(_refresh):
				RunManager.equipment_changed.connect(_refresh)
			if not RunManager.health_changed.is_connected(_on_health_changed):
				RunManager.health_changed.connect(_on_health_changed)
			if not RunManager.resources_changed.is_connected(_on_resources_changed):
				RunManager.resources_changed.connect(_on_resources_changed)
			if not RunManager.relics_updated.is_connected(_refresh):
				RunManager.relics_updated.connect(_refresh)
			if not RunManager.backpack_changed.is_connected(_refresh):
				RunManager.backpack_changed.connect(_refresh)
			_refresh()


## Public rebuild entry — the StashWindow calls this after a cross-window drop
## so both sides stay in sync (and vice versa).
func refresh() -> void:
	if mode == MODE_BASE:
		_refresh_base()
	else:
		_refresh()


## Window-body drop target (base mode only): the whole window accepts a stash
## entry (→ carry it in the backpack) or a queued slot item (→ back into the
## backpack). Equip slot cells sit ABOVE this handler and STOP the drop walk, so
## their own can_accept (which rejects stash payloads) still rules the slots.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if mode != MODE_BASE or typeof(data) != TYPE_DICTIONARY:
		return false
	var src := str(data.get("src", ""))
	return src == "stash" or src == "slot"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if typeof(data) == TYPE_DICTIONARY:
		_drop_into_backpack(data)


# --- base mode ---------------------------------------------------------------


## Home-base variant — the pre-run loadout board:
##   MIDDLE D4 zone: slots (→ RunManager.pending_equipped) flanking the doll;
##          the hero switcher (→ RunManager.pending_hero_id) sits under the doll
##   BOTTOM the next-run backpack: RunManager.pending_loadout entries, padded to
##          effective_backpack_size with empty drop frames + locked cells to 30.
##          Filled by dragging from the StashWindow; drag a cell onto a matching
##          slot to wear it.
func _build_base() -> void:
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	content_root.add_child(margin)
	_base_box = VBoxContainer.new()
	_base_box.add_theme_constant_override("separation", 12)
	margin.add_child(_base_box)
	_refresh_base()


func _on_meta_currency_changed(_v: int) -> void:
	_refresh_base()


## Rebuild the whole base-mode body. Old children are removed immediately (not
## just queue_freed) so the fixed-size window never shows doubled content.
func _refresh_base() -> void:
	if not is_instance_valid(_base_box):
		return
	# The stash can shrink under us (forge dismantle/curse, another screen):
	# drop pending references that no longer resolve to a stash entry.
	_sanitize_pending()
	for child in _base_box.get_children():
		_base_box.remove_child(child)
		child.queue_free()
	_slot_parts.clear()  # the layered slot visuals died with the old children

	_base_box.add_child(_build_base_title_ribbon())

	# ── MIDDLE: the D4 zone (slots flanking the doll + hero switcher) ──
	_base_box.add_child(_build_d4_middle_base())

	var hero_data := _load_hero(_effective_hero_id())
	_base_box.add_child(_build_base_attribute_strip(hero_data.get("starting_attributes", {})))

	# ── BOTTOM: next-run backpack (pending_loadout), locked cells to 7×3 ──
	var cap := RunManager.effective_backpack_size()
	var visible_cap = mini(cap, BASE_BACKPACK_DISPLAY_CELLS)
	var grid := _build_base_backpack_panel(RunManager.pending_loadout.size(), cap)
	var shown := 0
	for entry in RunManager.pending_loadout:
		if shown >= BASE_BACKPACK_DISPLAY_CELLS:
			break
		grid.add_child(_make_carry_cell(entry))
		shown += 1
	for _e in range(maxi(0, visible_cap - shown)):
		grid.add_child(_make_carry_empty_cell())
	for _l in range(maxi(0, BASE_BACKPACK_DISPLAY_CELLS - visible_cap)):
		grid.add_child(_make_locked_cell(BASE_GRID_CELL_SIZE))

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.3))
	_base_box.add_child(_status_label)
	_base_box.add_child(_make_base_back_button())


## The base-mode middle zone: LEFT head/chest/hands · CENTER the pending hero's
## paper-doll in its inset well + the ‹name› switcher + the stat line · RIGHT
## weapon/accessory + (cosmetic) tool slots. Slots read RunManager.pending_equipped.
func _build_d4_middle_base() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	for slot in LEFT_SLOTS:
		left.add_child(_make_base_slot_column(slot))
	row.add_child(left)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(340, 350)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", _base_focus_panel_style())
	var pad := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, 10)
	frame.add_child(pad)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	pad.add_child(inner)
	var hero_id := _effective_hero_id()
	var hero_data := _load_hero(hero_id)
	var tex := _load_portrait(str(hero_data.get("sprite_id", hero_id)))
	inner.add_child(
		_make_doll_stack(tex, _parse_tint(str(hero_data.get("tint", "#ffffff"))), BASE_DOLL_SIZE)
	)
	inner.add_child(_build_hero_switcher(hero_id, hero_data))
	row.add_child(frame)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	for slot in RIGHT_SLOTS:
		right.add_child(_make_base_slot_column(slot))
	right.add_child(_make_base_tool_slot_column())
	row.add_child(right)
	return row


# --- base mode: hero switcher -------------------------------------------------


## The hero the base-mode doll/nameplate should show. Pre-run, NOTHING has set
## RunManager.current_hero_id yet (only start_new_run / load_run write it), so
## a bare read renders an empty id ("HERO__NAME" nameplate + blank doll).
## Resolution order: current_hero_id (in/after a run) → pending_hero_id (a
## base-mode switcher pick) → the first roster entry (fresh save default).
func _effective_hero_id() -> String:
	var id := str(RunManager.current_hero_id)
	if id == "":
		id = str(RunManager.pending_hero_id)
	if id == "":
		var roster := _hero_roster()
		if not roster.is_empty():
			id = roster[0]
	return id


## ‹ name › switcher under the paper-doll: cycles the demo-filtered roster with
## wraparound (the deleted picker strip's selection rule). Arrows hide when only
## one hero exists — the plate stands alone. `hero_id` is the RESOLVED id from
## _effective_hero_id() (never ""), `hero_data` its loaded JSON.
func _build_hero_switcher(hero_id: String, hero_data: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.name = "HeroSwitcher"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var multi := _hero_roster().size() > 1
	if multi:
		row.add_child(_make_hero_arrow("‹", "icon_arrow_left", -1))
	var plate := PanelContainer.new()
	plate.custom_minimum_size = Vector2(90, 26)
	plate.add_theme_stylebox_override("panel", T.ui_nameplate_box())
	var name_lbl := Label.new()
	name_lbl.text = Settings.t(
		"HERO_%s_NAME" % hero_id, str(hero_data.get("name", hero_data.get("title", hero_id)))
	)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", T.UI_HEADER_GOLD)
	plate.add_child(name_lbl)
	row.add_child(plate)
	if multi:
		row.add_child(_make_hero_arrow("›", "icon_arrow_right", 1))
	return row


## One 26×26 brass-bordered switcher arrow (kit chevron art when delivered).
func _make_hero_arrow(glyph: String, kit_icon: String, step: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(26, 26)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var tex := T.ui_kit_tex(kit_icon)
	if tex:
		b.icon = tex
		b.expand_icon = true
	else:
		b.text = glyph
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_color_override("font_color", T.UI_BRASS_LIGHT)
	var normal := T.rounded_button(T.GLASS_BG, T.GLASS_HAIRLINE, 5, 1)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", T.rounded_button(T.GLASS_BG_HOVER, T.GLASS_GOLD, 5, 1))
	b.add_theme_stylebox_override("pressed", normal)
	b.pressed.connect(_cycle_hero.bind(step))
	return b


## The selectable roster: hero JSONs under HERO_DIR, demo-filtered (the same
## rule the old picker strip applied). The full roster returns when
## RunManager.DEMO_BUILD is flipped off.
func _hero_roster() -> Array[String]:
	var ids: Array[String] = []
	for hero_id in _list_hero_ids():
		if RunManager.DEMO_BUILD and not (hero_id in RunManager.DEMO_ALLOWED_HEROES):
			continue
		ids.append(hero_id)
	return ids


## Step the hero selection ±1 with wraparound. Persists the pick exactly like
## the old picker tiles: start_new_run reads pending_hero_id when no explicit
## hero is passed; current_hero_id makes the doll/name reflect it immediately.
func _cycle_hero(step: int) -> void:
	var roster := _hero_roster()
	if roster.size() <= 1:
		return
	var idx := maxi(roster.find(_effective_hero_id()), 0)
	var picked := roster[(idx + step + roster.size()) % roster.size()]
	RunManager.pending_hero_id = picked
	RunManager.current_hero_id = picked
	AudioManager.play_sfx("ui_click")
	_refresh_base()


## The dim 5-attribute line under the switcher (11px, `力量 X · 体质 X · …`).
func _make_stat_line(attrs: Variant) -> Label:
	var a: Dictionary = attrs if typeof(attrs) == TYPE_DICTIONARY else {}
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text = (
		tr("UI_EQUIP_STATS_LINE")
		. format(
			{
				"str": int(a.get("strength", 0)),
				"con": int(a.get("constitution", 0)),
				"int": int(a.get("intelligence", 0)),
				"luc": int(a.get("luck", 0)),
				"cha": int(a.get("charm", 0)),
			}
		)
	)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", T.UI_LABEL_DIM)
	return l


func _build_base_title_ribbon() -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(0, 70)
	var ribbon := PanelContainer.new()
	ribbon.custom_minimum_size = Vector2(380, 64)
	ribbon.add_theme_stylebox_override("panel", _base_title_plaque_style())
	bind_drag_area(ribbon)
	holder.add_child(ribbon)
	var label := Label.new()
	label.text = tr("UI_EQUIP_TITLE_CHARACTER")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", T.display_font(700))
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.58, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.025, 0.01, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	ribbon.add_child(label)
	return holder


func _build_base_backpack_panel(used: int, cap: int) -> GridContainer:
	var panel := PanelContainer.new()
	panel.name = "BaseBackpackPanel"
	panel.custom_minimum_size = Vector2(628, 298)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _base_backpack_panel_style())
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 12)
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(pad)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	pad.add_child(box)
	box.add_child(_build_backpack_header(used, cap, ""))

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(center)
	var grid := _make_backpack_grid()
	center.add_child(grid)
	_base_box.add_child(panel)
	return grid


## Base-mode five-stat strip above the backpack, using the project attribute icons.
func _build_base_attribute_strip(attrs: Variant) -> Control:
	var a: Dictionary = attrs if typeof(attrs) == TYPE_DICTIONARY else {}
	var holder := CenterContainer.new()
	holder.name = "BaseAttributeStrip"
	holder.custom_minimum_size = Vector2(0, 42)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	holder.add_child(row)
	for attr in ATTR_ORDER:
		var pill := _make_base_attribute_pill(attr, int(a.get(attr, 0)))
		row.add_child(pill)
	return holder


func _make_base_attribute_pill(attr: String, value: int) -> Control:
	var pill := HBoxContainer.new()
	pill.name = "AttrPill_%s" % attr
	pill.custom_minimum_size = Vector2(58, 34)
	pill.alignment = BoxContainer.ALIGNMENT_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_STOP
	pill.tooltip_text = _base_attribute_tooltip(attr)
	pill.add_theme_constant_override("separation", 3)

	var tex_path := str(ATTR_ICON_PATHS.get(attr, ""))
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex_path != "" and ResourceLoader.exists(tex_path):
		icon.texture = load(tex_path)
	pill.add_child(icon)

	var label := Label.new()
	label.text = str(value)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", T.UI_BRASS_LIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(label)
	return pill


func _base_attribute_tooltip(attr: String) -> String:
	var name := tr(str(ATTR_LABEL_KEYS.get(attr, attr)))
	match attr:
		"strength":
			return "%s\n%s" % [name, "每点 +1 攻击伤害。"]
		"constitution":
			return "%s\n%s" % [name, "每点 +1 获得的格挡。"]
		"intelligence":
			return "%s\n%s" % [name, "每点使你施加的状态 +1 层，并增强工具效果。"]
		"luck":
			return "%s\n%s" % [name, "提高战利品稀有度，并增加发现工具的概率。"]
		"charm":
			return "%s\n%s" % [name, "降低商店价格，并影响部分事件选项。"]
		_:
			return name


func _make_base_back_button() -> Button:
	var b := Button.new()
	b.name = "CharacterBackButton"
	b.text = tr("PAUSE_BACK")
	b.custom_minimum_size = Vector2(0, 68)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_base_back_button(b)
	b.pressed.connect(close)
	return b


func _list_hero_ids() -> Array[String]:
	var ids: Array[String] = []
	var dir := DirAccess.open(HERO_DIR)
	if dir == null:
		return ids
	for file_name in dir.get_files():
		if file_name.ends_with(".json"):
			ids.append(file_name.get_basename())
	ids.sort()
	return ids


func _load_hero(hero_id: String) -> Dictionary:
	var path := HERO_DIR + hero_id + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


# --- shared: v2 equip-slot cell (layers + stylers) ---------------------------


## Shared v2 slot-cell scaffold: a 76px BackpackCell layered with (a) the
## empty-state placeholder (slot glyph tinted on the slot box), (b) a hidden
## EquipmentIcon for the filled state, (c) a hidden top-right rarity dot.
## Registered into _slot_parts / _slot_icons / _slot_cells for the stylers
## (_style_slot_empty / _style_slot_filled) to flip on every refresh.
func _make_slot_cell_parts(slot: String, cell_size: Vector2 = SLOT_CELL_SIZE) -> Dictionary:
	var cell = _new_cell(cell_size)
	cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var ph := Panel.new()
	ph.set_anchors_preset(Control.PRESET_FULL_RECT)
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_theme_stylebox_override(
		"panel", _base_slot_box_style("empty") if mode == MODE_BASE else T.ui_slot_box("empty")
	)
	var glyph_path := str(EQUIPMENT_ICON.SLOT_ICON_PATHS.get(slot, ""))
	if glyph_path != "" and ResourceLoader.exists(glyph_path):
		var glyph := TextureRect.new()
		glyph.texture = load(glyph_path)
		glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
		var inset := 12 if cell_size.x < SLOT_CELL_SIZE.x else 14
		glyph.offset_left = inset
		glyph.offset_top = inset
		glyph.offset_right = -inset
		glyph.offset_bottom = -inset
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		glyph.modulate = T.UI_SLOT_ICON_TINT
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ph.add_child(glyph)
	else:
		var letter := Label.new()
		letter.text = str(SLOT_LETTERS.get(slot, "?"))
		letter.set_anchors_preset(Control.PRESET_FULL_RECT)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter.add_theme_font_size_override("font_size", 20)
		letter.add_theme_color_override("font_color", T.UI_SLOT_ICON_TINT)
		letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ph.add_child(letter)
	cell.add_child(ph)

	var icon = EQUIPMENT_ICON.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = false
	cell.add_child(icon)

	var dot := Panel.new()
	dot.anchor_left = 1.0
	dot.anchor_right = 1.0
	dot.offset_left = -12
	dot.offset_right = -4
	dot.offset_top = 4
	dot.offset_bottom = 12
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.visible = false
	cell.add_child(dot)

	_slot_cells[slot] = cell
	_slot_icons[slot] = icon
	_slot_parts[slot] = {"placeholder": ph, "icon": icon, "dot": dot}
	return {"cell": cell, "icon": icon}


## Flip a slot cell to the EMPTY v2 look: placeholder glyph, brown slot label.
func _style_slot_empty(slot: String) -> void:
	var parts: Dictionary = _slot_parts.get(slot, {})
	if parts.is_empty():
		return
	(parts["placeholder"] as Control).visible = true
	(parts["icon"] as Control).visible = false
	(parts["dot"] as Control).visible = false
	var label: Label = _slot_labels[slot]
	label.text = _slot_label(slot)
	label.add_theme_color_override("font_color", T.UI_LABEL_BROWN)


## Flip a slot cell to the FILLED v2 look: EquipmentIcon restyled onto the flat
## 2px rarity-border box + the tiny top-right rarity dot; the label shows the
## item name in the rarity color.
func _style_slot_filled(slot: String, item_name: String, sprite: String, rarity: String) -> void:
	var parts: Dictionary = _slot_parts.get(slot, {})
	if parts.is_empty():
		return
	var rc: Color = EQUIPMENT_ICON.RARITY_COLORS.get(rarity, Color.WHITE)
	(parts["placeholder"] as Control).visible = false
	var icon = parts["icon"]
	icon.visible = true
	icon.set_equipment(slot, item_name, sprite, rarity)
	# Override the icon's own chunky style with the v2 filled box (2px rarity rim).
	icon.add_theme_stylebox_override(
		"panel",
		_base_slot_box_style("filled") if mode == MODE_BASE else T.ui_slot_box("filled", rc)
	)
	var dot := parts["dot"] as Panel
	dot.visible = true
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = rc
	dsb.set_corner_radius_all(4)
	dot.add_theme_stylebox_override("panel", dsb)
	var label: Label = _slot_labels[slot]
	label.text = item_name
	label.add_theme_color_override("font_color", rc)


# --- base mode: equipment slots (→ pending_equipped) ------------------------


## One equip slot as a compact column: a BackpackCell drop target over a name
## label. Shows the item queued in pending_equipped[slot]. D4 rule: ONLY accepts
## a matching-slot item dragged from this window's backpack grid (src "carry")
## — never a raw stash payload. Click or drag-off returns the item to the backpack.
func _make_base_slot_column(slot: String) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(98, 104)
	frame.add_theme_stylebox_override("panel", _base_slot_holder_style())
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 8)
	pad.add_theme_constant_override("margin_right", 8)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	frame.add_child(pad)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 3)
	pad.add_child(col)

	var center := CenterContainer.new()
	col.add_child(center)
	var parts := _make_slot_cell_parts(slot, BASE_SLOT_CELL_SIZE)
	var cell = parts["cell"]
	center.add_child(cell)

	var s := slot
	# Equip only from the backpack (src "carry"); stash payloads are REJECTED.
	cell.can_accept = func(data): return data.get("src") == "carry" and data.get("slot") == s
	cell.perform_drop = func(data): _equip_from_carry(s, data.get("entry"))

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.custom_minimum_size = Vector2(80, 0)
	label.add_theme_font_size_override("font_size", 10)
	col.add_child(label)
	_slot_labels[slot] = label

	var queued: Variant = RunManager.pending_equipped.get(slot, null)
	var inst: Dictionary = RunManager.as_equip_instance(queued) if queued != null else {}
	if inst.is_empty():
		_style_slot_empty(slot)
		cell.drag_payload = {}
		cell.hover_tip = "[b]%s[/b]\n%s" % [_slot_label(slot), tr("UI_EQUIP_EMPTY_SLOT")]
	else:
		var base_id: String = RunManager.equip_base(inst)
		var data: Dictionary = RunManager.get_equipment_data(base_id)
		var item_name := Settings.t("EQUIP_%s_NAME" % base_id, str(data.get("name", base_id)))
		_style_slot_filled(
			slot,
			item_name,
			str(data.get("sprite", "")),
			str(inst.get("rarity", data.get("rarity", "common")))
		)
		# Filled slot drags back off: onto the backpack grid (→ pending_loadout)
		# or onto the StashWindow (→ unassign; back to storage).
		cell.drag_payload = {"src": "slot", "slot": slot, "entry": queued}
		cell.preview_text = str(SLOT_LETTERS.get(slot, "?"))
		cell.preview_color = Color(1.0, 0.86, 0.4)
		cell.preview_tex = _load_equip_tex(str(data.get("sprite", "")))
		cell.hover_tip = _build_equipment_tooltip(data, slot, inst)
		cell.click_handler = func(btn):
			if btn == MOUSE_BUTTON_LEFT:
				_unassign_slot_to_carry(s)
	return frame


# --- base mode: backpack grid (→ pending_loadout) ----------------------------


## One next-run backpack cell showing a pending_loadout entry. Drag source
## (src "carry") for the equip slots and the StashWindow; drop target for stash
## entries and queued slot items.
func _make_base_tool_slot_column() -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(98, 104)
	frame.add_theme_stylebox_override("panel", _base_slot_holder_style())
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 8)
	pad.add_theme_constant_override("margin_right", 8)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	frame.add_child(pad)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	pad.add_child(col)

	var center := CenterContainer.new()
	col.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = BASE_SLOT_CELL_SIZE
	card.add_theme_stylebox_override("panel", _base_slot_box_style("tool"))
	center.add_child(card)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(42, 42)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_path := HOME_HUD_ICON_DIR + "icon_settings.png"
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	card.add_child(icon)

	var label := Label.new()
	label.text = tr("UI_EQUIP_TOOLS_TITLE")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.custom_minimum_size = Vector2(90, 0)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", T.UI_LABEL_BROWN)
	col.add_child(label)
	return frame


func _make_carry_cell(entry: Variant) -> Control:
	var inst: Dictionary = RunManager.as_equip_instance(entry)
	var base_id: String = RunManager.equip_base(inst)
	var data: Dictionary = RunManager.get_equipment_data(base_id)
	var slot := str(data.get("slot", "head"))
	var item_name := Settings.t("EQUIP_%s_NAME" % base_id, str(data.get("name", base_id)))

	var cell = _new_cell(BASE_GRID_CELL_SIZE)
	cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var icon = EQUIPMENT_ICON.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_equipment(
		slot, item_name, str(data.get("sprite", "")), str(data.get("rarity", "common"))
	)
	icon.add_theme_stylebox_override("panel", _base_slot_box_style("filled"))
	cell.add_child(icon)

	cell.hover_tip = _build_equipment_tooltip(data, slot, inst)
	# The payload carries the actual entry so slot / stash targets can move it.
	cell.drag_payload = {"src": "carry", "slot": slot, "entry": entry}
	cell.preview_text = str(SLOT_LETTERS.get(slot, "?"))
	cell.preview_color = Color(1.0, 0.86, 0.4)
	cell.preview_tex = _load_equip_tex(str(data.get("sprite", "")))
	_wire_base_backpack_drop(cell)
	return cell


## A recessed empty backpack frame — still a live drop target so the whole grid
## reads as the backpack area.
func _make_carry_empty_cell() -> Control:
	var cell = _new_cell(BASE_GRID_CELL_SIZE)
	var blank := Panel.new()
	blank.set_anchors_preset(Control.PRESET_FULL_RECT)
	blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blank.add_theme_stylebox_override("panel", _base_slot_box_style("cell_empty"))
	cell.add_child(blank)
	_wire_base_backpack_drop(cell)
	return cell


# --- shared: backpack grid chrome (header / locked cells / lock glyph) --------


## The fixed 30-cell display grid (10×3), shared by all three modes.
func _make_backpack_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "BackpackGrid"
	grid.columns = BASE_BACKPACK_GRID_COLUMNS if mode == MODE_BASE else GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 8 if mode == MODE_BASE else 6)
	grid.add_theme_constant_override("v_separation", 8 if mode == MODE_BASE else 6)
	return grid


## Backpack header row: gold 背包 title + dim `n / cap` count + the
## right-aligned usage hint (merged up from the old footer hint row). Pass
## hint_text "" to omit the hint (battle mode). The count Label is kept in
## _inv_title so map/battle _refresh can live-update it.
func _build_backpack_header(used: int, cap: int, hint_text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_section_title(tr("UI_EQUIP_BACKPACK_TITLE")))
	_inv_title = Label.new()
	_inv_title.text = "%d / %d" % [used, cap]
	_inv_title.add_theme_font_size_override("font_size", 12)
	_inv_title.add_theme_color_override("font_color", T.UI_LABEL_DIM)
	_inv_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_inv_title)
	var hint := Label.new()
	hint.text = hint_text
	hint.visible = hint_text != ""
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.clip_text = true
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", T.UI_SLOT_ICON_TINT)
	row.add_child(hint)
	return row


## One LOCKED backpack cell (index >= effective capacity): inert in every mode —
## no drag payload, can_accept stays invalid and `locked` hard-blocks drops, no
## click handlers. Only the tooltip talks (upgrade at the Outpost). Skinned by
## the kit's slot_locked.png when delivered (padlock baked into the art);
## until then the flat two-Panel padlock overlays the locked box.
func _make_locked_cell(cell_size: Vector2 = GRID_CELL_SIZE) -> Control:
	var cell = BACKPACK_CELL.new()
	cell.custom_minimum_size = cell_size
	cell.locked = true
	cell.hover_tip = tr("UI_EQUIP_CELL_LOCKED")
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(
		"panel",
		(
			_base_slot_box_style("cell_empty")
			if cell_size == BASE_GRID_CELL_SIZE
			else T.ui_slot_box("locked")
		)
	)
	cell.add_child(panel)
	if T.ui_kit_tex("slot_locked") == null:
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(_make_lock_glyph())
		cell.add_child(center)
	return cell


## A tiny flat padlock built from two Panels (border-only shackle ring over a
## filled body) — no font/emoji dependency, so it renders identically headless
## and under any locale font. Kit hook: icon_lock.png replaces it when delivered.
func _make_lock_glyph() -> Control:
	var tex := T.ui_kit_tex("icon_lock")
	if tex:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.custom_minimum_size = Vector2(18, 18)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return icon
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(16, 15)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shackle := Panel.new()
	shackle.position = Vector2(3, 0)
	shackle.size = Vector2(10, 9)
	shackle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0, 0, 0, 0)
	ssb.border_color = T.UI_LOCKED_GLYPH
	ssb.set_border_width_all(2)
	ssb.corner_radius_top_left = 5
	ssb.corner_radius_top_right = 5
	shackle.add_theme_stylebox_override("panel", ssb)
	holder.add_child(shackle)
	var body := Panel.new()
	body.position = Vector2(0, 7)
	body.size = Vector2(16, 8)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = T.UI_LOCKED_GLYPH
	bsb.set_corner_radius_all(2)
	body.add_theme_stylebox_override("panel", bsb)
	holder.add_child(body)
	return holder


## Backpack-area drop rules (base mode): a stash entry moves stash → carry; a
## queued slot item moves pending_equipped → pending_loadout.
func _wire_base_backpack_drop(cell) -> void:
	cell.can_accept = func(data):
		var src := str(data.get("src", ""))
		return src == "stash" or src == "slot"
	cell.perform_drop = func(data): _drop_into_backpack(data)


func _drop_into_backpack(data: Dictionary) -> void:
	match str(data.get("src", "")):
		"stash":
			_carry_from_stash(data.get("entry"))
		"slot":
			_unassign_slot_to_carry(str(data.get("slot", "")))


## Stash → backpack: append the entry to pending_loadout (capped at the usable
## backpack size). Guards against stale drags: the entry must still be available
## (in the stash and not already carried / assigned).
func _carry_from_stash(entry: Variant) -> void:
	if entry == null or RunManager.as_equip_instance(entry).is_empty():
		return
	if RunManager.pending_loadout.size() >= RunManager.effective_backpack_size():
		_flash_status(tr("UI_LOOT_BACKPACK_FULL"))
		return
	if _unassigned_stash_pool().find(entry) < 0:
		return  # no longer in the stash / already taken
	RunManager.pending_loadout.append(entry)
	AudioManager.play_sfx("ui_click")
	_refresh_base()
	_refresh_sibling_stash()


## Backpack → slot: move the entry from pending_loadout into
## pending_equipped[slot]; a displaced item swaps back into the freed backpack
## spot. Re-validates the item's JSON slot (the UI gates it, but keep the
## handler safe to call directly).
func _equip_from_carry(slot: String, entry: Variant) -> void:
	if entry == null or not slot in RunManager.EQUIPMENT_SLOTS:
		return
	var inst: Dictionary = RunManager.as_equip_instance(entry)
	if inst.is_empty():
		return
	var data: Dictionary = RunManager.get_equipment_data(RunManager.equip_base(inst))
	if str(data.get("slot", "")) != slot:
		return  # slot mismatch — ignore
	var idx: int = RunManager.pending_loadout.find(entry)
	if idx < 0:
		return  # stale drag — the entry left the backpack
	RunManager.pending_loadout.remove_at(idx)
	var displaced: Variant = RunManager.pending_equipped.get(slot, null)
	RunManager.pending_equipped[slot] = entry
	if displaced != null:
		# Room is guaranteed: we just freed the dragged entry's spot.
		RunManager.pending_loadout.append(displaced)
	AudioManager.play_sfx("ui_click")
	_refresh_base()
	_refresh_sibling_stash()


## Slot → backpack (click or drag-off): the queued item returns to
## pending_loadout when the backpack has room; otherwise flash a hint and keep it.
func _unassign_slot_to_carry(slot: String) -> void:
	var queued: Variant = RunManager.pending_equipped.get(slot, null)
	if queued == null:
		return
	if RunManager.pending_loadout.size() >= RunManager.effective_backpack_size():
		_flash_status(tr("UI_LOOT_BACKPACK_FULL"))
		return
	RunManager.pending_equipped.erase(slot)
	RunManager.pending_loadout.append(queued)
	AudioManager.play_sfx("ui_back")
	_refresh_base()
	_refresh_sibling_stash()


## MetaProgress.stash entries NOT consumed by a pending assignment (slot or
## carry), value-matched one assignment per entry so duplicate gear is handled.
## The StashWindow mirrors this consumption for its grid.
func _unassigned_stash_pool() -> Array:
	var pool: Array = MetaProgress.stash.duplicate()
	for v in RunManager.pending_equipped.values():
		var i: int = pool.find(v)
		if i >= 0:
			pool.remove_at(i)
	for e in RunManager.pending_loadout:
		var j: int = pool.find(e)
		if j >= 0:
			pool.remove_at(j)
	return pool


## Drop pending references that no longer resolve to a stash entry (the forge
## can dismantle / reroll items under us). Value-matched, consuming one stash
## occurrence per reference.
func _sanitize_pending() -> void:
	var pool: Array = MetaProgress.stash.duplicate()
	for slot in RunManager.pending_equipped.keys():  # keys() is a copy — safe to erase
		var i: int = pool.find(RunManager.pending_equipped[slot])
		if i < 0:
			RunManager.pending_equipped.erase(slot)
		else:
			pool.remove_at(i)
	var kept: Array = []
	for e in RunManager.pending_loadout:
		var j: int = pool.find(e)
		if j >= 0:
			pool.remove_at(j)
			kept.append(e)
	if kept.size() != RunManager.pending_loadout.size():
		RunManager.pending_loadout.clear()
		RunManager.pending_loadout.append_array(kept)


## Toggle the StashWindow beside this one (base context only).
func _toggle_stash_window() -> void:
	var wl := get_parent()
	if wl == null:
		return
	var host := wl.get_parent()
	if host == null:
		return
	load("res://run_system/ui/window/stash_window.gd").open_window(host)


## Rebuild the sibling StashWindow (if open) after a cross-window move.
func _refresh_sibling_stash() -> void:
	var wl := get_parent()
	if wl == null:
		return
	var sw = wl.get_node_or_null("StashWindow")
	if sw and not sw.is_queued_for_deletion() and sw.has_method("refresh"):
		sw.refresh()


func _flash_status(text: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = text
	AudioManager.play_sfx("error")


# --- map / battle mode --------------------------------------------------------


func _on_health_changed(_current: int, _maximum: int) -> void:
	_refresh()


func _on_resources_changed(_gold: int, _scrap: int) -> void:
	_refresh()


## The map/battle body — same D4 skeleton as base: vitals line, slots flanking
## the doll, a slim sets/relics strip, then the backpack grid.
func _build_map_battle() -> void:
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	content_root.add_child(margin)

	var vroot := VBoxContainer.new()
	vroot.add_theme_constant_override("separation", 14)
	margin.add_child(vroot)

	# ── Header: vitals only (the window title bar already shows the page name) ──
	_vitals_label = Label.new()
	_vitals_label.add_theme_font_size_override("font_size", 15)
	_vitals_label.add_theme_color_override("font_color", T.UI_HEADER_GOLD)
	vroot.add_child(_vitals_label)

	# ── MIDDLE: the D4 zone ──
	vroot.add_child(_build_d4_middle_run())

	# ── Slim strip: sets + relics (fixed height, scrolls if it overflows) ──
	vroot.add_child(T.ui_divider())
	var strip_scroll := ScrollContainer.new()
	strip_scroll.custom_minimum_size = Vector2(0, 60)
	strip_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vroot.add_child(strip_scroll)
	var strip := HBoxContainer.new()
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_theme_constant_override("separation", 24)
	strip_scroll.add_child(strip)

	var sets_col := VBoxContainer.new()
	sets_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_child(sets_col)
	sets_col.add_child(_section_title(tr("UI_EQUIP_ACTIVE_SETS")))
	_sets_container = VBoxContainer.new()
	_sets_container.add_theme_constant_override("separation", 2)
	sets_col.add_child(_sets_container)

	var relics_col := VBoxContainer.new()
	relics_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_child(relics_col)
	relics_col.add_child(_section_title(tr("UI_EQUIP_RELICS")))
	_relics_container = HFlowContainer.new()
	_relics_container.add_theme_constant_override("h_separation", 6)
	_relics_container.add_theme_constant_override("v_separation", 4)
	relics_col.add_child(_relics_container)

	# ── BOTTOM: backpack header + fixed 30-cell grid (hint hidden in battle) ──
	vroot.add_child(T.ui_divider())
	vroot.add_child(
		_build_backpack_header(0, 0, "" if _read_only else tr("UI_EQUIP_BACKPACK_HINT"))
	)
	_grid = _make_backpack_grid()
	vroot.add_child(_grid)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.3))
	vroot.add_child(_status_label)


## The run-mode middle zone: LEFT head/chest/hands · CENTER doll + attributes ·
## RIGHT weapon/accessory + the equipped tool row. Slot cells are persistent
## (refilled by _refresh), matching the old equipment-zone behavior.
func _build_d4_middle_run() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	for slot in LEFT_SLOTS:
		left.add_child(_make_run_slot_column(slot))
	row.add_child(left)

	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", T.ui_inset_panel())
	var pad := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, 10)
	frame.add_child(pad)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	pad.add_child(inner)

	var stack := _make_doll_stack(null, Color.WHITE)
	_portrait_rect = stack.get_meta("doll_rect")
	inner.add_child(stack)

	_attrs_label = Label.new()
	_attrs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attrs_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_attrs_label.add_theme_font_size_override("font_size", 11)
	_attrs_label.add_theme_color_override("font_color", T.UI_LABEL_DIM)
	_attrs_label.mouse_filter = Control.MOUSE_FILTER_STOP
	# Tooltip on hover: what each of the five attributes does.
	var attrs_ref: Label = _attrs_label
	var attrs_id: int = _attrs_label.get_instance_id()
	_attrs_label.mouse_entered.connect(
		func():
			if not is_instance_valid(attrs_ref):
				return
			Tooltip.show(
				tr("UI_EQUIP_ATTR_TIP"),
				attrs_ref.global_position + Vector2(attrs_ref.size.x * 0.5, 0),
				attrs_id
			)
	)
	_attrs_label.mouse_exited.connect(Tooltip.hide_if_owner.bind(attrs_id))
	_attrs_label.tree_exited.connect(Tooltip.hide_if_owner.bind(attrs_id))
	inner.add_child(_attrs_label)
	row.add_child(frame)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	for slot in RIGHT_SLOTS:
		right.add_child(_make_run_slot_column(slot))
	# Equipped tool slots — tools are HELD in the backpack and equipped into a
	# slot here (click a backpack tool to equip; click an equipped tool to unequip).
	right.add_child(_section_title(tr("UI_EQUIP_TOOLS_TITLE")))
	_tool_row = HBoxContainer.new()
	_tool_row.add_theme_constant_override("separation", 6)
	right.add_child(_tool_row)
	row.add_child(right)
	return row


## One run-mode equip slot column (cell over a name label). The BackpackCell
## wrapper owns drag/drop/click; the layered visuals come from the shared v2
## scaffold. Registered in _slot_* for _refresh to refill.
func _make_run_slot_column(slot: String) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)

	var center := CenterContainer.new()
	col.add_child(center)
	var parts := _make_slot_cell_parts(slot)
	var cell = parts["cell"]
	center.add_child(cell)
	# Drop target: accept a matching-slot equipment dragged from the backpack.
	var s := slot
	cell.can_accept = func(data):
		return (
			data.get("src") == "backpack" and data.get("kind") == "equip" and data.get("slot") == s
		)
	cell.perform_drop = func(data): _on_equip_pressed(str(data.get("item_id", "")), s, -1)
	if not _read_only:
		cell.click_handler = func(btn):
			if btn == MOUSE_BUTTON_LEFT:
				_on_unequip_pressed(s)

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.custom_minimum_size = Vector2(96, 0)
	label.add_theme_font_size_override("font_size", 11)
	col.add_child(label)
	_slot_labels[slot] = label
	return col


## The paper-doll stack used by both base and run middles: a flat cel
## ground-shadow pill behind the feet + the 220x320 portrait on top. The
## TextureRect is stashed in meta "doll_rect" for live refresh.
func _make_doll_stack(tex: Texture2D, tint: Color, doll_size: Vector2 = DOLL_SIZE) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = doll_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow := Panel.new()
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.anchor_left = 0.5
	shadow.anchor_right = 0.5
	shadow.anchor_top = 1.0
	shadow.anchor_bottom = 1.0
	shadow.offset_left = -doll_size.x * 0.28
	shadow.offset_right = doll_size.x * 0.28
	shadow.offset_top = -24
	shadow.offset_bottom = -4
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.38)  # flat cel shadow — no gradient
	sb.set_corner_radius_all(10)  # pill ≈ ground ellipse
	shadow.add_theme_stylebox_override("panel", sb)
	holder.add_child(shadow)
	var doll := TextureRect.new()
	doll.set_anchors_preset(Control.PRESET_FULL_RECT)
	doll.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	doll.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	doll.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	doll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex:
		doll.texture = tex
	doll.modulate = tint
	holder.add_child(doll)
	holder.set_meta("doll_rect", doll)
	return holder


## A BackpackCell pre-sized and pre-locked for the current mode (battle = locked:
## no drag sources, no drop targets).
func _new_cell(cell_size: Vector2):
	var cell = BACKPACK_CELL.new()
	cell.custom_minimum_size = cell_size
	cell.locked = _read_only
	return cell


func _refresh() -> void:
	# Vitals (floor is 0-indexed internally; display 1-based)
	if _vitals_label:
		_vitals_label.text = (
			tr("UI_EQUIP_VITALS")
			. format(
				{
					"hp": RunManager.current_health,
					"max": RunManager.max_health,
					"gold": RunManager.gold,
					"act": RunManager.current_act,
					"floor": max(1, RunManager.current_floor + 1),
				}
			)
		)

	# Character portrait + attributes
	if _portrait_rect:
		var sprite_id := str(RunManager.current_hero_data.get("sprite_id", "cowboy_bill"))
		var tex := _load_portrait(sprite_id)
		if tex:
			_portrait_rect.texture = tex
		_portrait_rect.modulate = _parse_tint(
			str(RunManager.current_hero_data.get("tint", "#ffffff"))
		)
	if _attrs_label:
		var p = RunManager.player_attributes
		_attrs_label.text = (
			tr("UI_EQUIP_STATS_LINE")
			. format(
				{
					"str": int(p.get("strength", 0)),
					"con": int(p.get("constitution", 0)),
					"int": int(p.get("intelligence", 0)),
					"luc": int(p.get("luck", 0)),
					"cha": int(p.get("charm", 0)),
				}
			)
		)

	# Equipment slots (v2 stylers flip the layered cell visuals)
	for slot in RunManager.EQUIPMENT_SLOTS:
		var cell = _slot_cells[slot]
		# Tolerant read: slot may hold an instance dict (new) or a legacy String.
		var slot_inst: Dictionary = RunManager.as_equip_instance(
			RunManager.equipped_items.get(slot, {})
		)
		var item_id: String = RunManager.equip_base(slot_inst)
		if item_id == "":
			_style_slot_empty(slot)
			# Empty slot: not a drag source; tooltip explains it.
			cell.drag_payload = {}
			cell.hover_tip = "[b]%s[/b]\n%s" % [_slot_label(slot), tr("UI_EQUIP_EMPTY_SLOT")]
		else:
			var data = RunManager.get_equipment_data(item_id)
			var item_name := Settings.t("EQUIP_%s_NAME" % item_id, str(data.get("name", item_id)))
			_style_slot_filled(
				slot,
				item_name,
				str(data.get("sprite", "")),
				str(slot_inst.get("rarity", data.get("rarity", "common")))
			)
			# Equipped item is draggable back into the backpack (unequip).
			cell.drag_payload = {"src": "slot", "slot": slot, "item_id": item_id}
			cell.preview_text = str(SLOT_LETTERS.get(slot, "?"))
			cell.preview_color = Color(1.0, 0.86, 0.4)
			cell.preview_tex = _load_equip_tex(str(data.get("sprite", "")))
			cell.hover_tip = _build_equipment_tooltip(data, slot, slot_inst)

	# Equipped tool slots (filled from tool_inventory; the rest show empty slots).
	if is_instance_valid(_tool_row):
		for child in _tool_row.get_children():
			child.queue_free()
		var inv: Array = RunManager.tool_inventory
		var slots: int = RunManager.tool_slots()
		for i in range(slots):
			if i < inv.size():
				_tool_row.add_child(_make_equipped_tool_cell(i, str(inv[i])))
			else:
				_tool_row.add_child(_make_empty_tool_cell())

	# Backpack grid (rebuild every refresh): the unlocked cells, then locked
	# padding up to the fixed 30-cell display.
	var cap := RunManager.effective_backpack_size()
	if _inv_title:
		_inv_title.text = "%d / %d" % [RunManager.backpack_count_used(), cap]
	for child in _grid.get_children():
		child.queue_free()
	for i in range(mini(cap, BACKPACK_DISPLAY_CELLS)):
		_grid.add_child(_make_grid_cell(i))
	for _l in range(maxi(0, BACKPACK_DISPLAY_CELLS - cap)):
		_grid.add_child(_make_locked_cell())

	# Active sets
	for child in _sets_container.get_children():
		child.queue_free()
	var active_tiers: Dictionary = RunManager.get_active_set_tiers()
	if active_tiers.is_empty():
		var none := Label.new()
		none.text = tr("UI_EQUIP_NONE_YET")
		none.add_theme_font_size_override("font_size", 13)
		none.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_sets_container.add_child(none)
	else:
		for set_id in active_tiers.keys():
			_sets_container.add_child(_build_set_row(str(set_id), int(active_tiers[set_id])))

	# Relics (chips with hover tooltip)
	for child in _relics_container.get_children():
		child.queue_free()
	if RunManager.relics.is_empty():
		var none := Label.new()
		none.text = tr("UI_EQUIP_NONE_YET")
		none.add_theme_font_size_override("font_size", 13)
		none.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_relics_container.add_child(none)
	else:
		for relic_id in RunManager.relics:
			_relics_container.add_child(_build_relic_chip(str(relic_id)))

	_status_label.text = ""


## Build one backpack cell from RunManager.backpack[index] — the cell states:
## null = empty, {"kind":"equip"} = interactive gear icon, {"kind":"gold"} /
## {"kind":"scrap"} = resource stack, {"kind":"tool"}.
func _make_grid_cell(index: int) -> Control:
	var cell := _build_cell_content(index)
	# Safe cells (index 0..safe-1) get a gold border; their contents survive death.
	if index < MetaProgress.effective_safe_cells():
		_add_safe_border(cell)
	return cell


func _build_cell_content(index: int) -> Control:
	var cell = RunManager.backpack[index] if index < RunManager.backpack.size() else null
	if typeof(cell) == TYPE_DICTIONARY:
		match str(cell.get("kind", "")):
			"equip":
				# Tolerant: equip cells now carry an instance under "item"; older
				# cells carried a bare "id" String. as_equip_instance handles both.
				var inst := RunManager.as_equip_instance(cell.get("item", cell.get("id", "")))
				return _make_equip_cell(RunManager.equip_base(inst), index, inst)
			"gold":
				return _make_resource_cell(
					tr("UI_EQUIP_CELL_GOLD"),
					int(cell.get("amount", 0)),
					T.SAND_LIGHT,
					index,
					"gold"
				)
			"scrap":
				return _make_resource_cell(
					tr("UI_EQUIP_CELL_SCRAP"),
					int(cell.get("amount", 0)),
					T.ACCENT_NEON_BLUE,
					index,
					"scrap"
				)
			"tool":
				return _make_tool_cell(str(cell.get("id", "")), index)
	# Empty cell — dim placeholder panel, still a valid drop target (map mode).
	var wrapper = _new_cell(GRID_CELL_SIZE)
	var blank := Panel.new()
	blank.set_anchors_preset(Control.PRESET_FULL_RECT)
	blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blank.add_theme_stylebox_override("panel", T.ui_slot_box("cell_empty"))
	wrapper.add_child(blank)
	_wire_backpack_drop(wrapper, index)
	return wrapper


## Overlay a gold border on a safe-cell tile (visual only; ignores mouse).
func _add_safe_border(cell: Control) -> void:
	var border := Panel.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(1.0, 0.82, 0.3)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(2)
	border.add_theme_stylebox_override("panel", sb)
	cell.add_child(border)


## Load an equipment sprite texture (same resolution rule as EquipmentIcon), or
## null if the art is missing. Used for the drag preview.
func _load_equip_tex(sprite_path: String) -> Texture2D:
	if sprite_path == "":
		return null
	var full := "res://battle_scene/assets/images/" + sprite_path
	if ResourceLoader.exists(full):
		return load(full) as Texture2D
	if FileAccess.file_exists(full):
		var img := Image.load_from_file(full)
		if img:
			return ImageTexture.create_from_image(img)
	return null


## Wire a backpack cell as a drop target: accepts another backpack cell (swap via
## move_cell) or an equipped item dragged from a slot (unequip into the bag).
func _wire_backpack_drop(cell, index: int) -> void:
	cell.can_accept = func(data):
		return (
			(data.get("src") == "backpack" and int(data.get("index", -1)) != index)
			or data.get("src") == "slot"
		)
	cell.perform_drop = func(data):
		if data.get("src") == "backpack":
			RunManager.move_cell(int(data.get("index", 0)), index)
		elif data.get("src") == "slot":
			_on_unequip_pressed(str(data.get("slot", "")))


## An equipment cell: gear icon. Drag onto a slot to equip / onto another cell to
## move. Click fallback: left = equip, right = discard, middle = toggle safe.
func _make_equip_cell(item_id: String, index: int, instance: Dictionary = {}) -> Control:
	var data = RunManager.get_equipment_data(item_id)
	var slot := str(data.get("slot", "head"))
	var item_name := Settings.t("EQUIP_%s_NAME" % item_id, str(data.get("name", item_id)))
	var cell = _new_cell(GRID_CELL_SIZE)
	cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var icon = EQUIPMENT_ICON.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_equipment(
		slot, item_name, str(data.get("sprite", "")), str(data.get("rarity", "common"))
	)
	cell.add_child(icon)
	cell.hover_tip = _build_equipment_tooltip(data, slot, instance)
	cell.drag_payload = {
		"src": "backpack", "index": index, "kind": "equip", "item_id": item_id, "slot": slot
	}
	cell.preview_text = str(SLOT_LETTERS.get(slot, "?"))
	cell.preview_color = Color(1.0, 0.86, 0.4)
	cell.preview_tex = _load_equip_tex(str(data.get("sprite", "")))
	_wire_backpack_drop(cell, index)
	if not _read_only:
		cell.click_handler = func(btn):
			if btn == MOUSE_BUTTON_LEFT:
				_on_equip_pressed(item_id, slot, index)
			elif btn == MOUSE_BUTTON_RIGHT:
				_confirm_discard(index, item_id)
			elif btn == MOUSE_BUTTON_MIDDLE:
				_toggle_safe(index)
	return cell


## A backpack TOOL cell: tool art (or ⚙ glyph) + tooltip. Left-click equips it into a
## free tool slot; middle-click toggles the safe zone; draggable to reorder/swap.
func _make_tool_cell(tool_id: String, index: int) -> Control:
	var data: Dictionary = RunManager.get_tool_data(tool_id)
	var tool_name := Settings.t("TOOL_%s_TITLE" % tool_id, str(data.get("title", tool_id)))
	var cell = _new_cell(GRID_CELL_SIZE)
	cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", T.icon_frame_style())
	cell.add_child(panel)

	var icon_path := str(data.get("icon", ""))
	var tex: Texture2D = null
	if icon_path != "" and ResourceLoader.exists(icon_path):
		tex = load(icon_path) as Texture2D
	if tex:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 6
		icon.offset_top = 6
		icon.offset_right = -6
		icon.offset_bottom = -6
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
	else:
		var glyph := Label.new()
		glyph.text = "⚙"
		glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.add_theme_font_size_override("font_size", 22)
		glyph.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(glyph)

	var desc := Settings.t("TOOL_%s_DESC" % tool_id, "")
	# The "click to equip" hint only applies when the window is editable.
	var equip_hint := "" if _read_only else tr("UI_EQUIP_TOOL_EQUIP_HINT")
	var tip := "[b]%s[/b]" % tool_name
	if desc != "":
		tip += "\n%s" % desc
	if equip_hint != "":
		tip += "\n[color=#9fd0ff]%s[/color]" % equip_hint
	cell.hover_tip = tip
	cell.drag_payload = {"src": "backpack", "index": index, "kind": "tool", "tool_id": tool_id}
	cell.preview_text = "⚙"
	cell.preview_color = Color(0.6, 0.8, 1.0)
	cell.preview_tex = tex
	_wire_backpack_drop(cell, index)
	if not _read_only:
		cell.click_handler = func(btn):
			if btn == MOUSE_BUTTON_LEFT:
				_equip_tool(index)
			elif btn == MOUSE_BUTTON_MIDDLE:
				_toggle_safe(index)
	return cell


## An equipped tool slot (the worn tool): icon + tooltip; click unequips it back into
## the backpack (map mode only — read-only in battle).
func _make_equipped_tool_cell(index: int, tool_id: String) -> Control:
	var data: Dictionary = RunManager.get_tool_data(tool_id)
	var title := Settings.t("TOOL_%s_TITLE" % tool_id, str(data.get("title", tool_id)))
	var desc := Settings.t("TOOL_%s_DESC" % tool_id, "")
	var b := Button.new()
	b.custom_minimum_size = SLOT_CELL_SIZE
	b.focus_mode = Control.FOCUS_NONE
	if _read_only:
		b.tooltip_text = "%s\n%s" % [title, desc] if desc != "" else title
	else:
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var unhint := tr("UI_EQUIP_TOOL_UNEQUIP_HINT")
		b.tooltip_text = (
			"%s\n%s\n%s" % [title, desc, unhint] if desc != "" else "%s\n%s" % [title, unhint]
		)
		b.pressed.connect(func() -> void: _unequip_tool(index))
	var icon_path := str(data.get("icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		b.icon = load(icon_path)
		b.expand_icon = true
	else:
		b.text = title.substr(0, 1).to_upper()
		b.add_theme_font_size_override("font_size", 16)
	var sb := T.ui_slot_box("filled")  # worn tool: brass-rimmed filled box
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", T.ui_slot_box("hover"))
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", T.UI_BRASS_LIGHT)
	return b


## An empty tool slot: the v2 "optional" look — lighter border + a faded ⚙
## glyph (StyleBoxFlat can't dash a border; the value drop reads as optional).
func _make_empty_tool_cell() -> Control:
	var p := Panel.new()
	p.custom_minimum_size = SLOT_CELL_SIZE
	p.add_theme_stylebox_override("panel", T.ui_slot_box("tool"))
	p.tooltip_text = tr("UI_EQUIP_TOOL_SLOT_EMPTY")
	var glyph := Label.new()
	glyph.text = "⚙"
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", 20)
	var tint := T.UI_SLOT_ICON_TINT
	tint.a = 0.55  # reduced opacity — reads as "optional"
	glyph.add_theme_color_override("font_color", tint)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(glyph)
	return p


## Equip a backpack tool (cell `index`) into a free tool slot, or flash a hint when
## every slot is full.
func _equip_tool(index: int) -> void:
	if _read_only:
		return
	if RunManager.equip_tool_from_backpack(index):
		AudioManager.play_sfx("ui_click")
	else:
		_status_label.text = tr("UI_EQUIP_TOOL_SLOTS_FULL")
		AudioManager.play_sfx("error")


## Unequip the tool in slot `index` back into the backpack (or flash if the bag is full).
func _unequip_tool(index: int) -> void:
	if _read_only:
		return
	if RunManager.unequip_tool(index):
		AudioManager.play_sfx("ui_back")
	else:
		_status_label.text = tr("UI_LOOT_BACKPACK_FULL")
		AudioManager.play_sfx("error")


## Right-click discard asks first — affixed gear is permanently lost otherwise.
func _confirm_discard(index: int, item_id: String) -> void:
	var item_name := Settings.t("EQUIP_%s_NAME" % item_id, item_id)
	var dlg := ConfirmationDialog.new()
	dlg.title = tr("UI_EQUIP_DISCARD_TITLE")
	dlg.dialog_text = tr("UI_EQUIP_DISCARD_CONFIRM").format({"item": item_name})
	dlg.exclusive = true  # block backpack interaction so `index` stays valid
	dlg.confirmed.connect(
		func():
			RunManager.discard_from_inventory(index)
			dlg.queue_free()
	)
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()


## A gold / Scrap resource stack cell. Draggable as a whole stack (move/swap via
## move_cell); middle-click still toggles safe.
func _make_resource_cell(
	label_text: String, amount: int, tint: Color, index: int, kind: String
) -> Control:
	var cell = _new_cell(GRID_CELL_SIZE)
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", T.icon_frame_style())
	cell.add_child(panel)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)

	var kind_lbl := Label.new()
	kind_lbl.text = label_text
	kind_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind_lbl.add_theme_font_size_override("font_size", 12)
	kind_lbl.add_theme_color_override("font_color", tint)
	box.add_child(kind_lbl)

	var amount_lbl := Label.new()
	amount_lbl.text = "x%d" % amount
	amount_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_lbl.add_theme_font_size_override("font_size", 18)
	amount_lbl.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9))
	box.add_child(amount_lbl)

	cell.drag_payload = {"src": "backpack", "index": index, "kind": kind}
	cell.preview_text = "x%d" % amount
	cell.preview_color = tint
	_wire_backpack_drop(cell, index)
	if not _read_only:
		cell.click_handler = func(btn):
			if btn == MOUSE_BUTTON_MIDDLE:
				_toggle_safe(index)
	return cell


## Move the stack at `index` between the safe zone (cells 0..safe-1) and the
## normal zone — into the first empty cell of the target zone. No-op if full.
func _toggle_safe(index: int) -> void:
	if _read_only:
		return
	var safe := MetaProgress.effective_safe_cells()
	var dst := -1
	if index < safe:
		dst = _first_empty_in_range(safe, RunManager.effective_backpack_size())
	else:
		dst = _first_empty_in_range(0, safe)
	if dst != -1:
		RunManager.move_cell(index, dst)
	else:
		_status_label.text = tr("UI_EQUIP_SAFE_FULL")


func _first_empty_in_range(lo: int, hi: int) -> int:
	for i in range(lo, mini(hi, RunManager.effective_backpack_size())):
		if RunManager.backpack[i] == null:
			return i
	return -1


func _on_equip_pressed(item_id: String, slot: String, _index: int) -> void:
	if _read_only:
		return
	if not RunManager.equip_to_slot(item_id, slot):
		_status_label.text = tr("UI_EQUIP_FULL_SWAP")


func _on_unequip_pressed(slot: String) -> void:
	if _read_only:
		return
	if RunManager.equip_base(RunManager.equipped_items.get(slot, {})) == "":
		return
	if not RunManager.unequip_slot(slot):
		_status_label.text = tr("UI_EQUIP_FULL_UNEQUIP")


func _build_relic_chip(relic_id: String) -> Control:
	var data = RunManager.get_relic_data(relic_id)
	var title = Settings.t("RELIC_%s_TITLE" % relic_id, str(data.get("title", relic_id)))
	var description = Settings.t("RELIC_%s_DESC" % relic_id, str(data.get("description", "")))
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", T.reward_row_style(T.PANEL_BG, T.PANEL_BORDER))
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	chip.add_child(lbl)
	chip.mouse_entered.connect(
		func() -> void:
			Tooltip.show(
				"[b]%s[/b]\n%s" % [title, description],
				chip.global_position + Vector2(chip.size.x * 0.5, 0),
				chip.get_instance_id()
			)
	)
	chip.mouse_exited.connect(func() -> void: Tooltip.hide_if_owner(chip.get_instance_id()))
	chip.tree_exited.connect(func() -> void: Tooltip.hide_if_owner(chip.get_instance_id()))
	return chip


func _build_set_row(set_id: String, count: int) -> HBoxContainer:
	var set_data = RunManager.get_equipment_set_data(set_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var equipment_set_name := Settings.t(
		"EQUIP_SET_%s_NAME" % set_id, str(set_data.get("name", set_id))
	)
	var name_lbl := Label.new()
	name_lbl.text = "%s  %d/5" % [equipment_set_name, count]
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.5))
	name_lbl.custom_minimum_size = Vector2(140, 0)
	row.add_child(name_lbl)

	var tier_list = set_data.get("tiers", [])
	if typeof(tier_list) == TYPE_ARRAY:
		for tier in tier_list:
			if typeof(tier) != TYPE_DICTIONARY:
				continue
			var threshold = int(tier.get("count", 0))
			var tier_label := Settings.t(
				"EQUIP_SET_%s_TIER_%d" % [set_id, threshold], str(tier.get("label", ""))
			)
			var label = Label.new()
			label.text = "[%d] %s" % [threshold, tier_label]
			label.add_theme_font_size_override("font_size", 12)
			if count >= threshold:
				label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
			else:
				label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			row.add_child(label)

	return row


func _load_portrait(sprite_id: String) -> Texture2D:
	var path := "%s%s/%s_portrait.png" % [HERO_SPRITE_DIR, sprite_id, sprite_id]
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img:
			return ImageTexture.create_from_image(img)
	return null


func _parse_tint(hex: String) -> Color:
	if hex.is_valid_html_color():
		return Color(hex)
	return Color.WHITE


## Rich tooltip text for an equipment item — delegates to the shared
## EQUIP_TOOLTIP helper (owner 2026-07-08: rarity·slot header, no generated
## name; set pieces keep theirs). `instance` = the rolled per-instance dict,
## {} falls back to the base JSON `bonuses` summary.
func _build_equipment_tooltip(data: Dictionary, slot: String, instance: Dictionary = {}) -> String:
	return EQUIP_TOOLTIP.text(data, slot, instance)


func _slot_label(slot: String) -> String:
	match slot:
		"head":
			return tr("UI_EQUIP_SLOT_HEAD")
		"chest":
			return tr("UI_EQUIP_SLOT_CHEST")
		"weapon":
			return tr("UI_EQUIP_SLOT_WEAPON")
		"hands":
			return tr("UI_EQUIP_SLOT_HANDS")
		"accessory":
			return tr("UI_EQUIP_SLOT_ACCESSORY")
		_:
			return slot.to_upper()


func _base_window_style() -> StyleBox:
	var style := StyleBoxTexture.new()
	style.texture = BASE_OUTER_FRAME_TEX
	style.texture_margin_left = 72
	style.texture_margin_right = 72
	style.texture_margin_top = 72
	style.texture_margin_bottom = 72
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	return style


func _base_slot_holder_style() -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	return style


func _base_slot_box_style(state: String = "cell_empty") -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.038, 0.036, 0.032, 0.96)
	style.border_color = Color(0.38, 0.265, 0.135, 0.98)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	if state == "filled":
		style.bg_color = Color(0.052, 0.050, 0.044, 0.94)
		style.border_color = Color(0.52, 0.36, 0.18, 1.0)
	elif state == "tool":
		style.bg_color = Color(0.050, 0.048, 0.043, 0.94)
		style.border_color = Color(0.42, 0.30, 0.15, 0.96)
	return style


func _base_focus_panel_style() -> StyleBox:
	var style := StyleBoxTexture.new()
	style.texture = BASE_FOCUS_FRAME_TEX
	return style


func _base_backpack_panel_style() -> StyleBox:
	var style := StyleBoxTexture.new()
	style.texture = BASE_BACKPACK_FRAME_TEX
	style.texture_margin_left = 28
	style.texture_margin_right = 28
	style.texture_margin_top = 26
	style.texture_margin_bottom = 26
	return style


func _base_title_plaque_style() -> StyleBox:
	var style := StyleBoxTexture.new()
	style.texture = BASE_TITLE_PLAQUE_TEX
	style.texture_margin_left = 72
	style.texture_margin_right = 72
	style.texture_margin_top = 34
	style.texture_margin_bottom = 34
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _base_back_button_style(state: String) -> StyleBox:
	var fallback := T.ui_button_accent(state)
	return T.concept_box("button_red_wide_%s" % state, fallback, 34, 24, 12)


func _style_base_back_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _base_back_button_style("normal"))
	button.add_theme_stylebox_override("hover", _base_back_button_style("hover"))
	button.add_theme_stylebox_override("pressed", _base_back_button_style("pressed"))
	button.add_theme_color_override("font_color", T.UI_HEADER_GOLD)
	button.add_theme_color_override("font_hover_color", T.UI_BRASS_LIGHT)
	button.add_theme_color_override("font_pressed_color", T.UI_HEADER_GOLD)
	button.add_theme_font_override("font", T.display_font(700))
	button.add_theme_font_size_override("font_size", 22)


func _base_stat_card_style() -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.050, 0.047, 0.040, 0.90)
	style.border_color = Color(0.245, 0.175, 0.105, 0.82)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _base_sheet_panel_style() -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.038, 0.036, 0.032, 0.92)
	style.border_color = Color(0.235, 0.165, 0.095, 0.76)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _base_ribbon_style(state: String) -> StyleBox:
	var bg := Color(0.085, 0.065, 0.042, 0.98)
	var border := Color(0.40, 0.29, 0.15, 1.0)
	if state == "selected":
		bg = Color(0.40, 0.105, 0.060, 0.96)
		border = Color(0.58, 0.38, 0.17, 0.86)
	elif state == "hover":
		bg = Color(0.12, 0.085, 0.048, 0.98)
		border = Color(0.72, 0.50, 0.23, 1.0)
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


## Gold v2 section header (display font, wide glyph spacing).
func _section_title(text: String) -> Label:
	return T.ui_header_label(text)

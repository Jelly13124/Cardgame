## ForgeWindow — the Forge building as a floating DraggableWindow (replaces the
## fullscreen buildings/forge_screen.gd). Four toggle tabs — Craft 打造 /
## Dismantle 拆解 / Reforge 重铸 / Curse 诅咒 — gated by the forge tier via
## `MetaProgress.building_can("forge", fn)` (locked tabs render disabled with a
## 🔒 hint). Dismantle / Reforge / Curse share a WORKBENCH: a drop slot that
## accepts a stash item dragged from this window's own compact stash grid
## (payload src "forge_stash") OR from the base-mode CharacterWindow's stash
## cells (payload src "stash", carrying the entry — resolved back to a
## MetaProgress.stash index by value), so the Diablo-style side-by-side windows
## can drag across. All economy/backend calls are the unchanged MetaProgress.*
## (dismantle_stash_item / reforge_stash_item_locked / curse_stash_item /
## spend_scrap + RunManager.make_equip_instance for craft). Rebuilds on
## scrap_changed / buildings_changed; the window frees on close, dropping the
## connections. NO class_name (ADR-0006) — loaded by path.
extends "res://run_system/ui/window/draggable_window.gd"

const AFFIX_POOL = preload("res://run_system/core/affix_pool.gd")
const EQUIPMENT_ICON = preload("res://run_system/ui/equipment_icon.gd")
const BACKPACK_CELL = preload("res://run_system/ui/backpack_cell.gd")

const WIN_SIZE := Vector2(560, 700)
## Compact stash grid (8 × 56px + separations = 490px, fits the 560-wide window).
const STASH_COLUMNS := 8
const GRID_CELL_SIZE := Vector2(56, 56)
const BENCH_CELL_SIZE := Vector2(88, 88)

## Scrap cost to craft a fresh item, by target rarity (spec: 40/80/140).
const CRAFT_COST := {"common": 40, "uncommon": 80, "rare": 140}
## Mirrors MetaProgress.CURSE_SCRAP_COST for the button label + gating (an
## autoload const can't seed a GDScript const, so this stays a literal).
const CURSE_COST := 100
## Slot → a representative base equipment item_id used when crafting that slot.
const CRAFT_BASE_BY_SLOT := {
	"head": "warden_helm",
	"chest": "warden_vest",
	"weapon": "warden_axe",
	"hands": "warden_gloves",
	"accessory": "warden_pendant",
}
const CRAFT_SLOTS := ["head", "chest", "weapon", "hands", "accessory"]
const CRAFT_RARITIES := ["common", "uncommon", "rare"]

## Tab ids double as the `building_can("forge", …)` function names.
const TABS := ["craft", "dismantle", "reforge", "curse"]
const TAB_LABEL_KEYS := {
	"craft": "UI_FORGE_TAB_CRAFT",
	"dismantle": "UI_FORGE_TAB_DISMANTLE",
	"reforge": "UI_FORGE_TAB_REFORGE",
	"curse": "UI_FORGE_TAB_CURSE",
}
## Lock-hint key per tier-gated tab (dismantle is T1 = always available once the
## building is open, so it has no hint).
const TAB_LOCK_KEYS := {
	"craft": "UI_FORGE_CRAFT_LOCKED",
	"reforge": "UI_FORGE_REFORGE_LOCKED",
	"curse": "UI_FORGE_CURSE_LOCKED",
}

## The selected tab (one of TABS); forced back to the first unlocked tab if the
## current one is tier-locked.
var _tab: String = "craft"
## Craft picker state (which slot / rarity the player has selected).
var _craft_slot: String = "head"
var _craft_rarity: String = "common"
## Index into MetaProgress.stash of the item currently on the workbench (-1 = none).
var _selected_index: int = -1
## Which affix ROW is picked for reforge (-1 = none). Forced to the locked affix
## index once the item has been reforged at least once.
var _selected_affix_index: int = -1
## Whole window body under the title bar, rebuilt wholesale on every change.
var _root: VBoxContainer


func _ready() -> void:
	init_window(tr("UI_BUILD_FORGE_NAME"), WIN_SIZE)
	_tab = _default_tab()
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	content_root.add_child(margin)
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 8)
	margin.add_child(_root)
	_rebuild()
	# Guarded connects (re-entry safe); queue_free on close drops them automatically.
	if not MetaProgress.scrap_changed.is_connected(_on_scrap_changed):
		MetaProgress.scrap_changed.connect(_on_scrap_changed)
	if not MetaProgress.buildings_changed.is_connected(_rebuild):
		MetaProgress.buildings_changed.connect(_rebuild)


func _on_scrap_changed(_v: int) -> void:
	_rebuild()


func _tab_unlocked(tab_id: String) -> bool:
	return MetaProgress.building_can("forge", tab_id)


## First unlocked tab in display order (craft is T2, so a fresh T1 forge lands on
## dismantle). Falls back to "dismantle" if somehow everything is gated.
func _default_tab() -> String:
	for tab_id in TABS:
		if _tab_unlocked(str(tab_id)):
			return str(tab_id)
	return "dismantle"


## Rebuild the whole body: scrap banner → 4-tab toggle bar → the selected tab's
## content → the shared compact stash grid. Old children are removed immediately
## (not just queue_freed) so the fixed-size window never doubles a frame.
func _rebuild() -> void:
	if not is_instance_valid(_root):
		return
	# Drop a stale bench selection (e.g. the item was dismantled out from under it).
	if _selected_index >= MetaProgress.stash.size():
		_selected_index = -1
		_selected_affix_index = -1
	if not _tab_unlocked(_tab):
		_tab = _default_tab()
	for child in _root.get_children():
		_root.remove_child(child)
		child.queue_free()

	# ── Scrap balance banner ──
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(Color(0.075, 0.055, 0.040, 0.94), T.PANEL_BORDER, 4, 2)
	)
	var bm := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		bm.add_theme_constant_override(side, 8)
	banner.add_child(bm)
	bm.add_child(T.currency_row(int(MetaProgress.scrap), "scrap", 20, 24))
	_root.add_child(banner)

	# ── Tab toggle bar ──
	_root.add_child(_build_tab_bar())

	# ── Selected tab's content ──
	match _tab:
		"craft":
			_build_craft_tab()
		_:
			_build_bench_tab(_tab)

	# ── Shared stash grid (also under Craft, so a fresh mint shows immediately) ──
	_root.add_child(HSeparator.new())
	_build_stash_section()


# --- tab bar -----------------------------------------------------------------


func _build_tab_bar() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for tab_v in TABS:
		var tab_id := str(tab_v)
		var unlocked := _tab_unlocked(tab_id)
		var selected := tab_id == _tab
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 38)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 17)
		var label_txt := tr(str(TAB_LABEL_KEYS[tab_id]))
		btn.text = label_txt if unlocked else "🔒 " + label_txt
		var fg := Color(1.0, 0.9, 0.55) if selected else Color(0.84, 0.78, 0.62)
		if not unlocked:
			fg = Color(0.5, 0.44, 0.36)
		btn.add_theme_color_override("font_color", fg)
		btn.add_theme_color_override("font_hover_color", fg.lightened(0.15))
		btn.add_theme_color_override("font_pressed_color", fg)
		btn.add_theme_color_override("font_disabled_color", fg)
		btn.add_theme_stylebox_override("normal", _tab_style(selected))
		btn.add_theme_stylebox_override("hover", _tab_style(selected))
		btn.add_theme_stylebox_override("pressed", _tab_style(true))
		btn.add_theme_stylebox_override("disabled", _tab_style(false))
		if not unlocked:
			btn.disabled = true
			if TAB_LOCK_KEYS.has(tab_id):
				btn.tooltip_text = tr(str(TAB_LOCK_KEYS[tab_id]))
		elif not selected:
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var tid := tab_id
			btn.pressed.connect(
				func() -> void:
					_tab = tid
					AudioManager.play_sfx("ui_click")
					_rebuild()
			)
		row.add_child(btn)
	return row


func _tab_style(selected: bool) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.30, 0.19, 0.08, 0.98) if selected else Color(0.10, 0.09, 0.08, 0.85)
	st.border_color = Color(1.0, 0.82, 0.35) if selected else Color(0.42, 0.33, 0.22, 0.9)
	st.set_border_width_all(2 if selected else 1)
	st.set_corner_radius_all(6)
	return st


# --- workbench (shared by dismantle / reforge / curse) ------------------------


## Bench layout: drop slot → selected item name → affix rows (pickable in the
## reforge tab, read-only elsewhere) → the tab's action button + status.
func _build_bench_tab(tab: String) -> void:
	var sel_inst: Dictionary = {}
	if _selected_index >= 0 and _selected_index < MetaProgress.stash.size():
		sel_inst = RunManager.as_equip_instance(MetaProgress.stash[_selected_index])

	_root.add_child(_section_title(tr("UI_FORGE_SELECTED_TITLE")))

	# The drop slot (also shows the benched item's icon). Accepts this window's
	# stash cells AND the CharacterWindow base-mode stash payload.
	var holder := CenterContainer.new()
	var slot_cell = BACKPACK_CELL.new()
	slot_cell.custom_minimum_size = BENCH_CELL_SIZE
	var slot_icon = EQUIPMENT_ICON.new()
	slot_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if sel_inst.is_empty():
		slot_icon.set_empty("weapon")
	else:
		var b := str(sel_inst.get("base", ""))
		var d: Dictionary = RunManager.get_equipment_data(b)
		slot_icon.set_equipment(
			str(d.get("slot", "head")),
			Settings.t("EQUIP_%s_NAME" % b, str(d.get("name", b))),
			str(d.get("sprite", "")),
			str(sel_inst.get("rarity", "common"))
		)
	slot_cell.add_child(slot_icon)
	slot_cell.can_accept = func(d):
		return (
			d.get("src") == "forge_stash"
			or (d.get("src") == "stash" and d.get("entry") != null)
		)
	slot_cell.perform_drop = func(d):
		if d.get("src") == "forge_stash":
			_select_item(int(d.get("index", -1)))
		else:
			_select_entry(d.get("entry"))
	holder.add_child(slot_cell)
	_root.add_child(holder)

	if sel_inst.is_empty():
		var bench_hint := Label.new()
		bench_hint.text = tr("UI_FORGE_BENCH_EMPTY")
		bench_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bench_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_label(bench_hint, 15, Color(0.72, 0.66, 0.52))
		_root.add_child(bench_hint)
		return

	# Selected item: name + rarity.
	var base_id := str(sel_inst.get("base", ""))
	var rarity := str(sel_inst.get("rarity", "common"))
	var cursed := bool(sel_inst.get("cursed", false))
	var data: Dictionary = RunManager.get_equipment_data(base_id)
	var item_name := Settings.t("EQUIP_%s_NAME" % base_id, str(data.get("name", base_id)))
	var name_lbl := Label.new()
	name_lbl.text = "%s [%s]" % [item_name, tr("UI_FORGE_RARITY_%s" % rarity.to_upper())]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(name_lbl, 17, Color(1, 0.92, 0.55), 1)
	_root.add_child(name_lbl)

	# Affix list. Reforge tab: click a row to PICK it (after the first reforge the
	# item LOCKS to that affix — reforge_index — and only it stays pickable).
	# Other tabs: the same rows, read-only.
	var locked := int(sel_inst.get("reforge_index", -1))
	var rcount := int(sel_inst.get("reforge_count", 0))
	var affixes := RunManager.equip_affixes(sel_inst)
	if locked >= 0:
		_selected_affix_index = locked  # a locked item forces the pick to the locked row
	if affixes.is_empty():
		var none := Label.new()
		none.text = "—"
		_style_label(none, 15, Color(0.7, 0.7, 0.68))
		_root.add_child(none)
	else:
		for ai in range(affixes.size()):
			_root.add_child(_build_affix_row(affixes[ai], ai, locked, tab == "reforge"))

	match tab:
		"dismantle":
			_build_dismantle_actions(rarity, cursed)
		"reforge":
			_build_reforge_actions(sel_inst, affixes, locked, rcount)
		"curse":
			_build_curse_actions(cursed)


## Dismantle (T1): one button; the badge shows the Scrap YIELD for this item.
func _build_dismantle_actions(rarity: String, cursed: bool) -> void:
	var dismantle_scrap := int(
		MetaProgress.DISMANTLE_SCRAP.get(rarity, MetaProgress.DISMANTLE_SCRAP["common"])
	)
	if cursed:
		dismantle_scrap += 5
	var btn := _cost_action_button(tr("UI_FORGE_DISMANTLE_VERB"), dismantle_scrap, Vector2(200, 40))
	btn.pressed.connect(_dismantle_selected)
	_root.add_child(btn)


## Reforge (T2): single button acting on the picked affix row; per-item lock +
## escalating cost via MetaProgress.reforge_cost_for. Exact forge_screen logic.
func _build_reforge_actions(
	sel_inst: Dictionary, affixes: Array, locked: int, rcount: int
) -> void:
	if affixes.is_empty():
		return
	var rcost := MetaProgress.reforge_cost_for(sel_inst)
	var pick_ok := (
		_selected_affix_index >= 0
		and _selected_affix_index < affixes.size()
		and not AFFIX_POOL.is_curse(affixes[_selected_affix_index])
	)
	var rbtn := _cost_action_button(tr("UI_FORGE_REFORGE_VERB"), rcost, Vector2(200, 40))
	rbtn.disabled = int(MetaProgress.scrap) < rcost or not pick_ok
	rbtn.pressed.connect(_reforge_selected)
	_root.add_child(rbtn)
	var status := Label.new()
	if locked >= 0:
		status.text = tr("UI_FORGE_REFORGE_LOCKED_AT").format({"n": rcount})
	elif not pick_ok:
		status.text = tr("UI_FORGE_REFORGE_PICK")
	else:
		status.text = tr("UI_FORGE_REFORGE_FIRST")
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(status, 13, Color(0.74, 0.70, 0.58))
	_root.add_child(status)


## Curse (T3): 100 Scrap, disabled if already cursed or short on Scrap.
func _build_curse_actions(cursed: bool) -> void:
	var btn := _cost_action_button(tr("UI_FORGE_CURSE_VERB"), CURSE_COST, Vector2(200, 40))
	btn.disabled = int(MetaProgress.scrap) < CURSE_COST or cursed
	btn.pressed.connect(func() -> void: _curse_item(_selected_index))
	_root.add_child(btn)


## One affix line. In the reforge tab clicking PICKS that affix (curses can't be
## picked; once locked only the locked row stays enabled). Elsewhere read-only.
func _build_affix_row(
	affix_v: Variant, affix_index: int, locked_index: int, can_pick: bool
) -> Control:
	var a := affix_v as Dictionary
	var is_curse := AFFIX_POOL.is_curse(a)
	var picked := can_pick and affix_index == _selected_affix_index
	var pickable := (
		can_pick and not is_curse and (locked_index < 0 or locked_index == affix_index)
	)

	var btn := Button.new()
	btn.text = AFFIX_POOL.describe(a)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 34)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 15)
	var fg := Color(1.0, 0.42, 0.42) if is_curse else Color(0.70, 0.92, 0.70)
	if can_pick and not pickable and not picked:
		fg = fg.darkened(0.4)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg.lightened(0.15))
	btn.add_theme_color_override("font_pressed_color", fg)
	btn.add_theme_color_override("font_disabled_color", fg)
	btn.add_theme_stylebox_override("normal", _affix_row_style(picked))
	btn.add_theme_stylebox_override("hover", _affix_row_style(picked))
	btn.add_theme_stylebox_override("pressed", _affix_row_style(true))
	btn.add_theme_stylebox_override("disabled", _affix_row_style(picked))
	if pickable:
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var ai := affix_index
		btn.pressed.connect(
			func() -> void:
				_selected_affix_index = ai
				AudioManager.play_sfx("ui_click")
				_rebuild()
		)
	else:
		btn.disabled = true
	return btn


## Stylebox for an affix row: gold-outlined when picked, faint otherwise.
func _affix_row_style(picked: bool) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.16, 0.14, 0.11, 0.9) if picked else Color(0.10, 0.10, 0.12, 0.55)
	st.border_color = Color(1.0, 0.82, 0.35) if picked else Color(0.32, 0.30, 0.26, 0.8)
	st.set_border_width_all(2 if picked else 1)
	st.set_corner_radius_all(5)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	return st


# --- the compact in-window stash grid -----------------------------------------


func _build_stash_section() -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(_section_title(tr("UI_FORGE_STASH_TITLE").format({"n": MetaProgress.stash.size()})))
	_root.add_child(head)

	if _tab != "craft":
		var hint := Label.new()
		hint.text = tr("UI_FORGE_WORKBENCH_HINT")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style_label(hint, 12, Color(0.65, 0.6, 0.5))
		_root.add_child(hint)

	if MetaProgress.stash.is_empty():
		var empty := Label.new()
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.text = tr("UI_FORGE_EMPTY")
		_style_label(empty, 14, Color(0.72, 0.66, 0.52))
		_root.add_child(empty)
		return

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_root.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = STASH_COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	for i in range(MetaProgress.stash.size()):
		grid.add_child(_build_forge_stash_cell(i))


## One stash cell: a draggable BackpackCell (EquipmentIcon child) that drops onto
## the workbench slot to bench it; left-click also benches it. The benched item
## gets a gold outline.
func _build_forge_stash_cell(index: int) -> Control:
	var inst := RunManager.as_equip_instance(MetaProgress.stash[index])
	var base_id := str(inst.get("base", ""))
	var data: Dictionary = RunManager.get_equipment_data(base_id)
	var slot := str(data.get("slot", "head"))
	var rarity := str(inst.get("rarity", "common"))
	var item_name := Settings.t("EQUIP_%s_NAME" % base_id, str(data.get("name", base_id)))

	var cell = BACKPACK_CELL.new()
	cell.custom_minimum_size = GRID_CELL_SIZE
	cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var icon = EQUIPMENT_ICON.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_equipment(slot, item_name, str(data.get("sprite", "")), rarity)
	cell.add_child(icon)

	cell.hover_tip = _forge_item_tooltip(inst)
	cell.drag_payload = {"src": "forge_stash", "index": index}
	cell.preview_text = item_name.substr(0, 1)
	cell.preview_color = Color(1.0, 0.86, 0.4)
	cell.preview_tex = _load_equip_tex(str(data.get("sprite", "")))
	var idx := index
	cell.click_handler = func(btn): if btn == MOUSE_BUTTON_LEFT: _select_item(idx)

	if index == _selected_index:
		var hl := Panel.new()
		hl.set_anchors_preset(Control.PRESET_FULL_RECT)
		hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0, 0, 0, 0)
		st.border_color = Color(1.0, 0.85, 0.35)
		st.set_border_width_all(3)
		st.set_corner_radius_all(6)
		hl.add_theme_stylebox_override("panel", st)
		cell.add_child(hl)
	return cell


# --- workbench actions ---------------------------------------------------------


## Put a stash item on the workbench (from a drag-drop or a click).
func _select_item(index: int) -> void:
	if index < 0 or index >= MetaProgress.stash.size():
		return
	_selected_index = index
	_selected_affix_index = -1  # reset the affix pick when a new item comes onto the bench
	AudioManager.play_sfx("ui_click")
	_rebuild()


## Bench a stash entry dropped from the CharacterWindow's base-mode stash grid
## (payload {"src": "stash", "slot": …, "entry": …}): resolve the entry back to
## its MetaProgress.stash index by VALUE (the same match remove_from_stash uses;
## duplicate gear is interchangeable for forge purposes).
func _select_entry(entry: Variant) -> void:
	if entry == null:
		return
	var idx: int = MetaProgress.stash.find(entry)
	if idx >= 0:
		_select_item(idx)


## Dismantle the workbench item, then clear the bench (its index is now stale).
func _dismantle_selected() -> void:
	if _selected_index < 0 or _selected_index >= MetaProgress.stash.size():
		return
	if MetaProgress.dismantle_stash_item(_selected_index):
		AudioManager.play_sfx("forge_dismantle")
		_selected_index = -1
	_rebuild()


## Reforge the PICKED affix on the workbench item. The backend locks the item to
## that affix on the first reforge and climbs the cost each time. Keeps the item
## selected so the new roll shows immediately.
func _reforge_selected() -> void:
	if _selected_index < 0 or _selected_affix_index < 0:
		return
	if MetaProgress.reforge_stash_item_locked(_selected_index, _selected_affix_index):
		AudioManager.play_sfx("forge_reforge")
	_rebuild()


## Curse the benched stash item in place (T3). MetaProgress.curse_stash_item owns
## the CURSE_SCRAP_COST spend, the cursed re-roll, the flag, the save, and emits
## scrap_changed (→ _rebuild). Rebuild explicitly too in case the scrap math no-ops.
func _curse_item(index: int) -> void:
	if not MetaProgress.curse_stash_item(index):
		return
	AudioManager.play_sfx("forge_curse")
	_rebuild()


# --- craft tab ------------------------------------------------------------------


## Craft (T2): slot + rarity pickers stacked (the 560-wide window can't fit
## forge_screen's single row) + a Craft button showing the Scrap cost.
func _build_craft_tab() -> void:
	_root.add_child(_section_title(tr("UI_FORGE_CRAFT_TITLE")))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(Color(0.11, 0.08, 0.06, 0.92), T.PANEL_BORDER, 6, 1)
	)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 10)
	box.add_child(slot_row)
	var slot_lbl := Label.new()
	slot_lbl.text = tr("UI_FORGE_SLOT")
	slot_lbl.custom_minimum_size = Vector2(72, 0)
	_style_label(slot_lbl, 15, Color(0.92, 0.88, 0.76))
	slot_row.add_child(slot_lbl)
	var slot_opt := OptionButton.new()
	slot_opt.custom_minimum_size = Vector2(0, 36)
	slot_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in CRAFT_SLOTS:
		slot_opt.add_item(tr("UI_FORGE_SLOT_%s" % str(s).to_upper()))
	slot_opt.selected = CRAFT_SLOTS.find(_craft_slot)
	slot_opt.item_selected.connect(
		func(idx: int) -> void:
			_craft_slot = str(CRAFT_SLOTS[idx])
			_rebuild()
	)
	slot_row.add_child(slot_opt)

	var rarity_row := HBoxContainer.new()
	rarity_row.add_theme_constant_override("separation", 10)
	box.add_child(rarity_row)
	var rarity_lbl := Label.new()
	rarity_lbl.text = tr("UI_FORGE_RARITY")
	rarity_lbl.custom_minimum_size = Vector2(72, 0)
	_style_label(rarity_lbl, 15, Color(0.92, 0.88, 0.76))
	rarity_row.add_child(rarity_lbl)
	var rarity_opt := OptionButton.new()
	rarity_opt.custom_minimum_size = Vector2(0, 36)
	rarity_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for r in CRAFT_RARITIES:
		rarity_opt.add_item(tr("UI_FORGE_RARITY_%s" % str(r).to_upper()))
	rarity_opt.selected = CRAFT_RARITIES.find(_craft_rarity)
	rarity_opt.item_selected.connect(
		func(idx: int) -> void:
			_craft_rarity = str(CRAFT_RARITIES[idx])
			_rebuild()
	)
	rarity_row.add_child(rarity_opt)

	var cost := int(CRAFT_COST.get(_craft_rarity, CRAFT_COST["common"]))
	var craft_btn := _cost_action_button(tr("UI_FORGE_CRAFT_VERB"), cost, Vector2(200, 40))
	craft_btn.disabled = int(MetaProgress.scrap) < cost
	craft_btn.pressed.connect(_on_craft_pressed)
	box.add_child(craft_btn)
	_root.add_child(panel)


## Spend Scrap and mint a fresh stash item of the selected slot + rarity.
func _on_craft_pressed() -> void:
	var cost := int(CRAFT_COST.get(_craft_rarity, CRAFT_COST["common"]))
	var base_id := str(CRAFT_BASE_BY_SLOT.get(_craft_slot, ""))
	if base_id == "":
		return
	if not MetaProgress.spend_scrap(cost):
		return
	var inst: Dictionary = RunManager.make_equip_instance(base_id, _craft_rarity)
	if inst.is_empty():
		return
	MetaProgress.add_to_stash(inst)
	AudioManager.play_sfx("forge_craft")
	# add_to_stash saves but emits no signal; spend_scrap already emitted
	# scrap_changed → _rebuild picks the new item up. Rebuild explicitly too
	# in case scrap was unchanged for any reason.
	_rebuild()


# --- shared helpers --------------------------------------------------------------


## Load an equipment sprite texture for the drag preview (mirrors character_window).
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


## Rich tooltip for a stash item: name + one colored line per affix.
func _forge_item_tooltip(inst: Dictionary) -> String:
	var base_id := str(inst.get("base", ""))
	var data: Dictionary = RunManager.get_equipment_data(base_id)
	var nm := Settings.t("EQUIP_%s_NAME" % base_id, str(data.get("name", base_id)))
	var lines: Array[String] = ["[b]%s[/b]" % nm]
	for affix in RunManager.equip_affixes(inst):
		if typeof(affix) != TYPE_DICTIONARY:
			continue
		var label := AFFIX_POOL.describe(affix)
		if AFFIX_POOL.is_curse(affix):
			lines.append("[color=#e0584c]%s[/color]" % label)
		else:
			lines.append("[color=#5fd06a]%s[/color]" % label)
	return "\n".join(lines)


## A Scrap-cost action button: verb text (left) + a Scrap amount+icon badge
## overlaid on the right. Caller sets `.disabled` / `.pressed` after this returns.
func _cost_action_button(verb: String, cost: int, min_size: Vector2) -> Button:
	var btn := Button.new()
	btn.text = verb
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = min_size
	T.apply_button_theme(btn)
	btn.add_theme_color_override("font_disabled_color", Color(0.72, 0.64, 0.50, 0.92))
	btn.add_child(T.overlay_cost_badge(cost, "scrap", 15, 16, -8, -66))
	return btn


func _section_title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	return l


func _style_label(label: Label, font_size: int, color: Color, outline: int = 0) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if outline > 0:
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
		label.add_theme_constant_override("outline_size", outline)

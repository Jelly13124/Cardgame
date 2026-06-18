## Warehouse (仓库) building screen — Phase-3 functions over the shared building
## API. Subclasses the building screen base (no class_name, ADR-0006): instantiate
## with `.new()`, set `building_id = "warehouse"`, add as child.
##
## Functions by tier (see MetaProgress.BUILDING_DEFS["warehouse"]):
##   T1 hero_select — pick the hero for the next run (unlock-gated heroes dimmed).
##   T1 loadout     — two-column CHARACTER | STASH board: drag stash gear onto the
##                    5 equip slots to start the run already wearing it.
##   T3 conversion  — currency exchange (Core→Caps, Caps→Scrap) with a ~10% tax.
##
## Layout: LEFT = compact hero picker + the 5 equipment SLOTS (drop targets);
## RIGHT = the permanent stash as a draggable grid. Dragging a stash item onto a
## matching-slot cell marks it as the run's starting-equipped item for that slot
## (RunManager.pending_equipped[slot]); dragging a slot back to the stash unequips
## it. The chosen items stay listed in the stash data but are HIDDEN from the grid
## while assigned to a slot, so they cannot also be marked elsewhere — start_new_run
## removes them from the stash exactly once when it equips them.
##
## This file only READS the MetaProgress building API + existing add/spend
## currency methods and writes RunManager.pending_equipped / pending_hero_id /
## current_hero_id. It owns its own i18n block (ui_build_warehouse.csv).
##
## Drag system MIRRORS equipment_panel.gd: BackpackCell wrappers own
## _get_drag_data/_can_drop_data/_drop_data, with an EquipmentIcon cosmetic child.
extends "res://run_system/ui/buildings/building_screen_base.gd"

const EQUIPMENT_ICON = preload("res://run_system/ui/equipment_icon.gd")
const BACKPACK_CELL = preload("res://run_system/ui/backpack_cell.gd")

const HERO_DIR := "res://run_system/data/heroes/"

const CELL_SIZE := Vector2(74, 74)
const STASH_COLUMNS := 4
const SLOT_LETTERS := {"head": "H", "chest": "C", "weapon": "W", "hands": "Hd", "accessory": "Ac"}

## Conversion tunables (spec §Warehouse): Core→Caps 1:2, Caps→Scrap 4:1, ~10% tax
## (floored). Each row converts a fixed chunk of the source currency.
const CONV_CORE_CHUNK := 50
const CONV_CORE_RATE := 2.0
const CONV_CAPS_CHUNK := 40
const CONV_CAPS_RATE := 0.25
const CONV_TAX := 0.10

## Balances row (rebuilt on every _refresh via the base's signal wiring).
var _balances_lbl: Label = null
## Status line for transient feedback (selection / conversion results).
var _status_lbl: Label = null


## Build all tier-gated function blocks. Called once by the base's _build(); the
## base also calls our _refresh() override after, and on every currency/buildings
## change signal it already connects.
func _build_content(container: VBoxContainer) -> void:
	# Top: live currency balances (Core / Caps / Scrap).
	_balances_lbl = Label.new()
	_balances_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(_balances_lbl, 20, Color(0.92, 0.86, 0.62), 2)
	container.add_child(_balances_lbl)

	_status_lbl = Label.new()
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(_status_lbl, 17, Color(0.70, 0.86, 0.55), 1)
	_status_lbl.visible = false
	container.add_child(_status_lbl)

	container.add_child(HSeparator.new())

	# Two-column body: LEFT character (hero pick + equip slots) | RIGHT stash grid.
	_build_loadout_board(container)
	container.add_child(HSeparator.new())
	_build_conversion(container)

	_update_balances()


# --- T1: two-column loadout board (character | stash) ----------------------


## The headline: an HBoxContainer with LEFT character column (hero picker + the 5
## equipment slots as drop targets) and RIGHT stash column (draggable grid).
## Gated on the warehouse "loadout" function (T1). Rebuilt wholesale on _refresh.
func _build_loadout_board(container: VBoxContainer) -> void:
	container.add_child(_function_header(tr("UI_WAREHOUSE_LOADOUT_TITLE"), "loadout"))
	if not MetaProgress.building_can("warehouse", "loadout"):
		container.add_child(_locked_note("loadout"))
		return

	var hint := Label.new()
	hint.text = tr("UI_WAREHOUSE_LOADOUT_HINT")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(hint, 16, Color(0.80, 0.74, 0.58), 1)
	container.add_child(hint)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 28)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(body)

	body.add_child(_build_character_column())
	body.add_child(VSeparator.new())
	body.add_child(_build_stash_column())


# --- LEFT column: hero picker + equip slots --------------------------------


func _build_character_column() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(360, 0)

	# Compact hero picker.
	var hero_title := Label.new()
	hero_title.text = tr("UI_WAREHOUSE_HERO_TITLE")
	_style_label(hero_title, 20, accent, 2)
	col.add_child(hero_title)
	col.add_child(_build_hero_picker())

	# The 5 equipment slots as drop targets.
	var slots_title := Label.new()
	slots_title.text = tr("UI_WAREHOUSE_SLOTS_HEADER")
	_style_label(slots_title, 20, accent, 2)
	col.add_child(slots_title)

	for slot in RunManager.EQUIPMENT_SLOTS:
		col.add_child(_build_slot_row(slot))
	return col


## Compact hero buttons in a wrap; the picked hero is highlighted. Mirrors the old
## hero_select but inline (no per-hero "Select" button — the row IS the button).
func _build_hero_picker() -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)

	for hero_id in _list_hero_ids():
		# DEMO BUILD: only the allowed heroes appear in the picker (full roster
		# returns when RunManager.DEMO_BUILD is flipped off).
		if RunManager.DEMO_BUILD and not (hero_id in RunManager.DEMO_ALLOWED_HEROES):
			continue
		var data := _load_hero(hero_id)
		var locked := _hero_locked(hero_id)
		var english_name := str(data.get("name", hero_id))
		var hero_name := Settings.t("HERO_%s_NAME" % hero_id, english_name)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 38)
		T.apply_button_theme(btn)
		if locked:
			btn.text = "%s 🔒" % hero_name
			btn.disabled = true
		elif str(RunManager.current_hero_id) == hero_id:
			btn.text = "● %s" % hero_name
			btn.add_theme_color_override("font_color", Color(0.55, 0.85, 0.5))
		else:
			btn.text = hero_name
			btn.pressed.connect(_on_hero_picked.bind(hero_id, hero_name))
		flow.add_child(btn)
	return flow


func _on_hero_picked(hero_id: String, hero_name: String) -> void:
	# Persist the choice into RunManager.pending_hero_id; start_new_run reads it as
	# the next run's hero when no explicit hero_id is passed. Also set
	# current_hero_id so the "selected" marker + deck editor reflect it immediately.
	RunManager.pending_hero_id = hero_id
	RunManager.current_hero_id = hero_id
	_flash_status(tr("UI_WAREHOUSE_HERO_PICK_OK").format({"hero": hero_name}))
	_refresh()


## One equip slot: a BackpackCell drop-target (EquipmentIcon cosmetic child) + a
## name label. Shows the item currently queued in pending_equipped[slot], else the
## empty-slot placeholder. Drag-accepts a matching-slot stash item; click/drag the
## filled cell back to the stash to unequip.
func _build_slot_row(slot: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var cell := BACKPACK_CELL.new()
	cell.custom_minimum_size = CELL_SIZE
	cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var icon := EQUIPMENT_ICON.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(icon)

	var s := slot
	# Accept a matching-slot equipment dragged from the stash grid.
	cell.can_accept = func(data): return (
		data.get("src") == "stash" and data.get("slot") == s
	)
	cell.perform_drop = func(data): _assign_to_slot(s, data.get("entry"))

	var queued: Variant = RunManager.pending_equipped.get(slot, null)
	var inst: Dictionary = RunManager.as_equip_instance(queued) if queued != null else {}
	var label := Label.new()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if inst.is_empty():
		icon.set_empty(slot)
		cell.drag_payload = {}
		cell.hover_tip = "[b]%s[/b]\n%s" % [_slot_label(slot), tr("UI_EQUIP_EMPTY_SLOT")]
		_style_label(label, 17, Color(0.72, 0.66, 0.52), 1)
		label.text = "%s: %s" % [_slot_label(slot), tr("UI_EQUIP_EMPTY")]
	else:
		var base_id: String = RunManager.equip_base(inst)
		var data: Dictionary = RunManager.get_equipment_data(base_id)
		var item_name := Settings.t("EQUIP_%s_NAME" % base_id, str(data.get("name", base_id)))
		icon.set_equipment(slot, item_name, str(data.get("sprite", "")), str(data.get("rarity", "common")))
		# Filled slot is draggable back into the stash (unequip).
		cell.drag_payload = {"src": "slot", "slot": slot}
		cell.preview_text = str(SLOT_LETTERS.get(slot, "?"))
		cell.preview_color = Color(1.0, 0.86, 0.4)
		cell.preview_tex = _load_equip_tex(str(data.get("sprite", "")))
		cell.hover_tip = _equip_tooltip(inst)
		cell.click_handler = func(btn): if btn == MOUSE_BUTTON_LEFT: _unassign_slot(s)
		_style_label(label, 17, Color(0.90, 0.84, 0.64), 1)
		label.text = "%s: %s" % [_slot_label(slot), _describe_item(inst)]

	row.add_child(cell)
	row.add_child(label)
	return row


# --- RIGHT column: permanent stash grid ------------------------------------


func _build_stash_column() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	# Count only entries still available (not assigned to a slot) over capacity.
	title.text = tr("UI_WAREHOUSE_STASH_HEADER").format(
		{"n": _available_stash_indices().size(), "cap": MetaProgress.effective_stash_cap()}
	)
	_style_label(title, 20, accent, 2)
	col.add_child(title)

	var available := _available_stash_indices()
	if available.is_empty():
		var empty := Label.new()
		empty.text = tr("UI_WAREHOUSE_LOADOUT_EMPTY")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style_label(empty, 18, Color(0.72, 0.66, 0.52), 1)
		col.add_child(empty)
		return col

	var grid := GridContainer.new()
	grid.columns = STASH_COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)

	for i in available:
		grid.add_child(_build_stash_cell(MetaProgress.stash[i]))
	return col


## One stash cell: a draggable BackpackCell (EquipmentIcon cosmetic child) carrying
## the stash entry + its slot. Drop it on a matching slot to equip; left-click also
## auto-equips into its slot.
func _build_stash_cell(entry: Variant) -> Control:
	var inst: Dictionary = RunManager.as_equip_instance(entry)
	var base_id: String = RunManager.equip_base(inst)
	var data: Dictionary = RunManager.get_equipment_data(base_id)
	var slot := str(data.get("slot", "head"))
	var item_name := Settings.t("EQUIP_%s_NAME" % base_id, str(data.get("name", base_id)))

	var cell := BACKPACK_CELL.new()
	cell.custom_minimum_size = CELL_SIZE
	cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var icon := EQUIPMENT_ICON.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_equipment(slot, item_name, str(data.get("sprite", "")), str(data.get("rarity", "common")))
	cell.add_child(icon)

	cell.hover_tip = _equip_tooltip(inst)
	# Drag payload carries the actual stash entry so the slot can mark it directly.
	cell.drag_payload = {"src": "stash", "slot": slot, "entry": entry}
	cell.preview_text = str(SLOT_LETTERS.get(slot, "?"))
	cell.preview_color = Color(1.0, 0.86, 0.4)
	cell.preview_tex = _load_equip_tex(str(data.get("sprite", "")))
	# Click fallback: assign to its matching slot.
	cell.click_handler = func(btn): if btn == MOUSE_BUTTON_LEFT: _assign_to_slot(slot, entry)
	# Accept a slot item dragged here (unequip back to stash).
	cell.can_accept = func(d): return d.get("src") == "slot"
	cell.perform_drop = func(d): _unassign_slot(str(d.get("slot", "")))
	return cell


# --- assign / unassign loadout slots ---------------------------------------


## Mark stash `entry` as the run's starting item for `slot`. If a different item is
## already queued in that slot, it returns to the stash automatically (it was never
## removed from stash data — pending_equipped just references it). Validates the
## item's JSON slot matches.
func _assign_to_slot(slot: String, entry: Variant) -> void:
	if entry == null or not slot in RunManager.EQUIPMENT_SLOTS:
		return
	var inst: Dictionary = RunManager.as_equip_instance(entry)
	if inst.is_empty():
		return
	var base_id: String = RunManager.equip_base(inst)
	var data: Dictionary = RunManager.get_equipment_data(base_id)
	if str(data.get("slot", "")) != slot:
		return  # slot mismatch — ignore
	RunManager.pending_equipped[slot] = entry
	_refresh()


## Clear the queued item from `slot` (it returns to the available stash grid).
func _unassign_slot(slot: String) -> void:
	if RunManager.pending_equipped.has(slot):
		RunManager.pending_equipped.erase(slot)
		_refresh()


## Indices into MetaProgress.stash of entries NOT currently assigned to a slot, so
## a queued item shows in its slot but is hidden from the stash grid (can't be
## double-marked). Matches by VALUE against pending_equipped (same as remove_from_stash).
func _available_stash_indices() -> Array[int]:
	var assigned: Array = RunManager.pending_equipped.values()
	var taken: Array[int] = []  # stash indices already consumed by an assignment
	var out: Array[int] = []
	for i in range(MetaProgress.stash.size()):
		var entry: Variant = MetaProgress.stash[i]
		if RunManager.as_equip_instance(entry).is_empty():
			continue
		# Consume one assignment match per stash entry (handles duplicate gear).
		var matched := false
		for a in range(assigned.size()):
			if a in taken:
				continue
			if assigned[a] == entry:
				taken.append(a)
				matched = true
				break
		if not matched:
			out.append(i)
	return out


## Load an equipment sprite texture for the drag preview (mirrors equipment_panel).
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


## Rich tooltip for an equip instance: name + one localized line per rolled affix.
func _equip_tooltip(inst: Dictionary) -> String:
	var base_id: String = RunManager.equip_base(inst)
	var data: Dictionary = RunManager.get_equipment_data(base_id)
	var name_str := Settings.t("EQUIP_%s_NAME" % base_id, str(data.get("name", base_id)))
	var lines: Array[String] = ["[b]%s[/b]" % name_str]
	for affix in RunManager.equip_affixes(inst):
		if typeof(affix) != TYPE_DICTIONARY:
			continue
		var label := MetaProgress.AFFIX_POOL.describe(affix)
		if MetaProgress.AFFIX_POOL.is_curse(affix):
			lines.append("[color=#e0584c]%s[/color]" % label)
		else:
			lines.append("[color=#5fd06a]%s[/color]" % label)
	return "\n".join(lines)


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


# --- T3: conversion --------------------------------------------------------


func _build_conversion(container: VBoxContainer) -> void:
	container.add_child(_function_header(tr("UI_WAREHOUSE_CONVERT_TITLE"), "conversion"))
	if not MetaProgress.building_can("warehouse", "conversion"):
		container.add_child(_locked_note("conversion"))
		return

	# Core → Caps (1:2, ~10% tax).
	var core_out := _converted_amount(CONV_CORE_CHUNK, CONV_CORE_RATE)
	container.add_child(
		_conversion_row(
			tr("UI_WAREHOUSE_CONVERT_CORE").format({"src": CONV_CORE_CHUNK, "dst": core_out}),
			MetaProgress.core >= CONV_CORE_CHUNK,
			_on_convert_core_to_caps
		)
	)

	# Caps → Scrap (4:1, ~10% tax).
	var caps_out := _converted_amount(CONV_CAPS_CHUNK, CONV_CAPS_RATE)
	container.add_child(
		_conversion_row(
			tr("UI_WAREHOUSE_CONVERT_CAPS").format({"src": CONV_CAPS_CHUNK, "dst": caps_out}),
			MetaProgress.caps >= CONV_CAPS_CHUNK,
			_on_convert_caps_to_scrap
		)
	)


## Post-tax destination amount for converting `chunk` of source at `rate`. Tax is
## floored off the gross so grinding never rounds in the player's favor.
func _converted_amount(chunk: int, rate: float) -> int:
	return int(floor(chunk * rate * (1.0 - CONV_TAX)))


func _conversion_row(label_text: String, affordable: bool, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(lbl, 17, Color(0.88, 0.82, 0.62), 1)
	row.add_child(lbl)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 40)
	btn.text = tr("UI_WAREHOUSE_CONVERT_DO")
	T.apply_button_theme(btn)
	btn.disabled = not affordable
	if affordable:
		btn.pressed.connect(cb)
	row.add_child(btn)
	return row


func _on_convert_core_to_caps() -> void:
	if MetaProgress.core < CONV_CORE_CHUNK:
		return
	var out := _converted_amount(CONV_CORE_CHUNK, CONV_CORE_RATE)
	# add_core(-n) clamps at 0 but we already checked the balance, so it is exact.
	MetaProgress.add_core(-CONV_CORE_CHUNK)
	MetaProgress.add_caps(out)
	_flash_status(
		tr("UI_WAREHOUSE_CONVERT_OK").format(
			{
				"src": CONV_CORE_CHUNK,
				"src_name": tr("UI_WAREHOUSE_CUR_CORE"),
				"dst": out,
				"dst_name": tr("UI_WAREHOUSE_CUR_CAPS")
			}
		)
	)
	# _refresh() fires via core_changed/caps_changed; call once for immediacy.
	_refresh()


func _on_convert_caps_to_scrap() -> void:
	if not MetaProgress.spend_caps(CONV_CAPS_CHUNK):
		return
	var out := _converted_amount(CONV_CAPS_CHUNK, CONV_CAPS_RATE)
	MetaProgress.add_scrap(out)
	_flash_status(
		tr("UI_WAREHOUSE_CONVERT_OK").format(
			{
				"src": CONV_CAPS_CHUNK,
				"src_name": tr("UI_WAREHOUSE_CUR_CAPS"),
				"dst": out,
				"dst_name": tr("UI_WAREHOUSE_CUR_SCRAP")
			}
		)
	)
	_refresh()


# --- shared helpers --------------------------------------------------------


## Override the base refresh: keep its tier badge / action button logic, then
## rebuild our content so toggles + balances repaint. The base connects _refresh
## to buildings_changed and all three currency signals, so this runs on any of
## those. We rebuild the content box from scratch (cheap; few rows).
func _refresh() -> void:
	super._refresh()
	if not is_instance_valid(_content_box):
		return
	for child in _content_box.get_children():
		child.queue_free()
	# Children are freed deferred; rebuild into the (still valid) box. The newly
	# added nodes coexist with the queued-free old ones for one frame — harmless.
	_build_content(_content_box)


func _update_balances() -> void:
	if not is_instance_valid(_balances_lbl):
		return
	_balances_lbl.text = tr("UI_WAREHOUSE_BALANCES").format(
		{"core": MetaProgress.core, "caps": MetaProgress.caps, "scrap": MetaProgress.scrap}
	)


func _flash_status(text: String) -> void:
	if not is_instance_valid(_status_lbl):
		return
	_status_lbl.text = text
	_status_lbl.visible = true


## A function sub-header: title plus a small tier-requirement tag.
func _function_header(title: String, function: String) -> Label:
	var lbl := Label.new()
	var min_tier := _function_min_tier(function)
	lbl.text = "%s  (T%d)" % [title, min_tier]
	_style_label(lbl, 22, accent, 2)
	return lbl


## A standard "locked — needs tier N" note for an above-tier function.
func _locked_note(function: String) -> Label:
	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = tr("UI_WAREHOUSE_FN_LOCKED").format({"n": _function_min_tier(function)})
	_style_label(note, 17, Color(0.78, 0.60, 0.40), 1)
	return note


## Minimum tier that gates a warehouse function (from BUILDING_DEFS). 99 if absent.
func _function_min_tier(function: String) -> int:
	var defs: Dictionary = MetaProgress.BUILDING_DEFS.get("warehouse", {})
	var functions: Dictionary = defs.get("functions", {})
	return int(functions.get(function, 99))


## "<Name> · <affix>, <affix>" for one equip instance, localized.
func _describe_item(inst: Dictionary) -> String:
	var base_id: String = RunManager.equip_base(inst)
	var data: Dictionary = RunManager.get_equipment_data(base_id)
	var item_name := Settings.t("EQUIP_%s_NAME" % base_id, str(data.get("name", base_id)))
	var parts: Array[String] = []
	for affix in RunManager.equip_affixes(inst):
		if typeof(affix) == TYPE_DICTIONARY:
			parts.append(MetaProgress.AFFIX_POOL.describe(affix))
	if parts.is_empty():
		return item_name
	return "%s · %s" % [item_name, ", ".join(parts)]


# --- hero data (mirrors hero_select.gd, read-only) -------------------------


func _hero_locked(_hero_id: String) -> bool:
	return false  # Feng Shui Master removed; no heroes are unlock-gated.


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

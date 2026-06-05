## Warehouse (仓库) building screen — Phase-3 functions over the shared building
## API. Subclasses the building screen base (no class_name, ADR-0006): instantiate
## with `.new()`, set `building_id = "warehouse"`, add as child.
##
## Functions by tier (see MetaProgress.BUILDING_DEFS["warehouse"]):
##   T1 hero_select — pick the hero for the next run (unlock-gated heroes dimmed).
##   T1 loadout     — mark permanent-stash gear to carry into the next run.
##   T2 more_slots  — Core upgrade meant to raise stash capacity (see REPORT note).
##   T3 conversion  — currency exchange (Core→Caps, Caps→Scrap) with a ~10% tax.
##
## This file only READS the MetaProgress building API + existing add/spend
## currency methods and writes RunManager.pending_loadout / current_hero_id. It
## owns its own i18n block (assets/translations/ui_build_warehouse.csv).
extends "res://run_system/ui/buildings/building_screen_base.gd"

const HERO_DIR := "res://run_system/data/heroes/"
## Hero gated behind the jerry_unlock base upgrade (mirrors hero_select.gd).
const LOCKED_HERO_ID := "hero_fengshui_master"

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

	_build_hero_select(container)
	container.add_child(HSeparator.new())
	_build_loadout(container)
	container.add_child(HSeparator.new())
	_build_more_slots(container)
	container.add_child(HSeparator.new())
	_build_conversion(container)

	_update_balances()


# --- T1: hero select -------------------------------------------------------


func _build_hero_select(container: VBoxContainer) -> void:
	container.add_child(_function_header(tr("UI_WAREHOUSE_HERO_TITLE"), "hero_select"))
	if not MetaProgress.building_can("warehouse", "hero_select"):
		container.add_child(_locked_note("hero_select"))
		return

	for hero_id in _list_hero_ids():
		var data := _load_hero(hero_id)
		var locked := _hero_locked(hero_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var name_lbl := Label.new()
		var english_name := str(data.get("name", hero_id))
		var hero_name := Settings.t("HERO_%s_NAME" % hero_id, english_name)
		name_lbl.text = hero_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_label(
			name_lbl, 19, Color(0.62, 0.62, 0.64) if locked else Color(0.92, 0.86, 0.66), 1
		)
		row.add_child(name_lbl)

		if str(RunManager.current_hero_id) == hero_id:
			var marker := Label.new()
			marker.text = tr("UI_WAREHOUSE_HERO_SELECTED")
			_style_label(marker, 17, Color(0.55, 0.85, 0.5), 1)
			row.add_child(marker)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 40)
		T.apply_button_theme(btn)
		if locked:
			btn.text = tr("UI_WAREHOUSE_HERO_LOCKED")
			btn.disabled = true
		else:
			btn.text = tr("UI_WAREHOUSE_HERO_PICK")
			btn.pressed.connect(_on_hero_picked.bind(hero_id, hero_name))
		row.add_child(btn)

		container.add_child(row)


func _on_hero_picked(hero_id: String, hero_name: String) -> void:
	# NOTE: there is no persistent "pending_hero_id" to thread into start_new_run
	# (heroes are chosen at run start via hero_select.gd). We store the choice into
	# RunManager.current_hero_id as a visible marker — it is harmless because
	# start_new_run overwrites it with its hero_id argument. See REPORT.
	RunManager.current_hero_id = hero_id
	_flash_status(tr("UI_WAREHOUSE_HERO_PICK_OK").format({"hero": hero_name}))
	_refresh()


# --- T1: loadout -----------------------------------------------------------


func _build_loadout(container: VBoxContainer) -> void:
	container.add_child(_function_header(tr("UI_WAREHOUSE_LOADOUT_TITLE"), "loadout"))
	if not MetaProgress.building_can("warehouse", "loadout"):
		container.add_child(_locked_note("loadout"))
		return

	var cap := _loadout_cap()
	var marked: int = RunManager.pending_loadout.size()
	var count_lbl := Label.new()
	count_lbl.text = tr("UI_WAREHOUSE_LOADOUT_COUNT").format({"n": marked, "cap": cap})
	_style_label(count_lbl, 17, Color(0.80, 0.74, 0.58), 1)
	container.add_child(count_lbl)

	if MetaProgress.stash.is_empty():
		var empty := Label.new()
		empty.text = tr("UI_WAREHOUSE_LOADOUT_EMPTY")
		_style_label(empty, 18, Color(0.72, 0.66, 0.52), 1)
		container.add_child(empty)
		return

	for i in range(MetaProgress.stash.size()):
		var stash_entry: Variant = MetaProgress.stash[i]
		var inst: Dictionary = RunManager.as_equip_instance(stash_entry)
		if inst.is_empty():
			continue
		var marked_now: bool = _pending_index_of(stash_entry) >= 0

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var info := Label.new()
		info.text = _describe_item(inst)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_label(
			info, 17, Color(0.90, 0.84, 0.64) if marked_now else Color(0.78, 0.72, 0.56), 1
		)
		row.add_child(info)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(140, 38)
		T.apply_button_theme(btn)
		if marked_now:
			btn.text = tr("UI_WAREHOUSE_LOADOUT_REMOVE")
			btn.pressed.connect(_on_loadout_toggle.bind(stash_entry))
		elif marked >= cap:
			btn.text = tr("UI_WAREHOUSE_LOADOUT_ADD")
			btn.disabled = true
		else:
			btn.text = tr("UI_WAREHOUSE_LOADOUT_ADD")
			btn.pressed.connect(_on_loadout_toggle.bind(stash_entry))
		row.add_child(btn)

		container.add_child(row)


func _on_loadout_toggle(stash_entry: Variant) -> void:
	var idx := _pending_index_of(stash_entry)
	if idx >= 0:
		RunManager.pending_loadout.remove_at(idx)
	else:
		if RunManager.pending_loadout.size() >= _loadout_cap():
			return
		RunManager.pending_loadout.append(stash_entry)
	_refresh()


## Index of `stash_entry` inside pending_loadout (by value), or -1 if not marked.
func _pending_index_of(stash_entry: Variant) -> int:
	return RunManager.pending_loadout.find(stash_entry)


## Sane cap: never queue more gear than the backpack can hold at run start.
func _loadout_cap() -> int:
	return RunManager.MAX_INVENTORY


# --- T2: more slots --------------------------------------------------------


func _build_more_slots(container: VBoxContainer) -> void:
	container.add_child(_function_header(tr("UI_WAREHOUSE_SLOTS_TITLE"), "more_slots"))
	if not MetaProgress.building_can("warehouse", "more_slots"):
		container.add_child(_locked_note("more_slots"))
		return

	# STASH_CAP is a const and there is no persistent warehouse_slot_bonus field, so
	# the upgrade cannot actually raise capacity yet. Show the current cap and a
	# clear note (see REPORT). The row is intentionally non-functional rather than
	# silently spending Core for no effect.
	var cap_lbl := Label.new()
	cap_lbl.text = tr("UI_WAREHOUSE_SLOTS_CAP").format({"cap": MetaProgress.STASH_CAP})
	_style_label(cap_lbl, 18, Color(0.88, 0.82, 0.62), 1)
	container.add_child(cap_lbl)

	var note := Label.new()
	note.text = tr("UI_WAREHOUSE_SLOTS_TODO")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(note, 16, Color(0.82, 0.62, 0.40), 1)
	container.add_child(note)


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


func _hero_locked(hero_id: String) -> bool:
	return hero_id == LOCKED_HERO_ID and MetaProgress.get_upgrade_level("jerry_unlock") <= 0


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

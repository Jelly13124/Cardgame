## Forge building screen 铁匠铺. Subclasses the shared building screen shell and
## overrides `_build_content()` to render Scrap-spending services over the
## permanent stash, gated by the Forge building tier via
## `MetaProgress.building_can("forge", fn)`:
##   - T1 dismantle — list each stash item with a Dismantle button.
##   - T2 reforge   — per-item Reforge (N Scrap) button (reroll one affix).
##   - T2 craft     — pick slot + rarity, spend Scrap, mint a new stash item.
##   - T3 curse     — per-item Curse (100 Scrap) button (reroll to cursed).
##
## NO class_name (ADR-0006). Loaded by path. Content is rebuilt on
## `scrap_changed` + `buildings_changed` (the base already wires those signals to
## its own `_refresh`, but `_refresh` only repaints the tier badge / action
## button — it does NOT re-run `_build_content`, so we rebuild the body here).
extends "res://run_system/ui/buildings/building_screen_base.gd"

## Affix roller for describe()/is_curse()/roll() (no class_name — preload per ADR-0006).
const AFFIX_POOL = preload("res://run_system/core/affix_pool.gd")
## Stash grid cell + icon (shared with the warehouse loadout board).
const EQUIPMENT_ICON := preload("res://run_system/ui/equipment_icon.gd")
const BACKPACK_CELL := preload("res://run_system/ui/backpack_cell.gd")
const CELL_SIZE := Vector2(74, 74)
const STASH_COLUMNS := 4

## Scrap cost to craft a fresh item, by target rarity (spec: 40/80/140).
const CRAFT_COST := {"common": 40, "uncommon": 80, "rare": 140}
## Scrap cost to curse an item. The actual spend is owned by the backend
## (MetaProgress.curse_stash_item / MetaProgress.CURSE_SCRAP_COST); this mirrors it
## for the button label + gating. (Autoload consts can't seed a GDScript const, so
## this is kept as a literal and must match MetaProgress.CURSE_SCRAP_COST.)
const CURSE_COST := 100
## Slot → a representative base equipment item_id used when crafting that slot.
## (Scanned from run_system/data/equipment/*.json; one base per slot.)
const CRAFT_BASE_BY_SLOT := {
	"head": "warden_helm",
	"chest": "warden_vest",
	"weapon": "warden_axe",
	"hands": "warden_gloves",
	"accessory": "warden_pendant",
}
const CRAFT_SLOTS := ["head", "chest", "weapon", "hands", "accessory"]
const CRAFT_RARITIES := ["common", "uncommon", "rare"]

## The container the base hands us in `_build_content`; cached so we can rebuild
## the body on currency / building changes without re-running `_build`.
var _body: VBoxContainer
## Craft picker state (which slot / rarity the player has selected).
var _craft_slot: String = "head"
var _craft_rarity: String = "common"
## Index into MetaProgress.stash of the item currently on the workbench (-1 = none).
var _selected_index: int = -1


func _build_content(container: VBoxContainer) -> void:
	_body = container
	# The base connects scrap_changed / buildings_changed to its `_refresh`
	# (badge + action button only). We add our own listeners to rebuild the body.
	MetaProgress.scrap_changed.connect(func(_v): _rebuild_body())
	MetaProgress.buildings_changed.connect(_rebuild_body)
	_rebuild_body()


## Rebuild the whole content body from the current building tier + stash state.
## Layout: scrap balance → two-column workbench (LEFT stash grid | RIGHT drop slot
## + the selected item's affixes & dismantle/reforge actions) → craft control.
func _rebuild_body() -> void:
	if not is_instance_valid(_body):
		return
	for child in _body.get_children():
		child.queue_free()

	# Drop a stale selection (e.g. the item was dismantled out from under it).
	if _selected_index >= MetaProgress.stash.size():
		_selected_index = -1

	# Current Scrap balance.
	var scrap_lbl := Label.new()
	scrap_lbl.text = tr("UI_FORGE_SCRAP").format({"n": int(MetaProgress.scrap)})
	_style_label(scrap_lbl, 22, Color(0.78, 0.86, 0.62), 2)
	_body.add_child(scrap_lbl)

	var can_dismantle := MetaProgress.building_can("forge", "dismantle")
	var can_reforge := MetaProgress.building_can("forge", "reforge")
	var can_craft := MetaProgress.building_can("forge", "craft")
	var can_curse := MetaProgress.building_can("forge", "curse")

	var hint := Label.new()
	hint.text = tr("UI_FORGE_WORKBENCH_HINT")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(hint, 16, Color(0.80, 0.74, 0.58), 1)
	_body.add_child(hint)

	# --- Two-column workbench: LEFT stash | RIGHT drop slot + actions ---
	var board := HBoxContainer.new()
	board.add_theme_constant_override("separation", 28)
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(board)
	board.add_child(_build_stash_column())
	board.add_child(VSeparator.new())
	board.add_child(_build_workbench_column(can_dismantle, can_reforge, can_curse))

	# --- Craft control (T2): mint a fresh item; independent of the workbench ---
	_body.add_child(HSeparator.new())
	if can_craft:
		_body.add_child(_build_craft_control())
	else:
		_body.add_child(_locked_hint(tr("UI_FORGE_CRAFT_LOCKED")))


# --- LEFT column: the stash as a draggable / clickable grid -----------------


func _build_stash_column() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(360, 0)

	var title := Label.new()
	title.text = tr("UI_FORGE_STASH_TITLE").format({"n": MetaProgress.stash.size()})
	_style_label(title, 20, accent, 2)
	col.add_child(title)

	if MetaProgress.stash.is_empty():
		var empty := Label.new()
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.text = tr("UI_FORGE_EMPTY")
		_style_label(empty, 18, Color(0.72, 0.66, 0.52), 1)
		col.add_child(empty)
		return col

	var grid := GridContainer.new()
	grid.columns = STASH_COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	for i in range(MetaProgress.stash.size()):
		grid.add_child(_build_forge_stash_cell(i))
	return col


## One stash cell: a draggable BackpackCell (EquipmentIcon child) that drops onto the
## workbench slot to select it; left-click also selects it. The selected item gets a
## gold outline.
func _build_forge_stash_cell(index: int) -> Control:
	var inst := RunManager.as_equip_instance(MetaProgress.stash[index])
	var base_id := str(inst.get("base", ""))
	var data: Dictionary = RunManager.get_equipment_data(base_id)
	var slot := str(data.get("slot", "head"))
	var rarity := str(inst.get("rarity", "common"))
	var item_name := Settings.t("EQUIP_%s_NAME" % base_id, str(data.get("name", base_id)))

	var cell := BACKPACK_CELL.new()
	cell.custom_minimum_size = CELL_SIZE
	cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var icon := EQUIPMENT_ICON.new()
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


# --- RIGHT column: the workbench (drop slot + selected-item actions) --------


func _build_workbench_column(can_dismantle: bool, can_reforge: bool, can_curse: bool) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = tr("UI_FORGE_BENCH_TITLE")
	_style_label(title, 20, accent, 2)
	col.add_child(title)

	var sel_inst: Dictionary = {}
	if _selected_index >= 0 and _selected_index < MetaProgress.stash.size():
		sel_inst = RunManager.as_equip_instance(MetaProgress.stash[_selected_index])

	# The drop slot (also shows the selected item's icon).
	var slot_holder := CenterContainer.new()
	var slot_cell := BACKPACK_CELL.new()
	slot_cell.custom_minimum_size = Vector2(104, 104)
	var slot_icon := EQUIPMENT_ICON.new()
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
	slot_cell.can_accept = func(d): return d.get("src") == "forge_stash"
	slot_cell.perform_drop = func(d): _select_item(int(d.get("index", -1)))
	slot_holder.add_child(slot_cell)
	col.add_child(slot_holder)

	if sel_inst.is_empty():
		var bench_hint := Label.new()
		bench_hint.text = tr("UI_FORGE_BENCH_EMPTY")
		bench_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bench_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_label(bench_hint, 17, Color(0.72, 0.66, 0.52), 1)
		col.add_child(bench_hint)
		if not can_reforge:
			col.add_child(_locked_hint(tr("UI_FORGE_REFORGE_LOCKED")))
		return col

	# Selected item: name + rarity.
	var base_id := str(sel_inst.get("base", ""))
	var rarity := str(sel_inst.get("rarity", "common"))
	var cursed := bool(sel_inst.get("cursed", false))
	var data: Dictionary = RunManager.get_equipment_data(base_id)
	var item_name := Settings.t("EQUIP_%s_NAME" % base_id, str(data.get("name", base_id)))
	var name_lbl := Label.new()
	name_lbl.text = "%s [%s]" % [item_name, rarity.capitalize()]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(name_lbl, 19, Color(1, 0.92, 0.55), 1)
	col.add_child(name_lbl)

	# Affix list — each affix on its own row with a per-affix reforge button (T2).
	var reforge_cost := int(
		MetaProgress.REFORGE_COST.get(rarity, MetaProgress.REFORGE_COST["common"])
	)
	var affixes := RunManager.equip_affixes(sel_inst)
	if affixes.is_empty():
		var none := Label.new()
		none.text = "—"
		_style_label(none, 16, Color(0.7, 0.7, 0.68), 1)
		col.add_child(none)
	else:
		for ai in range(affixes.size()):
			col.add_child(_build_affix_row(affixes[ai], ai, reforge_cost, can_reforge))

	col.add_child(HSeparator.new())

	# Dismantle (T1) + Curse (T3).
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	col.add_child(btn_row)
	if can_dismantle:
		var dismantle_scrap := int(
			MetaProgress.DISMANTLE_SCRAP.get(rarity, MetaProgress.DISMANTLE_SCRAP["common"])
		)
		if cursed:
			dismantle_scrap += 5
		var dismantle_btn := Button.new()
		dismantle_btn.text = tr("UI_FORGE_DISMANTLE").format({"n": dismantle_scrap})
		dismantle_btn.custom_minimum_size = Vector2(150, 38)
		T.apply_button_theme(dismantle_btn)
		dismantle_btn.pressed.connect(_dismantle_selected)
		btn_row.add_child(dismantle_btn)
	if can_curse:
		var curse_btn := Button.new()
		curse_btn.text = tr("UI_FORGE_CURSE").format({"n": CURSE_COST})
		curse_btn.custom_minimum_size = Vector2(160, 38)
		T.apply_button_theme(curse_btn)
		curse_btn.add_theme_color_override("font_disabled_color", Color(0.72, 0.64, 0.50, 0.92))
		curse_btn.disabled = int(MetaProgress.scrap) < CURSE_COST or cursed
		curse_btn.pressed.connect(func() -> void: _curse_item(_selected_index))
		btn_row.add_child(curse_btn)
	if not can_reforge:
		col.add_child(_locked_hint(tr("UI_FORGE_REFORGE_LOCKED")))
	if not can_curse:
		col.add_child(_locked_hint(tr("UI_FORGE_CURSE_LOCKED")))
	return col


## One affix line on the workbench: the affix text + (T2) a button that rerolls just
## this affix. Curses are shown red and cannot be reforged.
func _build_affix_row(
	affix_v: Variant, affix_index: int, reforge_cost: int, can_reforge: bool
) -> Control:
	var a := affix_v as Dictionary
	var is_curse := AFFIX_POOL.is_curse(a)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lbl := Label.new()
	lbl.text = AFFIX_POOL.describe(a)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(lbl, 17, Color(1.0, 0.42, 0.42) if is_curse else Color(0.7, 0.92, 0.7), 1)
	row.add_child(lbl)

	if can_reforge and not is_curse:
		var rb := Button.new()
		rb.text = tr("UI_FORGE_REFORGE_ONE").format({"n": reforge_cost})
		rb.custom_minimum_size = Vector2(150, 34)
		rb.add_theme_font_size_override("font_size", 16)
		T.apply_button_theme(rb)
		rb.add_theme_color_override("font_disabled_color", Color(0.72, 0.64, 0.50, 0.92))
		rb.disabled = int(MetaProgress.scrap) < reforge_cost
		var ai := affix_index
		rb.pressed.connect(func() -> void: _reforge_affix(ai))
		row.add_child(rb)
	return row


# --- workbench actions ------------------------------------------------------


## Put a stash item on the workbench (from a drag-drop or a click).
func _select_item(index: int) -> void:
	if index < 0 or index >= MetaProgress.stash.size():
		return
	_selected_index = index
	AudioManager.play_sfx("ui_click")
	_rebuild_body()


## Dismantle the workbench item, then clear the bench (its index is now stale).
func _dismantle_selected() -> void:
	if _selected_index < 0 or _selected_index >= MetaProgress.stash.size():
		return
	if MetaProgress.dismantle_stash_item(_selected_index):
		_selected_index = -1
	_rebuild_body()


## Reforge just affix `affix_index` of the workbench item (keeps it selected so the
## new roll shows immediately).
func _reforge_affix(affix_index: int) -> void:
	if _selected_index < 0:
		return
	MetaProgress.reforge_stash_item_affix(_selected_index, affix_index)
	_rebuild_body()


## Load an equipment sprite texture for the drag preview (mirrors warehouse_screen).
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


## Craft picker (T2): two option buttons (slot + rarity) and a Craft button whose
## label shows the current target's Scrap cost.
func _build_craft_control() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = tr("UI_FORGE_CRAFT_TITLE")
	_style_label(title, 20, Color(1, 0.92, 0.55), 2)
	box.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)

	var slot_lbl := Label.new()
	slot_lbl.text = tr("UI_FORGE_SLOT")
	_style_label(slot_lbl, 16, Color(0.86, 0.86, 0.8), 1)
	row.add_child(slot_lbl)

	var slot_opt := OptionButton.new()
	slot_opt.custom_minimum_size = Vector2(160, 36)
	for s in CRAFT_SLOTS:
		slot_opt.add_item(tr("UI_FORGE_SLOT_%s" % s.to_upper()))
	slot_opt.selected = CRAFT_SLOTS.find(_craft_slot)
	slot_opt.item_selected.connect(
		func(idx: int) -> void:
			_craft_slot = str(CRAFT_SLOTS[idx])
			_rebuild_body()
	)
	row.add_child(slot_opt)

	var rarity_lbl := Label.new()
	rarity_lbl.text = tr("UI_FORGE_RARITY")
	_style_label(rarity_lbl, 16, Color(0.86, 0.86, 0.8), 1)
	row.add_child(rarity_lbl)

	var rarity_opt := OptionButton.new()
	rarity_opt.custom_minimum_size = Vector2(160, 36)
	for r in CRAFT_RARITIES:
		rarity_opt.add_item(tr("UI_FORGE_RARITY_%s" % r.to_upper()))
	rarity_opt.selected = CRAFT_RARITIES.find(_craft_rarity)
	rarity_opt.item_selected.connect(
		func(idx: int) -> void:
			_craft_rarity = str(CRAFT_RARITIES[idx])
			_rebuild_body()
	)
	row.add_child(rarity_opt)

	var cost := int(CRAFT_COST.get(_craft_rarity, CRAFT_COST["common"]))
	var craft_btn := Button.new()
	craft_btn.text = tr("UI_FORGE_CRAFT").format({"n": cost})
	craft_btn.custom_minimum_size = Vector2(170, 36)
	T.apply_button_theme(craft_btn)
	craft_btn.add_theme_color_override("font_disabled_color", Color(0.72, 0.64, 0.50, 0.92))
	craft_btn.disabled = int(MetaProgress.scrap) < cost
	craft_btn.pressed.connect(_on_craft_pressed)
	row.add_child(craft_btn)

	return box


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
	# add_to_stash saves but emits no signal; spend_scrap already emitted
	# scrap_changed → _rebuild_body picks the new item up. Rebuild explicitly too
	# in case scrap was unchanged for any reason.
	_rebuild_body()


## Curse a stash item in place (T3) via the backend. MetaProgress.curse_stash_item
## handles the CURSE_SCRAP_COST spend, the cursed re-roll, the cursed flag, the save,
## and emits scrap_changed (→ _rebuild_body). Rebuild explicitly too in case the
## scrap math no-ops, so the new cursed affixes show immediately.
func _curse_item(index: int) -> void:
	if not MetaProgress.curse_stash_item(index):
		return
	_rebuild_body()


## A dim italic-ish lock hint line for a function above the current tier.
func _locked_hint(text: String) -> Control:
	var lbl := Label.new()
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.text = text
	_style_label(lbl, 16, Color(0.66, 0.62, 0.54), 1)
	return lbl

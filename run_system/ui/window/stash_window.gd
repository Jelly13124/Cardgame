## StashWindow — the permanent gear stash (MetaProgress.stash) as its own
## floating DraggableWindow. D4 container model: the stash is PURE STORAGE —
## nothing is equipped from here. To use an item the player drags it into the
## base-mode CharacterWindow's backpack (→ RunManager.pending_loadout); to store
## an item they drag a backpack cell (or a queued slot item) back onto this
## window.
##   GRID   8 columns of the stash entries NOT currently assigned to the next
##          run (pending_equipped / pending_loadout consume entries by VALUE —
##          the same match start_new_run's remove_from_stash uses), padded with
##          empty frames up to the full capacity.
##   DRAG   cells drag OUT as {"src": "stash", "slot", "entry"} — the same
##          payload the old base-mode stash grid used, so the ForgeWindow bench
##          (and the CharacterWindow backpack area) accept it unchanged.
##   DROP   the whole window accepts {"src": "carry"} (backpack → store) and
##          {"src": "slot"} (queued slot → unassign, back to storage).
## Cross-window sync: after a drop, both this window and the sibling
## CharacterWindow rebuild via their public refresh(). Base-context only (no
## map/battle callers). NO class_name (ADR-0006) — loaded by path.
extends "res://run_system/ui/window/draggable_window.gd"

const EQUIPMENT_ICON = preload("res://run_system/ui/equipment_icon.gd")
const BACKPACK_CELL = preload("res://run_system/ui/backpack_cell.gd")
const AFFIX_POOL = preload("res://run_system/core/affix_pool.gd")

const WIN_SIZE := Vector2(560, 620)
const GRID_COLUMNS := 8
const GRID_CELL_SIZE := Vector2(56, 56)
const SLOT_LETTERS := {"head": "H", "chest": "C", "weapon": "W", "hands": "Hd", "accessory": "Ac"}

## Body VBox, rebuilt wholesale on every refresh.
var _body: VBoxContainer


## Toggle-open the stash window on `host`'s WindowLayer: if one is already open,
## close it and return null; otherwise create, open and return it. When the
## base-mode CharacterWindow is open the stash docks BESIDE it (left if there is
## room, else right) for the D4 dual-window drag flow.
static func open_window(host: Node) -> Control:
	var wl = load("res://run_system/ui/window/window_layer.gd").ensure(host)
	var existing = wl.get_node_or_null("StashWindow")
	if existing and not existing.is_queued_for_deletion():
		existing.close()
		return null
	var win = load("res://run_system/ui/window/stash_window.gd").new()
	win.name = "StashWindow"
	wl.open(win)
	var cw = wl.get_node_or_null("CharacterWindow")
	if cw and not cw.is_queued_for_deletion():
		var vp: Vector2 = win.get_viewport_rect().size
		var x: float = cw.position.x - win.size.x - 16.0
		if x < 8.0:
			x = minf(cw.position.x + cw.size.x + 16.0, vp.x - win.size.x - 8.0)
		win.position = Vector2(maxf(x, 8.0), cw.position.y)
	return win


func _ready() -> void:
	init_window(tr("UI_STASH_WINDOW_TITLE"), WIN_SIZE)
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	content_root.add_child(margin)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	margin.add_child(_body)
	# No dedicated stash_changed signal exists — forge mutations (dismantle /
	# reforge / curse) surface through scrap_changed, building unlocks through
	# buildings_changed. Guarded connects; queue_free on close drops them.
	if not MetaProgress.buildings_changed.is_connected(refresh):
		MetaProgress.buildings_changed.connect(refresh)
	if not MetaProgress.scrap_changed.is_connected(_on_scrap_changed):
		MetaProgress.scrap_changed.connect(_on_scrap_changed)
	refresh()


func _on_scrap_changed(_v: int) -> void:
	refresh()


## Public rebuild entry — the CharacterWindow calls this after a cross-window
## drop so both sides stay in sync (and vice versa).
func refresh() -> void:
	if not is_instance_valid(_body):
		return
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()

	var available := _available_stash_indices()
	var cap := MetaProgress.effective_stash_cap()
	var head := Label.new()
	head.text = tr("UI_EQUIP_STASH_HEADER").format({"n": available.size(), "cap": cap})
	head.add_theme_font_size_override("font_size", 14)
	head.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	_body.add_child(head)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	for i in available:
		grid.add_child(_make_stash_cell(i))
	# Render the FULL capacity (filled cells first, then empty frames) so vacant
	# space reads as storage slots — and stays a live drop target.
	for _e in range(maxi(0, cap - available.size())):
		grid.add_child(_make_empty_cell())

	var hint := Label.new()
	hint.text = tr("UI_EQUIP_D4_HINT")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.65, 0.6, 0.5))
	_body.add_child(hint)


## Window-body drop target: store a backpack (carry) entry or unassign a queued
## slot item. Cells forward to the same handler, so the whole window is one big
## storage target.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var src := str(data.get("src", ""))
	return src == "carry" or src == "slot"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if typeof(data) == TYPE_DICTIONARY:
		_handle_drop(data)


func _handle_drop(data: Dictionary) -> void:
	match str(data.get("src", "")):
		"carry":
			_store_from_carry(data.get("entry"))
		"slot":
			_unassign_slot(str(data.get("slot", "")))


## Backpack → stash: remove one value-matched entry from pending_loadout. The
## entry never left MetaProgress.stash (pending_* only reference it), so
## dropping the reference alone puts it back in this grid.
func _store_from_carry(entry: Variant) -> void:
	if entry == null:
		return
	var idx: int = RunManager.pending_loadout.find(entry)
	if idx < 0:
		return  # stale drag — already gone
	RunManager.pending_loadout.remove_at(idx)
	AudioManager.play_sfx("ui_back")
	refresh()
	_refresh_sibling_character()


## Queued slot → stash: clear the pending_equipped reference; the entry
## reappears in this grid.
func _unassign_slot(slot: String) -> void:
	if not RunManager.pending_equipped.has(slot):
		return
	RunManager.pending_equipped.erase(slot)
	AudioManager.play_sfx("ui_back")
	refresh()
	_refresh_sibling_character()


## Rebuild the sibling base-mode CharacterWindow (if open) after a cross-window move.
func _refresh_sibling_character() -> void:
	var wl := get_parent()
	if wl == null:
		return
	var cw = wl.get_node_or_null("CharacterWindow")
	if cw and not cw.is_queued_for_deletion() and cw.has_method("refresh"):
		cw.refresh()


## Indices into MetaProgress.stash of entries NOT currently assigned to the next
## run — an entry referenced by pending_equipped (worn at start) or
## pending_loadout (carried in the backpack) is hidden here so it cannot be
## taken twice. Matches by VALUE, consuming one assignment per stash entry
## (handles duplicate gear). Mirrors character_window._unassigned_stash_pool.
func _available_stash_indices() -> Array[int]:
	var assigned: Array = RunManager.pending_equipped.values() + RunManager.pending_loadout
	var taken: Array[int] = []  # assignment indices already consumed by a stash entry
	var out: Array[int] = []
	for i in range(MetaProgress.stash.size()):
		var entry: Variant = MetaProgress.stash[i]
		if RunManager.as_equip_instance(entry).is_empty():
			continue
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


## One stash cell: gear icon + tooltip. Drag OUT to the CharacterWindow backpack
## (carry it) or the ForgeWindow bench; also a drop target for storing.
func _make_stash_cell(stash_index: int) -> Control:
	var entry: Variant = MetaProgress.stash[stash_index]
	var inst: Dictionary = RunManager.as_equip_instance(entry)
	var base_id: String = RunManager.equip_base(inst)
	var data: Dictionary = RunManager.get_equipment_data(base_id)
	var slot := str(data.get("slot", "head"))
	var item_name := Settings.t("EQUIP_%s_NAME" % base_id, str(data.get("name", base_id)))

	var cell = BACKPACK_CELL.new()
	cell.custom_minimum_size = GRID_CELL_SIZE
	cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var icon = EQUIPMENT_ICON.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_equipment(
		slot, item_name, str(data.get("sprite", "")), str(data.get("rarity", "common"))
	)
	cell.add_child(icon)

	cell.hover_tip = _equipment_tooltip(data, slot, inst)
	# The payload carries the actual stash entry (forge + character window both
	# resolve it back by value).
	cell.drag_payload = {"src": "stash", "slot": slot, "entry": entry}
	cell.preview_text = str(SLOT_LETTERS.get(slot, "?"))
	cell.preview_color = Color(1.0, 0.86, 0.4)
	cell.preview_tex = _load_equip_tex(str(data.get("sprite", "")))
	_wire_store_drop(cell)
	return cell


## A recessed empty storage frame — still a live drop target.
func _make_empty_cell() -> Control:
	var cell = BACKPACK_CELL.new()
	cell.custom_minimum_size = GRID_CELL_SIZE
	var blank := Panel.new()
	blank.set_anchors_preset(Control.PRESET_FULL_RECT)
	blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.05, 0.55)
	style.border_color = Color(0.34, 0.28, 0.20, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	blank.add_theme_stylebox_override("panel", style)
	cell.add_child(blank)
	_wire_store_drop(cell)
	return cell


func _wire_store_drop(cell) -> void:
	cell.can_accept = func(data):
		var src := str(data.get("src", ""))
		return src == "carry" or src == "slot"
	cell.perform_drop = func(data): _handle_drop(data)


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


## Rich equipment tooltip (duplicated from character_window — a shared helper
## would need a preload back-reference; forge_window sets the same precedent).
func _equipment_tooltip(data: Dictionary, slot: String, instance: Dictionary) -> String:
	var item_id := str(data.get("id", ""))
	var name_str := Settings.t("EQUIP_%s_NAME" % item_id, str(data.get("name", "?")))
	var rarity := str(instance.get("rarity", data.get("rarity", "common")))
	var rarity_str := Settings.t("UI_FORGE_RARITY_%s" % rarity.to_upper(), rarity)
	var desc := Settings.t("EQUIP_%s_DESC" % item_id, str(data.get("description", "")))
	var set_id := str(instance.get("set_id", data.get("set_id", "")))

	var lines: Array = []
	lines.append("[b]%s[/b]" % name_str)
	lines.append("[i]%s · %s[/i]" % [_slot_label(slot), rarity_str])
	lines.append("")
	var affixes: Array = RunManager.equip_affixes(instance) if not instance.is_empty() else []
	if affixes.is_empty():
		var bonuses = data.get("bonuses", {})
		if typeof(bonuses) == TYPE_DICTIONARY and not bonuses.is_empty():
			var parts: Array = []
			for attr in bonuses.keys():
				parts.append("+%d %s" % [int(bonuses[attr]), str(attr).substr(0, 3)])
			lines.append(", ".join(parts))
		else:
			lines.append(tr("UI_EQUIP_NO_BONUSES"))
	else:
		for affix in affixes:
			var label := AFFIX_POOL.describe(affix as Dictionary)
			if AFFIX_POOL.is_curse(affix as Dictionary):
				lines.append("[color=#e0584c]%s[/color]" % label)
			else:
				lines.append("[color=#5fd06a]%s[/color]" % label)
	if set_id != "":
		var equipment_set_name := Settings.t("EQUIP_SET_%s_NAME" % set_id, set_id.replace("_", " "))
		lines.append("[i]%s[/i]" % tr("UI_EQUIP_SET_PREFIX").format({"name": equipment_set_name}))
	if desc != "":
		lines.append("")
		lines.append(desc)
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

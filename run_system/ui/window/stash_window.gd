## StashWindow — the permanent gear stash (MetaProgress.stash) as its own
## floating DraggableWindow. D4 container model: the stash is PURE STORAGE —
## nothing is equipped from here. To use an item the player drags it into the
## base-mode CharacterWindow's backpack (→ RunManager.pending_loadout); to store
## an item they drag a backpack cell (or a queued slot item) back onto this
## window.
##   GRID   5 columns / 25 cells of the stash entries NOT currently assigned to the next
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
const STASH_OUTER_FRAME_TEX = preload("res://run_system/assets/images/ui/window_frames_v2/character_outer_frame.png")

const WIN_SIZE := Vector2(860, 980)
const GRID_COLUMNS := 5
const STASH_PAGE_CELLS := 25
const GRID_CELL_SIZE := Vector2(124, 124)
const SLOT_LETTERS := {"head": "H", "chest": "C", "weapon": "W", "hands": "Hd", "accessory": "Ac"}
const SORT_DEFAULT := 0
const SORT_RARITY := 1
const SORT_SLOT := 2
const SORT_NAME := 3
const ORGANIZE_SORT_MODE := SORT_RARITY
const RARITY_RANK := {"rare": 0, "uncommon": 1, "common": 2}
const SLOT_RANK := {"weapon": 0, "head": 1, "chest": 2, "hands": 3, "accessory": 4}

## Body VBox, rebuilt wholesale on every refresh.
var _body: VBoxContainer
var _sort_mode := SORT_DEFAULT
var _stash_page := 0


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
		var gap := 16.0
		var pair_w: float = win.size.x + gap + cw.size.x
		var left := maxf(8.0, (vp.x - pair_w) * 0.5)
		var right := minf(left + win.size.x + gap, vp.x - cw.size.x - 8.0)
		win.position = Vector2(left, cw.position.y)
		cw.position = Vector2(maxf(right, 8.0), cw.position.y)
	return win


func _ready() -> void:
	init_window(tr("UI_STASH_WINDOW_TITLE"), WIN_SIZE, false)
	add_theme_stylebox_override("panel", _stash_window_style())
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	content_root.add_child(margin)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
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
	var display_cells := maxi(cap, available.size())
	var page_count := maxi(1, int(ceil(float(display_cells) / float(STASH_PAGE_CELLS))))
	_stash_page = clampi(_stash_page, 0, page_count - 1)
	var page_start := _stash_page * STASH_PAGE_CELLS

	_body.add_child(_build_stash_title_plaque())
	_body.add_child(_build_stash_top_bar())

	var grid_row := HBoxContainer.new()
	grid_row.name = "StashPageRow"
	grid_row.alignment = BoxContainer.ALIGNMENT_CENTER
	grid_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_row.add_theme_constant_override("separation", 12)
	_body.add_child(grid_row)

	var prev := _make_page_button("‹", -1, Vector2(40, 180))
	prev.name = "StashPrevPageButton"
	prev.disabled = _stash_page <= 0
	grid_row.add_child(prev)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_row.add_child(center)
	var grid := GridContainer.new()
	grid.name = "StashGrid"
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	center.add_child(grid)
	for offset in range(STASH_PAGE_CELLS):
		var absolute_index := page_start + offset
		if absolute_index < available.size():
			grid.add_child(_make_stash_cell(available[absolute_index]))
		else:
			grid.add_child(_make_empty_cell())

	var next := _make_page_button("›", 1, Vector2(40, 180))
	next.name = "StashNextPageButton"
	next.disabled = _stash_page >= page_count - 1
	grid_row.add_child(next)

	_body.add_child(T.ui_divider())
	_body.add_child(_make_back_button())


func _build_stash_title_plaque() -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(0, 82)
	var plaque := PanelContainer.new()
	plaque.custom_minimum_size = Vector2(520, 78)
	plaque.add_theme_stylebox_override(
		"panel", T.concept_box("title_plaque", _stash_red_button_style("normal"), 52, 30, 16)
	)
	bind_drag_area(plaque)
	holder.add_child(plaque)
	var label := Label.new()
	label.text = tr("UI_STASH_WINDOW_TITLE")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", T.display_font(700))
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.58, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.025, 0.01, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	plaque.add_child(label)
	return holder


func _build_stash_top_bar() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 68)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 14)

	var sort := OptionButton.new()
	sort.name = "StashSortOption"
	sort.custom_minimum_size = Vector2(250, 54)
	sort.add_item(tr("UI_STASH_SORT_DEFAULT"), SORT_DEFAULT)
	sort.add_item(tr("UI_STASH_SORT_RARITY"), SORT_RARITY)
	sort.add_item(tr("UI_STASH_SORT_SLOT"), SORT_SLOT)
	sort.add_item(tr("UI_STASH_SORT_NAME"), SORT_NAME)
	sort.select(_sort_mode)
	_style_stash_button(sort)
	sort.item_selected.connect(_on_sort_selected)
	header.add_child(sort)

	var organize := Button.new()
	organize.name = "StashAutoOrganizeButton"
	organize.text = tr("UI_STASH_AUTO_ORGANIZE")
	organize.custom_minimum_size = Vector2(250, 54)
	_style_stash_button(organize, true)
	organize.pressed.connect(_auto_organize_stash)
	header.add_child(organize)
	return header


func _make_page_button(text: String, delta: int, min_size: Vector2 = Vector2(54, 54)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 28)
	_style_stash_button(b)
	b.pressed.connect(_change_page.bind(delta))
	return b


func _make_back_button() -> Button:
	var b := Button.new()
	b.name = "StashBackButton"
	b.text = tr("PAUSE_BACK")
	b.custom_minimum_size = Vector2(0, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_stash_button(b, true)
	b.pressed.connect(close)
	return b


func _stash_window_style() -> StyleBox:
	var style := StyleBoxTexture.new()
	style.texture = STASH_OUTER_FRAME_TEX
	style.texture_margin_left = 72
	style.texture_margin_right = 72
	style.texture_margin_top = 72
	style.texture_margin_bottom = 72
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


func _stash_slot_style() -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.038, 0.036, 0.032, 0.96)
	style.border_color = Color(0.39, 0.27, 0.14, 0.98)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _stash_red_button_style(state: String) -> StyleBox:
	var fb := T.ui_button_accent(state)
	return T.concept_box("button_red_wide_%s" % state, fb, 34, 24, 12)


func _stash_dark_button_style(state: String) -> StyleBox:
	var fb := T.ui_button_brass(state)
	return T.concept_box("button_dark_%s" % state, fb, 30, 24, 10)


func _stash_dropdown_style(_state: String) -> StyleBox:
	return T.concept_box("dropdown_frame", T.ui_button_brass("normal"), 30, 22, 10)


func _style_stash_button(button: Button, accent: bool = false) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if accent:
		button.add_theme_stylebox_override("normal", _stash_red_button_style("normal"))
		button.add_theme_stylebox_override("hover", _stash_red_button_style("hover"))
		button.add_theme_stylebox_override("pressed", _stash_red_button_style("pressed"))
		button.add_theme_color_override("font_color", T.UI_HEADER_GOLD)
		button.add_theme_color_override("font_hover_color", T.UI_BRASS_LIGHT)
		button.add_theme_color_override("font_pressed_color", T.UI_HEADER_GOLD)
	else:
		var normal := _stash_dropdown_style("normal") if button is OptionButton else _stash_dark_button_style("normal")
		var hover := _stash_dropdown_style("hover") if button is OptionButton else _stash_dark_button_style("hover")
		var pressed := _stash_dropdown_style("pressed") if button is OptionButton else _stash_dark_button_style("pressed")
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", pressed)
		button.add_theme_color_override("font_color", T.UI_BRASS_LIGHT)
		button.add_theme_color_override("font_hover_color", T.UI_HEADER_GOLD)
		button.add_theme_color_override("font_pressed_color", T.UI_HEADER_GOLD)


func _on_sort_selected(index: int) -> void:
	_sort_mode = index
	_stash_page = 0
	AudioManager.play_sfx("ui_click")
	refresh()


func _auto_organize_stash() -> void:
	MetaProgress.stash.sort_custom(
		func(a, b): return _entry_sort_less(a, b, ORGANIZE_SORT_MODE)
	)
	_sort_mode = SORT_DEFAULT
	_stash_page = 0
	MetaProgress.save_progress()
	AudioManager.play_sfx("ui_click")
	refresh()
	_refresh_sibling_character()


func _change_page(delta: int) -> void:
	_stash_page = maxi(0, _stash_page + delta)
	AudioManager.play_sfx("ui_click")
	refresh()


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
	_apply_view_sort(out)
	return out


func _apply_view_sort(indices: Array[int]) -> void:
	if _sort_mode == SORT_DEFAULT or indices.size() <= 1:
		return
	indices.sort_custom(
		func(a, b): return _entry_sort_less(MetaProgress.stash[int(a)], MetaProgress.stash[int(b)], _sort_mode)
	)


func _entry_sort_less(a: Variant, b: Variant, mode: int) -> bool:
	var ka := _entry_sort_key(a, mode)
	var kb := _entry_sort_key(b, mode)
	for i in range(mini(ka.size(), kb.size())):
		if ka[i] == kb[i]:
			continue
		if typeof(ka[i]) == TYPE_INT and typeof(kb[i]) == TYPE_INT:
			return int(ka[i]) < int(kb[i])
		return str(ka[i]) < str(kb[i])
	return ka.size() < kb.size()


func _entry_sort_key(entry: Variant, mode: int) -> Array:
	var inst: Dictionary = RunManager.as_equip_instance(entry)
	var base_id: String = RunManager.equip_base(inst)
	var data: Dictionary = RunManager.get_equipment_data(base_id)
	var slot := str(data.get("slot", ""))
	var rarity := str(inst.get("rarity", data.get("rarity", "common")))
	var name := Settings.t("EQUIP_%s_NAME" % base_id, str(data.get("name", base_id))).to_lower()
	match mode:
		SORT_RARITY:
			return [
				int(RARITY_RANK.get(rarity, 99)),
				int(SLOT_RANK.get(slot, 99)),
				name,
				base_id,
			]
		SORT_SLOT:
			return [
				int(SLOT_RANK.get(slot, 99)),
				int(RARITY_RANK.get(rarity, 99)),
				name,
				base_id,
			]
		SORT_NAME:
			return [name, int(RARITY_RANK.get(rarity, 99)), int(SLOT_RANK.get(slot, 99)), base_id]
		_:
			return [base_id, name]


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
	icon.add_theme_stylebox_override("panel", _stash_slot_style())
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
	blank.add_theme_stylebox_override("panel", _stash_slot_style())
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

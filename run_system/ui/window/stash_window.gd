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
##
## VISUALS (2026-07-08): charcoal lightline window per
## docs/art/previews/stash_page_ui_simple_comic_concept_20260708.png — riveted
## charcoal frame, crate + titleplate + n/cap + square ✕ header row, dropdown +
## segmented sort buttons + orange auto-organize, rarity corner ribbons on
## filled cells, dashed-slot drag hint footer. Every lightline texture is
## null-guarded (silent programmatic fallback while Codex art regenerates).
extends "res://run_system/ui/window/draggable_window.gd"

const EQUIPMENT_ICON = preload("res://run_system/ui/equipment_icon.gd")
const BACKPACK_CELL = preload("res://run_system/ui/backpack_cell.gd")
const AFFIX_POOL = preload("res://run_system/core/affix_pool.gd")
const EQUIP_TOOLTIP = preload("res://run_system/ui/equip_tooltip.gd")

const WIN_SIZE := Vector2(860, 1000)
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
## Segmented sort-bar labels, in display order (concept: 默认/稀有度/部位/名称).
const SORT_KEYS := {
	SORT_DEFAULT: "UI_STASH_SORT_DEFAULT",
	SORT_RARITY: "UI_STASH_SORT_RARITY",
	SORT_SLOT: "UI_STASH_SORT_SLOT",
	SORT_NAME: "UI_STASH_SORT_NAME",
}

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
	add_theme_stylebox_override("panel", T.ll_charcoal_panel())
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
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

	_body.add_child(_build_title_row())
	_body.add_child(_build_sort_row())

	var grid_row := HBoxContainer.new()
	grid_row.name = "StashPageRow"
	grid_row.alignment = BoxContainer.ALIGNMENT_CENTER
	grid_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_row.add_theme_constant_override("separation", 12)
	_body.add_child(grid_row)

	var prev := _make_page_button(-1)
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
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	center.add_child(grid)
	for offset in range(STASH_PAGE_CELLS):
		var absolute_index := page_start + offset
		if absolute_index < available.size():
			grid.add_child(_make_stash_cell(available[absolute_index]))
		else:
			grid.add_child(_make_empty_cell())

	var next := _make_page_button(1)
	next.name = "StashNextPageButton"
	next.disabled = _stash_page >= page_count - 1
	grid_row.add_child(next)

	var dots := _build_page_dots(page_count)
	if dots != null:
		_body.add_child(dots)
	_body.add_child(_build_drag_hint_row())


## Header row (concept): crate icon left, recessed titleplate 仓库 centered,
## used/cap counter + square red ✕ right. The whole strip is the drag handle
## (this window has no stock title bar).
func _build_title_row() -> Control:
	var row := HBoxContainer.new()
	row.name = "StashTitleRow"
	row.custom_minimum_size = Vector2(0, 64)
	row.add_theme_constant_override("separation", 10)
	bind_drag_area(row)

	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_BEGIN
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)
	var crate_tex := T.lightline_tex("icon_crate")
	if crate_tex != null:
		var crate := TextureRect.new()
		crate.texture = crate_tex
		crate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		crate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		crate.custom_minimum_size = Vector2(56, 52)
		crate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		crate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		left.add_child(crate)

	var plaque := PanelContainer.new()
	plaque.custom_minimum_size = Vector2(300, 58)
	plaque.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plaque.add_theme_stylebox_override("panel", T.ll_titleplate())
	bind_drag_area(plaque)
	row.add_child(plaque)
	var title := Label.new()
	title.text = tr("UI_STASH_WINDOW_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", T.display_font(700))
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", T.UI_HEADER_GOLD)
	title.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.04, 1.0))
	title.add_theme_constant_override("outline_size", 4)
	plaque.add_child(title)

	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 14)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right)
	var cap_label := Label.new()
	cap_label.name = "StashCapacityLabel"
	cap_label.text = "%d/%d" % [_stored_count(), MetaProgress.effective_stash_cap()]
	cap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap_label.add_theme_font_override("font", T.display_font(600))
	cap_label.add_theme_font_size_override("font_size", 24)
	cap_label.add_theme_color_override("font_color", T.UI_HEADER_GOLD)
	right.add_child(cap_label)
	var close_btn := T.ll_close_button(44.0)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(close)
	right.add_child(close_btn)
	return row


## Sort strip (concept): 排序 label + dropdown + four segmented mode buttons
## (selected = orange, rest = dark) + the orange 一键整理 button. Both the
## dropdown and the segments drive the SAME existing _on_sort_selected.
func _build_sort_row() -> Control:
	var row := HBoxContainer.new()
	row.name = "StashSortRow"
	row.custom_minimum_size = Vector2(0, 56)
	row.add_theme_constant_override("separation", 8)

	var sort_label := Label.new()
	sort_label.text = tr("UI_STASH_SORT_LABEL")
	sort_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sort_label.add_theme_font_size_override("font_size", 18)
	sort_label.add_theme_color_override("font_color", T.UI_BRASS_LIGHT)
	row.add_child(sort_label)

	var sort := OptionButton.new()
	sort.name = "StashSortOption"
	sort.custom_minimum_size = Vector2(190, 54)
	sort.add_theme_font_size_override("font_size", 17)
	sort.add_item(tr("UI_STASH_SORT_DEFAULT"), SORT_DEFAULT)
	sort.add_item(tr("UI_STASH_SORT_RARITY"), SORT_RARITY)
	sort.add_item(tr("UI_STASH_SORT_SLOT"), SORT_SLOT)
	sort.add_item(tr("UI_STASH_SORT_NAME"), SORT_NAME)
	sort.select(_sort_mode)
	_style_sort_dropdown(sort)
	sort.item_selected.connect(_on_sort_selected)
	row.add_child(sort)

	for mode in [SORT_DEFAULT, SORT_RARITY, SORT_SLOT, SORT_NAME]:
		var seg := Button.new()
		seg.name = "StashSortSegment%d" % int(mode)
		seg.text = tr(str(SORT_KEYS[mode]))
		seg.custom_minimum_size = Vector2(0, 54)
		seg.add_theme_font_size_override("font_size", 17)
		_style_ll_button(seg, int(mode) == _sort_mode)
		seg.pressed.connect(_on_sort_selected.bind(int(mode)))
		row.add_child(seg)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	var organize := Button.new()
	organize.name = "StashAutoOrganizeButton"
	organize.text = tr("UI_STASH_AUTO_ORGANIZE")
	organize.custom_minimum_size = Vector2(150, 54)
	organize.add_theme_font_size_override("font_size", 18)
	_style_ll_button(organize, true)
	organize.pressed.connect(_auto_organize_stash)
	row.add_child(organize)
	return row


## Lightline ◀ / ▶ page arrow at its native square-ish aspect; text fallback
## while the arrow PNGs are undelivered.
func _make_page_button(delta: int) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(40, 39)
	var tex := T.lightline_tex("btn_arrow_left" if delta < 0 else "btn_arrow_right")
	if tex != null:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var box := StyleBoxTexture.new()
			box.texture = tex
			match state:
				"hover":
					box.modulate_color = Color(1.15, 1.15, 1.15)
				"pressed":
					box.modulate_color = Color(0.82, 0.82, 0.82)
				"disabled":
					box.modulate_color = Color(0.45, 0.45, 0.45, 0.8)
			b.add_theme_stylebox_override(state, box)
	else:
		b.text = "‹" if delta < 0 else "›"
		b.add_theme_font_size_override("font_size", 26)
		T.apply_button_theme(b)
	b.pressed.connect(_change_page.bind(delta))
	return b


## Cyan progress dots under the grid — current page lit, others dimmed.
## Decoration only; returns null on a single page or while the dot PNG is absent.
func _build_page_dots(page_count: int) -> Control:
	if page_count <= 1:
		return null
	var tex := T.lightline_tex("icon_dot_cyan")
	if tex == null:
		return null
	var row := HBoxContainer.new()
	row.name = "StashPageDots"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(page_count):
		var dot := TextureRect.new()
		dot.texture = tex
		dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dot.custom_minimum_size = Vector2(14, 14)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i != _stash_page:
			dot.modulate = Color(0.38, 0.42, 0.44, 0.9)
		row.add_child(dot)
	return row


## Footer hint strip (concept): dashed crate slot → “拖拽物品到背包” → arrow →
## dashed backpack slot. Pure decoration — no input.
func _build_drag_hint_row() -> Control:
	var panel := PanelContainer.new()
	panel.name = "StashDragHintRow"
	panel.custom_minimum_size = Vector2(0, 66)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", T.ll_inset_thin())
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)

	var crate := _make_hint_slot("icon_crate", Color(1.0, 0.66, 0.24))
	if crate != null:
		box.add_child(crate)
	var label := Label.new()
	label.text = tr("UI_STASH_DRAG_HINT")
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", T.UI_BRASS_LIGHT)
	box.add_child(label)
	var arrow_tex := T.lightline_tex("icon_arrow_right")
	if arrow_tex != null:
		var arrow := TextureRect.new()
		arrow.texture = arrow_tex
		arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		arrow.custom_minimum_size = Vector2(24, 30)
		arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(arrow)
	var bag := _make_hint_slot("icon_backpack", Color(0.45, 0.83, 0.95))
	if bag != null:
		box.add_child(bag)
	return panel


## One dashed mini-slot with an icon inside (hint row). The dashed frame tints
## per side (orange crate / cyan backpack, like the concept); the icon stays
## full-color. Null when neither texture is delivered.
func _make_hint_slot(icon_name: String, frame_tint: Color) -> Control:
	var frame_tex := T.lightline_tex(T.INK_SET + "_slot_brackets")
	var icon_tex := T.lightline_tex(icon_name)
	if frame_tex == null and icon_tex == null:
		return null
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(52, 51)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if frame_tex != null:
		var frame := TextureRect.new()
		frame.texture = frame_tex
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.modulate = frame_tint
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(frame)
	if icon_tex != null:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 11
		icon.offset_top = 11
		icon.offset_right = -11
		icon.offset_bottom = -11
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(icon)
	return holder


## Number of gear entries actually stored (header counter). Counts the WHOLE
## stash — entries queued for the next run still occupy storage capacity.
func _stored_count() -> int:
	var n := 0
	for entry in MetaProgress.stash:
		if not RunManager.as_equip_instance(entry).is_empty():
			n += 1
	return n


## Orange (selected/primary) vs dark (unselected) lightline button styling for
## the sort segments + auto-organize.
func _style_ll_button(button: Button, accent: bool) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed"]:
		var box: StyleBox = T.ll_button(state) if accent else _dark_button_box(state)
		button.add_theme_stylebox_override(state, box)
	if accent:
		button.add_theme_color_override("font_color", T.UI_ACCENT_TEXT)
		button.add_theme_color_override("font_hover_color", T.UI_ACCENT_TEXT)
		button.add_theme_color_override("font_pressed_color", T.UI_ACCENT_TEXT)
	else:
		button.add_theme_color_override("font_color", T.UI_BRASS_LIGHT)
		button.add_theme_color_override("font_hover_color", T.UI_HEADER_GOLD)
		button.add_theme_color_override("font_pressed_color", T.UI_HEADER_GOLD)
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	button.add_theme_constant_override("outline_size", 2)


## Dark segmented-button box (btn_dark 9-slice, hover/pressed by modulate),
## programmatic brass fallback while the PNG is undelivered.
func _dark_button_box(state: String) -> StyleBox:
	var box := T.lightline_box("btn_dark", T.ui_button_brass(state), 24)
	var tb := box as StyleBoxTexture
	if tb != null:
		match state:
			"hover":
				tb.modulate_color = Color(1.15, 1.15, 1.15)
			"pressed":
				tb.modulate_color = Color(0.85, 0.85, 0.85)
		tb.content_margin_left = 16
		tb.content_margin_right = 16
		tb.content_margin_top = 8
		tb.content_margin_bottom = 10
	return box


## Style the sort OptionButton with the lightline dropdown field (its ▼ cap is
## baked into the art, so the theme arrow is blanked). Themed-button fallback
## while the PNG is undelivered.
func _style_sort_dropdown(sort: OptionButton) -> void:
	sort.focus_mode = Control.FOCUS_NONE
	sort.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sort.add_theme_color_override("font_color", T.UI_BRASS_LIGHT)
	sort.add_theme_color_override("font_hover_color", T.UI_HEADER_GOLD)
	sort.add_theme_color_override("font_pressed_color", T.UI_HEADER_GOLD)
	var tex := T.lightline_tex("field_dropdown")
	if tex == null:
		T.apply_button_theme(sort)
		return
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxTexture.new()
		box.texture = tex
		box.texture_margin_left = 28
		box.texture_margin_top = 26
		box.texture_margin_right = 92
		box.texture_margin_bottom = 26
		box.content_margin_left = 18
		box.content_margin_right = 68
		box.content_margin_top = 4
		box.content_margin_bottom = 6
		match state:
			"hover":
				box.modulate_color = Color(1.1, 1.1, 1.1)
			"pressed":
				box.modulate_color = Color(0.86, 0.86, 0.86)
			"disabled":
				box.modulate_color = Color(0.6, 0.6, 0.6)
		sort.add_theme_stylebox_override(state, box)
	# Blank the built-in arrow — the field art already bakes its own ▼ cap.
	var blank := Image.create_empty(2, 2, false, Image.FORMAT_RGBA8)
	sort.add_theme_icon_override("arrow", ImageTexture.create_from_image(blank))


func _on_sort_selected(index: int) -> void:
	_sort_mode = index
	_stash_page = 0
	AudioManager.play_sfx("ui_click")
	refresh()


func _auto_organize_stash() -> void:
	MetaProgress.stash.sort_custom(func(a, b): return _entry_sort_less(a, b, ORGANIZE_SORT_MODE))
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
		func(a, b):
			return _entry_sort_less(
				MetaProgress.stash[int(a)], MetaProgress.stash[int(b)], _sort_mode
			)
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


## One stash cell: lightline slot frame + gear icon + rarity corner ribbon +
## tooltip. Drag OUT to the CharacterWindow backpack (carry it) or the
## ForgeWindow bench; also a drop target for storing.
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
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", T.ll_slot("normal"))
	cell.add_child(frame)
	var icon = EQUIPMENT_ICON.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 12
	icon.offset_top = 12
	icon.offset_right = -12
	icon.offset_bottom = -12
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_equipment(
		slot, item_name, str(data.get("sprite", "")), str(data.get("rarity", "common"))
	)
	# The lightline slot frame carries the border; the icon panel goes bare and
	# rarity moves to the corner ribbon (concept look).
	icon.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	cell.add_child(icon)
	var ribbon := _make_rarity_ribbon(str(inst.get("rarity", data.get("rarity", "common"))))
	if ribbon != null:
		cell.add_child(ribbon)

	cell.hover_tip = _equipment_tooltip(data, slot, inst)
	# The payload carries the actual stash entry (forge + character window both
	# resolve it back by value).
	cell.drag_payload = {"src": "stash", "slot": slot, "entry": entry}
	cell.preview_text = str(SLOT_LETTERS.get(slot, "?"))
	cell.preview_color = Color(1.0, 0.86, 0.4)
	cell.preview_tex = _load_equip_tex(str(data.get("sprite", "")))
	_wire_store_drop(cell)
	return cell


## Top-left rarity triangle ribbon — the light lightline template tinted with
## the shared EQUIPMENT_ICON rarity color. Null while the PNG is undelivered.
func _make_rarity_ribbon(rarity: String) -> Control:
	var tex := T.lightline_tex("ribbon_rarity_corner")
	if tex == null:
		return null
	var ribbon := TextureRect.new()
	ribbon.texture = tex
	ribbon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ribbon.stretch_mode = TextureRect.STRETCH_SCALE
	ribbon.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ribbon.offset_left = 7
	ribbon.offset_top = 7
	ribbon.offset_right = 7 + 36
	ribbon.offset_bottom = 7 + 36
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.modulate = EQUIPMENT_ICON.RARITY_COLORS.get(rarity, Color.WHITE)
	return ribbon


## A recessed empty storage frame — still a live drop target.
func _make_empty_cell() -> Control:
	var cell = BACKPACK_CELL.new()
	cell.custom_minimum_size = GRID_CELL_SIZE
	var blank := Panel.new()
	blank.set_anchors_preset(Control.PRESET_FULL_RECT)
	blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blank.add_theme_stylebox_override("panel", T.ll_slot("normal"))
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


## Rich equipment tooltip — delegates to the shared EQUIP_TOOLTIP helper
## (owner 2026-07-08: rarity·slot header, no generated name; set pieces keep
## theirs). Replaces the old per-window duplicated builders.
func _equipment_tooltip(data: Dictionary, slot: String, instance: Dictionary) -> String:
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

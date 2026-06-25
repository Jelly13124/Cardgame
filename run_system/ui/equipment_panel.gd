## Character page — Diablo-style 3-zone layout, full screen:
##   LEFT   = hero portrait + attributes
##   MIDDLE = the 5 equipment slots (vertical column)
##   RIGHT  = the backpack as a grid of cells
##   BOTTOM = active sets + relics strip
## Built dynamically; attached as a direct child of map_scene. Listens to
## RunManager state signals for live refresh.
##
## The backpack grid is built "stack-ready": each cell is produced by
## _make_grid_cell(index) so a future economy pass (gold/core stacks occupying
## cells) only has to extend that one method, not restructure the grid.
extends Control
class_name EquipmentPanel

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const EQUIPMENT_ICON = preload("res://run_system/ui/equipment_icon.gd")
const BACKPACK_CELL = preload("res://run_system/ui/backpack_cell.gd")
const AFFIX_POOL = preload("res://run_system/core/affix_pool.gd")
const HERO_SPRITE_DIR := "res://battle_scene/assets/images/heroes/"

const GRID_COLUMNS := 5
const CELL_SIZE := Vector2(76, 76)
const SLOT_LETTERS := {"head": "H", "chest": "C", "weapon": "W", "hands": "Hd", "accessory": "Ac"}

var _slot_icons: Dictionary = {}  # slot → EquipmentIcon
var _slot_cells: Dictionary = {}  # slot → BackpackCell (drag/drop wrapper)
var _slot_labels: Dictionary = {}  # slot → Label (slot/item name)
var _grid: GridContainer
var _tool_row: HBoxContainer  # equipped tool slots (tools are held in the backpack)
var _portrait_rect: TextureRect
var _attrs_label: Label
var _vitals_label: Label
var _inv_title: Label
var _sets_container: VBoxContainer
var _relics_container: HFlowContainer
var _status_label: Label


func _ready() -> void:
	# MapScene's Control rect is NOT viewport-sized (it draws via get_viewport_rect()
	# but never sets its own size), so PRESET_FULL_RECT would collapse the page (and
	# its opaque bg ColorRect) to ~(0,0) — the map shows through. Size ourselves to
	# the viewport explicitly and stay updated on resize.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	RunManager.equipment_changed.connect(_refresh)
	RunManager.health_changed.connect(_on_health_changed)
	RunManager.resources_changed.connect(_on_resources_changed)
	RunManager.relics_updated.connect(_refresh)
	RunManager.backpack_changed.connect(_refresh)
	_refresh()


func _fit_to_viewport() -> void:
	set_position(Vector2.ZERO)
	set_size(get_viewport_rect().size)


func _on_health_changed(_current: int, _maximum: int) -> void:
	_refresh()


func _on_resources_changed(_gold: int, _core: int) -> void:
	_refresh()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.045, 0.038, 0.030, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Edge-to-edge page (small margin only).
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 22)
	add_child(margin)

	var vroot := VBoxContainer.new()
	vroot.add_theme_constant_override("separation", 14)
	margin.add_child(vroot)

	# ── Header: title + vitals + back ──
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	vroot.add_child(header)
	var title := Label.new()
	title.text = tr("UI_EQUIP_TITLE_CHARACTER")
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	header.add_child(title)
	_vitals_label = Label.new()
	_vitals_label.add_theme_font_size_override("font_size", 20)
	_vitals_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.7))
	_vitals_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_vitals_label)

	# ── Body: 3 zones ──
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vroot.add_child(body)

	body.add_child(_build_character_zone())
	body.add_child(_build_equipment_zone())
	body.add_child(_build_backpack_zone())

	# ── Bottom strip: sets + relics ──
	vroot.add_child(HSeparator.new())
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 40)
	vroot.add_child(strip)

	var sets_col := VBoxContainer.new()
	sets_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_child(sets_col)
	sets_col.add_child(_section_title(tr("UI_EQUIP_ACTIVE_SETS")))
	_sets_container = VBoxContainer.new()
	_sets_container.add_theme_constant_override("separation", 4)
	sets_col.add_child(_sets_container)

	var relics_col := VBoxContainer.new()
	relics_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_child(relics_col)
	relics_col.add_child(_section_title(tr("UI_EQUIP_RELICS")))
	_relics_container = HFlowContainer.new()
	_relics_container.add_theme_constant_override("h_separation", 8)
	_relics_container.add_theme_constant_override("v_separation", 6)
	relics_col.add_child(_relics_container)

	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.3))
	vroot.add_child(_status_label)

	_add_close_x()


## Top-right ✕ — returns to the map (queue_free), same as the old back button.
func _add_close_x() -> void:
	var x := T.close_x_button()
	x.anchor_left = 1.0
	x.anchor_right = 1.0
	x.offset_left = -64.0
	x.offset_right = -16.0
	x.offset_top = 16.0
	x.offset_bottom = 64.0
	x.pressed.connect(queue_free)
	add_child(x)


## ESC also closes the character page (map has no competing ESC handler).
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()


func _build_character_zone() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(360, 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(frame)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	frame.add_child(inner)

	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = Vector2(300, 420)
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(_portrait_rect)

	_attrs_label = Label.new()
	_attrs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attrs_label.add_theme_font_size_override("font_size", 20)
	_attrs_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
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

	return col


func _build_equipment_zone() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(300, 0)
	col.add_child(_section_title(tr("UI_EQUIP_SLOTS")))

	for slot in RunManager.EQUIPMENT_SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		col.add_child(row)

		# BackpackCell wrapper owns drag/drop/click; the EquipmentIcon is a
		# mouse-ignoring cosmetic child filling it.
		var cell := BACKPACK_CELL.new()
		cell.custom_minimum_size = CELL_SIZE
		cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var icon := EQUIPMENT_ICON.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon)
		# Drop target: accept a matching-slot equipment dragged from the backpack.
		var s := slot
		cell.can_accept = func(data): return (
			data.get("src") == "backpack"
			and data.get("kind") == "equip"
			and data.get("slot") == s
		)
		cell.perform_drop = func(data): _on_equip_pressed(str(data.get("item_id", "")), s, -1)
		cell.click_handler = func(btn): if btn == MOUSE_BUTTON_LEFT: _on_unequip_pressed(s)
		row.add_child(cell)
		_slot_icons[slot] = icon
		_slot_cells[slot] = cell

		var label := Label.new()
		label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		_slot_labels[slot] = label

	return col


func _build_backpack_zone() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Equipped tool slots — tools are HELD in the backpack and equipped into a slot
	# here (click a backpack tool to equip; click an equipped tool to unequip).
	col.add_child(_section_title(tr("UI_EQUIP_TOOLS_TITLE")))
	_tool_row = HBoxContainer.new()
	_tool_row.add_theme_constant_override("separation", 8)
	col.add_child(_tool_row)

	_inv_title = _section_title("")
	col.add_child(_inv_title)
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	col.add_child(_grid)
	var hint := Label.new()
	hint.text = tr("UI_EQUIP_BACKPACK_HINT")
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.65, 0.6, 0.5))
	col.add_child(hint)
	return col


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
			tr("UI_EQUIP_STATS")
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

	# Equipment slots
	for slot in RunManager.EQUIPMENT_SLOTS:
		var icon: EquipmentIcon = _slot_icons[slot]
		var cell = _slot_cells[slot]
		var label: Label = _slot_labels[slot]
		# Tolerant read: slot may hold an instance dict (new) or a legacy String.
		var slot_inst: Dictionary = RunManager.as_equip_instance(RunManager.equipped_items.get(slot, {}))
		var item_id: String = RunManager.equip_base(slot_inst)
		var slot_label := _slot_label(slot)
		if item_id == "":
			icon.set_empty(slot)
			# Empty slot: not a drag source; tooltip explains it.
			cell.drag_payload = {}
			cell.hover_tip = "[b]%s[/b]\n%s" % [slot_label, tr("UI_EQUIP_EMPTY_SLOT")]
			label.text = "%s: %s" % [slot_label, tr("UI_EQUIP_EMPTY")]
		else:
			var data = RunManager.get_equipment_data(item_id)
			var item_name := Settings.t("EQUIP_%s_NAME" % item_id, str(data.get("name", item_id)))
			icon.set_equipment(slot, item_name, str(data.get("sprite", "")), str(data.get("rarity", "common")))
			# Equipped item is draggable back into the backpack (unequip).
			cell.drag_payload = {"src": "slot", "slot": slot, "item_id": item_id}
			cell.preview_text = str(SLOT_LETTERS.get(slot, "?"))
			cell.preview_color = Color(1.0, 0.86, 0.4)
			cell.preview_tex = _load_equip_tex(str(data.get("sprite", "")))
			cell.hover_tip = _build_equipment_tooltip(data, slot, slot_inst)
			label.text = "%s: %s" % [slot_label, item_name]

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

	# Backpack grid (rebuild every refresh)
	if _inv_title:
		_inv_title.text = tr("UI_EQUIP_INVENTORY_COUNT").format(
			{"n": RunManager.backpack_count_used(), "max": RunManager.effective_backpack_size()}
		)
	for child in _grid.get_children():
		child.queue_free()
	for i in range(RunManager.effective_backpack_size()):
		_grid.add_child(_make_grid_cell(i))

	# Active sets
	for child in _sets_container.get_children():
		child.queue_free()
	var active_tiers: Dictionary = RunManager.get_active_set_tiers()
	if active_tiers.is_empty():
		var none := Label.new()
		none.text = tr("UI_EQUIP_NONE_YET")
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
		none.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_relics_container.add_child(none)
	else:
		for relic_id in RunManager.relics:
			_relics_container.add_child(_build_relic_chip(str(relic_id)))

	_status_label.text = ""


## Build one backpack cell from RunManager.backpack[index] — the four cell
## states: null = empty, {"kind":"equip"} = interactive gear icon,
## {"kind":"gold"} / {"kind":"core"} = non-interactive resource stack.
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
					tr("UI_EQUIP_CELL_GOLD"), int(cell.get("amount", 0)), T.SAND_LIGHT, index, "gold"
				)
			"core":
				return _make_resource_cell(
					tr("UI_EQUIP_CELL_CORE"),
					int(cell.get("amount", 0)),
					T.ACCENT_NEON_BLUE,
					index,
					"core"
				)
			"gem":
				return _make_gem_cell(str(cell.get("id", "")), index)
			"tool":
				return _make_tool_cell(str(cell.get("id", "")), index)
	# Empty cell — dim placeholder panel, still a valid drop target.
	var wrapper := BACKPACK_CELL.new()
	wrapper.custom_minimum_size = CELL_SIZE
	var blank := Panel.new()
	blank.set_anchors_preset(Control.PRESET_FULL_RECT)
	blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := T.panel_with_shadow(Color(0.10, 0.085, 0.07, 0.6), T.PANEL_BORDER, 2, 1)
	blank.add_theme_stylebox_override("panel", style)
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
	cell.can_accept = func(data): return (
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
	var cell := BACKPACK_CELL.new()
	cell.custom_minimum_size = CELL_SIZE
	cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var icon := EQUIPMENT_ICON.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_equipment(slot, item_name, str(data.get("sprite", "")), str(data.get("rarity", "common")))
	cell.add_child(icon)
	cell.hover_tip = _build_equipment_tooltip(data, slot, instance)
	cell.drag_payload = {
		"src": "backpack", "index": index, "kind": "equip", "item_id": item_id, "slot": slot
	}
	cell.preview_text = str(SLOT_LETTERS.get(slot, "?"))
	cell.preview_color = Color(1.0, 0.86, 0.4)
	cell.preview_tex = _load_equip_tex(str(data.get("sprite", "")))
	_wire_backpack_drop(cell, index)
	cell.click_handler = func(btn):
		if btn == MOUSE_BUTTON_LEFT:
			_on_equip_pressed(item_id, slot, index)
		elif btn == MOUSE_BUTTON_RIGHT:
			_confirm_discard(index, item_id)
		elif btn == MOUSE_BUTTON_MIDDLE:
			_toggle_safe(index)
	return cell


## A gem cell: gem art (or ◆ glyph) + tooltip. Draggable to reorder/swap; gems are
## socketed from the deck viewer (which frees the cell), not from here. Middle-click
## toggles the safe zone like the other cell kinds.
func _make_gem_cell(gem_id: String, index: int) -> Control:
	var data: Dictionary = RunManager.get_gem_data(gem_id)
	var gem_name := Settings.t("GEM_%s_TITLE" % gem_id, str(data.get("title", gem_id)))
	var cell := BACKPACK_CELL.new()
	cell.custom_minimum_size = CELL_SIZE
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
		glyph.text = "◆"
		glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.add_theme_font_size_override("font_size", 28)
		glyph.add_theme_color_override("font_color", Color(0.55, 0.95, 0.7))
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(glyph)

	var desc := Settings.t("GEM_%s_DESC" % gem_id, "")
	cell.hover_tip = gem_name if desc == "" else "%s\n%s" % [gem_name, desc]
	cell.drag_payload = {"src": "backpack", "index": index, "kind": "gem", "gem_id": gem_id}
	cell.preview_text = "◆"
	cell.preview_color = Color(0.55, 0.95, 0.7)
	cell.preview_tex = tex
	_wire_backpack_drop(cell, index)
	cell.click_handler = func(btn): if btn == MOUSE_BUTTON_MIDDLE: _toggle_safe(index)
	return cell


## A backpack TOOL cell: tool art (or ⚙ glyph) + tooltip. Left-click equips it into a
## free tool slot; middle-click toggles the safe zone; draggable to reorder/swap.
func _make_tool_cell(tool_id: String, index: int) -> Control:
	var data: Dictionary = RunManager.get_tool_data(tool_id)
	var tool_name := Settings.t("TOOL_%s_TITLE" % tool_id, str(data.get("title", tool_id)))
	var cell := BACKPACK_CELL.new()
	cell.custom_minimum_size = CELL_SIZE
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
		glyph.add_theme_font_size_override("font_size", 26)
		glyph.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(glyph)

	var desc := Settings.t("TOOL_%s_DESC" % tool_id, "")
	var equip_hint := tr("UI_EQUIP_TOOL_EQUIP_HINT")
	if desc == "":
		cell.hover_tip = "[b]%s[/b]\n[color=#9fd0ff]%s[/color]" % [tool_name, equip_hint]
	else:
		cell.hover_tip = "[b]%s[/b]\n%s\n[color=#9fd0ff]%s[/color]" % [tool_name, desc, equip_hint]
	cell.drag_payload = {"src": "backpack", "index": index, "kind": "tool", "tool_id": tool_id}
	cell.preview_text = "⚙"
	cell.preview_color = Color(0.6, 0.8, 1.0)
	cell.preview_tex = tex
	_wire_backpack_drop(cell, index)
	cell.click_handler = func(btn):
		if btn == MOUSE_BUTTON_LEFT:
			_equip_tool(index)
		elif btn == MOUSE_BUTTON_MIDDLE:
			_toggle_safe(index)
	return cell


## An equipped tool slot (the worn tool): icon + tooltip; click unequips it back into
## the backpack.
func _make_equipped_tool_cell(index: int, tool_id: String) -> Control:
	var data: Dictionary = RunManager.get_tool_data(tool_id)
	var title := Settings.t("TOOL_%s_TITLE" % tool_id, str(data.get("title", tool_id)))
	var desc := Settings.t("TOOL_%s_DESC" % tool_id, "")
	var b := Button.new()
	b.custom_minimum_size = CELL_SIZE
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var unhint := tr("UI_EQUIP_TOOL_UNEQUIP_HINT")
	b.tooltip_text = (
		"%s\n%s\n%s" % [title, desc, unhint] if desc != "" else "%s\n%s" % [title, unhint]
	)
	var icon_path := str(data.get("icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		b.icon = load(icon_path)
		b.expand_icon = true
	else:
		b.text = title.substr(0, 1).to_upper()
		b.add_theme_font_size_override("font_size", 18)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.16, 0.9)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.55, 0.75, 0.95, 0.95)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.pressed.connect(func() -> void: _unequip_tool(index))
	return b


## An empty tool slot (dim, with a faint ⚙ so it reads as a slot awaiting a tool).
func _make_empty_tool_cell() -> Control:
	var p := Panel.new()
	p.custom_minimum_size = CELL_SIZE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.22)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.5, 0.55, 0.7, 0.5)
	p.add_theme_stylebox_override("panel", sb)
	p.tooltip_text = tr("UI_EQUIP_TOOL_SLOT_EMPTY")
	var glyph := Label.new()
	glyph.text = "⚙"
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", 22)
	glyph.add_theme_color_override("font_color", Color(0.5, 0.55, 0.7, 0.5))
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(glyph)
	return p


## Equip a backpack tool (cell `index`) into a free tool slot, or flash a hint when
## every slot is full.
func _equip_tool(index: int) -> void:
	if RunManager.equip_tool_from_backpack(index):
		AudioManager.play_sfx("ui_click")
	else:
		_status_label.text = tr("UI_EQUIP_TOOL_SLOTS_FULL")
		AudioManager.play_sfx("error")


## Unequip the tool in slot `index` back into the backpack (or flash if the bag is full).
func _unequip_tool(index: int) -> void:
	if RunManager.unequip_tool(index):
		AudioManager.play_sfx("ui_back")
	else:
		_status_label.text = tr("UI_LOOT_BACKPACK_FULL")
		AudioManager.play_sfx("error")


## Right-click discard now asks first — affixed gear is permanently lost otherwise.
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


## A gold / Core resource stack cell. Draggable as a whole stack (move/swap via
## move_cell); middle-click still toggles safe.
func _make_resource_cell(
	label_text: String, amount: int, tint: Color, index: int, kind: String
) -> Control:
	var cell := BACKPACK_CELL.new()
	cell.custom_minimum_size = CELL_SIZE
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
	kind_lbl.add_theme_font_size_override("font_size", 14)
	kind_lbl.add_theme_color_override("font_color", tint)
	box.add_child(kind_lbl)

	var amount_lbl := Label.new()
	amount_lbl.text = "x%d" % amount
	amount_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_lbl.add_theme_font_size_override("font_size", 22)
	amount_lbl.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9))
	box.add_child(amount_lbl)

	cell.drag_payload = {"src": "backpack", "index": index, "kind": kind}
	cell.preview_text = "x%d" % amount
	cell.preview_color = tint
	_wire_backpack_drop(cell, index)
	cell.click_handler = func(btn): if btn == MOUSE_BUTTON_MIDDLE: _toggle_safe(index)
	return cell


## Move the stack at `index` between the safe zone (cells 0..safe-1) and the
## normal zone — into the first empty cell of the target zone. No-op if full.
func _toggle_safe(index: int) -> void:
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
	if not RunManager.equip_to_slot(item_id, slot):
		_status_label.text = tr("UI_EQUIP_FULL_SWAP")


func _on_unequip_pressed(slot: String) -> void:
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
	row.add_theme_constant_override("separation", 12)

	var equipment_set_name := Settings.t("EQUIP_SET_%s_NAME" % set_id, str(set_data.get("name", set_id)))
	var name_lbl := Label.new()
	name_lbl.text = "%s  %d/5" % [equipment_set_name, count]
	name_lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.5))
	name_lbl.custom_minimum_size = Vector2(180, 0)
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


func _format_bonuses(bonuses) -> String:
	if typeof(bonuses) != TYPE_DICTIONARY or bonuses.is_empty():
		return tr("UI_EQUIP_NO_BONUSES")
	var parts: Array = []
	for attr in bonuses.keys():
		parts.append("+%d %s" % [int(bonuses[attr]), str(attr).substr(0, 3)])
	return ", ".join(parts)


## Rich tooltip text for an equipment item. `instance` is the per-instance equip
## dict (E_B) whose rolled affixes are listed one-per-line; pass {} to fall back
## to the base JSON `bonuses` summary (legacy / no instance available). Curse
## affixes render red, positives green.
func _build_equipment_tooltip(data: Dictionary, slot: String, instance: Dictionary = {}) -> String:
	var item_id := str(data.get("id", ""))
	var name_str := Settings.t("EQUIP_%s_NAME" % item_id, str(data.get("name", "?")))
	# Prefer the instance's rolled rarity; fall back to the base JSON rarity.
	var rarity := str(instance.get("rarity", data.get("rarity", "common")))
	var rarity_str := Settings.t("EQUIP_RARITY_%s" % rarity, rarity)
	var desc := Settings.t("EQUIP_%s_DESC" % item_id, str(data.get("description", "")))
	# Prefer the instance's set_id (rolled), fall back to the base JSON.
	var set_id := str(instance.get("set_id", data.get("set_id", "")))

	var lines: Array = []
	lines.append("[b]%s[/b]" % name_str)
	lines.append("[i]%s · %s[/i]" % [_slot_label(slot), rarity_str])
	lines.append("")
	# Affix block: one localized line per rolled affix (curses red, positives green).
	var affixes: Array = RunManager.equip_affixes(instance) if not instance.is_empty() else []
	if affixes.is_empty():
		lines.append(_format_bonuses(data.get("bonuses", {})))
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


func _section_title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	return l

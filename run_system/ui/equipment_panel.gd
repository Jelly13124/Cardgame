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
const HERO_SPRITE_DIR := "res://battle_scene/assets/images/heroes/"

const GRID_COLUMNS := 5
const CELL_SIZE := Vector2(76, 76)

var _slot_icons: Dictionary = {}  # slot → EquipmentIcon
var _slot_labels: Dictionary = {}  # slot → Label (slot/item name)
var _grid: GridContainer
var _portrait_rect: TextureRect
var _attrs_label: Label
var _vitals_label: Label
var _inv_title: Label
var _sets_container: VBoxContainer
var _relics_container: HFlowContainer
var _status_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	RunManager.equipment_changed.connect(_refresh)
	RunManager.health_changed.connect(_on_health_changed)
	RunManager.resources_changed.connect(_on_resources_changed)
	RunManager.relics_updated.connect(_refresh)
	RunManager.backpack_changed.connect(_refresh)
	_refresh()


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
	header.add_child(_spacer())
	var close_btn := Button.new()
	close_btn.text = tr("UI_EQUIP_BACK_TO_MAP")
	close_btn.custom_minimum_size = Vector2(170, 44)
	T.apply_button_theme(close_btn)
	close_btn.pressed.connect(queue_free)
	header.add_child(close_btn)

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

		var icon := EQUIPMENT_ICON.new()
		icon.custom_minimum_size = CELL_SIZE
		icon.gui_input.connect(_on_slot_input.bind(slot))
		icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.add_child(icon)
		_slot_icons[slot] = icon

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
		var label: Label = _slot_labels[slot]
		var item_id: String = RunManager.equipped_items.get(slot, "")
		var slot_label := _slot_label(slot)
		if item_id == "":
			icon.set_empty(slot)
			icon.set_hover_tooltip("[b]%s[/b]\n%s" % [slot_label, tr("UI_EQUIP_EMPTY_SLOT")])
			label.text = "%s: %s" % [slot_label, tr("UI_EQUIP_EMPTY")]
		else:
			var data = RunManager.get_equipment_data(item_id)
			var item_name := Settings.t("EQUIP_%s_NAME" % item_id, str(data.get("name", item_id)))
			icon.set_equipment(slot, item_name, str(data.get("sprite", "")))
			icon.set_hover_tooltip(_build_equipment_tooltip(data, slot))
			label.text = "%s: %s" % [slot_label, item_name]

	# Backpack grid (rebuild every refresh)
	if _inv_title:
		_inv_title.text = tr("UI_EQUIP_INVENTORY_COUNT").format(
			{"n": RunManager.backpack_count_used(), "max": RunManager.MAX_INVENTORY}
		)
	for child in _grid.get_children():
		child.queue_free()
	for i in range(RunManager.MAX_INVENTORY):
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
				return _make_equip_cell(str(cell.get("id", "")), index)
			"gold":
				return _make_resource_cell(
					tr("UI_EQUIP_CELL_GOLD"), int(cell.get("amount", 0)), T.SAND_LIGHT, index
				)
			"core":
				return _make_resource_cell(
					tr("UI_EQUIP_CELL_CORE"), int(cell.get("amount", 0)), T.ACCENT_NEON_BLUE, index
				)
	# Empty cell — dim placeholder panel.
	var blank := Panel.new()
	blank.custom_minimum_size = CELL_SIZE
	var style := T.panel_with_shadow(Color(0.10, 0.085, 0.07, 0.6), T.PANEL_BORDER, 2, 1)
	blank.add_theme_stylebox_override("panel", style)
	return blank


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


## An equipment cell: gear icon, left-click equips, right-click discards (by the
## backpack CELL index — NOT a position in the equip list).
func _make_equip_cell(item_id: String, index: int) -> Control:
	var data = RunManager.get_equipment_data(item_id)
	var slot := str(data.get("slot", "head"))
	var item_name := Settings.t("EQUIP_%s_NAME" % item_id, str(data.get("name", item_id)))
	var icon := EQUIPMENT_ICON.new()
	icon.custom_minimum_size = CELL_SIZE
	icon.set_equipment(slot, item_name, str(data.get("sprite", "")))
	icon.set_hover_tooltip(_build_equipment_tooltip(data, slot))
	icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	icon.gui_input.connect(_on_cell_input.bind(item_id, slot, index))
	return icon


## A gold / Core resource stack cell. Non-interactive: a labelled count tile.
func _make_resource_cell(label_text: String, amount: int, tint: Color, index: int) -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = CELL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", T.icon_frame_style())
	panel.gui_input.connect(_on_resource_input.bind(index))

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
	return panel


func _on_slot_input(event: InputEvent, slot: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_unequip_pressed(slot)


func _on_cell_input(event: InputEvent, item_id: String, slot: String, index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_on_equip_pressed(item_id, slot, index)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		RunManager.discard_from_inventory(index)
	elif event.button_index == MOUSE_BUTTON_MIDDLE:
		_toggle_safe(index)


## Middle-click a gold/core stack to move it into/out of a safe cell.
func _on_resource_input(event: InputEvent, index: int) -> void:
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_MIDDLE
	):
		_toggle_safe(index)


## Move the stack at `index` between the safe zone (cells 0..safe-1) and the
## normal zone — into the first empty cell of the target zone. No-op if full.
func _toggle_safe(index: int) -> void:
	var safe := MetaProgress.effective_safe_cells()
	var dst := -1
	if index < safe:
		dst = _first_empty_in_range(safe, RunManager.MAX_INVENTORY)
	else:
		dst = _first_empty_in_range(0, safe)
	if dst != -1:
		RunManager.move_cell(index, dst)
	else:
		_status_label.text = tr("UI_EQUIP_SAFE_FULL")


func _first_empty_in_range(lo: int, hi: int) -> int:
	for i in range(lo, mini(hi, RunManager.MAX_INVENTORY)):
		if RunManager.backpack[i] == null:
			return i
	return -1


func _on_equip_pressed(item_id: String, slot: String, _index: int) -> void:
	if not RunManager.equip_to_slot(item_id, slot):
		_status_label.text = tr("UI_EQUIP_FULL_SWAP")


func _on_unequip_pressed(slot: String) -> void:
	if RunManager.equipped_items.get(slot, "") == "":
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

	var set_name := Settings.t("EQUIP_SET_%s_NAME" % set_id, str(set_data.get("name", set_id)))
	var name_lbl := Label.new()
	name_lbl.text = "%s  %d/5" % [set_name, count]
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


## Rich tooltip text for an equipment item.
func _build_equipment_tooltip(data: Dictionary, slot: String) -> String:
	var item_id := str(data.get("id", ""))
	var name_str := Settings.t("EQUIP_%s_NAME" % item_id, str(data.get("name", "?")))
	var rarity := str(data.get("rarity", "common"))
	var rarity_str := Settings.t("EQUIP_RARITY_%s" % rarity, rarity)
	var desc := Settings.t("EQUIP_%s_DESC" % item_id, str(data.get("description", "")))
	var bonuses_text := _format_bonuses(data.get("bonuses", {}))
	var set_id := str(data.get("set_id", ""))

	var lines: Array = []
	lines.append("[b]%s[/b]" % name_str)
	lines.append("[i]%s · %s[/i]" % [_slot_label(slot), rarity_str])
	lines.append("")
	lines.append(bonuses_text)
	if set_id != "":
		var set_name := Settings.t("EQUIP_SET_%s_NAME" % set_id, set_id.replace("_", " "))
		lines.append("[i]%s[/i]" % tr("UI_EQUIP_SET_PREFIX").format({"name": set_name}))
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


func _spacer() -> Control:
	var s = Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s

## Map-screen character info + equipment management page. Shows HP, gold,
## floor, relics, equipped gear, inventory, active set tiers, and attributes
## in one consolidated view. Built dynamically; attached as a direct child of
## map_scene. Listens to RunManager state signals for live refresh.
extends Control
class_name EquipmentPanel

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const EQUIPMENT_ICON = preload("res://run_system/ui/equipment_icon.gd")

var _slot_rows: Dictionary = {}  # slot → { icon, name_label, action_button }
var _inventory_container: VBoxContainer
var _inventory_title: Label  # Direct field reference for the inventory header (replaces a fragile tree search).
var _sets_container: VBoxContainer
var _relics_container: VBoxContainer
var _vitals_label: Label  # HP / Gold / Floor summary line
var _stats_label: Label
var _status_label: Label  # transient "INVENTORY FULL" etc.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	RunManager.equipment_changed.connect(_refresh)
	RunManager.health_changed.connect(_on_health_changed)
	RunManager.resources_changed.connect(_on_resources_changed)
	RunManager.relics_updated.connect(_refresh)
	_refresh()


func _on_health_changed(_current: int, _maximum: int) -> void:
	_refresh()


func _on_resources_changed(_gold: int, _core: int) -> void:
	_refresh()


func _build() -> void:
	# Full-screen page background. This is a screen, not a modal overlay.
	var bg := ColorRect.new()
	bg.color = Color(0.045, 0.038, 0.030, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var page_margin := MarginContainer.new()
	page_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	page_margin.add_theme_constant_override("margin_left", 54)
	page_margin.add_theme_constant_override("margin_right", 54)
	page_margin.add_theme_constant_override("margin_top", 42)
	page_margin.add_theme_constant_override("margin_bottom", 42)
	add_child(page_margin)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_margin.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vroot := VBoxContainer.new()
	vroot.add_theme_constant_override("separation", 12)
	vroot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vroot)

	# Title + close
	var header := HBoxContainer.new()
	vroot.add_child(header)
	var title := Label.new()
	title.text = tr("UI_EQUIP_TITLE_CHARACTER")
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	header.add_child(title)
	header.add_child(_spacer())
	var close_btn := Button.new()
	close_btn.text = tr("UI_EQUIP_BACK_TO_MAP")
	close_btn.custom_minimum_size = Vector2(160, 42)
	T.apply_button_theme(close_btn)
	close_btn.pressed.connect(queue_free)
	header.add_child(close_btn)

	# Vitals row (HP / Gold / Floor) — populated by _refresh
	_vitals_label = Label.new()
	_vitals_label.add_theme_font_size_override("font_size", 16)
	_vitals_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.7))
	vroot.add_child(_vitals_label)

	# Two-column body
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vroot.add_child(body)

	# Left column: slots
	var slots_col := VBoxContainer.new()
	slots_col.add_theme_constant_override("separation", 8)
	slots_col.custom_minimum_size = Vector2(420, 0)
	slots_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(slots_col)
	var slots_title := Label.new()
	slots_title.text = tr("UI_EQUIP_SLOTS")
	slots_title.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	slots_col.add_child(slots_title)
	for slot in RunManager.EQUIPMENT_SLOTS:
		_slot_rows[slot] = _build_slot_row(slot, slots_col)

	# Right column: inventory
	var inv_col := VBoxContainer.new()
	inv_col.add_theme_constant_override("separation", 8)
	inv_col.custom_minimum_size = Vector2(420, 0)
	inv_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(inv_col)
	_inventory_title = Label.new()
	_inventory_title.name = "InventoryTitle"
	_inventory_title.text = tr("UI_EQUIP_INVENTORY_COUNT").format(
		{"n": 0, "max": RunManager.MAX_INVENTORY}
	)
	_inventory_title.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	inv_col.add_child(_inventory_title)
	_inventory_container = VBoxContainer.new()
	_inventory_container.add_theme_constant_override("separation", 6)
	inv_col.add_child(_inventory_container)

	# Active sets section
	var sep1 := HSeparator.new()
	vroot.add_child(sep1)
	var sets_title := Label.new()
	sets_title.text = tr("UI_EQUIP_ACTIVE_SETS")
	sets_title.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	vroot.add_child(sets_title)
	_sets_container = VBoxContainer.new()
	_sets_container.add_theme_constant_override("separation", 4)
	vroot.add_child(_sets_container)

	# Relics section
	var sep_relics := HSeparator.new()
	vroot.add_child(sep_relics)
	var relics_title := Label.new()
	relics_title.text = tr("UI_EQUIP_RELICS")
	relics_title.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	vroot.add_child(relics_title)
	_relics_container = VBoxContainer.new()
	_relics_container.add_theme_constant_override("separation", 2)
	vroot.add_child(_relics_container)

	# Stats row
	var sep2 := HSeparator.new()
	vroot.add_child(sep2)
	_stats_label = Label.new()
	_stats_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	vroot.add_child(_stats_label)

	# Transient status (errors)
	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.3))
	vroot.add_child(_status_label)


func _build_slot_row(slot: String, parent: VBoxContainer) -> Dictionary:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", T.reward_row_style(T.PANEL_BG, T.PANEL_BORDER))
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(frame)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	frame.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var icon := EQUIPMENT_ICON.new()
	row.add_child(icon)

	var label := Label.new()
	label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	label.custom_minimum_size = Vector2(220, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var unequip := Button.new()
	unequip.text = tr("UI_EQUIP_UNEQUIP")
	unequip.custom_minimum_size = Vector2(118, 40)
	T.apply_button_theme(unequip)
	unequip.pressed.connect(_on_unequip_pressed.bind(slot))
	row.add_child(unequip)

	return {"icon": icon, "name_label": label, "action_button": unequip}


func _refresh() -> void:
	# Vitals: HP / Gold / Floor. Floor is 0-indexed internally; display as 1-based.
	if _vitals_label:
		var floor_display = max(1, RunManager.current_floor + 1)
		_vitals_label.text = (
			tr("UI_EQUIP_VITALS")
			. format(
				{
					"hp": RunManager.current_health,
					"max": RunManager.max_health,
					"gold": RunManager.gold,
					"floor": floor_display,
				}
			)
		)

	# Slots
	for slot in RunManager.EQUIPMENT_SLOTS:
		var row = _slot_rows[slot]
		var item_id: String = RunManager.equipped_items.get(slot, "")
		var slot_label := _slot_label(slot)
		if item_id == "":
			row["icon"].set_empty(slot)
			row["icon"].set_hover_tooltip("[b]%s[/b]\n%s" % [slot_label, tr("UI_EQUIP_EMPTY_SLOT")])
			row["name_label"].text = "%s: %s" % [slot_label, tr("UI_EQUIP_EMPTY")]
			row["action_button"].visible = false
		else:
			var data = RunManager.get_equipment_data(item_id)
			var item_name := Settings.t("EQUIP_%s_NAME" % item_id, str(data.get("name", item_id)))
			row["icon"].set_equipment(slot, item_name, str(data.get("sprite", "")))
			row["icon"].set_hover_tooltip(_build_equipment_tooltip(data, slot))
			row["action_button"].visible = true
			row["name_label"].text = (
				"%s: %s\n%s"
				% [
					slot_label,
					item_name,
					_format_bonuses(data.get("bonuses", {})),
				]
			)

	# Inventory title
	if _inventory_title:
		_inventory_title.text = tr("UI_EQUIP_INVENTORY_COUNT").format(
			{"n": RunManager.inventory_items.size(), "max": RunManager.MAX_INVENTORY}
		)

	# Inventory rows (rebuild every refresh — simpler than diffing)
	for child in _inventory_container.get_children():
		child.queue_free()
	for i in range(RunManager.inventory_items.size()):
		var item_id: String = RunManager.inventory_items[i]
		_inventory_container.add_child(_build_inventory_row(item_id, i))

	# Active sets
	for child in _sets_container.get_children():
		child.queue_free()
	var active_tiers: Dictionary = RunManager.get_active_set_tiers()
	for set_id in active_tiers.keys():
		_sets_container.add_child(_build_set_row(str(set_id), int(active_tiers[set_id])))

	# Relics
	for child in _relics_container.get_children():
		child.queue_free()
	if RunManager.relics.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = tr("UI_EQUIP_NONE_YET")
		none_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_relics_container.add_child(none_lbl)
	else:
		for relic_id in RunManager.relics:
			_relics_container.add_child(_build_relic_row(str(relic_id)))

	# Stats
	var p = RunManager.player_attributes
	_stats_label.text = (
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
	_status_label.text = ""


func _build_inventory_row(item_id: String, index: int) -> Control:
	var data = RunManager.get_equipment_data(item_id)
	var slot = str(data.get("slot", "head"))

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", T.reward_row_style(T.PANEL_BG, T.PANEL_BORDER))
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	frame.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var item_name := Settings.t("EQUIP_%s_NAME" % item_id, str(data.get("name", item_id)))
	var icon := EQUIPMENT_ICON.new()
	icon.set_equipment(slot, item_name, str(data.get("sprite", "")))
	icon.set_hover_tooltip(_build_equipment_tooltip(data, slot))
	row.add_child(icon)

	var info := Label.new()
	info.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	info.custom_minimum_size = Vector2(200, 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var set_tag = ""
	var set_id_str := str(data.get("set_id", ""))
	if set_id_str != "":
		set_tag = "  [%s]" % Settings.t("EQUIP_SET_%s_NAME" % set_id_str, set_id_str)
	info.text = "%s\n%s%s" % [item_name, _format_bonuses(data.get("bonuses", {})), set_tag]
	row.add_child(info)

	var equip_btn := Button.new()
	equip_btn.text = tr("UI_EQUIP_EQUIP")
	equip_btn.custom_minimum_size = Vector2(96, 40)
	T.apply_button_theme(equip_btn)
	equip_btn.pressed.connect(_on_equip_pressed.bind(item_id, slot, index))
	row.add_child(equip_btn)

	var discard_btn := Button.new()
	discard_btn.text = tr("UI_EQUIP_DISCARD")
	discard_btn.custom_minimum_size = Vector2(112, 40)
	T.apply_button_theme(discard_btn)
	discard_btn.pressed.connect(_on_discard_pressed.bind(index, discard_btn))
	row.add_child(discard_btn)

	return frame


func _build_relic_row(relic_id: String) -> Label:
	var data = RunManager.get_relic_data(relic_id)
	var title = Settings.t("RELIC_%s_TITLE" % relic_id, str(data.get("title", relic_id)))
	var description = Settings.t("RELIC_%s_DESC" % relic_id, str(data.get("description", "")))
	var row := Label.new()
	row.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.text = "%s: %s" % [title, description]
	return row


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

	# Tier descriptions, highlighted if active
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


func _on_equip_pressed(item_id: String, slot: String, _inventory_index: int) -> void:
	if not RunManager.equip_to_slot(item_id, slot):
		_status_label.text = tr("UI_EQUIP_FULL_SWAP")


func _on_unequip_pressed(slot: String) -> void:
	if not RunManager.unequip_slot(slot):
		_status_label.text = tr("UI_EQUIP_FULL_UNEQUIP")


func _on_discard_pressed(index: int, btn: Button) -> void:
	if btn:
		btn.disabled = true  # Prevent same-frame double-click discarding wrong index after refresh.
	RunManager.discard_from_inventory(index)


func _format_bonuses(bonuses) -> String:
	if typeof(bonuses) != TYPE_DICTIONARY or bonuses.is_empty():
		return tr("UI_EQUIP_NO_BONUSES")
	var parts: Array = []
	for attr in bonuses.keys():
		parts.append("+%d %s" % [int(bonuses[attr]), str(attr).substr(0, 3)])
	return ", ".join(parts)


## Rich tooltip text for an equipment item — name, slot, rarity, full
## attribute bonuses, optional set tag, and description.
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


## Localized display label for an equipment slot id (head/chest/weapon/hands/
## accessory). Falls back to the upper-cased raw id for any unknown slot.
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


func _spacer() -> Control:
	var s = Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s

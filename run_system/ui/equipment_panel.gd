## Map-screen equipment management modal. Built dynamically; attached to a
## CanvasLayer. Listens to RunManager.equipment_changed for live refresh.
extends Control
class_name EquipmentPanel

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const EQUIPMENT_ICON = preload("res://run_system/ui/equipment_icon.gd")

var _slot_rows: Dictionary = {}        # slot → { icon, name_label, action_button }
var _inventory_container: VBoxContainer
var _inventory_title: Label  # Direct field reference for the inventory header (replaces a fragile tree search).
var _sets_container: VBoxContainer
var _stats_label: Label
var _status_label: Label                # transient "INVENTORY FULL" etc.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	RunManager.equipment_changed.connect(_refresh)
	_refresh()


func _build() -> void:
	# Dim background
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Central panel
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	panel.custom_minimum_size = Vector2(900, 640)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vroot := VBoxContainer.new()
	vroot.add_theme_constant_override("separation", 12)
	margin.add_child(vroot)

	# Title + close
	var header := HBoxContainer.new()
	vroot.add_child(header)
	var title := Label.new()
	title.text = "EQUIPMENT"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	header.add_child(title)
	header.add_child(_spacer())
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.pressed.connect(queue_free)
	header.add_child(close_btn)

	# Two-column body
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	vroot.add_child(body)

	# Left column: slots
	var slots_col := VBoxContainer.new()
	slots_col.add_theme_constant_override("separation", 8)
	slots_col.custom_minimum_size = Vector2(420, 0)
	body.add_child(slots_col)
	var slots_title := Label.new()
	slots_title.text = "── SLOTS ──"
	slots_title.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	slots_col.add_child(slots_title)
	for slot in RunManager.EQUIPMENT_SLOTS:
		_slot_rows[slot] = _build_slot_row(slot, slots_col)

	# Right column: inventory
	var inv_col := VBoxContainer.new()
	inv_col.add_theme_constant_override("separation", 8)
	inv_col.custom_minimum_size = Vector2(420, 0)
	body.add_child(inv_col)
	_inventory_title = Label.new()
	_inventory_title.name = "InventoryTitle"
	_inventory_title.text = "── INVENTORY (0/8) ──"
	_inventory_title.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	inv_col.add_child(_inventory_title)
	_inventory_container = VBoxContainer.new()
	_inventory_container.add_theme_constant_override("separation", 6)
	inv_col.add_child(_inventory_container)

	# Active sets section
	var sep1 := HSeparator.new()
	vroot.add_child(sep1)
	var sets_title := Label.new()
	sets_title.text = "── ACTIVE SETS ──"
	sets_title.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	vroot.add_child(sets_title)
	_sets_container = VBoxContainer.new()
	_sets_container.add_theme_constant_override("separation", 4)
	vroot.add_child(_sets_container)

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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var icon := EQUIPMENT_ICON.new()
	row.add_child(icon)

	var label := Label.new()
	label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	label.custom_minimum_size = Vector2(220, 0)
	row.add_child(label)

	var unequip := Button.new()
	unequip.text = "UNEQUIP"
	unequip.pressed.connect(_on_unequip_pressed.bind(slot))
	row.add_child(unequip)

	return { "icon": icon, "name_label": label, "action_button": unequip }


func _refresh() -> void:
	# Slots
	for slot in RunManager.EQUIPMENT_SLOTS:
		var row = _slot_rows[slot]
		var item_id: String = RunManager.equipped_items.get(slot, "")
		if item_id == "":
			row["icon"].set_empty(slot)
			row["name_label"].text = "%s — (empty)" % slot.to_upper()
			row["action_button"].visible = false
		else:
			var data = RunManager.get_equipment_data(item_id)
			row["icon"].set_equipment(slot, str(data.get("name", item_id)), str(data.get("sprite", "")))
			row["name_label"].text = "%s — %s\n%s" % [
				slot.to_upper(),
				str(data.get("name", item_id)),
				_format_bonuses(data.get("bonuses", {})),
			]
			row["action_button"].visible = true

	# Inventory title
	if _inventory_title:
		_inventory_title.text = "── INVENTORY (%d/%d) ──" % [RunManager.inventory_items.size(), RunManager.MAX_INVENTORY]

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

	# Stats
	var p = RunManager.player_attributes
	_stats_label.text = "STR:%d  CON:%d  INT:%d  LUC:%d  CHA:%d" % [
		int(p.get("strength", 0)), int(p.get("constitution", 0)),
		int(p.get("intelligence", 0)), int(p.get("luck", 0)), int(p.get("charm", 0)),
	]
	_status_label.text = ""


func _build_inventory_row(item_id: String, index: int) -> HBoxContainer:
	var data = RunManager.get_equipment_data(item_id)
	var slot = str(data.get("slot", "head"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var icon := EQUIPMENT_ICON.new()
	icon.set_equipment(slot, str(data.get("name", item_id)), str(data.get("sprite", "")))
	row.add_child(icon)

	var info := Label.new()
	info.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	info.custom_minimum_size = Vector2(200, 0)
	var set_tag = ""
	if str(data.get("set_id", "")) != "":
		set_tag = "  [%s]" % str(data.get("set_id"))
	info.text = "%s\n%s%s" % [str(data.get("name", item_id)), _format_bonuses(data.get("bonuses", {})), set_tag]
	row.add_child(info)

	var equip_btn := Button.new()
	equip_btn.text = "EQUIP"
	equip_btn.pressed.connect(_on_equip_pressed.bind(item_id, slot, index))
	row.add_child(equip_btn)

	var discard_btn := Button.new()
	discard_btn.text = "DISCARD"
	discard_btn.pressed.connect(_on_discard_pressed.bind(index, discard_btn))
	row.add_child(discard_btn)

	return row


func _build_set_row(set_id: String, count: int) -> HBoxContainer:
	var set_data = RunManager.get_equipment_set_data(set_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_lbl := Label.new()
	name_lbl.text = "%s  %d/5" % [str(set_data.get("name", set_id)), count]
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
			var label = Label.new()
			label.text = "[%d] %s" % [threshold, str(tier.get("label", ""))]
			if count >= threshold:
				label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
			else:
				label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			row.add_child(label)

	return row


func _on_equip_pressed(item_id: String, slot: String, _inventory_index: int) -> void:
	if not RunManager.equip_to_slot(item_id, slot):
		_status_label.text = "INVENTORY FULL — discard something first to swap"


func _on_unequip_pressed(slot: String) -> void:
	if not RunManager.unequip_slot(slot):
		_status_label.text = "INVENTORY FULL — discard something first to unequip"


func _on_discard_pressed(index: int, btn: Button) -> void:
	if btn:
		btn.disabled = true  # Prevent same-frame double-click discarding wrong index after refresh.
	RunManager.discard_from_inventory(index)


func _format_bonuses(bonuses) -> String:
	if typeof(bonuses) != TYPE_DICTIONARY or bonuses.is_empty():
		return "(no bonuses)"
	var parts: Array = []
	for attr in bonuses.keys():
		parts.append("+%d %s" % [int(bonuses[attr]), str(attr).substr(0, 3)])
	return ", ".join(parts)


func _spacer() -> Control:
	var s = Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s

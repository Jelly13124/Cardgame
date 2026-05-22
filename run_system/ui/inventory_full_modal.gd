## Modal shown when an incoming equipment drop would overflow inventory.
## Player picks one bag item to discard, or skips the new item.
extends Control
class_name InventoryFullModal

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const EQUIPMENT_ICON = preload("res://run_system/ui/equipment_icon.gd")

signal resolved(took_item: bool)

var _incoming_item_id: String
var _selected_bag_index: int = -1
var _bag_buttons: Array[Button] = []


func setup(incoming_item_id: String) -> void:
	_incoming_item_id = incoming_item_id


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	panel.custom_minimum_size = Vector2(680, 480)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "INVENTORY FULL"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Pick something to discard, or skip the new equipment:"
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	vbox.add_child(subtitle)

	var bag_grid := GridContainer.new()
	bag_grid.columns = 4
	bag_grid.add_theme_constant_override("h_separation", 6)
	bag_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(bag_grid)
	for i in range(RunManager.inventory_items.size()):
		var btn := Button.new()
		var data = RunManager.get_equipment_data(RunManager.inventory_items[i])
		btn.text = str(data.get("name", RunManager.inventory_items[i]))
		btn.toggle_mode = true
		btn.pressed.connect(_on_bag_pressed.bind(i, btn))
		bag_grid.add_child(btn)
		_bag_buttons.append(btn)

	var incoming_box := HBoxContainer.new()
	incoming_box.add_theme_constant_override("separation", 8)
	vbox.add_child(incoming_box)
	var inc_label_l := Label.new()
	inc_label_l.text = "── INCOMING ──"
	inc_label_l.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	incoming_box.add_child(inc_label_l)
	var inc_data = RunManager.get_equipment_data(_incoming_item_id)
	var inc_icon = EQUIPMENT_ICON.new()
	inc_icon.set_equipment(str(inc_data.get("slot", "head")), str(inc_data.get("name", _incoming_item_id)), str(inc_data.get("sprite", "")))
	incoming_box.add_child(inc_icon)
	var inc_label := Label.new()
	inc_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	var set_tag := ""
	if str(inc_data.get("set_id", "")) != "":
		set_tag = "  [%s]" % str(inc_data.get("set_id"))
	inc_label.text = "%s%s" % [str(inc_data.get("name", _incoming_item_id)), set_tag]
	incoming_box.add_child(inc_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	vbox.add_child(actions)
	var discard_btn := Button.new()
	discard_btn.text = "DISCARD SELECTED"
	discard_btn.pressed.connect(_on_discard_selected)
	actions.add_child(discard_btn)
	var skip_btn := Button.new()
	skip_btn.text = "SKIP NEW ITEM"
	skip_btn.pressed.connect(_on_skip)
	actions.add_child(skip_btn)


func _on_bag_pressed(index: int, btn: Button) -> void:
	_selected_bag_index = index
	# Single-select: clear others
	for other in _bag_buttons:
		if other != btn and other.button_pressed:
			other.set_pressed_no_signal(false)


func _on_discard_selected() -> void:
	if _selected_bag_index < 0:
		return  # nothing selected, ignore
	RunManager.discard_from_inventory(_selected_bag_index)
	RunManager.add_to_inventory(_incoming_item_id)
	emit_signal("resolved", true)
	queue_free()


func _on_skip() -> void:
	emit_signal("resolved", false)
	queue_free()

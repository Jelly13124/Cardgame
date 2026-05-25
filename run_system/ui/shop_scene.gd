## The merchant shop. Loaded when player visits a `merchant` map node.
## Rolls a small visual stock (3 cards / 2 equipment / 1 relic) plus a
## remove-card service. Cards render via JsonCardFactory; equipment via
## EquipmentIcon; relics via their JSON `icon` field. Returns to map_scene
## via the LEAVE button.
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const EQUIPMENT_ICON = preload("res://run_system/ui/equipment_icon.gd")
const CARD_FACTORY_SCENE = preload("res://battle_scene/my_card_factory.tscn")

# --- Pricing (per rarity) ---
const CARD_PRICE := { "common": 70, "uncommon": 120, "rare": 200 }
const EQUIP_PRICE := { "common": 60, "uncommon": 100, "rare": 180 }
const RELIC_PRICE := 150
const REMOVE_CARD_PRICE := 75

const RARITY_COLORS := {
	"common": Color(0.85, 0.85, 0.85),
	"uncommon": Color(0.45, 0.8, 1.0),
	"rare": Color(1.0, 0.85, 0.35),
}

# Rolled stock — set once in _ready
var _stock_cards: Array = []        # [{card_id, rarity, price}]
var _stock_equipment: Array = []    # [{item_id, rarity, price}]
var _stock_relic: String = ""

var _card_factory: Node
var _gold_label: Label
var _remove_service_btn: Button
var _remove_card_picker: Control = null


func _ready() -> void:
	_card_factory = CARD_FACTORY_SCENE.instantiate()
	add_child(_card_factory)
	_card_factory.card_size = Vector2(160, 220)

	_roll_stock()
	_build_ui()
	RunManager.resources_changed.connect(_on_resources_changed)


func _on_resources_changed(_gold: int, _core: int) -> void:
	if _gold_label:
		_gold_label.text = "GOLD: %d" % RunManager.gold


# --- Stock rolling ---------------------------------------------------------

func _roll_stock() -> void:
	var card_pool := _list_cards_by_rarity()
	for rarity in ["common", "uncommon", "rare"]:
		var pool: Array = card_pool.get(rarity, [])
		if pool.is_empty():
			continue
		var pick: String = pool[randi() % pool.size()]
		_stock_cards.append({"card_id": pick, "rarity": rarity, "price": int(CARD_PRICE[rarity])})

	for rarity in ["common", "uncommon"]:
		var item_id = RunManager.roll_equipment_drop(rarity)
		if item_id != "":
			_stock_equipment.append({"item_id": item_id, "rarity": rarity, "price": int(EQUIP_PRICE[rarity])})

	_stock_relic = _roll_unowned_relic()


func _list_cards_by_rarity() -> Dictionary:
	var result := {"common": [], "uncommon": [], "rare": []}
	var dir = DirAccess.open("res://battle_scene/card_info/player/")
	if dir == null:
		return result
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var card_id := file_name.get_basename()
		if card_id.ends_with("_plus"):
			continue
		var data := _load_json("res://battle_scene/card_info/player/" + file_name)
		var rarity := str(data.get("rarity", "common"))
		if rarity in result:
			result[rarity].append(card_id)
	return result


func _roll_unowned_relic() -> String:
	var dir = DirAccess.open("res://run_system/data/relics/")
	if dir == null:
		return ""
	var candidates: Array[String] = []
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var relic_id := file_name.get_basename()
		if relic_id in RunManager.relics:
			continue
		candidates.append(relic_id)
	if candidates.is_empty():
		return ""
	return candidates[randi() % candidates.size()]


func _load_json(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


# --- UI build --------------------------------------------------------------

func _build_ui() -> void:
	# Backdrop — solid dark with subtle warmth
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.025, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Try to load optional codex-generated background art on top of solid color
	var bg_path := "res://run_system/assets/images/shop/shop_interior_bg.png"
	if ResourceLoader.exists(bg_path):
		var bg_img := TextureRect.new()
		bg_img.texture = load(bg_path)
		bg_img.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		bg_img.modulate = Color(1, 1, 1, 0.65)
		add_child(bg_img)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 60)
	root.add_theme_constant_override("margin_right", 60)
	root.add_theme_constant_override("margin_top", 30)
	root.add_theme_constant_override("margin_bottom", 30)
	add_child(root)

	var vroot := VBoxContainer.new()
	vroot.add_theme_constant_override("separation", 16)
	root.add_child(vroot)

	# Header row: title + gold
	var header := HBoxContainer.new()
	vroot.add_child(header)
	var title := Label.new()
	title.text = "THE MERCHANT"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_gold_label = Label.new()
	_gold_label.text = "GOLD: %d" % RunManager.gold
	_gold_label.add_theme_font_size_override("font_size", 26)
	_gold_label.add_theme_color_override("font_color", Color(1, 0.85, 0.24))
	header.add_child(_gold_label)

	# Scrollable body
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vroot.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	scroll.add_child(body)

	# Cards section
	body.add_child(_section_header("── CARDS ──"))
	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 24)
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(cards_row)
	for entry in _stock_cards:
		cards_row.add_child(_build_card_stall(entry))

	# Equipment + Relic side by side
	if not _stock_equipment.is_empty() or _stock_relic != "":
		var mid_row := HBoxContainer.new()
		mid_row.add_theme_constant_override("separation", 36)
		mid_row.alignment = BoxContainer.ALIGNMENT_CENTER
		body.add_child(mid_row)

		if not _stock_equipment.is_empty():
			var equip_col := VBoxContainer.new()
			equip_col.add_theme_constant_override("separation", 8)
			mid_row.add_child(equip_col)
			equip_col.add_child(_section_header("── EQUIPMENT ──"))
			var equip_row := HBoxContainer.new()
			equip_row.add_theme_constant_override("separation", 18)
			equip_col.add_child(equip_row)
			for entry in _stock_equipment:
				equip_row.add_child(_build_equipment_stall(entry))

		if _stock_relic != "":
			var relic_col := VBoxContainer.new()
			relic_col.add_theme_constant_override("separation", 8)
			mid_row.add_child(relic_col)
			relic_col.add_child(_section_header("── RELIC ──"))
			relic_col.add_child(_build_relic_stall(_stock_relic))

	# Services
	body.add_child(_section_header("── SERVICES ──"))
	body.add_child(_build_remove_service_row())

	# Footer: LEAVE button right-aligned
	var footer := HBoxContainer.new()
	vroot.add_child(footer)
	var fspacer := Control.new()
	fspacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(fspacer)
	var leave_btn := Button.new()
	leave_btn.text = "LEAVE"
	leave_btn.custom_minimum_size = Vector2(180, 56)
	leave_btn.add_theme_font_size_override("font_size", 20)
	leave_btn.pressed.connect(_on_leave_pressed)
	footer.add_child(leave_btn)


func _section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl


# --- Stall builders --------------------------------------------------------

func _build_card_stall(entry: Dictionary) -> Control:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 6)
	wrapper.custom_minimum_size = Vector2(200, 320)

	# Card visual
	var card_box := Control.new()
	card_box.custom_minimum_size = Vector2(180, 240)
	wrapper.add_child(card_box)

	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", T.panel_with_shadow(Color(0.09, 0.072, 0.055, 0.92), T.PANEL_BORDER, 3))
	card_box.add_child(frame)

	var card_id: String = str(entry["card_id"])
	var card = _card_factory.create_card(card_id, null)
	if card:
		if card.get_parent():
			card.get_parent().remove_child(card)
		card.can_be_interacted_with = false
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.position = Vector2(10, 10)
		card_box.add_child(card)

	# Price + BUY
	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override("separation", 10)
	wrapper.add_child(price_row)
	var price_lbl := Label.new()
	price_lbl.text = "%dg" % int(entry["price"])
	price_lbl.add_theme_font_size_override("font_size", 18)
	price_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.24))
	price_row.add_child(price_lbl)
	var buy_btn := Button.new()
	buy_btn.text = "BUY"
	buy_btn.custom_minimum_size = Vector2(100, 36)
	buy_btn.pressed.connect(_on_buy_card.bind(card_id, int(entry["price"]), buy_btn))
	price_row.add_child(buy_btn)

	return wrapper


func _build_equipment_stall(entry: Dictionary) -> Control:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 4)
	wrapper.custom_minimum_size = Vector2(180, 220)
	wrapper.alignment = BoxContainer.ALIGNMENT_CENTER

	var item_id: String = str(entry["item_id"])
	var data := RunManager.get_equipment_data(item_id)
	var slot := str(data.get("slot", "head"))

	# Icon centered
	var icon_holder := HBoxContainer.new()
	icon_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	wrapper.add_child(icon_holder)
	var icon := EQUIPMENT_ICON.new()
	icon.custom_minimum_size = Vector2(96, 96)
	icon_holder.add_child(icon)
	icon.set_equipment(slot, str(data.get("name", item_id)), str(data.get("sprite", "")))

	# Name
	var name_lbl := Label.new()
	name_lbl.text = str(data.get("name", item_id))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	wrapper.add_child(name_lbl)

	# Bonuses
	var bonus_lbl := Label.new()
	bonus_lbl.text = _format_bonuses(data.get("bonuses", {}))
	bonus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_lbl.add_theme_color_override("font_color", RARITY_COLORS.get(str(entry["rarity"]), Color.WHITE))
	wrapper.add_child(bonus_lbl)

	# Set tag if any
	if str(data.get("set_id", "")) != "":
		var set_lbl := Label.new()
		set_lbl.text = "[%s]" % str(data.get("set_id"))
		set_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		set_lbl.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
		wrapper.add_child(set_lbl)

	# Price + BUY
	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override("separation", 8)
	wrapper.add_child(price_row)
	var price_lbl := Label.new()
	price_lbl.text = "%dg" % int(entry["price"])
	price_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.24))
	price_row.add_child(price_lbl)
	var buy_btn := Button.new()
	buy_btn.text = "BUY"
	buy_btn.custom_minimum_size = Vector2(90, 32)
	buy_btn.pressed.connect(_on_buy_equipment.bind(item_id, int(entry["price"]), buy_btn))
	price_row.add_child(buy_btn)

	return wrapper


func _build_relic_stall(relic_id: String) -> Control:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 6)
	wrapper.custom_minimum_size = Vector2(260, 220)
	wrapper.alignment = BoxContainer.ALIGNMENT_CENTER

	var data := RunManager.get_relic_data(relic_id)

	# Icon centered
	var icon_holder := HBoxContainer.new()
	icon_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	wrapper.add_child(icon_holder)
	var icon_path: String = str(data.get("icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var tex := TextureRect.new()
		tex.texture = load(icon_path)
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.custom_minimum_size = Vector2(96, 96)
		tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_holder.add_child(tex)

	# Title
	var title := Label.new()
	title.text = str(data.get("title", relic_id))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	wrapper.add_child(title)

	# Description
	var desc := Label.new()
	desc.text = str(data.get("description", ""))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(240, 0)
	desc.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	wrapper.add_child(desc)

	# Price + BUY
	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override("separation", 10)
	wrapper.add_child(price_row)
	var price_lbl := Label.new()
	price_lbl.text = "%dg" % RELIC_PRICE
	price_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.24))
	price_row.add_child(price_lbl)
	var buy_btn := Button.new()
	buy_btn.text = "BUY"
	buy_btn.custom_minimum_size = Vector2(100, 36)
	buy_btn.pressed.connect(_on_buy_relic.bind(relic_id, RELIC_PRICE, buy_btn))
	price_row.add_child(buy_btn)

	return wrapper


func _build_remove_service_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var info := Label.new()
	info.text = "Remove a card from your deck"
	info.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	info.custom_minimum_size = Vector2(280, 0)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(info)

	var price_lbl := Label.new()
	price_lbl.text = "%dg" % REMOVE_CARD_PRICE
	price_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.24))
	row.add_child(price_lbl)

	_remove_service_btn = Button.new()
	_remove_service_btn.text = "REMOVE"
	_remove_service_btn.custom_minimum_size = Vector2(120, 40)
	_remove_service_btn.pressed.connect(_on_remove_service_pressed)
	row.add_child(_remove_service_btn)

	return row


# --- Purchase handlers -----------------------------------------------------

func _on_buy_card(card_id: String, price: int, btn: Button) -> void:
	if RunManager.purchase_card(card_id, price):
		_mark_sold(btn)


func _on_buy_equipment(item_id: String, price: int, btn: Button) -> void:
	if RunManager.purchase_equipment(item_id, price):
		_mark_sold(btn)


func _on_buy_relic(relic_id: String, price: int, btn: Button) -> void:
	if RunManager.purchase_relic(relic_id, price):
		_mark_sold(btn)


func _mark_sold(btn: Button) -> void:
	btn.disabled = true
	btn.text = "SOLD"


# --- Remove-card picker ----------------------------------------------------

func _on_remove_service_pressed() -> void:
	if RunManager.gold < REMOVE_CARD_PRICE:
		return
	if _remove_card_picker:
		return
	var picker := _build_card_remove_picker()
	_remove_card_picker = picker
	add_child(picker)


func _build_card_remove_picker() -> Control:
	var modal := Control.new()
	modal.name = "RemoveCardPicker"
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	panel.custom_minimum_size = Vector2(1100, 720)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "REMOVE A CARD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.55, 0.55))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Pick a card to permanently remove from your deck."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	vbox.add_child(subtitle)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(1040, 560)
	vbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(grid)

	for entry in RunManager.player_deck:
		var uid: String = str(entry.get("uid", ""))
		var card_id: String = str(entry.get("card_id", ""))
		if uid == "" or card_id == "":
			continue
		grid.add_child(_make_removal_slot(card_id, uid, modal))

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(actions)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.custom_minimum_size = Vector2(140, 42)
	cancel.pressed.connect(_on_remove_cancel.bind(modal))
	actions.add_child(cancel)

	return modal


func _make_removal_slot(card_id: String, uid: String, modal: Control) -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(180, 260)

	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", T.panel_with_shadow(Color(0.09, 0.072, 0.055, 0.92), T.PANEL_BORDER, 3))
	wrapper.add_child(frame)

	var card = _card_factory.create_card(card_id, null)
	if card:
		if card.get_parent():
			card.get_parent().remove_child(card)
		card.can_be_interacted_with = false
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.position = Vector2(10, 20)
		card.pivot_offset = Vector2(80, 110)
		wrapper.add_child(card)

	var button := Button.new()
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_on_remove_pick.bind(uid, modal))
	wrapper.add_child(button)

	if card:
		button.mouse_entered.connect(func():
			frame.add_theme_stylebox_override("panel", T.panel_with_shadow(Color(0.18, 0.06, 0.06, 0.96), Color(1.0, 0.4, 0.3), 3))
			var tween = create_tween()
			tween.tween_property(card, "scale", Vector2(1.06, 1.06), 0.10)
		)
		button.mouse_exited.connect(func():
			frame.add_theme_stylebox_override("panel", T.panel_with_shadow(Color(0.09, 0.072, 0.055, 0.92), T.PANEL_BORDER, 3))
			var tween = create_tween()
			tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.10)
		)

	return wrapper


func _on_remove_pick(uid: String, modal: Control) -> void:
	if RunManager.purchase_card_removal(uid, REMOVE_CARD_PRICE):
		_mark_sold(_remove_service_btn)
	_remove_card_picker = null
	modal.queue_free()


func _on_remove_cancel(modal: Control) -> void:
	_remove_card_picker = null
	modal.queue_free()


# --- Leave -----------------------------------------------------------------

func _on_leave_pressed() -> void:
	get_tree().change_scene_to_file(RunManager.MAP_SCENE)


# --- Helpers ---------------------------------------------------------------

func _format_bonuses(bonuses) -> String:
	if typeof(bonuses) != TYPE_DICTIONARY or bonuses.is_empty():
		return "(no bonuses)"
	var parts: Array = []
	for attr in bonuses.keys():
		parts.append("+%d %s" % [int(bonuses[attr]), str(attr).substr(0, 3).to_upper()])
	return ", ".join(parts)

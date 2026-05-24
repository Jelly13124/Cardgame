## The merchant shop. Loaded when player visits a `merchant` map node.
## Rolls a small stock (3 cards / 2 equipment / 1 relic) plus a remove-card
## service, all gated by gold. Returns to map_scene via LEAVE button.
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const EQUIPMENT_ICON = preload("res://run_system/ui/equipment_icon.gd")

# --- Pricing (per rarity) ---
const CARD_PRICE := { "common": 70, "uncommon": 120, "rare": 200 }
const EQUIP_PRICE := { "common": 60, "uncommon": 100, "rare": 180 }
const RELIC_PRICE := 150
const REMOVE_CARD_PRICE := 75

# Rolled stock — set once in _ready, consumed by purchases
var _stock_cards: Array = []        # [{card_id, rarity, price}]
var _stock_equipment: Array = []    # [{item_id, rarity, price}]
var _stock_relic: String = ""       # single relic id
var _gold_label: Label
var _remove_service_btn: Button
var _remove_card_picker: Control = null


func _ready() -> void:
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
		# Exclude _plus variants from shop pool — player upgrades via rest/shop service
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
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.025, 0.02, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 60)
	root.add_theme_constant_override("margin_right", 60)
	root.add_theme_constant_override("margin_top", 30)
	root.add_theme_constant_override("margin_bottom", 30)
	add_child(root)

	var vroot := VBoxContainer.new()
	vroot.add_theme_constant_override("separation", 12)
	root.add_child(vroot)

	# Header row: title + gold
	var header := HBoxContainer.new()
	vroot.add_child(header)
	var title := Label.new()
	title.text = "THE MERCHANT"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_gold_label = Label.new()
	_gold_label.text = "GOLD: %d" % RunManager.gold
	_gold_label.add_theme_font_size_override("font_size", 24)
	_gold_label.add_theme_color_override("font_color", Color(1, 0.85, 0.24))
	header.add_child(_gold_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vroot.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)

	# Cards section
	body.add_child(_section_header("── CARDS ──"))
	for entry in _stock_cards:
		body.add_child(_build_card_row(entry))

	# Equipment section
	if not _stock_equipment.is_empty():
		body.add_child(_section_header("── EQUIPMENT ──"))
		for entry in _stock_equipment:
			body.add_child(_build_equipment_row(entry))

	# Relic section
	if _stock_relic != "":
		body.add_child(_section_header("── RELIC ──"))
		body.add_child(_build_relic_row(_stock_relic))

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
	leave_btn.custom_minimum_size = Vector2(160, 50)
	leave_btn.pressed.connect(_on_leave_pressed)
	footer.add_child(leave_btn)


func _section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	return lbl


func _build_card_row(entry: Dictionary) -> HBoxContainer:
	var data := _load_json("res://battle_scene/card_info/player/" + str(entry["card_id"]) + ".json")
	return _build_purchase_row(
		str(data.get("title", entry["card_id"])),
		str(entry["rarity"]),
		str(data.get("description", "")),
		int(entry["price"]),
		func(btn: Button): _on_buy_card(str(entry["card_id"]), int(entry["price"]), btn),
	)


func _build_equipment_row(entry: Dictionary) -> HBoxContainer:
	var data := RunManager.get_equipment_data(str(entry["item_id"]))
	var bonuses_str := _format_bonuses(data.get("bonuses", {}))
	var set_tag := ""
	if str(data.get("set_id", "")) != "":
		set_tag = "  [%s]" % str(data.get("set_id"))
	return _build_purchase_row(
		str(data.get("name", entry["item_id"])),
		str(entry["rarity"]),
		"%s%s" % [bonuses_str, set_tag],
		int(entry["price"]),
		func(btn: Button): _on_buy_equipment(str(entry["item_id"]), int(entry["price"]), btn),
	)


func _build_relic_row(relic_id: String) -> HBoxContainer:
	var data := RunManager.get_relic_data(relic_id)
	return _build_purchase_row(
		str(data.get("title", relic_id)),
		"relic",
		str(data.get("description", "")),
		RELIC_PRICE,
		func(btn: Button): _on_buy_relic(relic_id, RELIC_PRICE, btn),
	)


func _build_purchase_row(name: String, rarity: String, sub: String, price: int, on_buy: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 56)

	var info := Label.new()
	info.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.text = "%s  (%s)\n  %s" % [name, rarity, sub]
	row.add_child(info)

	var price_lbl := Label.new()
	price_lbl.text = "%dg" % price
	price_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.24))
	price_lbl.custom_minimum_size = Vector2(70, 0)
	row.add_child(price_lbl)

	var buy_btn := Button.new()
	buy_btn.text = "BUY"
	buy_btn.custom_minimum_size = Vector2(100, 40)
	buy_btn.pressed.connect(on_buy.bind(buy_btn))
	row.add_child(buy_btn)

	return row


func _build_remove_service_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 56)

	var info := Label.new()
	info.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.text = "Remove a card from your deck (one-shot per visit)."
	row.add_child(info)

	var price_lbl := Label.new()
	price_lbl.text = "%dg" % REMOVE_CARD_PRICE
	price_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.24))
	price_lbl.custom_minimum_size = Vector2(70, 0)
	row.add_child(price_lbl)

	_remove_service_btn = Button.new()
	_remove_service_btn.text = "REMOVE"
	_remove_service_btn.custom_minimum_size = Vector2(100, 40)
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
	# Note: if inventory full, purchase silently fails. Player must visit
	# CHARACTER panel and discard something, then retry. No modal here.


func _on_buy_relic(relic_id: String, price: int, btn: Button) -> void:
	if RunManager.purchase_relic(relic_id, price):
		_mark_sold(btn)


func _mark_sold(btn: Button) -> void:
	btn.disabled = true
	btn.text = "SOLD"


func _on_remove_service_pressed() -> void:
	if RunManager.gold < REMOVE_CARD_PRICE:
		return
	# Open card picker (any card; ALL deck cards are valid targets)
	if _remove_card_picker:
		return  # already open
	var picker := _build_card_remove_picker()
	_remove_card_picker = picker
	add_child(picker)


func _build_card_remove_picker() -> Control:
	var modal := Control.new()
	modal.name = "RemoveCardPicker"
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	panel.custom_minimum_size = Vector2(700, 480)
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
	title.text = "REMOVE A CARD"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.55, 0.55))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Pick a card to permanently remove from your deck."
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	vbox.add_child(subtitle)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(660, 340)
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for entry in RunManager.player_deck:
		var uid: String = str(entry.get("uid", ""))
		var card_id: String = str(entry.get("card_id", ""))
		var data := _load_json("res://battle_scene/card_info/player/" + card_id + ".json")
		var btn := Button.new()
		btn.text = str(data.get("title", card_id))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 42)
		btn.pressed.connect(_on_remove_pick.bind(uid, modal))
		list.add_child(btn)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(actions)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.custom_minimum_size = Vector2(120, 36)
	cancel.pressed.connect(_on_remove_cancel.bind(modal))
	actions.add_child(cancel)

	return modal


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
		parts.append("+%d %s" % [int(bonuses[attr]), str(attr).substr(0, 3)])
	return ", ".join(parts)

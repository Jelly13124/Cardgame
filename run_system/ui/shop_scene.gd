## The merchant shop. Loaded when player visits a `merchant` map node.
## Rolls a visual stock (6 cards / 3 equipment / 3 relics) plus a
## remove-card service. Cards render via JsonCardFactory; equipment via
## EquipmentIcon; relics via their JSON `icon` field. Returns to map_scene
## via the LEAVE button.
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const EQUIPMENT_ICON = preload("res://run_system/ui/equipment_icon.gd")
const CARD_FACTORY_SCENE = preload("res://battle_scene/my_card_factory.tscn")
# Lazy-loaded at call site to avoid map→shop→map cyclic preload.
const MAP_SCENE_PATH := "res://run_system/ui/map_scene.tscn"
const SHOP_BACKGROUND_PATH := "res://run_system/assets/images/shop/shop_interior_bg.png"
const SHOPKEEPER_PATH := "res://run_system/assets/images/shop/shopkeeper.png"

# --- Pricing (per rarity) ---
const CARD_PRICE := {"common": 70, "uncommon": 120, "rare": 200}
const EQUIP_PRICE := {"common": 60, "uncommon": 100, "rare": 180}
const RELIC_PRICE := 150
const REMOVE_CARD_PRICE := 75
const SHOP_CARD_COUNT := 6
const SHOP_EQUIPMENT_COUNT := 3
const SHOP_RELIC_COUNT := 3
const CARD_RARITY_SEQUENCE := ["common", "common", "uncommon", "common", "uncommon", "rare"]
const EQUIPMENT_RARITY_SEQUENCE := ["common", "uncommon", "rare"]

const SHOP_BOARD_BG := Color(0.055, 0.040, 0.032, 0.94)
const SHOP_PANEL_BG := Color(0.080, 0.055, 0.040, 0.92)
const SHOP_PANEL_BG_DARK := Color(0.045, 0.035, 0.030, 0.96)
const SHOP_PANEL_BORDER := Color(0.55, 0.30, 0.13, 1.0)
const SHOP_PRICE := Color(1.0, 0.84, 0.18)

const RARITY_COLORS := {
	"common": Color(0.85, 0.85, 0.85),
	"uncommon": Color(0.45, 0.8, 1.0),
	"rare": Color(1.0, 0.85, 0.35),
}

# Rolled stock — set once in _ready
var _stock_cards: Array = []  # [{card_id, rarity, price}]
var _stock_equipment: Array = []  # [{item_id, rarity, price}]
var _stock_relics: Array = []  # [{relic_id, price}]
var _remove_price: int = 75


## Apply Scrap Workshop discount to a base price. Always rounds up so
## the player never gets things free due to rounding.
func _discounted_price(base_cost: int) -> int:
	var bias = RunManager._get_meta_effect_value("scrap_workshop")
	var multiplier := float(bias.get("multiplier", 1.0))
	# Charm lowers merchant prices (floored at 0.60x), stacking with the
	# Scrap Workshop discount and the ascension surcharge below.
	var price: float = float(base_cost) * multiplier * RunManager.charm_shop_mult()
	# Ascension A4+: +10% surcharge ON TOP of any Scrap Workshop discount.
	if RunManager.ascension >= 4:
		price *= 1.10
	return int(ceil(price))


var _card_factory: Node
var _gold_label: Label
var _remove_service_btn: Button
var _remove_card_picker: Control = null


func _ready() -> void:
	_card_factory = CARD_FACTORY_SCENE.instantiate()
	add_child(_card_factory)
	# play_card.tscn is intrinsically 208x286; match it (cards scaled back to the old
	# 160x220 footprint at placement so the stalls/remove-service layout still fits).
	_card_factory.card_size = Vector2(208, 286)

	_roll_stock()
	_build_ui()
	RunManager.resources_changed.connect(_on_resources_changed)
	# Gold now lives in the backpack — refresh the label whenever the backpack
	# changes (a purchase spends gold via backpack mutation, not resources_changed).
	RunManager.backpack_changed.connect(_refresh_gold_label)


func _on_resources_changed(_gold: int, _core: int) -> void:
	_refresh_gold_label()


func _refresh_gold_label() -> void:
	if _gold_label:
		_gold_label.text = "%d" % RunManager.total_gold()


# --- Stock rolling ---------------------------------------------------------


func _roll_stock() -> void:
	_stock_cards.clear()
	_stock_equipment.clear()
	_stock_relics.clear()

	var card_pool := _list_cards_by_rarity()
	for rarity in CARD_RARITY_SEQUENCE:
		var pick := _take_random_from_pool(card_pool, rarity)
		if pick == "":
			continue
		_stock_cards.append(
			{"card_id": pick, "rarity": rarity, "price": _discounted_price(int(CARD_PRICE[rarity]))}
		)

	while _stock_cards.size() < SHOP_CARD_COUNT:
		var fallback_card := _take_random_from_any_pool(card_pool, CARD_RARITY_SEQUENCE)
		if fallback_card.is_empty():
			break
		var fallback_rarity := str(fallback_card["rarity"])
		_stock_cards.append(
			{
				"card_id": str(fallback_card["id"]),
				"rarity": fallback_rarity,
				"price": _discounted_price(int(CARD_PRICE[fallback_rarity]))
			}
		)

	var equipment_pool := _list_equipment_by_rarity()
	for rarity in EQUIPMENT_RARITY_SEQUENCE:
		var item_id := _take_random_from_pool(equipment_pool, rarity)
		if item_id == "":
			continue
		_stock_equipment.append(_make_equipment_stock_entry(item_id, rarity))

	while _stock_equipment.size() < SHOP_EQUIPMENT_COUNT:
		var fallback_equipment := _take_random_from_any_pool(
			equipment_pool, EQUIPMENT_RARITY_SEQUENCE
		)
		if fallback_equipment.is_empty():
			break
		_stock_equipment.append(
			_make_equipment_stock_entry(
				str(fallback_equipment["id"]), str(fallback_equipment["rarity"])
			)
		)

	var relic_pool := _list_unowned_relics()
	while _stock_relics.size() < SHOP_RELIC_COUNT and not relic_pool.is_empty():
		var index := randi() % relic_pool.size()
		var relic_id := str(relic_pool[index])
		relic_pool.remove_at(index)
		_stock_relics.append({"relic_id": relic_id, "price": _discounted_price(RELIC_PRICE)})

	_remove_price = _discounted_price(REMOVE_CARD_PRICE)


func _take_random_from_pool(pools: Dictionary, rarity: String) -> String:
	var pool: Array = pools.get(rarity, [])
	if pool.is_empty():
		return ""
	var index := randi() % pool.size()
	var pick := str(pool[index])
	pool.remove_at(index)
	pools[rarity] = pool
	return pick


func _take_random_from_any_pool(pools: Dictionary, rarity_order: Array) -> Dictionary:
	var available: Array = []
	for rarity_value in rarity_order:
		var candidate_rarity := str(rarity_value)
		var pool: Array = pools.get(candidate_rarity, [])
		if not pool.is_empty() and not available.has(candidate_rarity):
			available.append(candidate_rarity)
	if available.is_empty():
		return {}
	var selected_rarity := str(available[randi() % available.size()])
	return {"id": _take_random_from_pool(pools, selected_rarity), "rarity": selected_rarity}


func _make_equipment_stock_entry(item_id: String, rarity: String) -> Dictionary:
	var price_key := rarity
	if not EQUIP_PRICE.has(price_key):
		price_key = "common"
	return {
		"item_id": item_id,
		"rarity": rarity,
		"price": _discounted_price(int(EQUIP_PRICE[price_key]))
	}


func _list_cards_by_rarity() -> Dictionary:
	var result := {"common": [], "uncommon": [], "rare": []}
	# Block other heroes' exclusive cards (e.g. the Feng Shui Master's yin/yang
	# cards must not appear in Cowboy Bill's shop).
	var hero_id := str(RunManager.current_hero_id)
	var blocked := {}
	for h in MetaProgress.HERO_EXCLUSIVE_CARDS:
		if h != hero_id:
			for cid in MetaProgress.HERO_EXCLUSIVE_CARDS[h]:
				blocked[str(cid)] = true
	var dir = DirAccess.open("res://battle_scene/card_info/player/")
	if dir == null:
		return result
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var card_id := file_name.get_basename()
		if card_id.ends_with("_plus"):
			continue
		if blocked.has(card_id):
			continue
		var data := _load_json("res://battle_scene/card_info/player/" + file_name)
		var rarity := str(data.get("rarity", "common"))
		if rarity in result:
			result[rarity].append(card_id)
	return result


func _list_equipment_by_rarity() -> Dictionary:
	var result := {"common": [], "uncommon": [], "rare": []}
	var dir = DirAccess.open("res://run_system/data/equipment/")
	if dir == null:
		return result
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var item_id := file_name.get_basename()
		var data := _load_json("res://run_system/data/equipment/" + file_name)
		var rarity := str(data.get("rarity", "common"))
		if rarity in result:
			result[rarity].append(item_id)
	return result


func _list_unowned_relics() -> Array:
	var dir = DirAccess.open("res://run_system/data/relics/")
	if dir == null:
		return []
	var candidates: Array = []
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var relic_id := file_name.get_basename()
		if relic_id in RunManager.relics:
			continue
		# "unique" relics are hero-starting only — never stock them in the shop.
		if str(RunManager.get_relic_data(relic_id).get("rarity", "common")) == "unique":
			continue
		candidates.append(relic_id)
	return candidates


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
	_add_scene_art()

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 44)
	root.add_theme_constant_override("margin_right", 300)
	root.add_theme_constant_override("margin_top", 36)
	root.add_theme_constant_override("margin_bottom", 36)
	add_child(root)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var board := PanelContainer.new()
	board.custom_minimum_size = Vector2(1280, 900)
	board.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(SHOP_BOARD_BG, SHOP_PANEL_BORDER, 4, 3)
	)
	center.add_child(board)

	var board_margin := MarginContainer.new()
	board_margin.add_theme_constant_override("margin_left", 28)
	board_margin.add_theme_constant_override("margin_right", 28)
	board_margin.add_theme_constant_override("margin_top", 22)
	board_margin.add_theme_constant_override("margin_bottom", 22)
	board.add_child(board_margin)

	var vroot := VBoxContainer.new()
	vroot.add_theme_constant_override("separation", 14)
	board_margin.add_child(vroot)

	# Header row: title + gold
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	vroot.add_child(header)
	var title := Label.new()
	title.text = tr("UI_SHOP_TITLE")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var gold_chip := PanelContainer.new()
	gold_chip.custom_minimum_size = Vector2(170, 46)
	gold_chip.add_theme_stylebox_override(
		"panel",
		T.panel_with_shadow(Color(0.11, 0.07, 0.035, 0.96), Color(0.78, 0.48, 0.16, 1.0), 4, 2)
	)
	header.add_child(gold_chip)

	var gold_margin := MarginContainer.new()
	gold_margin.add_theme_constant_override("margin_left", 14)
	gold_margin.add_theme_constant_override("margin_right", 14)
	gold_margin.add_theme_constant_override("margin_top", 6)
	gold_margin.add_theme_constant_override("margin_bottom", 6)
	gold_chip.add_child(gold_margin)

	var gold_row := HBoxContainer.new()
	gold_row.alignment = BoxContainer.ALIGNMENT_CENTER
	gold_row.add_theme_constant_override("separation", 8)
	gold_margin.add_child(gold_row)

	var gold_title := Label.new()
	gold_title.text = tr("UI_SHOP_GOLD")
	gold_title.add_theme_font_size_override("font_size", 20)
	gold_title.add_theme_color_override("font_color", T.TEXT_MAIN)
	gold_row.add_child(gold_title)

	_gold_label = Label.new()
	_gold_label.text = "%d" % RunManager.total_gold()
	_gold_label.add_theme_font_size_override("font_size", 24)
	_gold_label.add_theme_color_override("font_color", SHOP_PRICE)
	gold_row.add_child(_gold_label)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	vroot.add_child(body)

	var cards_section := _make_section_panel(tr("UI_SHOP_SECTION_CARDS"), Vector2(0, 328))
	body.add_child(cards_section["panel"] as Control)
	var cards_body := cards_section["body"] as VBoxContainer
	var cards_center := CenterContainer.new()
	cards_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_body.add_child(cards_center)
	var cards_grid := GridContainer.new()
	cards_grid.columns = max(1, min(6, _stock_cards.size()))
	cards_grid.add_theme_constant_override("h_separation", 12)
	cards_grid.add_theme_constant_override("v_separation", 8)
	cards_center.add_child(cards_grid)
	for entry in _stock_cards:
		cards_grid.add_child(_build_card_stall(entry))

	if not _stock_equipment.is_empty() or not _stock_relics.is_empty():
		var mid_row := HBoxContainer.new()
		mid_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid_row.add_theme_constant_override("separation", 14)
		mid_row.alignment = BoxContainer.ALIGNMENT_CENTER
		body.add_child(mid_row)

		if not _stock_equipment.is_empty():
			var equip_section := _make_section_panel(
				tr("UI_SHOP_SECTION_EQUIPMENT"), Vector2(0, 246)
			)
			mid_row.add_child(equip_section["panel"] as Control)
			var equip_body := equip_section["body"] as VBoxContainer
			var equip_center := CenterContainer.new()
			equip_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			equip_body.add_child(equip_center)
			var equip_grid := GridContainer.new()
			equip_grid.columns = max(1, min(3, _stock_equipment.size()))
			equip_grid.add_theme_constant_override("h_separation", 12)
			equip_grid.add_theme_constant_override("v_separation", 8)
			equip_center.add_child(equip_grid)
			for entry in _stock_equipment:
				equip_grid.add_child(_build_equipment_stall(entry))

		if not _stock_relics.is_empty():
			var relic_section := _make_section_panel(tr("UI_SHOP_SECTION_RELIC"), Vector2(0, 246))
			mid_row.add_child(relic_section["panel"] as Control)
			var relic_body := relic_section["body"] as VBoxContainer
			var relic_center := CenterContainer.new()
			relic_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			relic_body.add_child(relic_center)
			var relic_grid := GridContainer.new()
			relic_grid.columns = max(1, min(3, _stock_relics.size()))
			relic_grid.add_theme_constant_override("h_separation", 12)
			relic_grid.add_theme_constant_override("v_separation", 8)
			relic_center.add_child(relic_grid)
			for entry in _stock_relics:
				relic_grid.add_child(_build_relic_stall(entry))

	var services_section := _make_section_panel(tr("UI_SHOP_SECTION_SERVICES"), Vector2(0, 88))
	body.add_child(services_section["panel"] as Control)
	var services_body := services_section["body"] as VBoxContainer
	services_body.add_child(_build_remove_service_row())


func _add_scene_art() -> void:
	if ResourceLoader.exists(SHOP_BACKGROUND_PATH):
		var bg := TextureRect.new()
		bg.texture = load(SHOP_BACKGROUND_PATH)
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
	else:
		var bg := ColorRect.new()
		bg.color = Color(0.025, 0.020, 0.016, 1.0)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.40)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	if ResourceLoader.exists(SHOPKEEPER_PATH):
		var keeper := TextureRect.new()
		keeper.texture = load(SHOPKEEPER_PATH)
		keeper.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		keeper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		keeper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		keeper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		keeper.anchor_left = 1.0
		keeper.anchor_top = 1.0
		keeper.anchor_right = 1.0
		keeper.anchor_bottom = 1.0
		keeper.offset_left = -330
		keeper.offset_top = -520
		keeper.offset_right = -36
		keeper.offset_bottom = -32
		add_child(keeper)


func _section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl


func _make_section_panel(title: String, min_size: Vector2 = Vector2.ZERO) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(SHOP_PANEL_BG, SHOP_PANEL_BORDER, 4, 2)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	margin.add_child(body)
	body.add_child(_section_header(title))

	return {"panel": panel, "body": body}


func _make_shop_button(text: String, min_size: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.add_theme_font_size_override("font_size", 20)
	T.apply_button_theme(btn)
	return btn


# --- Stall builders --------------------------------------------------------


func _build_card_stall(entry: Dictionary) -> Control:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 6)
	wrapper.custom_minimum_size = Vector2(188, 268)
	wrapper.alignment = BoxContainer.ALIGNMENT_CENTER

	var card_plate := PanelContainer.new()
	card_plate.custom_minimum_size = Vector2(176, 232)
	card_plate.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(SHOP_PANEL_BG_DARK, SHOP_PANEL_BORDER, 3, 2)
	)
	wrapper.add_child(card_plate)

	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 6)
	card_margin.add_theme_constant_override("margin_right", 6)
	card_margin.add_theme_constant_override("margin_top", 6)
	card_margin.add_theme_constant_override("margin_bottom", 6)
	card_plate.add_child(card_margin)

	var card_box := Control.new()
	card_box.custom_minimum_size = Vector2(164, 220)
	card_margin.add_child(card_box)

	var card_id: String = str(entry["card_id"])
	var card = _card_factory.create_card(card_id, null)
	if card:
		if card.get_parent():
			card.get_parent().remove_child(card)
		card.can_be_interacted_with = false
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.position = Vector2(2, 0)
		card.pivot_offset = Vector2(0, 0)
		card.scale = Vector2(160.0 / 208.0, 160.0 / 208.0)
		card_box.add_child(card)

	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override("separation", 8)
	wrapper.add_child(price_row)
	var price_lbl := Label.new()
	price_lbl.text = tr("UI_SHOP_PRICE").format({"n": int(entry["price"])})
	price_lbl.add_theme_font_size_override("font_size", 18)
	price_lbl.add_theme_color_override("font_color", SHOP_PRICE)
	price_row.add_child(price_lbl)
	var buy_btn := _make_shop_button(tr("UI_SHOP_BUY"), Vector2(88, 34))
	buy_btn.pressed.connect(_on_buy_card.bind(card_id, int(entry["price"]), buy_btn))
	price_row.add_child(buy_btn)

	return wrapper


func _build_equipment_stall(entry: Dictionary) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(176, 174)
	frame.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(SHOP_PANEL_BG_DARK, Color(0.44, 0.29, 0.16, 1.0), 3, 1)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	frame.add_child(margin)

	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 3)
	wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(wrapper)

	var item_id: String = str(entry["item_id"])
	var data := RunManager.get_equipment_data(item_id)
	var slot := str(data.get("slot", "head"))
	var equip_name := Settings.t("EQUIP_%s_NAME" % item_id, str(data.get("name", item_id)))

	var icon_holder := HBoxContainer.new()
	icon_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	wrapper.add_child(icon_holder)
	var icon := EQUIPMENT_ICON.new()
	icon.custom_minimum_size = Vector2(52, 52)
	icon_holder.add_child(icon)
	icon.set_equipment(slot, equip_name, str(data.get("sprite", "")), str(data.get("rarity", "common")))

	var name_lbl := Label.new()
	name_lbl.text = equip_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.custom_minimum_size = Vector2(150, 0)
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	wrapper.add_child(name_lbl)

	var bonus_lbl := Label.new()
	bonus_lbl.text = _format_bonuses(data.get("bonuses", {}))
	bonus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_lbl.add_theme_font_size_override("font_size", 15)
	bonus_lbl.add_theme_color_override(
		"font_color", RARITY_COLORS.get(str(entry["rarity"]), Color.WHITE)
	)
	wrapper.add_child(bonus_lbl)

	var set_id := str(data.get("set_id", ""))
	if set_id != "":
		var set_lbl := Label.new()
		set_lbl.text = "[%s]" % Settings.t("SET_%s_NAME" % set_id, set_id)
		set_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		set_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		set_lbl.custom_minimum_size = Vector2(150, 0)
		set_lbl.add_theme_font_size_override("font_size", 14)
		set_lbl.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
		wrapper.add_child(set_lbl)

	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override("separation", 6)
	wrapper.add_child(price_row)
	var price_lbl := Label.new()
	price_lbl.text = tr("UI_SHOP_PRICE").format({"n": int(entry["price"])})
	price_lbl.add_theme_font_size_override("font_size", 16)
	price_lbl.add_theme_color_override("font_color", SHOP_PRICE)
	price_row.add_child(price_lbl)
	var buy_btn := _make_shop_button(tr("UI_SHOP_BUY"), Vector2(78, 32))
	buy_btn.pressed.connect(_on_buy_equipment.bind(item_id, int(entry["price"]), buy_btn))
	price_row.add_child(buy_btn)

	return frame


func _build_relic_stall(entry: Dictionary) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(176, 174)
	frame.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(SHOP_PANEL_BG_DARK, Color(0.62, 0.44, 0.22, 1.0), 3, 1)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	frame.add_child(margin)

	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 3)
	wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(wrapper)

	var relic_id := str(entry["relic_id"])
	var price := int(entry["price"])
	var data := RunManager.get_relic_data(relic_id)

	var icon_holder := HBoxContainer.new()
	icon_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	wrapper.add_child(icon_holder)
	var icon_path: String = str(data.get("icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var tex := TextureRect.new()
		tex.texture = load(icon_path)
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.custom_minimum_size = Vector2(48, 48)
		tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_holder.add_child(tex)

	var title := Label.new()
	title.text = Settings.t("RELIC_%s_TITLE" % relic_id, str(data.get("title", relic_id)))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.custom_minimum_size = Vector2(150, 0)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	wrapper.add_child(title)

	var desc := Label.new()
	desc.text = Settings.t("RELIC_%s_DESC" % relic_id, str(data.get("description", "")))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.clip_text = true
	desc.max_lines_visible = 2
	desc.custom_minimum_size = Vector2(150, 0)
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	wrapper.add_child(desc)

	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override("separation", 6)
	wrapper.add_child(price_row)
	var price_lbl := Label.new()
	price_lbl.text = tr("UI_SHOP_PRICE").format({"n": price})
	price_lbl.add_theme_font_size_override("font_size", 16)
	price_lbl.add_theme_color_override("font_color", SHOP_PRICE)
	price_row.add_child(price_lbl)
	var buy_btn := _make_shop_button(tr("UI_SHOP_BUY"), Vector2(78, 32))
	buy_btn.pressed.connect(_on_buy_relic.bind(relic_id, price, buy_btn))
	price_row.add_child(buy_btn)

	return frame


func _build_remove_service_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var info := Label.new()
	info.text = tr("UI_SHOP_REMOVE_SERVICE_INFO")
	info.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	info.custom_minimum_size = Vector2(260, 0)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(info)

	var price_lbl := Label.new()
	price_lbl.text = tr("UI_SHOP_PRICE").format({"n": _remove_price})
	price_lbl.add_theme_font_size_override("font_size", 18)
	price_lbl.add_theme_color_override("font_color", SHOP_PRICE)
	row.add_child(price_lbl)

	_remove_service_btn = _make_shop_button(tr("UI_SHOP_REMOVE"), Vector2(126, 38))
	_remove_service_btn.pressed.connect(_on_remove_service_pressed)
	row.add_child(_remove_service_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var leave_btn := _make_shop_button(tr("UI_SHOP_LEAVE"), Vector2(170, 38))
	leave_btn.pressed.connect(_on_leave_pressed)
	row.add_child(leave_btn)

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
	btn.text = tr("UI_SHOP_SOLD")


# --- Remove-card picker ----------------------------------------------------


func _on_remove_service_pressed() -> void:
	if RunManager.total_gold() < _remove_price:
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
	title.text = tr("UI_SHOP_REMOVE_MODAL_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.55, 0.55))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = tr("UI_SHOP_REMOVE_MODAL_SUBTITLE")
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
	var cancel := _make_shop_button(tr("UI_SHOP_CANCEL"), Vector2(140, 42))
	cancel.pressed.connect(_on_remove_cancel.bind(modal))
	actions.add_child(cancel)

	return modal


func _make_removal_slot(card_id: String, uid: String, modal: Control) -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(180, 260)

	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(Color(0.09, 0.072, 0.055, 0.92), T.PANEL_BORDER, 3)
	)
	wrapper.add_child(frame)

	var card = _card_factory.create_card(card_id, null)
	if card:
		if card.get_parent():
			card.get_parent().remove_child(card)
		card.can_be_interacted_with = false
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.position = Vector2(10, 20)
		card.pivot_offset = Vector2(0, 0)
		card.scale = Vector2(160.0 / 208.0, 160.0 / 208.0)
		wrapper.add_child(card)

	var button := Button.new()
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_on_remove_pick.bind(uid, modal))
	wrapper.add_child(button)

	if card:
		button.mouse_entered.connect(
			func():
				frame.add_theme_stylebox_override(
					"panel",
					T.panel_with_shadow(Color(0.18, 0.06, 0.06, 0.96), Color(1.0, 0.4, 0.3), 3)
				)
				var tween = create_tween()
				tween.tween_property(card, "scale", Vector2(1.06, 1.06), 0.10)
		)
		button.mouse_exited.connect(
			func():
				frame.add_theme_stylebox_override(
					"panel", T.panel_with_shadow(Color(0.09, 0.072, 0.055, 0.92), T.PANEL_BORDER, 3)
				)
				var tween = create_tween()
				tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.10)
		)

	return wrapper


func _on_remove_pick(uid: String, modal: Control) -> void:
	if RunManager.purchase_card_removal(uid, _remove_price):
		_mark_sold(_remove_service_btn)
	_remove_card_picker = null
	modal.queue_free()


func _on_remove_cancel(modal: Control) -> void:
	_remove_card_picker = null
	modal.queue_free()


# --- Leave -----------------------------------------------------------------


func _on_leave_pressed() -> void:
	get_tree().change_scene_to_file(MAP_SCENE_PATH)


# --- Helpers ---------------------------------------------------------------


func _format_bonuses(bonuses) -> String:
	if typeof(bonuses) != TYPE_DICTIONARY or bonuses.is_empty():
		return tr("UI_SHOP_NO_BONUSES")
	var parts: Array = []
	for attr in bonuses.keys():
		parts.append("+%d %s" % [int(bonuses[attr]), str(attr).substr(0, 3).to_upper()])
	return ", ".join(parts)


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var img := Image.new()
	if img.load(path) != OK:
		return null
	return ImageTexture.create_from_image(img)

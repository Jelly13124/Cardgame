## Market (黑市) building screen. Subclasses the shared building shell and fills
## the content VBox with the Market's tier-gated functions:
##   - T1 tool_shop : buy 3 random tools with Caps (flat price).
##   - T2 equip_shop: buy equipment INSTANCES with Caps (rarity-priced).
##   - T3 refresh   : spend Caps to re-roll the stocked tools + equipment.
##
## The base card-unlock/card-shop system was removed (Phase A refactor): every
## non-curse, non-basic card is draftable by default via
## MetaProgress.get_unlocked_card_pool(), so the Market no longer sells cards.
##
## NO class_name (ADR-0006: subclass via path string, instantiate with `.new()`).
## Reads only the shared MetaProgress / RunManager API; edits no shared file.
extends "res://run_system/ui/buildings/building_screen_base.gd"

const EQUIPMENT_DIR := "res://run_system/data/equipment/"
const EQUIPMENT_ICON := preload("res://run_system/ui/equipment_icon.gd")

## Equipment shelf-tile icon size.
const SHELF_ICON := Vector2(96, 96)

## Equipment buy prices in Caps, by rarity (spec: 60/140/280).
const EQUIP_CAPS_PRICE := {"common": 60, "uncommon": 140, "rare": 280}
## How many equipment items to stock per rarity bucket.
const EQUIP_STOCK_PER_RARITY := {"common": 2, "uncommon": 2, "rare": 1}
## Flat Caps price per tool (tools have no rarity tiers).
const MARKET_TOOL_PRICE := 40
## How many random tools to stock.
const MARKET_TOOL_COUNT := 3
## Refresh (T3): base Caps cost, +10 per use this visit.
const MARKET_REFRESH_BASE := 20
const MARKET_REFRESH_STEP := 10

const RARITY_ORDER := ["common", "uncommon", "rare"]
const RARITY_COLORS := {
	"common": Color(0.85, 0.85, 0.85),
	"uncommon": Color(0.45, 0.8, 1.0),
	"rare": Color(1.0, 0.85, 0.35),
}
const PRICE_COLOR := Color(1.0, 0.84, 0.18)

## Rolled equipment stock — set once for the session in _build_content. Each
## entry: {base, rarity, price}. Stable until refreshed.
var _equip_stock: Array = []
## Rolled tool stock — set once for the session in _build_content. Each
## entry: tool_id String. Stable until refreshed.
var _tool_stock: Array = []
## How many times the T3 refresh has been used this visit (price escalates).
var _refresh_uses: int = 0

## Live-refresh handles so balances + buttons repaint without a full rebuild.
var _caps_label: Label = null
var _mkt_core_label: Label = null
## The whole content host, so currency/building changes can rebuild the lists.
var _market_box: VBoxContainer = null


func _build_content(container: VBoxContainer) -> void:
	# Roll stock once for the session (stable until refreshed).
	if _tool_stock.is_empty():
		_tool_stock = _roll_tool_stock()
	if _equip_stock.is_empty():
		_equip_stock = _roll_equip_stock()

	_market_box = container
	# Repaint on currency / building changes. The base already connects _refresh
	# (badge/action button); we add our own content rebuild on the same signals.
	if not MetaProgress.caps_changed.is_connected(_on_market_changed):
		MetaProgress.caps_changed.connect(_on_market_changed)
	if not MetaProgress.core_changed.is_connected(_on_market_changed):
		MetaProgress.core_changed.connect(_on_market_changed)
	if not MetaProgress.buildings_changed.is_connected(_rebuild_market):
		MetaProgress.buildings_changed.connect(_rebuild_market)
	if not MetaProgress.upgrades_changed.is_connected(_rebuild_market):
		MetaProgress.upgrades_changed.connect(_rebuild_market)

	_populate(container)


func _on_market_changed(_v: int) -> void:
	_refresh_balances()


func _rebuild_market() -> void:
	if not is_instance_valid(_market_box):
		return
	for child in _market_box.get_children():
		child.queue_free()
	_populate(_market_box)


func _refresh_balances() -> void:
	if is_instance_valid(_caps_label):
		_caps_label.text = "%d" % MetaProgress.caps
	if is_instance_valid(_mkt_core_label):
		_mkt_core_label.text = "%d" % MetaProgress.core


func _populate(container: VBoxContainer) -> void:
	container.add_child(_build_balances_row())

	# T1: tool shop (Caps).
	if MetaProgress.building_can("market", "tool_shop"):
		container.add_child(_build_tool_section())
	else:
		container.add_child(_locked_section(tr("UI_MARKET_TOOL_SECTION"), 1))

	# T2: equipment shop (Caps).
	if MetaProgress.building_can("market", "equip_shop"):
		container.add_child(_build_equip_section())
	else:
		container.add_child(_locked_section(tr("UI_MARKET_EQUIP_SECTION"), 2))

	# T3: refresh stock (Caps).
	if MetaProgress.building_can("market", "refresh"):
		container.add_child(_build_refresh_section())
	else:
		container.add_child(_locked_section(tr("UI_MARKET_REFRESH_SECTION"), 3))


# --- Balances --------------------------------------------------------------


## Balances banner — matches the banner treatment on the other 4 screens (forge
## Scrap / outpost Core / clinic Caps) so the Market's currency readout reads
## as the same UI element instead of a bare label row.
func _build_balances_row() -> Control:
	var banner := _styled_panel(true)
	var bm := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		bm.add_theme_constant_override(side, TOK_MARGIN_INNER)
	banner.add_child(bm)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	bm.add_child(row)

	var caps_title := Label.new()
	caps_title.text = tr("UI_MARKET_CAPS")
	_style_label(caps_title, 20, TOK_TEXT, 1)
	row.add_child(caps_title)

	_caps_label = Label.new()
	_caps_label.text = "%d" % MetaProgress.caps
	_style_label(_caps_label, 22, PRICE_COLOR, 2)
	row.add_child(_caps_label)

	var core_title := Label.new()
	core_title.text = tr("UI_MARKET_CORE")
	_style_label(core_title, 20, TOK_TEXT, 1)
	row.add_child(core_title)

	_mkt_core_label = Label.new()
	_mkt_core_label.text = "%d" % MetaProgress.core
	_style_label(_mkt_core_label, 22, Color(0.55, 0.85, 1.0), 2)
	row.add_child(_mkt_core_label)

	return banner


# --- Tool shop (T1, Caps) ---------------------------------------------------


func _build_tool_section() -> Control:
	var section := _make_section(tr("UI_MARKET_TOOL_SECTION"))
	var body := section.get_meta("body") as VBoxContainer

	if _tool_stock.is_empty():
		var empty := Label.new()
		empty.text = tr("UI_MARKET_TOOL_EMPTY")
		_style_label(empty, 18, Color(0.8, 0.74, 0.6), 1)
		body.add_child(empty)
		return section

	var shelf := HFlowContainer.new()
	shelf.add_theme_constant_override("h_separation", 14)
	shelf.add_theme_constant_override("v_separation", 14)
	shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(shelf)
	for tool_id in _tool_stock:
		shelf.add_child(_build_tool_tile(str(tool_id)))
	return section


## One tool sitting on the shelf: an icon (or glyph fallback), its name, and a
## Caps buy button. Mirrors shop_scene._build_tool_stall's data lookups.
func _build_tool_tile(tool_id: String) -> Control:
	var data := RunManager.get_tool_data(tool_id)
	var tool_name := Settings.t("TOOL_%s_TITLE" % tool_id, str(data.get("title", tool_id)))

	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override(
		"panel",
		T.panel_with_shadow(Color(0.12, 0.085, 0.060, 0.95), Color(0.62, 0.44, 0.22, 1.0), 3, 2)
	)
	var tm := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		tm.add_theme_constant_override(s, 10)
	tile.add_child(tm)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size = Vector2(150, 0)
	tm.add_child(col)

	var icon_holder := CenterContainer.new()
	col.add_child(icon_holder)
	var icon_path := str(data.get("icon", ""))
	var tex: Texture2D = null
	if icon_path != "" and ResourceLoader.exists(icon_path):
		tex = load(icon_path) as Texture2D
	if tex:
		var icon := TextureRect.new()
		icon.custom_minimum_size = SHELF_ICON
		icon.texture = tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_holder.add_child(icon)
	else:
		var glyph := Label.new()
		glyph.custom_minimum_size = SHELF_ICON
		glyph.text = tool_name.substr(0, 1) if tool_name != "" else "?"
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.add_theme_font_size_override("font_size", 30)
		glyph.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		icon_holder.add_child(glyph)

	var name_lbl := Label.new()
	name_lbl.text = tool_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(name_lbl, 16, Color(0.95, 0.92, 0.85), 1)
	col.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = Settings.t("TOOL_%s_DESC" % tool_id, "")
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(desc_lbl, 13, Color(0.82, 0.76, 0.62), 1)
	col.add_child(desc_lbl)

	var buy_btn := Button.new()
	buy_btn.custom_minimum_size = Vector2(0, 38)
	buy_btn.add_theme_font_size_override("font_size", 17)
	T.apply_button_theme(buy_btn)
	buy_btn.text = tr("UI_MARKET_BUY_CAPS").format({"n": MARKET_TOOL_PRICE})
	buy_btn.disabled = MetaProgress.caps < MARKET_TOOL_PRICE
	buy_btn.pressed.connect(_on_buy_tool.bind(tool_id, buy_btn))
	col.add_child(buy_btn)

	return tile


func _on_buy_tool(tool_id: String, btn: Button) -> void:
	if not MetaProgress.spend_caps(MARKET_TOOL_PRICE):
		return
	if not RunManager.add_tool_to_backpack(tool_id):
		# Backpack full → refund the Caps so the player isn't charged for nothing.
		MetaProgress.add_caps(MARKET_TOOL_PRICE)
		if is_instance_valid(btn):
			btn.text = tr("UI_MARKET_STASH_FULL")
		return
	if is_instance_valid(btn):
		btn.disabled = true
		btn.text = tr("UI_MARKET_BOUGHT")
	# caps_changed → _on_market_changed repaints balances + other buy buttons'
	# disabled state via _refresh_balances; this button keeps its SOLD state.


# --- Equipment shop (T2, Caps) ----------------------------------------------


func _build_equip_section() -> Control:
	var section := _make_section(tr("UI_MARKET_EQUIP_SECTION"))
	var body := section.get_meta("body") as VBoxContainer

	if _equip_stock.is_empty():
		var empty := Label.new()
		empty.text = tr("UI_MARKET_EQUIP_EMPTY")
		_style_label(empty, 18, Color(0.8, 0.74, 0.6), 1)
		body.add_child(empty)
		return section

	# Lay the stock out as tiles on a shelf (wrapping grid) instead of a text list.
	var shelf := HFlowContainer.new()
	shelf.add_theme_constant_override("h_separation", 14)
	shelf.add_theme_constant_override("v_separation", 14)
	shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(shelf)
	for entry in _equip_stock:
		shelf.add_child(_build_equip_tile(entry))
	return section


## One piece of gear sitting on the shelf: a rarity-framed tile with the item icon,
## its name, and a Caps buy button (which doubles as the price tag).
func _build_equip_tile(entry: Dictionary) -> Control:
	var base_id: String = str(entry.get("base", ""))
	var rarity: String = str(entry.get("rarity", "common"))
	var price: int = int(entry.get("price", 0))
	var data := RunManager.get_equipment_data(base_id)
	var slot := str(data.get("slot", "head"))
	var equip_name := Settings.t("EQUIP_%s_NAME" % base_id, str(data.get("name", base_id)))

	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override(
		"panel",
		T.panel_with_shadow(
			Color(0.12, 0.085, 0.060, 0.95), RARITY_COLORS.get(rarity, Color(0.6, 0.5, 0.4)), 3, 2
		)
	)
	var tm := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		tm.add_theme_constant_override(s, 10)
	tile.add_child(tm)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size = Vector2(150, 0)
	tm.add_child(col)

	var icon_holder := CenterContainer.new()
	var icon := EQUIPMENT_ICON.new()
	icon.custom_minimum_size = SHELF_ICON
	icon.set_equipment(slot, equip_name, str(data.get("sprite", "")), rarity)
	icon.set_hover_tooltip(
		"[b]%s[/b]\n%s" % [equip_name, tr("UI_MARKET_RARITY_%s" % rarity.to_upper())]
	)
	icon_holder.add_child(icon)
	col.add_child(icon_holder)

	var name_lbl := Label.new()
	name_lbl.text = equip_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(name_lbl, 16, RARITY_COLORS.get(rarity, Color(0.95, 0.92, 0.85)), 1)
	col.add_child(name_lbl)

	var buy_btn := Button.new()
	buy_btn.custom_minimum_size = Vector2(0, 38)
	buy_btn.add_theme_font_size_override("font_size", 17)
	T.apply_button_theme(buy_btn)
	buy_btn.text = tr("UI_MARKET_BUY_CAPS").format({"n": price})
	buy_btn.disabled = MetaProgress.caps < price
	buy_btn.pressed.connect(_on_buy_equipment.bind(base_id, rarity, price, buy_btn))
	col.add_child(buy_btn)

	return tile


func _on_buy_equipment(base_id: String, rarity: String, price: int, btn: Button) -> void:
	if not MetaProgress.spend_caps(price):
		return
	var inst := RunManager.make_equip_instance(base_id, rarity)
	if not MetaProgress.add_to_stash(inst):
		# Stash full → refund the Caps so the player isn't charged for nothing.
		MetaProgress.add_caps(price)
		if is_instance_valid(btn):
			btn.text = tr("UI_MARKET_STASH_FULL")
		return
	if is_instance_valid(btn):
		btn.disabled = true
		btn.text = tr("UI_MARKET_BOUGHT")
	# caps_changed → _on_market_changed repaints balances + other buy buttons'
	# disabled state via _refresh_balances; this button keeps its SOLD state.


# --- Refresh (T3, Caps) ------------------------------------------------------


func _build_refresh_section() -> Control:
	var section := _make_section(tr("UI_MARKET_REFRESH_SECTION"))
	var body := section.get_meta("body") as VBoxContainer

	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = tr("UI_MARKET_REFRESH_NOTE")
	_style_label(note, 17, Color(0.85, 0.66, 0.40), 1)
	body.add_child(note)

	var cost := _refresh_cost()
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(220, 44)
	btn.add_theme_font_size_override("font_size", 18)
	T.apply_button_theme(btn)
	btn.text = tr("UI_MARKET_REFRESH_BTN").format({"n": cost})
	btn.disabled = MetaProgress.caps < cost
	btn.pressed.connect(_on_refresh_stock)
	body.add_child(btn)

	return section


func _refresh_cost() -> int:
	return MARKET_REFRESH_BASE + MARKET_REFRESH_STEP * _refresh_uses


func _on_refresh_stock() -> void:
	var cost := _refresh_cost()
	if not MetaProgress.spend_caps(cost):
		return
	_refresh_uses += 1
	_tool_stock = _roll_tool_stock()
	_equip_stock = _roll_equip_stock()
	_rebuild_market()


# --- Section / helpers ------------------------------------------------------


## A titled panel; the inner content VBox is stored on the panel's "body" meta.
## Uses the shared Phase-B panel token (`_styled_panel`) + gold section-title
## color so the Market's shelves match the panel language on the other 4
## screens instead of the market-only SECTION_BG/SECTION_BORDER it used before.
func _make_section(title: String) -> PanelContainer:
	var panel := _styled_panel(false)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, TOK_MARGIN_OUTER)
	panel.add_child(margin)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", TOK_ROW_SEP)
	margin.add_child(body)

	var header := Label.new()
	header.text = title.to_upper()
	_style_label(header, TOK_FONT_SECTION, TOK_GOLD, 2)
	body.add_child(header)

	panel.set_meta("body", body)
	return panel


## A locked-function placeholder section with the tier needed to unlock it.
func _locked_section(title: String, tier: int) -> Control:
	var section := _make_section(title)
	var body := section.get_meta("body") as VBoxContainer
	body.add_child(_body_label(tr("UI_MARKET_LOCKED_HINT").format({"t": tier}), true))
	return section


## Roll a small, session-stable tool stock from the whole tool pool.
func _roll_tool_stock() -> Array:
	var pool: Array = RunManager.tool_pool().duplicate()
	pool.shuffle()
	var stock: Array = []
	for i in range(min(MARKET_TOOL_COUNT, pool.size())):
		stock.append(str(pool[i]))
	return stock


## Roll a small, session-stable equipment stock from disk, bucketed by rarity.
func _roll_equip_stock() -> Array:
	var by_rarity := _list_equipment_by_rarity()
	var stock: Array = []
	for rarity in RARITY_ORDER:
		var pool: Array = (by_rarity.get(rarity, []) as Array).duplicate()
		pool.shuffle()
		var want := int(EQUIP_STOCK_PER_RARITY.get(rarity, 1))
		var taken := 0
		for base_id in pool:
			if taken >= want:
				break
			(
				stock
				. append(
					{
						"base": str(base_id),
						"rarity": rarity,
						"price": int(EQUIP_CAPS_PRICE.get(rarity, EQUIP_CAPS_PRICE["common"])),
					}
				)
			)
			taken += 1
	return stock


func _list_equipment_by_rarity() -> Dictionary:
	var result := {"common": [], "uncommon": [], "rare": []}
	var dir = DirAccess.open(EQUIPMENT_DIR)
	if dir == null:
		return result
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var item_id := file_name.get_basename()
		var data := _load_json(EQUIPMENT_DIR + file_name)
		var rarity := str(data.get("rarity", "common"))
		if rarity in result:
			result[rarity].append(item_id)
	return result


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

## Market (黑市) building screen, re-skinned to the 2026-07-07 "lightline"
## concept — the exact five-tool layout approved on 2026-07-14:
##   工具货架 (T1 tool_shop)        — 5 full-height product cards, large icon,
##                                    centered name + compact olive Caps plaque.
##   装备货架 (T2 equip_shop)       — FIVE items, one per equipment slot; the
##                                    complete card owns the rarity frame; a
##                                    rarity·slot line replaces generated names.
##   资源兑换 (T3 resource_convert) — a compact bottom strip with both exchange
##                                    directions side by side.
## Refresh stays UNGATED (available from T1): the tool-shelf header carries the
## olive refresh button even while that shelf is still locked, so the function
## is reachable at every tier exactly as before. One refresh rerolls both shelves.
##
## Purchase routes equipment into the player-owned base backpack; permanent
## storage changes only when the player explicitly drags gear into the stash.
## Tool purchases retain their backpack full-refund guard. Escalating refresh
## cost, conversion math/handlers, and tier gating via
## `_locked_section` are all the pre-reskin code paths.
##
## The bounty shelf moved to the OUTPOST in the 2026-07-07 redesign; the Market
## no longer has a bounty section. The base card-unlock/card-shop system was
## removed (Phase A refactor) — the Market doesn't sell cards.
##
## Every generated market PNG lookup falls back to a programmatic StyleBox /
## spacer / text so a missing asset never crashes (warn-free placeholder rule).
## NO class_name (ADR-0006: subclass via path string, instantiate with `.new()`).
## Reads only the shared MetaProgress / RunManager API; edits no shared file.
extends "res://run_system/ui/buildings/building_screen_base.gd"

const EQUIPMENT_DIR := "res://run_system/data/equipment/"
const EQUIPMENT_ICON := preload("res://run_system/ui/equipment_icon.gd")
const EQUIP_TOOLTIP := preload("res://run_system/ui/equip_tooltip.gd")
const MARKET_UI_DIR := "res://run_system/assets/images/ui/market/"
const MARKET_SHELF_FRAME_PATH := MARKET_UI_DIR + "market_shelf_panel_frame.png"
const MARKET_TOOL_CARD_PATH := MARKET_UI_DIR + "market_tool_card_frame.png"
const MARKET_EQUIP_CARD_PATHS := {
	"common": MARKET_UI_DIR + "market_equip_card_common.png",
	"uncommon": MARKET_UI_DIR + "market_equip_card_uncommon.png",
	"rare": MARKET_UI_DIR + "market_equip_card_rare.png",
}
const MARKET_EXCHANGE_ROW_PATH := MARKET_UI_DIR + "market_exchange_row_frame.png"

## Pixel geometry measured from the accepted 1672×941 concept and mapped to
## 1920×1080. The normal project stretch policy scales this composition at
## other resolutions without changing the internal proportions.
const CONTENT_MIN_HEIGHT := 869.0
const MERCHANT_SCENE_WIDTH := 456.0
const TOOL_SECTION_HEIGHT := 329.0
const EQUIP_SECTION_HEIGHT := 367.0
const CONVERT_SECTION_HEIGHT := 169.0
const TOOL_CARD_HEIGHT := 254.0
const EQUIP_CARD_HEIGHT := 301.0
const SHELF_CARD_GAP := 17
const SHELF_ICON := Vector2(116, 116)
const EQUIP_SHELF_ICON := Vector2(154, 154)

## Equipment buy prices in Caps, by rarity (spec: 60/140/280).
const EQUIP_CAPS_PRICE := {"common": 60, "uncommon": 140, "rare": 280}
## Equipment shelf: FIVE items — one per equipment slot (owner 2026-07-08),
## rarity rolled per slot by these weights.
const EQUIP_SLOT_ORDER := ["weapon", "head", "chest", "hands", "accessory"]
const EQUIP_RARITY_WEIGHTS := {"common": 50, "uncommon": 35, "rare": 15}
## Flat Caps price per tool (tools have no rarity tiers).
const MARKET_TOOL_PRICE := 40
## How many random tools to stock (owner 2026-07-14: five, concept parity).
const MARKET_TOOL_COUNT := 5
## Refresh (ungated): base Caps cost, +10 per use this visit.
const MARKET_REFRESH_BASE := 20
const MARKET_REFRESH_STEP := 10

## Conversion tunables (Caps↔Scrap bidirectional, ~10% tax floored) [tunable].
## Caps→Scrap 4:1 (kept from the old warehouse rate); Scrap→Caps is the reverse
## direction at the inverse chunk so grinding the loop always loses to the tax.
## Each row converts a fixed chunk of the SOURCE currency.
const CONV_CAPS_CHUNK := 40  # Caps → Scrap: spend 40 caps
const CONV_CAPS_RATE := 0.25  # → 10 scrap gross (before tax)
const CONV_SCRAP_CHUNK := 20  # Scrap → Caps: spend 20 scrap
const CONV_SCRAP_RATE := 2.0  # → 40 caps gross (before tax)
const CONV_TAX := 0.10

const RARITY_ORDER := ["common", "uncommon", "rare"]
const RARITY_COLORS := {
	"common": Color(0.85, 0.85, 0.85),
	"uncommon": Color(0.45, 0.8, 1.0),
	"rare": Color(0.72, 0.42, 0.84),
}
const PRICE_COLOR := Color(1.0, 0.84, 0.18)

## Rolled equipment stock — set once for the session in _build_content. Each
## entry: {base, rarity, price}. Stable until refreshed.
var _equip_stock: Array = []
## Rolled tool stock — set once for the session in _build_content. Each
## entry: tool_id String. Stable until refreshed.
var _tool_stock: Array = []
## How many times the refresh has been used this visit (price escalates).
var _refresh_uses: int = 0
## Transient feedback line for the last conversion. Kept as data (not a node)
## because the whole content box is rebuilt on every currency change — the
## conversion section re-renders it after each rebuild.
var _convert_status_text: String = ""

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
	if not MetaProgress.scrap_changed.is_connected(_on_market_changed):
		MetaProgress.scrap_changed.connect(_on_market_changed)
	if not MetaProgress.buildings_changed.is_connected(_rebuild_market):
		MetaProgress.buildings_changed.connect(_rebuild_market)
	if not MetaProgress.upgrades_changed.is_connected(_rebuild_market):
		MetaProgress.upgrades_changed.connect(_rebuild_market)

	_populate(container)


func _on_market_changed(_v: int) -> void:
	# The shared top bar owns the only persistent balance readout. Purchase and
	# conversion handlers update their local state/rebuild explicitly.
	pass


func _rebuild_market() -> void:
	if not is_instance_valid(_market_box):
		return
	for child in _market_box.get_children():
		child.queue_free()
	_populate(_market_box)


## Exact concept composition. The regenerated scene background already contains
## the merchant and counter as one illustration; this transparent spacer only
## protects their measured 456px left-side footprint from the service column.
func _populate(container: VBoxContainer) -> void:
	var columns := HBoxContainer.new()
	columns.name = "MarketNpcAndServices"
	columns.add_theme_constant_override("separation", 18)
	columns.custom_minimum_size = Vector2(0, CONTENT_MIN_HEIGHT)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(columns)

	var merchant_space := Control.new()
	merchant_space.name = "MarketMerchantSceneSpacer"
	merchant_space.custom_minimum_size = Vector2(MERCHANT_SCENE_WIDTH, CONTENT_MIN_HEIGHT)
	merchant_space.size_flags_horizontal = Control.SIZE_FILL
	merchant_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(merchant_space)

	var services := VBoxContainer.new()
	services.name = "MarketServiceColumn"
	services.add_theme_constant_override("separation", 2)
	services.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	services.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(services)

	# T1: tool shop (Caps). The header refresh button renders in BOTH states so
	# the ungated refresh stays reachable exactly as before the reskin.
	if MetaProgress.building_can("market", "tool_shop"):
		services.add_child(_build_tool_section())
	else:
		services.add_child(
			_locked_section(tr("UI_MARKET_TOOL_SHELF"), 1, true, TOOL_SECTION_HEIGHT)
		)

	# T2: equipment shop (Caps).
	if MetaProgress.building_can("market", "equip_shop"):
		services.add_child(_build_equip_section())
	else:
		services.add_child(
			_locked_section(tr("UI_MARKET_EQUIP_SHELF"), 2, false, EQUIP_SECTION_HEIGHT)
		)

	# T3: resource conversion (Caps↔Scrap) — from the old Warehouse.
	if MetaProgress.building_can("market", "resource_convert"):
		services.add_child(_build_convert_section())
	else:
		services.add_child(
			_locked_section(tr("UI_MARKET_CONVERT_TITLE"), 3, false, CONVERT_SECTION_HEIGHT)
		)


# --- Tool shop (T1, Caps) ---------------------------------------------------


func _build_tool_section() -> Control:
	var section := _make_section(tr("UI_MARKET_TOOL_SHELF"), true)
	section.name = "MarketToolShelf"
	section.custom_minimum_size = Vector2(0, TOOL_SECTION_HEIGHT)
	var body := section.get_meta("body") as VBoxContainer

	if _tool_stock.is_empty():
		var empty := Label.new()
		empty.text = tr("UI_MARKET_TOOL_EMPTY")
		_style_label(empty, 18, Color(0.8, 0.74, 0.6), 1)
		body.add_child(empty)
		return section

	# Concept: five tool cards stretch to fill one dominant shelf row.
	var shelf := HBoxContainer.new()
	shelf.add_theme_constant_override("separation", SHELF_CARD_GAP)
	shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(shelf)
	for tool_id in _tool_stock:
		shelf.add_child(_build_tool_tile(str(tool_id)))
	return section


## One exact-concept tool card. The generated full-height card is the only item
## frame; icon, name and price are laid over its quiet interior.
## Purchase path unchanged: _on_buy_tool (spend → add_tool_to_backpack → refund
## on full backpack).
func _build_tool_tile(tool_id: String) -> Control:
	var data := RunManager.get_tool_data(tool_id)
	var tool_name := Settings.t("TOOL_%s_TITLE" % tool_id, str(data.get("title", tool_id)))

	var card := PanelContainer.new()
	card.name = "MarketToolTile_%s" % tool_id
	card.custom_minimum_size = Vector2(0, TOOL_CARD_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tool_desc := Settings.t("TOOL_%s_DESC" % tool_id, "")
	var tool_tip := "[b]%s[/b]" % tool_name
	if not tool_desc.is_empty():
		tool_tip += "\n%s" % tool_desc
	Tooltip.bind_hover(card, tool_tip)
	card.add_theme_stylebox_override(
		"panel", _market_texture_style(MARKET_TOOL_CARD_PATH, T.ll_inset(), 16, 16, 0)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(col)

	var icon_holder := CenterContainer.new()
	icon_holder.custom_minimum_size = Vector2(0, 143)
	icon_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon_holder.add_child(icon)
	else:
		var glyph := Label.new()
		glyph.custom_minimum_size = SHELF_ICON
		glyph.text = tool_name.substr(0, 1) if tool_name != "" else "?"
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.add_theme_font_size_override("font_size", 34)
		glyph.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		icon_holder.add_child(glyph)

	# Frameless name line (tools keep their names — they're hand-authored).
	var name_lbl := Label.new()
	name_lbl.text = tool_name
	name_lbl.custom_minimum_size = Vector2(0, 32)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(name_lbl, 18, Color(0.95, 0.70, 0.24), 1)
	col.add_child(name_lbl)

	var buy_btn := _price_footer(MARKET_TOOL_PRICE, 175.0, 47.0)
	buy_btn.disabled = MetaProgress.caps < MARKET_TOOL_PRICE
	buy_btn.pressed.connect(_on_buy_tool.bind(tool_id, buy_btn))
	col.add_child(buy_btn)

	return card


func _on_buy_tool(tool_id: String, btn: Button) -> void:
	if not MetaProgress.spend_caps(MARKET_TOOL_PRICE):
		return
	if not RunManager.add_tool_to_backpack(tool_id):
		# Backpack full → refund the Caps so the player isn't charged for nothing.
		MetaProgress.add_caps(MARKET_TOOL_PRICE)
		if is_instance_valid(btn):
			_set_price_button_status(btn, tr("UI_MARKET_BACKPACK_FULL"))
		return
	if is_instance_valid(btn):
		btn.disabled = true
		_set_price_button_status(btn, tr("UI_MARKET_BOUGHT"))
	# caps_changed → _on_market_changed repaints the scrap chip; this button
	# keeps its SOLD state (pre-reskin behavior: other buttons repaint on the
	# next full rebuild).


# --- Equipment shop (T2, Caps) ----------------------------------------------


func _build_equip_section() -> Control:
	# No refresh button here: the tool-shelf one rerolls BOTH shelves for one
	# cost, so a second identical button just misled (owner 2026-07-08).
	var section := _make_section(tr("UI_MARKET_EQUIP_SHELF"))
	section.name = "MarketEquipmentShelf"
	section.custom_minimum_size = Vector2(0, EQUIP_SECTION_HEIGHT)
	var body := section.get_meta("body") as VBoxContainer

	if _equip_stock.is_empty():
		var empty := Label.new()
		empty.text = tr("UI_MARKET_EQUIP_EMPTY")
		_style_label(empty, 18, Color(0.8, 0.74, 0.6), 1)
		body.add_child(empty)
		return section

	var shelf := HBoxContainer.new()
	shelf.add_theme_constant_override("separation", SHELF_CARD_GAP)
	shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(shelf)
	for entry in _equip_stock:
		shelf.add_child(_build_equip_tile(entry))
	return section


## One exact-concept equipment card. The generated complete card shell owns the
## rarity frame; the inner EquipmentIcon contributes only the illustration.
## A rarity·slot line replaces generated names. Hover shows the shared tooltip.
## Purchase path unchanged: _on_buy_equipment (spend → instance → stash → refund
## on full stash).
func _build_equip_tile(entry: Dictionary) -> Control:
	var base_id: String = str(entry.get("base", ""))
	var rarity: String = str(entry.get("rarity", "common"))
	var price: int = int(entry.get("price", 0))
	var data := RunManager.get_equipment_data(base_id)
	var slot := str(data.get("slot", "head"))
	var equip_name := Settings.t("EQUIP_%s_NAME" % base_id, str(data.get("name", base_id)))

	var card := PanelContainer.new()
	card.name = "MarketEquipmentTile_%s" % base_id
	card.custom_minimum_size = Vector2(0, EQUIP_CARD_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Tooltip.bind_hover(card, EQUIP_TOOLTIP.text(data, slot, {"rarity": rarity}))
	var frame_path := str(MARKET_EQUIP_CARD_PATHS.get(rarity, MARKET_EQUIP_CARD_PATHS["common"]))
	card.add_theme_stylebox_override(
		"panel", _market_texture_style(frame_path, T.ll_inset(), 16, 16, 0)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(col)

	var icon_holder := CenterContainer.new()
	icon_holder.custom_minimum_size = Vector2(0, 184)
	icon_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# The reusable inventory EquipmentIcon intentionally resets itself to 64px in
	# _ready(). A market product card needs the accepted 154px illustration, so
	# render the same resolved equipment texture directly without its slot frame.
	var resolved := EQUIPMENT_ICON.resolve_equipment_texture(
		str(data.get("sprite", "")), slot, rarity
	)
	if resolved != null:
		var art := TextureRect.new()
		art.texture = resolved
		art.custom_minimum_size = EQUIP_SHELF_ICON
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_holder.add_child(art)
	else:
		var fallback_icon := EQUIPMENT_ICON.new()
		fallback_icon.set_equipment(slot, equip_name, "", rarity)
		fallback_icon.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		icon_holder.add_child(fallback_icon)
	col.add_child(icon_holder)

	# Rarity · slot line, rarity-tinted — generated names are noise (owner).
	var kind_lbl := Label.new()
	kind_lbl.text = (
		"%s · %s"
		% [
			tr("UI_MARKET_RARITY_%s" % rarity.to_upper()),
			tr("UI_EQUIP_SLOT_%s" % slot.to_upper()),
		]
	)
	kind_lbl.custom_minimum_size = Vector2(0, 43)
	kind_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(kind_lbl, 18, RARITY_COLORS.get(rarity, Color(0.95, 0.92, 0.85)), 1)
	col.add_child(kind_lbl)

	var buy_btn := _price_footer(price, 184.0, 50.0)
	buy_btn.disabled = MetaProgress.caps < price
	buy_btn.pressed.connect(_on_buy_equipment.bind(base_id, rarity, price, buy_btn))
	col.add_child(buy_btn)

	return card


func _on_buy_equipment(base_id: String, rarity: String, price: int, btn: Button) -> void:
	if not MetaProgress.spend_caps(price):
		return
	var inst := RunManager.make_equip_instance(base_id, rarity)
	if not MetaProgress.add_to_base_backpack(inst):
		# Base backpack full → refund the Caps so the player isn't charged for nothing.
		MetaProgress.add_caps(price)
		if is_instance_valid(btn):
			_set_price_button_status(btn, tr("UI_MARKET_BACKPACK_FULL"))
		return
	if is_instance_valid(btn):
		btn.disabled = true
		_set_price_button_status(btn, tr("UI_MARKET_BOUGHT"))
	# caps_changed → _on_market_changed repaints the scrap chip; this button
	# keeps its SOLD state (pre-reskin behavior).


# --- Refresh (ungated, Caps) --------------------------------------------------


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


## The concept's section-header refresh control: an olive lightline button with
## the refresh icon and 刷新 verb. The tool-shelf button rerolls both stocks
## with one spend, exactly the pre-reskin behavior.
func _refresh_button() -> Button:
	var cost := _refresh_cost()
	var btn := _olive_button(tr("UI_MARKET_REFRESH_VERB"))
	btn.custom_minimum_size = Vector2(152, 38)
	Tooltip.bind_hover(btn, "%s\n%s" % [
		tr("UI_MARKET_REFRESH_NOTE"),
		tr("UI_HOME_UPGRADE_COST").format({"n": cost}),
	])
	var icon_tex := T.lightline_tex("icon_refresh")
	if icon_tex != null:
		btn.icon = icon_tex
		btn.add_theme_constant_override("icon_max_width", 22)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.disabled = MetaProgress.caps < cost
	btn.pressed.connect(_on_refresh_stock)
	return btn


# --- Resource conversion (T3, from the removed Warehouse) --------------------
# The rows, math, and handlers are ported verbatim from warehouse_screen.gd's
# T3 conversion block (economy unchanged); only the row VISUAL follows the
# concept's row_convert language now.


func _build_convert_section() -> Control:
	var section := _make_section(tr("UI_MARKET_CONVERT_TITLE"))
	section.name = "MarketConversionPanel"
	section.custom_minimum_size = Vector2(0, CONVERT_SECTION_HEIGHT)
	Tooltip.bind_hover(section, (
		_convert_status_text if _convert_status_text != "" else tr("UI_MARKET_CONVERT_TAX_NOTE")
	))
	var body := section.get_meta("body") as VBoxContainer

	# Compact bottom strip: both directions share one line so the actual goods
	# keep most of the market's vertical space.
	var group := HBoxContainer.new()
	group.name = "MarketConversionStrip"
	group.custom_minimum_size = Vector2(0, 80)
	group.add_theme_constant_override("separation", 9)
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Tooltip.bind_hover(group, tr("UI_MARKET_CONVERT_TAX_NOTE"))
	body.add_child(group)

	# Caps → Scrap (4:1, ~10% tax).
	var caps_out := _converted_amount(CONV_CAPS_CHUNK, CONV_CAPS_RATE)
	group.add_child(
		_conversion_row(
			CONV_CAPS_CHUNK,
			"caps",
			caps_out,
			"scrap",
			MetaProgress.caps >= CONV_CAPS_CHUNK,
			_on_convert_caps_to_scrap
		)
	)

	# Scrap → Caps (reverse, ~10% tax).
	var scrap_out := _converted_amount(CONV_SCRAP_CHUNK, CONV_SCRAP_RATE)
	group.add_child(
		_conversion_row(
			CONV_SCRAP_CHUNK,
			"scrap",
			scrap_out,
			"caps",
			MetaProgress.scrap >= CONV_SCRAP_CHUNK,
			_on_convert_scrap_to_caps
		)
	)

	return section


## Post-tax destination amount for converting `chunk` of source at `rate`. Tax is
## floored off the gross so grinding never rounds in the player's favor.
func _converted_amount(chunk: int, rate: float) -> int:
	return int(floor(chunk * rate * (1.0 - CONV_TAX)))


## One concept conversion row (row_convert language): [src icon][amount field] →
## [dst icon][amount field] ... [olive swap button]. Same math + handlers as the
## pre-reskin row; the tax note lives on the section (and the row tooltip).
func _conversion_row(
	src_amount: int,
	src_cur: String,
	dst_amount: int,
	dst_cur: String,
	affordable: bool,
	cb: Callable
) -> Control:
	var panel := PanelContainer.new()
	panel.name = "MarketConversion_%s_to_%s" % [src_cur, dst_cur]
	panel.custom_minimum_size = Vector2(0, 80)
	panel.add_theme_stylebox_override(
		"panel", _market_texture_style(MARKET_EXCHANGE_ROW_PATH, T.ll_inset(), 14, 14, 0)
	)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Tooltip.bind_hover(panel, tr("UI_MARKET_CONVERT_TAX_NOTE"))

	var m := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(side, 12)
	for side in ["margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 8)
	panel.add_child(m)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(line)

	line.add_child(_ll_icon("icon_%s" % src_cur, 38))
	line.add_child(_amount_field(src_amount))
	line.add_child(_ll_icon("icon_arrow_right", 32))
	line.add_child(_ll_icon("icon_%s" % dst_cur, 38))
	line.add_child(_amount_field(dst_amount))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(spacer)

	var btn := _olive_button(tr("UI_MARKET_CONVERT_DO"))
	btn.custom_minimum_size = Vector2(144, 63)
	btn.add_theme_font_size_override("font_size", 16)
	Tooltip.bind_hover(btn, tr("UI_MARKET_CONVERT_TAX_NOTE"))
	btn.disabled = not affordable
	if affordable:
		btn.pressed.connect(cb)
	line.add_child(btn)
	return panel


func _on_convert_scrap_to_caps() -> void:
	if not MetaProgress.spend_scrap(CONV_SCRAP_CHUNK):
		return
	var out := _converted_amount(CONV_SCRAP_CHUNK, CONV_SCRAP_RATE)
	MetaProgress.add_caps(out)
	_flash_status(
		tr("UI_MARKET_CONVERT_OK").format(
			{
				"src": CONV_SCRAP_CHUNK,
				"src_name": tr("UI_MARKET_CONVERT_CUR_SCRAP"),
				"dst": out,
				"dst_name": tr("UI_MARKET_CONVERT_CUR_CAPS")
			}
		)
	)


func _on_convert_caps_to_scrap() -> void:
	if not MetaProgress.spend_caps(CONV_CAPS_CHUNK):
		return
	var out := _converted_amount(CONV_CAPS_CHUNK, CONV_CAPS_RATE)
	MetaProgress.add_scrap(out)
	_flash_status(
		tr("UI_MARKET_CONVERT_OK").format(
			{
				"src": CONV_CAPS_CHUNK,
				"src_name": tr("UI_MARKET_CONVERT_CUR_CAPS"),
				"dst": out,
				"dst_name": tr("UI_MARKET_CONVERT_CUR_SCRAP")
			}
		)
	)


## Record the conversion feedback and repaint: the content rebuild refreshes the
## row buttons' affordability AND re-renders the status line from the stored text
## (currency signals only repaint the balance labels, not the buttons).
func _flash_status(text: String) -> void:
	_convert_status_text = text
	_rebuild_market()


# --- Section / helpers ------------------------------------------------------


## A concept-specific shelf section. The generated panel frame, header and card
## inset reproduce the accepted 1920×1080 geometry instead of inheriting the
## generic building-panel proportions.
func _make_section(title: String, with_refresh: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel", _market_texture_style(MARKET_SHELF_FRAME_PATH, T.ll_section(), 22, 18, 7)
	)

	var margin := MarginContainer.new()
	# 7px StyleBox content inset + 17px layout inset = the measured 24px
	# shelf-to-first-card offset in the accepted concept.
	margin.add_theme_constant_override("margin_left", 17)
	margin.add_theme_constant_override("margin_right", 17)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 7)
	margin.add_child(body)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	body.add_child(header)
	var header_lbl := Label.new()
	header_lbl.text = title
	_style_label(header_lbl, TOK_FONT_SECTION, TOK_GOLD, 2)
	header.add_child(header_lbl)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	if with_refresh:
		header.add_child(_refresh_button())

	panel.set_meta("header", header)
	panel.set_meta("body", body)
	return panel


## A locked-function placeholder section with the tier needed to unlock it.
## `with_refresh` keeps the ungated refresh reachable from a locked shelf header.
func _locked_section(
	title: String, tier: int, with_refresh: bool = false, min_height: float = 0.0
) -> Control:
	var section := _make_section(title, with_refresh)
	if min_height > 0.0:
		section.custom_minimum_size = Vector2(0, min_height)
	var body := section.get_meta("body") as VBoxContainer
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_ll_icon("icon_lock", 26))
	var lbl := Label.new()
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(lbl, 17, Color(0.78, 0.6, 0.5), 1)
	lbl.text = tr("UI_MARKET_LOCKED_HINT").format({"t": tier})
	row.add_child(lbl)
	body.add_child(row)
	return section


## The concept-matched price footer on a shop card: compact olive plaque with
## centered amount -> Caps icon and no redundant 购买 verb. Caller still sets
## `.disabled` / `.pressed`.
func _price_footer(price: int, plaque_width: float, plaque_height: float) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(plaque_width, plaque_height)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	T.apply_concept_price_button(btn, "olive")
	T.centered_currency_button_content(btn, price, "caps", 20, 22, false, 10)
	return btn


func _set_price_button_status(btn: Button, status: String) -> void:
	var holder := btn.get_node_or_null("CenteredCurrencyContent") as Control
	if is_instance_valid(holder):
		holder.visible = false
	btn.text = status
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_font_size_override("font_size", 14)


## An orange lightline primary button (concept's main action button).
func _orange_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 40)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(0.16, 0.10, 0.04))
	btn.add_theme_color_override("font_hover_color", Color(0.20, 0.13, 0.05))
	btn.add_theme_color_override("font_pressed_color", Color(0.12, 0.08, 0.03))
	# Disabled = clearly darker plate + light text (dark-on-dim was unreadable).
	btn.add_theme_color_override("font_disabled_color", Color(0.88, 0.82, 0.68, 0.95))
	btn.add_theme_color_override("font_outline_color", Color(1.0, 0.92, 0.72, 0.35))
	btn.add_theme_constant_override("outline_size", 1)
	btn.add_theme_stylebox_override("normal", T.ll_button("normal"))
	btn.add_theme_stylebox_override("hover", T.ll_button("hover"))
	btn.add_theme_stylebox_override("pressed", T.ll_button("pressed"))
	var disabled_box := T.ll_button("normal")
	if disabled_box is StyleBoxTexture:
		(disabled_box as StyleBoxTexture).modulate_color = Color(0.42, 0.42, 0.42)
	btn.add_theme_stylebox_override("disabled", disabled_box)
	return btn


## An olive lightline secondary button (refresh / swap actions), cream text.
func _olive_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 40)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(0.93, 0.90, 0.78))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.86))
	btn.add_theme_color_override("font_pressed_color", Color(0.80, 0.77, 0.66))
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.52, 0.44, 0.9))
	T.apply_concept_price_button(btn, "olive")
	return btn


## The concept's recessed amount field in a conversion row.
func _amount_field(amount: int) -> Control:
	var field := PanelContainer.new()
	field.custom_minimum_size = Vector2(106, 51)
	var fallback := StyleBoxFlat.new()
	fallback.bg_color = Color(0.07, 0.065, 0.055, 0.95)
	fallback.border_color = Color(0.34, 0.30, 0.20, 0.9)
	fallback.set_border_width_all(1)
	fallback.set_corner_radius_all(4)
	var box := T.lightline_box("bar_plain", fallback, 24)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	field.add_theme_stylebox_override("panel", box)
	var lbl := Label.new()
	lbl.text = str(amount)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(lbl, 18, PRICE_COLOR, 1)
	field.add_child(lbl)
	return field


## Load one generated market frame as a nine-slice StyleBox. Every frame keeps
## a programmatic fallback, so a missing/importing asset cannot crash the shop.
func _market_texture_style(
	texture_path: String,
	fallback: StyleBox,
	margin_h: int,
	margin_v: int,
	content_margin: int
) -> StyleBox:
	if not ResourceLoader.exists(texture_path):
		return fallback
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return fallback
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margin_h
	style.texture_margin_right = margin_h
	style.texture_margin_top = margin_v
	style.texture_margin_bottom = margin_v
	style.content_margin_left = content_margin
	style.content_margin_right = content_margin
	style.content_margin_top = content_margin
	style.content_margin_bottom = content_margin
	return style


## A lightline PNG as a fixed-size TextureRect, or an equal-size empty spacer
## when the art is undelivered (warn-free placeholder).
func _ll_icon(icon_name: String, px: float) -> Control:
	var tex := T.lightline_tex(icon_name)
	if tex == null:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(px, px)
		return spacer
	var rect := TextureRect.new()
	rect.texture = tex
	rect.custom_minimum_size = Vector2(px, px)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Roll a small, session-stable tool stock from the whole tool pool.
func _roll_tool_stock() -> Array:
	var pool: Array = RunManager.tool_pool().duplicate()
	pool.shuffle()
	var stock: Array = []
	for i in range(min(MARKET_TOOL_COUNT, pool.size())):
		stock.append(str(pool[i]))
	return stock


## Roll the equipment shelf: ONE item per equipment slot (owner 2026-07-08).
## Per slot: roll a rarity by EQUIP_RARITY_WEIGHTS, pick a random base with that
## slot+rarity; if no base exists at that exact rarity, pick any base of the
## slot and keep its own rarity. Price follows the final rarity.
func _roll_equip_stock() -> Array:
	var by_slot := _list_equipment_by_slot()
	var stock: Array = []
	for slot in EQUIP_SLOT_ORDER:
		var entries: Array = by_slot.get(slot, [])
		if entries.is_empty():
			continue
		var rarity := _roll_rarity()
		var pool: Array = entries.filter(func(e): return str(e.get("rarity", "")) == rarity)
		var picked: Dictionary
		if pool.is_empty():
			picked = entries[randi() % entries.size()]
			rarity = str(picked.get("rarity", "common"))
		else:
			picked = pool[randi() % pool.size()]
		(
			stock
			. append(
				{
					"base": str(picked.get("id", "")),
					"rarity": rarity,
					"price": int(EQUIP_CAPS_PRICE.get(rarity, EQUIP_CAPS_PRICE["common"])),
				}
			)
		)
	return stock


## Weighted rarity roll for one shelf slot.
func _roll_rarity() -> String:
	var total := 0
	for r in EQUIP_RARITY_WEIGHTS:
		total += int(EQUIP_RARITY_WEIGHTS[r])
	var roll := randi() % maxi(total, 1)
	for r in RARITY_ORDER:
		roll -= int(EQUIP_RARITY_WEIGHTS.get(r, 0))
		if roll < 0:
			return r
	return "common"


## slot → Array of {id, rarity} for every sellable base on disk. Only the three
## shop rarities go on the shelf (set/cursed exotics drop elsewhere).
func _list_equipment_by_slot() -> Dictionary:
	var result := {}
	var dir = DirAccess.open(EQUIPMENT_DIR)
	if dir == null:
		return result
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var data := _load_json(EQUIPMENT_DIR + file_name)
		var slot := str(data.get("slot", ""))
		var rarity := str(data.get("rarity", "common"))
		# Set pieces are exotic drops. Their base JSON keeps a compatibility rarity,
		# but showing that value on the shelf made set art read as ordinary gear.
		if str(data.get("set_id", "")) != "":
			continue
		if slot == "" or not rarity in RARITY_ORDER:
			continue
		if not result.has(slot):
			result[slot] = []
		(result[slot] as Array).append({"id": file_name.get_basename(), "rarity": rarity})
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

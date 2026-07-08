## Market (黑市) building screen, re-skinned to the 2026-07-07 "lightline"
## concept (docs/art/previews/base_building_market_ui_simple_comic_20260707.png —
## the 3-tool layout; the `_6tools_` variant is deliberately NOT implemented):
##   工具货架 (T1 tool_shop)        — 3 shop cards (item icon + recessed name bar
##                                    + orange Caps price footer, the
##                                    btn_icon_syringe/armor/bag card language),
##                                    olive 刷新 button in the section header.
##   装备货架 (T2 equip_shop)       — equipment shelf cards in the same framing
##                                    (rarity-tinted names), own 刷新 button.
##   资源兑换 (T3 resource_convert) — row_convert-style rows: src icon + amount
##                                    field → dst icon + amount field + olive
##                                    swap button; scrap balance chip in the
##                                    section header.
## Refresh stays UNGATED (available from T1): the tool-shelf header carries the
## olive refresh button even while that shelf is still locked, so the function
## is reachable at every tier exactly as before; the equipment-shelf header adds
## a second button (concept parity) wired to the SAME reroll action/cost.
##
## VISUAL RESKIN ONLY — backend untouched: purchase (spend_caps + add_tool /
## make_equip_instance + add_to_stash with full-refund guards), escalating
## refresh cost, conversion math/handlers, and the tier gating via
## `_locked_section` are all the pre-reskin code paths.
##
## The bounty shelf moved to the OUTPOST in the 2026-07-07 redesign; the Market
## no longer has a bounty section. The base card-unlock/card-shop system was
## removed (Phase A refactor) — the Market doesn't sell cards.
##
## Every lightline PNG lookup falls back to a programmatic StyleBox / spacer /
## text so a missing Codex asset never crashes (warn-free placeholder rule).
## NO class_name (ADR-0006: subclass via path string, instantiate with `.new()`).
## Reads only the shared MetaProgress / RunManager API; edits no shared file.
extends "res://run_system/ui/buildings/building_screen_base.gd"

const EQUIPMENT_DIR := "res://run_system/data/equipment/"
const EQUIPMENT_ICON := preload("res://run_system/ui/equipment_icon.gd")

## Shop-card item icon size (tools + equipment).
const SHELF_ICON := Vector2(84, 84)
## Shop-card minimum width (concept: wide cards filling the shelf row).
const SHELF_CARD_MIN_W := 170.0

## Equipment buy prices in Caps, by rarity (spec: 60/140/280).
const EQUIP_CAPS_PRICE := {"common": 60, "uncommon": 140, "rare": 280}
## How many equipment items to stock per rarity bucket.
const EQUIP_STOCK_PER_RARITY := {"common": 2, "uncommon": 2, "rare": 1}
## Flat Caps price per tool (tools have no rarity tiers).
const MARKET_TOOL_PRICE := 40
## How many random tools to stock.
const MARKET_TOOL_COUNT := 3
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
	"rare": Color(1.0, 0.85, 0.35),
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

## Live-refresh handle: the convert-section scrap balance chip (the Caps balance
## lives on the base header's cost chip, so the content doesn't duplicate it).
var _mkt_scrap_label: Label = null
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
	_refresh_balances()


func _rebuild_market() -> void:
	if not is_instance_valid(_market_box):
		return
	for child in _market_box.get_children():
		child.queue_free()
	_populate(_market_box)


func _refresh_balances() -> void:
	if is_instance_valid(_mkt_scrap_label):
		_mkt_scrap_label.text = "%d" % MetaProgress.scrap


## Concept section order: tool shelf → equipment shelf → resource exchange.
## (No balances banner — the base header's cost chip already shows Caps.)
func _populate(container: VBoxContainer) -> void:
	# T1: tool shop (Caps). The header refresh button renders in BOTH states so
	# the ungated refresh stays reachable exactly as before the reskin.
	if MetaProgress.building_can("market", "tool_shop"):
		container.add_child(_build_tool_section())
	else:
		container.add_child(_locked_section(tr("UI_MARKET_TOOL_SHELF"), 1, true))

	# T2: equipment shop (Caps).
	if MetaProgress.building_can("market", "equip_shop"):
		container.add_child(_build_equip_section())
	else:
		container.add_child(_locked_section(tr("UI_MARKET_EQUIP_SHELF"), 2))

	# T3: resource conversion (Caps↔Scrap) — from the old Warehouse.
	if MetaProgress.building_can("market", "resource_convert"):
		container.add_child(_build_convert_section())
	else:
		container.add_child(_locked_section(tr("UI_MARKET_CONVERT_TITLE"), 3))


# --- Tool shop (T1, Caps) ---------------------------------------------------


func _build_tool_section() -> Control:
	var section := _make_section(tr("UI_MARKET_TOOL_SHELF"), true)
	var body := section.get_meta("body") as VBoxContainer

	if _tool_stock.is_empty():
		var empty := Label.new()
		empty.text = tr("UI_MARKET_TOOL_EMPTY")
		_style_label(empty, 18, Color(0.8, 0.74, 0.6), 1)
		body.add_child(empty)
		return section

	# Concept: the 3 tool cards stretch to fill the shelf row.
	var shelf := HBoxContainer.new()
	shelf.add_theme_constant_override("separation", 14)
	shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(shelf)
	for tool_id in _tool_stock:
		shelf.add_child(_build_tool_tile(str(tool_id)))
	return section


## One concept shop card (btn_icon_* language): framed dark card with the item
## icon on top, a recessed name bar, and the orange Caps price footer (the buy
## button). The tool description moves to the card tooltip.
## Purchase path unchanged: _on_buy_tool (spend → add_tool_to_backpack → refund
## on full backpack).
func _build_tool_tile(tool_id: String) -> Control:
	var data := RunManager.get_tool_data(tool_id)
	var tool_name := Settings.t("TOOL_%s_TITLE" % tool_id, str(data.get("title", tool_id)))

	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", T.ll_inset())
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.tooltip_text = Settings.t("TOOL_%s_DESC" % tool_id, "")
	var tm := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		tm.add_theme_constant_override(s, 10)
	tile.add_child(tm)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(SHELF_CARD_MIN_W, 0)
	tm.add_child(col)

	var icon_holder := CenterContainer.new()
	icon_holder.custom_minimum_size = Vector2(0, SHELF_ICON.y + 12)
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

	col.add_child(_name_bar(tool_name, Color(0.95, 0.92, 0.85)))

	var buy_btn := _price_footer(MARKET_TOOL_PRICE)
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
	# caps_changed → _on_market_changed repaints the scrap chip; this button
	# keeps its SOLD state (pre-reskin behavior: other buttons repaint on the
	# next full rebuild).


# --- Equipment shop (T2, Caps) ----------------------------------------------


func _build_equip_section() -> Control:
	# Second refresh button (concept parity) — same reroll action + cost.
	var section := _make_section(tr("UI_MARKET_EQUIP_SHELF"), true)
	var body := section.get_meta("body") as VBoxContainer

	if _equip_stock.is_empty():
		var empty := Label.new()
		empty.text = tr("UI_MARKET_EQUIP_EMPTY")
		_style_label(empty, 18, Color(0.8, 0.74, 0.6), 1)
		body.add_child(empty)
		return section

	var shelf := HBoxContainer.new()
	shelf.add_theme_constant_override("separation", 14)
	shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(shelf)
	for entry in _equip_stock:
		shelf.add_child(_build_equip_tile(entry))
	return section


## One equipment shop card: same btn_icon_* framing as the tool cards, with the
## rarity-framed EQUIPMENT_ICON (its hover tooltip is unchanged), a rarity-
## tinted name bar, and the orange Caps price footer.
## Purchase path unchanged: _on_buy_equipment (spend → instance → stash → refund
## on full stash).
func _build_equip_tile(entry: Dictionary) -> Control:
	var base_id: String = str(entry.get("base", ""))
	var rarity: String = str(entry.get("rarity", "common"))
	var price: int = int(entry.get("price", 0))
	var data := RunManager.get_equipment_data(base_id)
	var slot := str(data.get("slot", "head"))
	var equip_name := Settings.t("EQUIP_%s_NAME" % base_id, str(data.get("name", base_id)))

	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", T.ll_inset())
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tm := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		tm.add_theme_constant_override(s, 10)
	tile.add_child(tm)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(SHELF_CARD_MIN_W, 0)
	tm.add_child(col)

	var icon_holder := CenterContainer.new()
	icon_holder.custom_minimum_size = Vector2(0, SHELF_ICON.y + 12)
	var icon := EQUIPMENT_ICON.new()
	icon.custom_minimum_size = SHELF_ICON
	icon.set_equipment(slot, equip_name, str(data.get("sprite", "")), rarity)
	icon.set_hover_tooltip(
		"[b]%s[/b]\n%s" % [equip_name, tr("UI_MARKET_RARITY_%s" % rarity.to_upper())]
	)
	icon_holder.add_child(icon)
	col.add_child(icon_holder)

	col.add_child(_name_bar(equip_name, RARITY_COLORS.get(rarity, Color(0.95, 0.92, 0.85))))

	var buy_btn := _price_footer(price)
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
## the refresh icon, 刷新 verb, and the escalating Caps cost badge. Both shelf
## headers get one; they trigger the SAME reroll (one spend rerolls both stocks,
## exactly the pre-reskin behavior).
func _refresh_button() -> Button:
	var cost := _refresh_cost()
	var btn := _olive_button(tr("UI_MARKET_REFRESH_VERB"))
	btn.custom_minimum_size = Vector2(176, 42)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.tooltip_text = tr("UI_MARKET_REFRESH_NOTE")
	var icon_tex := T.lightline_tex("icon_refresh")
	if icon_tex != null:
		btn.icon = icon_tex
		btn.add_theme_constant_override("icon_max_width", 22)
	btn.disabled = MetaProgress.caps < cost
	btn.pressed.connect(_on_refresh_stock)
	btn.add_child(T.overlay_cost_badge(cost, "caps", 14, 15, -8, -62))
	return btn


# --- Resource conversion (T3, from the removed Warehouse) --------------------
# The rows, math, and handlers are ported verbatim from warehouse_screen.gd's
# T3 conversion block (economy unchanged); only the row VISUAL follows the
# concept's row_convert language now.


func _build_convert_section() -> Control:
	var section := _make_section(tr("UI_MARKET_CONVERT_TITLE"))
	var body := section.get_meta("body") as VBoxContainer

	# Live Scrap balance chip in the section header (Caps already shows on the
	# base header chip; Scrap is the one balance this screen must add).
	var header := section.get_meta("header") as HBoxContainer
	var scrap_row := T.currency_row(MetaProgress.scrap, "scrap", 20, 22)
	header.add_child(scrap_row)
	_mkt_scrap_label = scrap_row.get_meta("amount_label") as Label
	_mkt_scrap_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.62))

	# Group both conversion rows in one block so they read as one function.
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", TOK_ROW_SEP)
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

	var tax_lbl := Label.new()
	tax_lbl.text = tr("UI_MARKET_CONVERT_TAX_NOTE")
	tax_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(tax_lbl, TOK_FONT_DIM, TOK_TEXT_DIM, 1)
	body.add_child(tax_lbl)

	# Last-conversion feedback (survives the rebuild the currency change causes).
	if _convert_status_text != "":
		var status := Label.new()
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style_label(status, 17, Color(0.70, 0.86, 0.55), 1)
		status.text = _convert_status_text
		body.add_child(status)
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
	panel.add_theme_stylebox_override("panel", T.ll_inset())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.tooltip_text = tr("UI_MARKET_CONVERT_TAX_NOTE")

	var m := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(side, 12)
	for side in ["margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 8)
	panel.add_child(m)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(line)

	line.add_child(_ll_icon("icon_%s" % src_cur, 34))
	line.add_child(_amount_field(src_amount))
	line.add_child(_ll_icon("icon_arrow_right", 26))
	line.add_child(_ll_icon("icon_%s" % dst_cur, 34))
	line.add_child(_amount_field(dst_amount))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(spacer)

	var btn := _olive_button("")
	btn.custom_minimum_size = Vector2(110, 42)
	var swap_tex := T.lightline_tex("icon_swap")
	if swap_tex != null:
		btn.icon = swap_tex
		btn.add_theme_constant_override("icon_max_width", 24)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.tooltip_text = tr("UI_MARKET_CONVERT_DO")
	else:
		btn.text = tr("UI_MARKET_CONVERT_DO")
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


## A lightline shelf section: ll_section panel, a header row (gold title left,
## optional olive refresh button right — the header HBox is stored on the
## "header" meta for extra chips), and a content VBox on the "body" meta.
func _make_section(title: String, with_refresh: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", T.ll_section())

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, TOK_MARGIN_OUTER)
	panel.add_child(margin)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", TOK_ROW_SEP)
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
func _locked_section(title: String, tier: int, with_refresh: bool = false) -> Control:
	var section := _make_section(title, with_refresh)
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


## The recessed name bar under a shop card's item icon (concept: a slim dark
## framed strip). bar_plain 9-slice when delivered, flat dark box otherwise.
func _name_bar(text: String, color: Color) -> Control:
	var bar := PanelContainer.new()
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
	bar.add_theme_stylebox_override("panel", box)
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(lbl, 15, color, 1)
	bar.add_child(lbl)
	return bar


## The orange price footer (buy button) on a shop card: 购买 verb left, Caps
## amount+icon badge right. Caller still sets `.disabled` / `.pressed`.
func _price_footer(price: int) -> Button:
	var btn := _orange_button(tr("UI_MARKET_BUY_VERB"))
	btn.custom_minimum_size = Vector2(0, 40)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_child(T.overlay_cost_badge(price, "caps", 14, 15, -8, -64))
	return btn


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
	btn.add_theme_color_override("font_disabled_color", Color(0.30, 0.24, 0.16, 0.9))
	btn.add_theme_color_override("font_outline_color", Color(1.0, 0.92, 0.72, 0.35))
	btn.add_theme_constant_override("outline_size", 1)
	btn.add_theme_stylebox_override("normal", T.ll_button("normal"))
	btn.add_theme_stylebox_override("hover", T.ll_button("hover"))
	btn.add_theme_stylebox_override("pressed", T.ll_button("pressed"))
	var disabled_box := T.ll_button("normal")
	if disabled_box is StyleBoxTexture:
		(disabled_box as StyleBoxTexture).modulate_color = Color(0.55, 0.55, 0.55)
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
	btn.add_theme_stylebox_override("normal", T.ll_button_olive("normal"))
	btn.add_theme_stylebox_override("hover", T.ll_button_olive("hover"))
	btn.add_theme_stylebox_override("pressed", T.ll_button_olive("pressed"))
	var disabled_box := T.ll_button_olive("normal")
	if disabled_box is StyleBoxTexture:
		(disabled_box as StyleBoxTexture).modulate_color = Color(0.55, 0.55, 0.55)
	btn.add_theme_stylebox_override("disabled", disabled_box)
	return btn


## The concept's recessed amount field in a conversion row.
func _amount_field(amount: int) -> Control:
	var field := PanelContainer.new()
	field.custom_minimum_size = Vector2(110, 42)
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

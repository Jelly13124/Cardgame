## Market (黑市) building screen. Subclasses the shared building shell and fills
## the content VBox with the Market's tier-gated functions:
##   - T1 equip_shop : buy equipment INSTANCES with Caps (rarity-priced).
##   - T1 card_unlock: spend Core to unlock cards outside the base/hero pool.
##   - T3 card_shop  : buy an unlocked card with Caps (gated; minimal — see REPORT).
##
## NO class_name (ADR-0006: subclass via path string, instantiate with `.new()`).
## Reads only the shared MetaProgress / RunManager API; edits no shared file.
extends "res://run_system/ui/buildings/building_screen_base.gd"

const EQUIPMENT_DIR := "res://run_system/data/equipment/"
const CARD_DIR := "res://battle_scene/card_info/player/"
const EQUIPMENT_ICON := preload("res://run_system/ui/equipment_icon.gd")
const CARD_FACTORY_SCENE := preload("res://battle_scene/my_card_factory.tscn")

## Real-card display footprint: the native 208×286 card scaled down for shop tiles.
const CARD_NATIVE := Vector2(208, 286)
const CARD_TILE_SCALE := 0.62
## Equipment shelf-tile icon size.
const SHELF_ICON := Vector2(96, 96)

## Equipment buy prices in Caps, by rarity (spec: 60/140/280).
const EQUIP_CAPS_PRICE := {"common": 60, "uncommon": 140, "rare": 280}
## Card buy prices (T3 card_shop) in Caps, by rarity (spec: 200/350/600).
const CARD_CAPS_PRICE := {"common": 200, "uncommon": 350, "rare": 600}
## Core cost to unlock a card (T1 card_unlock).
const CARD_UNLOCK_CORE := 40
## How many equipment items to stock per rarity bucket.
const EQUIP_STOCK_PER_RARITY := {"common": 2, "uncommon": 2, "rare": 1}

const RARITY_ORDER := ["common", "uncommon", "rare"]
const RARITY_COLORS := {
	"common": Color(0.85, 0.85, 0.85),
	"uncommon": Color(0.45, 0.8, 1.0),
	"rare": Color(1.0, 0.85, 0.35),
}
const SECTION_BG := Color(0.080, 0.055, 0.040, 0.92)
const SECTION_BORDER := Color(0.55, 0.30, 0.13, 1.0)
const PRICE_COLOR := Color(1.0, 0.84, 0.18)

## Rolled equipment stock — set once for the session in _build_content. Each
## entry: {base, rarity, price}. Stable until the screen is rebuilt.
var _equip_stock: Array = []

## Live-refresh handles so balances + buttons repaint without a full rebuild.
var _caps_label: Label = null
var _mkt_core_label: Label = null
## The whole content host, so currency/building changes can rebuild the lists.
var _market_box: VBoxContainer = null
## Card factory for rendering real card visuals in the unlock / card-shop tiles.
## Persists across rebuilds (lives on the screen, not in _market_box).
var _card_factory: Node = null


func _build_content(container: VBoxContainer) -> void:
	# Roll equipment stock once for the session (stable across refresh).
	if _equip_stock.is_empty():
		_equip_stock = _roll_equip_stock()

	# Card factory renders real card art in the unlock / card-shop tiles. Built once
	# and parented to the screen so it survives _market_box rebuilds (mirrors loot_reward).
	if _card_factory == null:
		_card_factory = CARD_FACTORY_SCENE.instantiate()
		add_child(_card_factory)
		_card_factory.card_size = CARD_NATIVE

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

	# T1: equipment shop (Caps).
	if MetaProgress.building_can("market", "equip_shop"):
		container.add_child(_build_equip_section())
	else:
		container.add_child(_locked_section(tr("UI_MARKET_EQUIP_SECTION"), 1))

	# T1: card unlock (Core).
	if MetaProgress.building_can("market", "card_unlock"):
		container.add_child(_build_card_unlock_section())
	else:
		container.add_child(_locked_section(tr("UI_MARKET_UNLOCK_SECTION"), 1))

	# T3: card shop (Caps) — gated; minimal (see REPORT for the missing target).
	if MetaProgress.building_can("market", "card_shop"):
		container.add_child(_build_card_shop_section())
	else:
		container.add_child(_locked_section(tr("UI_MARKET_CARD_SHOP_SECTION"), 3))


# --- Balances --------------------------------------------------------------


func _build_balances_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)

	var caps_title := Label.new()
	caps_title.text = tr("UI_MARKET_CAPS")
	_style_label(caps_title, 20, Color(0.90, 0.86, 0.70), 1)
	row.add_child(caps_title)

	_caps_label = Label.new()
	_caps_label.text = "%d" % MetaProgress.caps
	_style_label(_caps_label, 22, PRICE_COLOR, 2)
	row.add_child(_caps_label)

	var core_title := Label.new()
	core_title.text = tr("UI_MARKET_CORE")
	_style_label(core_title, 20, Color(0.90, 0.86, 0.70), 1)
	row.add_child(core_title)

	_mkt_core_label = Label.new()
	_mkt_core_label.text = "%d" % MetaProgress.core
	_style_label(_mkt_core_label, 22, Color(0.55, 0.85, 1.0), 2)
	row.add_child(_mkt_core_label)

	return row


# --- Equipment shop (T1, Caps) ---------------------------------------------


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


# --- Card unlock (T1, Core) ------------------------------------------------


func _build_card_unlock_section() -> Control:
	var section := _make_section(tr("UI_MARKET_UNLOCK_SECTION"))
	var body := section.get_meta("body") as VBoxContainer

	var locked := _list_lockable_cards()
	if locked.is_empty():
		var empty := Label.new()
		empty.text = tr("UI_MARKET_UNLOCK_EMPTY")
		_style_label(empty, 18, Color(0.8, 0.74, 0.6), 1)
		body.add_child(empty)
		return section

	# Show the real card art for each lockable card, with an unlock button beneath.
	var grid := _card_grid()
	body.add_child(grid)
	var unlock_text := tr("UI_MARKET_UNLOCK_CORE").format({"n": CARD_UNLOCK_CORE})
	for card in locked:
		var cid := str(card.get("id", ""))
		grid.add_child(
			_build_card_tile(
				cid, unlock_text, MetaProgress.core < CARD_UNLOCK_CORE, _on_unlock_card.bind(cid)
			)
		)
	return section


func _on_unlock_card(card_id: String, btn: Button) -> void:
	# MetaProgress.unlock_card handles the 40-Core spend + append + save.
	if not MetaProgress.unlock_card(card_id):
		return
	if is_instance_valid(btn):
		btn.disabled = true
		btn.text = tr("UI_MARKET_UNLOCKED")
	# Rebuild so the just-unlocked card leaves the list (and appears in the T3
	# card shop if that tier is active).
	_rebuild_market()


## Cards on disk in the player card pool that are NOT yet unlocked: excludes
## the already-unlocked pool, _plus upgrades, and OTHER heroes' exclusive cards.
func _list_lockable_cards() -> Array:
	var result: Array = []
	var unlocked := MetaProgress.get_unlocked_card_pool()
	var active_hero := str(RunManager.current_hero_id) if RunManager else ""

	# Block every OTHER hero's exclusive cards (the active hero's are in the
	# unlocked pool already, so they won't appear as lockable anyway).
	var blocked := {}
	for h in MetaProgress.HERO_EXCLUSIVE_CARDS:
		if h != active_hero:
			for cid in MetaProgress.HERO_EXCLUSIVE_CARDS[h]:
				blocked[str(cid)] = true

	var dir = DirAccess.open(CARD_DIR)
	if dir == null:
		return result
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var card_id := file_name.get_basename()
		if card_id.ends_with("_plus"):
			continue
		if card_id in unlocked:
			continue
		if blocked.has(card_id):
			continue
		var data := _load_json(CARD_DIR + file_name)
		if str(data.get("type", "")) == "curse":
			continue  # curses are never offered as unlockable cards
		(
			result
			. append(
				{
					"id": card_id,
					"title": str(data.get("title", card_id)),
					"rarity": str(data.get("rarity", "common")),
				}
			)
		)
	return result


# --- Card shop (T3, Caps) — minimal/gated; see REPORT -----------------------


func _build_card_shop_section() -> Control:
	var section := _make_section(tr("UI_MARKET_CARD_SHOP_SECTION"))
	var body := section.get_meta("body") as VBoxContainer

	# Spend Caps to add an unlocked card onto the permanent run deck via
	# MetaProgress.buy_card_caps; purchased cards join every future run's deck.
	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = tr("UI_MARKET_CARD_SHOP_NOTE")
	_style_label(note, 17, Color(0.85, 0.66, 0.40), 1)
	body.add_child(note)

	var grid := _card_grid()
	body.add_child(grid)
	var unlocked := MetaProgress.get_unlocked_card_pool()
	var shown := 0
	for card_id in unlocked:
		var data := _load_json(CARD_DIR + card_id + ".json")
		if data.is_empty():
			continue
		var rarity := str(data.get("rarity", "common"))
		var price := int(CARD_CAPS_PRICE.get(rarity, CARD_CAPS_PRICE["common"]))
		grid.add_child(
			_build_card_tile(
				card_id,
				tr("UI_MARKET_BUY_CAPS").format({"n": price}),
				MetaProgress.caps < price,
				_on_buy_card_caps.bind(card_id, price)
			)
		)
		shown += 1
		if shown >= 8:
			break

	return section


func _on_buy_card_caps(card_id: String, price: int, btn: Button) -> void:
	# buy_card_caps spends the Caps + appends to purchased_cards (injected into
	# every future run's deck) + saves. Returns false on insufficient Caps.
	if not MetaProgress.buy_card_caps(card_id, price):
		return
	if is_instance_valid(btn):
		btn.text = tr("UI_MARKET_BOUGHT")
	# caps_changed → _on_market_changed repaints balances + the row buttons'
	# disabled state via _refresh_balances; rebuild so prices re-gate cleanly.
	_rebuild_market()


# --- Section / helpers ------------------------------------------------------


## A titled panel; the inner content VBox is stored on the panel's "body" meta.
func _make_section(title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(SECTION_BG, SECTION_BORDER, 4, 2)
	)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	panel.add_child(margin)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)

	var header := Label.new()
	header.text = title
	_style_label(header, 22, Color(0.86, 0.78, 0.52), 2)
	body.add_child(header)

	panel.set_meta("body", body)
	return panel


## A locked-function placeholder section with the tier needed to unlock it.
func _locked_section(title: String, tier: int) -> Control:
	var section := _make_section(title)
	var body := section.get_meta("body") as VBoxContainer
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = tr("UI_MARKET_LOCKED_HINT").format({"t": tier})
	_style_label(hint, 18, Color(0.72, 0.64, 0.50), 1)
	body.add_child(hint)
	return section


## A wrapping grid (HFlowContainer) that lays card tiles out across the width.
func _card_grid() -> HFlowContainer:
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return grid


## A card tile: the real card art (scaled, display-only) above one action button.
## press_cb is bound with everything EXCEPT the button — we append the button here.
func _build_card_tile(
	card_id: String, btn_text: String, disabled: bool, press_cb: Callable
) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(_make_card_visual(card_id))

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(CARD_NATIVE.x * CARD_TILE_SCALE, 38)
	btn.add_theme_font_size_override("font_size", 16)
	T.apply_button_theme(btn)
	btn.text = btn_text
	btn.disabled = disabled
	btn.pressed.connect(press_cb.bind(btn))
	col.add_child(btn)
	return col


## Real card visual, non-interactive, scaled down to the shop-tile footprint. The
## scaled card pivots from its top-left so it exactly fills a CARD_TILE_SCALE wrapper.
func _make_card_visual(card_id: String) -> Control:
	var disp := CARD_NATIVE * CARD_TILE_SCALE
	var wrapper := Control.new()
	wrapper.custom_minimum_size = disp
	if _card_factory == null:
		return wrapper
	var card = _card_factory.create_card(card_id, null)
	if card:
		if card.get_parent():
			card.get_parent().remove_child(card)
		card.can_be_interacted_with = false
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.pivot_offset = Vector2.ZERO
		card.scale = Vector2(CARD_TILE_SCALE, CARD_TILE_SCALE)
		card.position = Vector2.ZERO
		wrapper.add_child(card)
	return wrapper


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

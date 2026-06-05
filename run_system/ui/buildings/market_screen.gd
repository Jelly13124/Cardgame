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
var _core_label: Label = null
## The whole content host, so currency/building changes can rebuild the lists.
var _market_box: VBoxContainer = null


func _build_content(container: VBoxContainer) -> void:
	# Roll equipment stock once for the session (stable across refresh).
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
	if is_instance_valid(_core_label):
		_core_label.text = "%d" % MetaProgress.core


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

	_core_label = Label.new()
	_core_label.text = "%d" % MetaProgress.core
	_style_label(_core_label, 22, Color(0.55, 0.85, 1.0), 2)
	row.add_child(_core_label)

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

	for entry in _equip_stock:
		body.add_child(_build_equip_row(entry))
	return section


func _build_equip_row(entry: Dictionary) -> Control:
	var base_id: String = str(entry.get("base", ""))
	var rarity: String = str(entry.get("rarity", "common"))
	var price: int = int(entry.get("price", 0))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var data := RunManager.get_equipment_data(base_id)
	var equip_name := Settings.t("EQUIP_%s_NAME" % base_id, str(data.get("name", base_id)))

	var name_lbl := Label.new()
	name_lbl.text = equip_name
	name_lbl.custom_minimum_size = Vector2(280, 0)
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_style_label(name_lbl, 19, Color(0.95, 0.92, 0.85), 1)
	row.add_child(name_lbl)

	var rarity_lbl := Label.new()
	rarity_lbl.text = tr("UI_MARKET_RARITY_%s" % rarity.to_upper())
	rarity_lbl.custom_minimum_size = Vector2(110, 0)
	_style_label(rarity_lbl, 18, RARITY_COLORS.get(rarity, Color.WHITE), 1)
	row.add_child(rarity_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var buy_btn := Button.new()
	buy_btn.custom_minimum_size = Vector2(190, 40)
	buy_btn.add_theme_font_size_override("font_size", 18)
	T.apply_button_theme(buy_btn)
	buy_btn.text = tr("UI_MARKET_BUY_CAPS").format({"n": price})
	buy_btn.disabled = MetaProgress.caps < price
	buy_btn.pressed.connect(_on_buy_equipment.bind(base_id, rarity, price, buy_btn))
	row.add_child(buy_btn)

	return row


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

	for card in locked:
		body.add_child(_build_card_unlock_row(card))
	return section


func _build_card_unlock_row(card: Dictionary) -> Control:
	var card_id: String = str(card.get("id", ""))
	var title: String = str(card.get("title", card_id))
	var rarity: String = str(card.get("rarity", "common"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := Label.new()
	name_lbl.text = title
	name_lbl.custom_minimum_size = Vector2(280, 0)
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_style_label(name_lbl, 19, Color(0.95, 0.92, 0.85), 1)
	row.add_child(name_lbl)

	var rarity_lbl := Label.new()
	rarity_lbl.text = tr("UI_MARKET_RARITY_%s" % rarity.to_upper())
	rarity_lbl.custom_minimum_size = Vector2(110, 0)
	_style_label(rarity_lbl, 18, RARITY_COLORS.get(rarity, Color.WHITE), 1)
	row.add_child(rarity_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var unlock_btn := Button.new()
	unlock_btn.custom_minimum_size = Vector2(190, 40)
	unlock_btn.add_theme_font_size_override("font_size", 18)
	T.apply_button_theme(unlock_btn)
	unlock_btn.text = tr("UI_MARKET_UNLOCK_CORE").format({"n": CARD_UNLOCK_CORE})
	unlock_btn.disabled = MetaProgress.core < CARD_UNLOCK_CORE
	unlock_btn.pressed.connect(_on_unlock_card.bind(card_id, unlock_btn))
	row.add_child(unlock_btn)

	return row


func _on_unlock_card(card_id: String, btn: Button) -> void:
	# No MetaProgress.unlock_card() exists yet — implement inline per the spec:
	# check core>=cost, add_core(-cost), append to unlocked_cards, save. (REPORT:
	# a MetaProgress.unlock_card(id)->bool would be cleaner.)
	if card_id == "" or MetaProgress.core < CARD_UNLOCK_CORE:
		return
	if card_id in MetaProgress.unlocked_cards:
		return
	MetaProgress.add_core(-CARD_UNLOCK_CORE)  # saves + emits core_changed
	MetaProgress.unlocked_cards.append(card_id)
	MetaProgress.save_progress()
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

	# There is no out-of-run "add card to starting deck" target: player_deck is a
	# per-RUN structure (RunManager.player_deck), and the persistent starting deck
	# lives in the hero JSON, not in MetaProgress. So this T3 function cannot yet
	# deposit a bought card anywhere meaningful. Show it as a disabled preview
	# listing unlocked cards + their Caps price, with an explanatory note.
	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = tr("UI_MARKET_CARD_SHOP_NOTE")
	_style_label(note, 17, Color(0.85, 0.66, 0.40), 1)
	body.add_child(note)

	var unlocked := MetaProgress.get_unlocked_card_pool()
	var shown := 0
	for card_id in unlocked:
		var data := _load_json(CARD_DIR + card_id + ".json")
		if data.is_empty():
			continue
		var rarity := str(data.get("rarity", "common"))
		var title := str(data.get("title", card_id))
		var price := int(CARD_CAPS_PRICE.get(rarity, CARD_CAPS_PRICE["common"]))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_lbl := Label.new()
		name_lbl.text = title
		name_lbl.custom_minimum_size = Vector2(280, 0)
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_style_label(name_lbl, 19, Color(0.95, 0.92, 0.85), 1)
		row.add_child(name_lbl)

		var rarity_lbl := Label.new()
		rarity_lbl.text = tr("UI_MARKET_RARITY_%s" % rarity.to_upper())
		rarity_lbl.custom_minimum_size = Vector2(110, 0)
		_style_label(rarity_lbl, 18, RARITY_COLORS.get(rarity, Color.WHITE), 1)
		row.add_child(rarity_lbl)

		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)

		var buy_btn := Button.new()
		buy_btn.custom_minimum_size = Vector2(190, 40)
		buy_btn.add_theme_font_size_override("font_size", 18)
		T.apply_button_theme(buy_btn)
		buy_btn.text = tr("UI_MARKET_BUY_CAPS").format({"n": price})
		buy_btn.disabled = true  # no deck target yet — see REPORT.
		row.add_child(buy_btn)

		body.add_child(row)
		shown += 1
		if shown >= 8:
			break

	return section


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

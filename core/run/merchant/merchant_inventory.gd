extends RefCounted

## A merchant's stock (STS2 MerchantInventory): card, relic and tool entries
## plus card removal, and the one price pipeline every entry asks. Numbers
## from content/economy/merchant_economy.json; rolls use the run's `shops`
## stream, so a seed gives the same stock.

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const CARD_POOLS = preload("uid://c76axesxo6wit")  # res://core/run/card_pools.gd
const CARD_ENTRY = preload("uid://c4olkv36j1puq")  # res://core/run/merchant/merchant_card_entry.gd
const TOOL_ENTRY = preload("uid://cdyy8x7o7tfmp")  # res://core/run/merchant/merchant_tool_entry.gd
const RELIC_ENTRY = preload("uid://w22svgh4s36c")  # res://core/run/merchant/merchant_relic_entry.gd
const REMOVAL_ENTRY = preload("uid://b4mese8vlpdrt")  # res://core/run/merchant/merchant_card_removal_entry.gd

## The run facade (RunManager).
var owner
var card_entries: Array = []
var relic_entries: Array = []
var tool_entries: Array = []
var card_removal_entry = null


static func economy() -> Dictionary:
	return MODEL_DB.data("economy", "base:merchant_economy")


## A fresh merchant: six cards (one typed card on sale), three relics, three
## tools and card removal.
static func create(p_owner) -> RefCounted:
	var inv = load("uid://dgj1md8jt0tg7").new()  # res://core/run/merchant/merchant_inventory.gd
	inv.owner = p_owner
	var eco := economy()
	var rng = p_owner.rng("shops")
	var slots: Array = eco.get("card_slots", [])
	var typed: Array = []
	for i in slots.size():
		var entry = CARD_ENTRY.new(p_owner, inv)
		entry.slot = i
		inv.card_entries.append(entry)
		entry.populate()
		if str(slots[i].get("type", "")) != "" and entry.is_stocked():
			typed.append(entry)
	if not typed.is_empty():
		typed[rng.next_int(typed.size())].set_on_sale()
	for i in int(eco.get("relic_count", 0)):
		var entry = RELIC_ENTRY.new(p_owner, inv)
		entry.populate(inv.stocked_relic_ids())
		if entry.is_stocked():
			inv.relic_entries.append(entry)
	var tools: Array = p_owner.tool_pool().duplicate()
	rng.shuffle(tools)
	for i in mini(int(eco.get("tool_count", 0)), tools.size()):
		var entry = TOOL_ENTRY.new(p_owner, inv)
		entry.fill(str(tools[i]))
		inv.tool_entries.append(entry)
	inv.card_removal_entry = REMOVAL_ENTRY.new(p_owner, inv)
	inv.card_removal_entry.calc_cost()
	inv._wire()
	return inv


func all_entries() -> Array:
	var out: Array = card_entries + relic_entries + tool_entries
	if card_removal_entry != null:
		out.append(card_removal_entry)
	return out


func _wire() -> void:
	for entry in all_entries():
		entry.purchase_completed.connect(_update_entries)


func _update_entries(_bought = null) -> void:
	for entry in all_entries():
		entry.on_inventory_updated()


## The one price owner: Charm, the A4 surcharge, then every run listener's
## `modify_merchant_price(entry, price)`; rounded up, never negative.
func modify_price(entry, base: int) -> int:
	var price := float(base) * float(owner.charm_shop_mult())
	if owner.has_ascension("base:a4_merchant_surcharge"):
		price *= float(owner.ascension_param("base:a4_merchant_surcharge", "price_mult", 1.0))
	for listener in owner.run_listeners:
		if listener.has_method("modify_merchant_price"):
			price = float(listener.modify_merchant_price(entry, price))
	return maxi(0, int(ceil(price - 0.0001)))


## True when any run listener's `should_refill_merchant_entry` asks to restock.
func should_refill(entry) -> bool:
	for listener in owner.run_listeners:
		if listener.has_method("should_refill_merchant_entry") and listener.should_refill_merchant_entry(entry):
			return true
	return false


## Cards of the hero's character pool a merchant can stock.
func shop_card_pool() -> Array:
	return CARD_POOLS.shop_cards(str(owner.current_hero_id))


func stocked_card_ids() -> Dictionary:
	return _ids(card_entries, "card_id")


func stocked_relic_ids() -> Dictionary:
	return _ids(relic_entries, "relic_id")


func stocked_tool_ids() -> Dictionary:
	return _ids(tool_entries, "tool_id")


static func _ids(entries: Array, key: String) -> Dictionary:
	var out := {}
	for e in entries:
		var id := str(e.get(key))
		if id != "":
			out[id] = true
	return out


func to_dict() -> Dictionary:
	return {
		"cards": card_entries.map(func(e): return e.to_dict()),
		"relics": relic_entries.map(func(e): return e.to_dict()),
		"tools": tool_entries.map(func(e): return e.to_dict()),
		"removal": card_removal_entry.to_dict() if card_removal_entry != null else {},
	}


## The inventory saved by to_dict() (JSON numbers come back as floats).
static func from_dict(p_owner, d: Dictionary) -> RefCounted:
	var inv = load("uid://dgj1md8jt0tg7").new()  # res://core/run/merchant/merchant_inventory.gd
	inv.owner = p_owner
	for pair in [[CARD_ENTRY, "cards", inv.card_entries], [RELIC_ENTRY, "relics", inv.relic_entries], [TOOL_ENTRY, "tools", inv.tool_entries]]:
		var raw: Variant = d.get(pair[1], [])
		if typeof(raw) != TYPE_ARRAY:
			continue
		for item in raw:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var entry = pair[0].new(p_owner, inv)
			entry.load_dict(item)
			pair[2].append(entry)
	inv.card_removal_entry = REMOVAL_ENTRY.new(p_owner, inv)
	var removal: Variant = d.get("removal", {})
	if typeof(removal) == TYPE_DICTIONARY and not removal.is_empty():
		inv.card_removal_entry.load_dict(removal)
	else:
		inv.card_removal_entry.calc_cost()
	inv._wire()
	return inv

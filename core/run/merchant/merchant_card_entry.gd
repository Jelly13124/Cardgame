extends "res://core/run/merchant/merchant_entry.gd"

## A card slot (STS2 MerchantCardEntry). A typed slot stocks a card of its type
## at a rarity rolled by weight; a rarity slot stocks a card of that rarity.
## Never a card already in the inventory. A card on sale costs half.

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd

## Index into the economy's `card_slots`; -1 for a slot migrated from an old save.
var slot: int = -1
var card_id: String = ""
var rarity: String = ""
var on_sale: bool = false


func is_stocked() -> bool:
	return card_id != ""


func spec() -> Dictionary:
	var slots: Array = inventory.economy().get("card_slots", [])
	return slots[slot] if slot >= 0 and slot < slots.size() else {}


## Fills the slot from the hero's shop pool, then rolls its cost.
func populate() -> void:
	var eco: Dictionary = inventory.economy()
	var rng = owner.rng("shops")
	var taken: Dictionary = inventory.stocked_card_ids()
	var candidates: Array = inventory.shop_card_pool().filter(func(id): return not taken.has(id))
	var want_type := str(spec().get("type", ""))
	var want_rarity := str(spec().get("rarity", ""))
	if want_type != "":
		var typed := candidates.filter(func(id): return _type(id) == want_type)
		if not typed.is_empty():
			candidates = typed
		want_rarity = _roll_rarity(candidates, eco.get("card_rarity_weights", {}), rng)
	var pool := candidates.filter(func(id): return _rarity(id) == want_rarity)
	if pool.is_empty():
		pool = candidates
	if pool.is_empty():
		card_id = ""
		return
	card_id = str(pool[rng.next_int(pool.size())])
	rarity = _rarity(card_id)
	calc_cost()


func set_on_sale() -> void:
	on_sale = true
	calc_cost()


func calc_cost() -> void:
	var eco: Dictionary = inventory.economy()
	base_cost = roll_cost(float(eco.get("card_price", {}).get(rarity, 0)), eco.get("card_price_variance", []))
	if on_sale:
		base_cost /= 2


func _on_purchase() -> bool:
	owner.add_card_to_deck(card_id)
	return true


func _clear_after_purchase() -> void:
	card_id = ""


## The bought card still counts as stocked while the slot rolls, so it is not
## offered again.
func _restock_after_purchase() -> void:
	on_sale = false
	populate()


## A rarity by weight among those `candidates` still offer.
static func _roll_rarity(candidates: Array, weights: Dictionary, rng) -> String:
	var available: Array = []
	var total := 0
	for r in weights:
		if candidates.any(func(id): return _rarity(id) == r):
			available.append(r)
			total += int(weights[r])
	if total <= 0:
		return ""
	var roll: int = rng.next_int(total)
	for r in available:
		roll -= int(weights[r])
		if roll < 0:
			return r
	return available[-1]


static func _type(id: String) -> String:
	return str(MODEL_DB.data("card", id).get("type", ""))


static func _rarity(id: String) -> String:
	return str(MODEL_DB.data("card", id).get("rarity", "common"))


func to_dict() -> Dictionary:
	return {"base_cost": base_cost, "slot": slot, "card_id": card_id, "rarity": rarity, "on_sale": on_sale}


func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	slot = int(d.get("slot", -1))
	card_id = str(d.get("card_id", ""))
	rarity = str(d.get("rarity", ""))
	on_sale = bool(d.get("on_sale", false))

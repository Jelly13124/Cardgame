extends RefCounted

## The base market's rules (meta economy): shelf stock (tools and one
## equipment piece per slot), prices, the refresh cost and the Caps↔Scrap
## conversion with its tax. Numbers from content/economy/market_economy.json;
## rolls use the `shops` stream. The market screen renders and calls these.

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd

const RARITY_ORDER := ["common", "uncommon", "rare"]


static func economy() -> Dictionary:
	return MODEL_DB.data("economy", "base:market_economy")


static func tool_price() -> int:
	return int(economy().get("tool_price", 40))


## Distinct tools for the shelf.
static func roll_tool_stock() -> Array:
	var pool: Array = RunManager.tool_pool().duplicate()
	RunManager.rng("shops").shuffle(pool)
	var stock: Array = []
	for i in range(mini(int(economy().get("tool_count", 5)), pool.size())):
		stock.append(str(pool[i]))
	return stock


## One equipment base per slot: a weighted rarity, then a base of that slot and
## rarity (any base of the slot, keeping its own rarity, when none matches).
## Entries: {base, rarity, price}.
static func roll_equip_stock() -> Array:
	var eco := economy()
	var prices: Dictionary = eco.get("equipment_price", {})
	var by_slot := equipment_by_slot()
	var stock: Array = []
	for slot in eco.get("equipment_slot_order", []):
		var entries: Array = by_slot.get(str(slot), [])
		if entries.is_empty():
			continue
		var rarity := _roll_rarity(eco.get("equipment_rarity_weights", {}))
		var pool: Array = entries.filter(func(e): return str(e.get("rarity", "")) == rarity)
		var picked: Dictionary
		if pool.is_empty():
			picked = RunManager.rng("shops").pick(entries)
			rarity = str(picked.get("rarity", "common"))
		else:
			picked = RunManager.rng("shops").pick(pool)
		stock.append({"base": str(picked.get("id", "")), "rarity": rarity, "price": int(prices.get(rarity, prices.get("common", 60)))})
	return stock


## Caps to refresh the shelves after `uses` refreshes this visit.
static func refresh_cost(uses: int) -> int:
	var eco := economy()
	return int(eco.get("refresh_base", 20)) + int(eco.get("refresh_step", 10)) * uses


## {chunk, out} for a conversion ("caps_to_scrap" or "scrap_to_caps"): the
## source amount spent and the destination amount after the floored tax.
static func conversion(direction: String) -> Dictionary:
	var eco := economy()
	var row: Dictionary = eco.get(direction, {})
	var chunk := int(row.get("chunk", 0))
	return {"chunk": chunk, "out": int(floor(chunk * float(row.get("rate", 0.0)) * (1.0 - float(eco.get("conversion_tax", 0.1)))))}


## slot → [{id, rarity}] of every sellable base (set pieces and exotic rarities
## drop elsewhere, never on the shelf).
static func equipment_by_slot() -> Dictionary:
	var result := {}
	for item_id in MODEL_DB.ids("equipment"):
		var data := MODEL_DB.data("equipment", item_id)
		var slot := str(data.get("slot", ""))
		var rarity := str(data.get("rarity", "common"))
		if str(data.get("set_id", "")) != "":
			continue
		if slot == "" or not rarity in RARITY_ORDER:
			continue
		if not result.has(slot):
			result[slot] = []
		(result[slot] as Array).append({"id": item_id, "rarity": rarity})
	return result


static func _roll_rarity(weights: Dictionary) -> String:
	var total := 0
	for r in weights:
		total += int(weights[r])
	var roll: int = RunManager.rng("shops").next_int(maxi(total, 1))
	for r in RARITY_ORDER:
		roll -= int(weights.get(r, 0))
		if roll < 0:
			return r
	return "common"

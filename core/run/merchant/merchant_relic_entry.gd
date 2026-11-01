extends "res://core/run/merchant/merchant_entry.gd"

## A relic slot (STS2 MerchantRelicEntry): an unowned shop relic at a rarity
## rolled by weight, priced by rarity. An already-owned relic refuses the sale.

var relic_id: String = ""


func is_stocked() -> bool:
	return relic_id != ""


## Fills the slot with a relic not in `blacklist`, then rolls its cost.
func populate(blacklist: Dictionary) -> void:
	var eco: Dictionary = inventory.economy()
	var rng = owner.rng("shops")
	var candidates: Array = owner.get_unowned_relic_ids().filter(func(id): return not blacklist.has(id))
	relic_id = ""
	if candidates.is_empty():
		return
	var weights: Dictionary = eco.get("relic_rarity_weights", {})
	var available: Array = []
	var total := 0
	for r in weights:
		if candidates.any(func(id): return _rarity(id) == r):
			available.append(r)
			total += int(weights[r])
	var pool := candidates
	if total > 0:
		var roll: int = rng.next_int(total)
		for r in available:
			roll -= int(weights[r])
			if roll < 0:
				pool = candidates.filter(func(id): return _rarity(id) == r)
				break
	relic_id = str(pool[rng.next_int(pool.size())])
	base_cost = roll_cost(float(eco.get("relic_price", {}).get(_rarity(relic_id), 0)), eco.get("relic_price_variance", []))


func _rarity(id: String) -> String:
	return str(owner.get_relic_data(id).get("rarity", "common"))


func _on_purchase() -> bool:
	return owner.add_relic(relic_id)


func _clear_after_purchase() -> void:
	relic_id = ""


func _restock_after_purchase() -> void:
	var blacklist: Dictionary = inventory.stocked_relic_ids()
	populate(blacklist)


func to_dict() -> Dictionary:
	return {"base_cost": base_cost, "relic_id": relic_id}


func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	relic_id = str(d.get("relic_id", ""))

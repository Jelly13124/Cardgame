extends "res://core/run/merchant/merchant_entry.gd"

## A tool slot (STS2 MerchantPotionEntry: tools are our potions). The tool goes
## into the backpack; a full backpack refuses the sale.

var tool_id: String = ""


func is_stocked() -> bool:
	return tool_id != ""


func fill(id: String) -> void:
	var eco: Dictionary = inventory.economy()
	tool_id = id
	base_cost = roll_cost(float(eco.get("tool_price", 0)), eco.get("tool_price_variance", []))


func _on_purchase() -> bool:
	return owner.add_tool_to_backpack(tool_id)


func _clear_after_purchase() -> void:
	tool_id = ""


func _restock_after_purchase() -> void:
	var stocked: Dictionary = inventory.stocked_tool_ids()
	var pool: Array = owner.tool_pool().filter(func(id): return not stocked.has(id) and id != tool_id)
	tool_id = ""
	if not pool.is_empty():
		fill(str(pool[owner.rng("shops").next_int(pool.size())]))


func to_dict() -> Dictionary:
	return {"base_cost": base_cost, "tool_id": tool_id}


func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	tool_id = str(d.get("tool_id", ""))

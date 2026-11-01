extends "res://core/run/merchant/merchant_entry.gd"

## Card removal (STS2 MerchantCardRemovalEntry): once per visit, and each use
## in a run raises the next merchant's price by the step.

var used: bool = false


func is_stocked() -> bool:
	return not used


func calc_cost() -> void:
	var eco: Dictionary = inventory.economy()
	base_cost = int(eco.get("remove_card_price", 0)) + int(eco.get("remove_card_price_step", 0)) * int(owner.state.merchant_removals_used)


## Removal needs the card: use this instead of try_purchase().
func try_purchase() -> int:
	return _fail(Status.FAILURE_OUT_OF_STOCK)


func try_remove(uid: String) -> int:
	if used:
		return _fail(Status.FAILURE_OUT_OF_STOCK)
	if not enough_gold():
		return _fail(Status.FAILURE_GOLD)
	var spent := cost()
	if not owner.remove_card_from_deck_by_uid(uid):
		return _fail(Status.FAILURE_OUT_OF_STOCK)
	owner.add_resources(-spent, 0)
	used = true
	owner.state.merchant_removals_used += 1
	_complete(spent)
	return Status.SUCCESS


func to_dict() -> Dictionary:
	return {"base_cost": base_cost, "used": used}


func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	used = bool(d.get("used", false))

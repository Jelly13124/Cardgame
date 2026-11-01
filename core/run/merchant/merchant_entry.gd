extends RefCounted

## One merchant slot (STS2 MerchantEntry): what it holds, what it costs right
## now and how it sells. Subclasses stock the slot and hand the goods over;
## this base checks stock and gold, spends, then refills or clears the slot.

enum Status { SUCCESS, FAILURE_GOLD, FAILURE_OUT_OF_STOCK, FAILURE_SPACE }

signal purchase_completed(entry)
signal purchase_failed(status: int)
## The inventory changed (a purchase anywhere): the price may have moved.
signal entry_updated

## The run facade (RunManager).
var owner
## The inventory holding this entry (weak: it owns its entries).
var inventory:
	get:
		return _inventory.get_ref() if _inventory != null else null
	set(v):
		_inventory = weakref(v) if v != null else null
var _inventory: WeakRef = null
## Rolled once when the slot fills: base price x variance (halved on sale).
var base_cost: int = 0


func _init(p_owner = null, p_inventory = null) -> void:
	owner = p_owner
	inventory = p_inventory


## The price now, after Charm, ascension and relic hooks.
func cost() -> int:
	return inventory.modify_price(self, base_cost)


func enough_gold() -> bool:
	return cost() <= int(owner.total_gold())


func is_stocked() -> bool:
	return false


func try_purchase() -> int:
	if not is_stocked():
		return _fail(Status.FAILURE_OUT_OF_STOCK)
	if not enough_gold():
		return _fail(Status.FAILURE_GOLD)
	var spent := cost()
	if not _on_purchase():
		return _fail(Status.FAILURE_SPACE)
	owner.add_resources(-spent, 0)
	if inventory.should_refill(self):
		_restock_after_purchase()
	else:
		_clear_after_purchase()
	_complete(spent)
	return Status.SUCCESS


## After a successful sale: the run hears it, then the inventory and the UI.
func _complete(spent: int) -> void:
	owner.item_purchased({"entry": self, "gold_spent": spent})
	purchase_completed.emit(self)


func _fail(status: int) -> int:
	purchase_failed.emit(status)
	return status


## Hands the goods over; false when they do not fit (nothing is spent).
func _on_purchase() -> bool:
	return false


func _clear_after_purchase() -> void:
	pass


func _restock_after_purchase() -> void:
	pass


func on_inventory_updated() -> void:
	entry_updated.emit()


## A base cost: `price` x a variance roll from the `shops` stream.
func roll_cost(price: float, variance: Array) -> int:
	var lo := float(variance[0]) if variance.size() == 2 else 1.0
	var hi := float(variance[1]) if variance.size() == 2 else 1.0
	return int(round(price * (lo + (hi - lo) * owner.rng("shops").next_float())))


func to_dict() -> Dictionary:
	return {"base_cost": base_cost}


func load_dict(d: Dictionary) -> void:
	base_cost = int(d.get("base_cost", 0))

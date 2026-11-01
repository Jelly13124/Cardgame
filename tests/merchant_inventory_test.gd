extends Node

## The merchant inventory (phase 9b): stock composition, sale, price variance,
## the price pipeline, purchase statuses, refills, removal escalation, saving
## and seeded determinism.

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const INVENTORY = preload("uid://dgj1md8jt0tg7")  # res://core/run/merchant/merchant_inventory.gd
const ENTRY = preload("uid://ddpabrcjqxery")  # res://core/run/merchant/merchant_entry.gd
const RUN_SAVE = preload("uid://dkhd2poukjb61")  # res://core/save/run_save.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _fresh(seed_string := "MERCH001") -> RefCounted:
	RunManager.start_new_run("base:cowboy_bill", [], 0, seed_string)
	RunManager.add_resources(2000, 0)
	return INVENTORY.create(RunManager)


func _run() -> void:
	_test_composition()
	_test_sale()
	_test_variance()
	_test_price_pipeline()
	_test_purchase_statuses()
	_test_refill_and_event()
	_test_removal()
	_test_round_trip()
	_test_v5_migration()
	_test_seeded()

	RunManager.is_run_active = false
	RunManager.clear_run_save()
	if failures.is_empty():
		print("[OK] merchant inventory passed")
		get_tree().quit(0)
		return
	push_error("merchant inventory failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _card(id: String) -> Dictionary:
	return MODEL_DB.data("card", id)


func _test_composition() -> void:
	var inv = _fresh()
	var cards: Array = inv.card_entries
	_expect(cards.size() == 6, "six card slots, got %d" % cards.size())
	var types := cards.map(func(e): return str(_card(e.card_id).get("type", "")))
	_expect(types.slice(0, 5) == ["attack", "attack", "skill", "skill", "ability"], "typed slots hold their types, got %s" % [types])
	_expect(str(_card(cards[5].card_id).get("rarity", "")) == "rare", "the sixth slot is a rare")
	var ids := cards.map(func(e): return e.card_id)
	_expect(_distinct(ids), "no card repeats: %s" % [ids])
	for e in cards:
		_expect(e.rarity == str(_card(e.card_id).get("rarity", "")), "%s records its rarity" % e.card_id)

	var relic_ids: Array = inv.relic_entries.map(func(e): return e.relic_id)
	_expect(relic_ids.size() == 3 and _distinct(relic_ids), "three distinct relics: %s" % [relic_ids])
	for id in relic_ids:
		_expect(not RunManager.has_relic(id), "%s is not owned" % id)
		_expect(str(RunManager.get_relic_data(id).get("rarity", "")) != "unique", "%s is not unique" % id)

	var tool_ids: Array = inv.tool_entries.map(func(e): return e.tool_id)
	_expect(tool_ids.size() == 3 and _distinct(tool_ids), "three distinct tools: %s" % [tool_ids])
	_expect(inv.card_removal_entry != null and inv.card_removal_entry.is_stocked(), "card removal is offered")
	_expect(inv.all_entries().size() == 13, "all entries: 6 cards, 3 relics, 3 tools, removal")


func _test_sale() -> void:
	for s in ["SALE0001", "SALE0002", "SALE0003"]:
		var inv = _fresh(s)
		var on_sale: Array = inv.card_entries.filter(func(e): return e.on_sale)
		_expect(on_sale.size() == 1, "%s: exactly one card on sale" % s)
		_expect(inv.card_entries.find(on_sale[0]) < 5, "%s: the sale card is a typed slot" % s)
		var eco: Dictionary = INVENTORY.economy()
		var full: int = int(eco["card_price"][on_sale[0].rarity])
		var variance: Array = eco["card_price_variance"]
		var lo := int(round(full * float(variance[0]))) / 2
		var hi := int(round(full * float(variance[1]))) / 2
		_expect(on_sale[0].base_cost >= lo and on_sale[0].base_cost <= hi, "%s: sale halves the cost (%d in %d..%d)" % [s, on_sale[0].base_cost, lo, hi])


func _test_variance() -> void:
	var eco: Dictionary = INVENTORY.economy()
	for s in ["VAR00001", "VAR00002", "VAR00003", "VAR00004"]:
		var inv = _fresh(s)
		for e in inv.card_entries:
			if e.on_sale:
				continue
			var p := float(eco["card_price"][e.rarity])
			_expect(_within(e.base_cost, p, eco["card_price_variance"]), "%s card cost %d within variance of %d" % [s, e.base_cost, p])
		for e in inv.relic_entries:
			var rarity := str(RunManager.get_relic_data(e.relic_id).get("rarity", "common"))
			var p := float(eco["relic_price"][rarity])
			_expect(_within(e.base_cost, p, eco["relic_price_variance"]), "%s relic cost %d within variance of %d" % [s, e.base_cost, p])
		for e in inv.tool_entries:
			_expect(_within(e.base_cost, float(eco["tool_price"]), eco["tool_price_variance"]), "%s tool cost within variance" % s)
		_expect(inv.card_removal_entry.base_cost == int(eco["remove_card_price"]), "%s removal starts at its base price" % s)


func _test_price_pipeline() -> void:
	var inv = _fresh()
	var entry = inv.tool_entries[0]
	entry.base_cost = 100
	RunManager.base_attributes["charm"] = 0
	RunManager.recompute_attributes()
	_expect(entry.cost() == 100, "no modifiers: the base cost, got %d" % entry.cost())
	RunManager.base_attributes["charm"] = 4
	RunManager.recompute_attributes()
	var charmed := int(ceil(100.0 * RunManager.charm_shop_mult()))
	_expect(charmed < 100 and entry.cost() == charmed, "Charm discounts: %d, got %d" % [charmed, entry.cost()])
	RunManager.base_attributes["charm"] = 0
	RunManager.recompute_attributes()
	var listener := _Listener.new()
	listener.price_mult = 0.5
	RunManager.run_listeners.append(listener)
	_expect(entry.cost() == 50, "a listener's modify_merchant_price applies, got %d" % entry.cost())
	RunManager.run_listeners.erase(listener)
	RunManager.ascension = 4
	_expect(RunManager.has_ascension("base:a4_merchant_surcharge"), "A4 is active at ascension 4")
	_expect(entry.cost() == 110, "the A4 surcharge applies, got %d" % entry.cost())
	RunManager.ascension = 0


func _test_purchase_statuses() -> void:
	var inv = _fresh()
	var card = inv.card_entries[0]
	var gold: int = RunManager.total_gold()
	var cost: int = card.cost()
	var deck_size: int = RunManager.player_deck.size()
	_expect(card.try_purchase() == ENTRY.Status.SUCCESS, "a stocked, affordable card sells")
	_expect(RunManager.total_gold() == gold - cost, "the purchase spends the cost")
	_expect(RunManager.player_deck.size() == deck_size + 1, "the card joins the deck")
	_expect(not card.is_stocked(), "a bought slot is cleared")
	_expect(card.try_purchase() == ENTRY.Status.FAILURE_OUT_OF_STOCK, "a cleared slot is out of stock")

	inv = _fresh()
	RunManager.spend_gold(RunManager.total_gold())
	var failed := [-1]
	inv.relic_entries[0].purchase_failed.connect(func(status): failed[0] = status)
	_expect(inv.relic_entries[0].try_purchase() == ENTRY.Status.FAILURE_GOLD, "no gold: FAILURE_GOLD")
	_expect(failed[0] == ENTRY.Status.FAILURE_GOLD, "purchase_failed reports the status")

	inv = _fresh()
	RunManager.add_relic(inv.relic_entries[1].relic_id)
	_expect(inv.relic_entries[1].try_purchase() == ENTRY.Status.FAILURE_SPACE, "an owned relic: FAILURE_SPACE")

	inv = _fresh()
	while RunManager.add_tool_to_backpack("base:med_kit"):
		pass
	var before: int = RunManager.total_gold()
	_expect(inv.tool_entries[0].try_purchase() == ENTRY.Status.FAILURE_SPACE, "a full backpack: FAILURE_SPACE")
	_expect(RunManager.total_gold() == before and inv.tool_entries[0].is_stocked(), "a failed purchase spends nothing and keeps the stock")


func _test_refill_and_event() -> void:
	var inv = _fresh()
	var listener := _Listener.new()
	listener.refill = true
	RunManager.run_listeners.append(listener)
	var updates := [0]
	for e in inv.all_entries():
		e.entry_updated.connect(func(): updates[0] += 1)
	var slot = inv.card_entries[0]
	var bought: String = slot.card_id
	var cost: int = slot.cost()
	_expect(slot.try_purchase() == ENTRY.Status.SUCCESS, "the refill purchase sells")
	_expect(slot.is_stocked() and slot.card_id != bought, "a refill restocks a different card (%s -> %s)" % [bought, slot.card_id])
	_expect(not slot.on_sale, "a refilled slot is not on sale")
	_expect(str(_card(slot.card_id).get("type", "")) == "attack", "the refill keeps the slot's type")
	_expect(listener.purchases.size() == 1 and listener.purchases[0]["gold_spent"] == cost, "after_item_purchased reaches run listeners")
	_expect(updates[0] == inv.all_entries().size(), "every entry hears the purchase, got %d" % updates[0])
	RunManager.run_listeners.erase(listener)


func _test_removal() -> void:
	var inv = _fresh()
	var eco: Dictionary = INVENTORY.economy()
	var base := int(eco["remove_card_price"])
	var step := int(eco["remove_card_price_step"])
	var removal = inv.card_removal_entry
	var uid := str(RunManager.player_deck[0].get("uid", ""))
	var size: int = RunManager.player_deck.size()
	_expect(removal.try_remove(uid) == ENTRY.Status.SUCCESS, "removal removes a card")
	_expect(RunManager.player_deck.size() == size - 1, "the card leaves the deck")
	_expect(RunManager.state.merchant_removals_used == 1, "the removal is counted")
	_expect(not removal.is_stocked(), "removal is used for this visit")
	_expect(removal.try_remove(str(RunManager.player_deck[0].get("uid", ""))) == ENTRY.Status.FAILURE_OUT_OF_STOCK, "a second removal is refused")
	var next = INVENTORY.create(RunManager)
	_expect(next.card_removal_entry.base_cost == base + step, "the next merchant charges %d, got %d" % [base + step, next.card_removal_entry.base_cost])
	_expect(next.card_removal_entry.try_remove("no-such-uid") == ENTRY.Status.FAILURE_OUT_OF_STOCK or RunManager.state.merchant_removals_used == 1, "an unknown card is not removed")


func _test_round_trip() -> void:
	var inv = _fresh()
	inv.card_entries[2].try_purchase()
	var d: Dictionary = inv.to_dict()
	var json: Variant = JSON.parse_string(JSON.stringify(d))
	var back = INVENTORY.from_dict(RunManager, json)
	_expect(JSON.stringify(back.to_dict()) == JSON.stringify(d), "to_dict -> from_dict keeps every entry")
	_expect(not back.card_entries[2].is_stocked(), "a bought slot stays sold")
	for i in inv.card_entries.size():
		_expect(back.card_entries[i].cost() == inv.card_entries[i].cost(), "card %d keeps its cost" % i)
	RunManager.state.shop_stock["n1"] = d
	var saved: Dictionary = RUN_SAVE.to_dict(RunManager.state, 0)
	_expect(saved.has("merchant_removals_used"), "the run save holds the removal count")


func _test_v5_migration() -> void:
	var v5 := {
		"schema_version": 5,
		"shop_stock": {"f2_s0": {
			"cards": [{"card_id": "base:brace", "rarity": "common", "price": 60, "sold": true}],
			"tools": [{"tool_id": "base:med_kit", "price": 45}],
			"relics": [{"relic_id": "base:lucky_cog", "price": 130}],
			"remove_price": 70,
		}},
	}
	var out: Dictionary = RUN_SAVE.migrate(v5)
	_expect(int(out["schema_version"]) == RUN_SAVE.CURRENT, "migrates to the current schema")
	_expect(int(out.get("merchant_removals_used", -1)) == 0, "no removals used after migration")
	RunManager.start_new_run("base:cowboy_bill", [], 0, "MIGR0001")
	var inv = INVENTORY.from_dict(RunManager, out["shop_stock"]["f2_s0"])
	_expect(inv.card_entries.size() == 1 and not inv.card_entries[0].is_stocked(), "a sold old card stays sold")
	_expect(inv.card_entries[0].base_cost == 60 and not inv.card_entries[0].on_sale, "the old price is the base cost, no sale")
	_expect(inv.tool_entries[0].tool_id == "base:med_kit" and inv.tool_entries[0].base_cost == 45, "the old tool survives")
	_expect(inv.relic_entries[0].relic_id == "base:lucky_cog" and inv.relic_entries[0].is_stocked(), "the old relic survives")
	_expect(inv.card_removal_entry.base_cost == 70 and inv.card_removal_entry.is_stocked(), "the old removal price survives")


func _test_seeded() -> void:
	var a: Dictionary = _fresh("SEEDSAME").to_dict()
	var b: Dictionary = _fresh("SEEDSAME").to_dict()
	var c: Dictionary = _fresh("SEEDDIFF").to_dict()
	_expect(a == b, "the same seed gives the same inventory")
	_expect(a != c, "another seed gives another inventory")


func _within(cost: int, price: float, variance: Array) -> bool:
	return cost >= int(round(price * float(variance[0]))) and cost <= int(round(price * float(variance[1])))


func _distinct(items: Array) -> bool:
	var seen := {}
	for i in items:
		if seen.has(i):
			return false
		seen[i] = true
	return true


## Stands in for a relic with merchant hooks.
class _Listener:
	var price_mult := 1.0
	var refill := false
	var purchases: Array = []

	func modify_merchant_price(_entry, price: float) -> float:
		return price * price_mult

	func should_refill_merchant_entry(_entry) -> bool:
		return refill

	func after_item_purchased(purchase: Dictionary) -> void:
		purchases.append(purchase)

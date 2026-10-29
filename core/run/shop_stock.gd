extends RefCounted

## A merchant's stock (STS2 merchant inventory): cards by the rarity sequence,
## distinct tools and unowned relics at prices after Charm and the merchant
## surcharge. Numbers from content/economy/merchant_economy.json; rolls use the run's
## `shops` stream.

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd


static func economy() -> Dictionary:
	return MODEL_DB.data("economy", "base:merchant_economy")


## A base price after Charm (floored by RunManager) and the merchant surcharge;
## always rounds up.
static func price(base_cost: int) -> int:
	var p: float = float(base_cost) * RunManager.charm_shop_mult()
	if RunManager.has_ascension("base:a4_merchant_surcharge"):
		p *= float(RunManager.ascension_param("base:a4_merchant_surcharge", "price_mult", 1.1))
	return int(ceil(p))


## {cards: [{card_id, rarity, price}], tools: [{tool_id, price}],
##  relics: [{relic_id, price}], remove_price} from the card pools by rarity,
## the tool pool and the unowned relics.
static func roll(card_pools: Dictionary, tool_pool: Array, relic_pool: Array) -> Dictionary:
	var eco := economy()
	var rng = RunManager.rng("shops")
	var card_price: Dictionary = eco.get("card_price", {})
	var sequence: Array = eco.get("card_rarity_sequence", [])
	var cards: Array = []
	for rarity in sequence:
		var pick := _take(card_pools, str(rarity), rng)
		if pick != "":
			cards.append({"card_id": pick, "rarity": rarity, "price": price(int(card_price[rarity]))})
	while cards.size() < int(eco.get("card_count", 6)):
		var available: Array = []
		for rarity in sequence:
			if not card_pools.get(str(rarity), []).is_empty() and not available.has(str(rarity)):
				available.append(str(rarity))
		if available.is_empty():
			break
		var r := str(rng.pick(available))
		cards.append({"card_id": _take(card_pools, r, rng), "rarity": r, "price": price(int(card_price[r]))})
	var tools: Array = []
	var shuffled_tools := tool_pool.duplicate()
	rng.shuffle(shuffled_tools)
	for i in range(mini(int(eco.get("tool_count", 3)), shuffled_tools.size())):
		tools.append({"tool_id": str(shuffled_tools[i]), "price": price(int(eco.get("tool_price", 50)))})
	var relics: Array = []
	var candidates := relic_pool.duplicate()
	while relics.size() < int(eco.get("relic_count", 3)) and not candidates.is_empty():
		var index: int = rng.next_int(candidates.size())
		relics.append({"relic_id": str(candidates[index]), "price": price(int(eco.get("relic_price", 135)))})
		candidates.remove_at(index)
	return {"cards": cards, "tools": tools, "relics": relics, "remove_price": price(int(eco.get("remove_card_price", 75)))}


static func _take(pools: Dictionary, rarity: String, rng) -> String:
	var pool: Array = pools.get(rarity, [])
	if pool.is_empty():
		return ""
	var index: int = rng.next_int(pool.size())
	var pick := str(pool[index])
	pool.remove_at(index)
	pools[rarity] = pool
	return pick

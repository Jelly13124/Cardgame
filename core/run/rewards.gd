extends RefCounted

## Combat rewards (STS2 reward flow): what a won fight offers, as data the
## reward screen renders — gold, a card draft, a Luck-scaled tool and a
## Luck-scaled equipment piece — plus the draft's rarity-weighted card rolls and
## the level-up attribute choices. Numbers come from content/economy/rewards.json;
## every roll uses the run's `rewards` stream.

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd


static func economy() -> Dictionary:
	return MODEL_DB.data("economy", "base:rewards")


## The loot entries of a won `node_type` fight, in display order:
## {type: "gold", amount} · {type: "cards"} · {type: "tool", tool_id} ·
## {type: "equipment", instance, demo_set_piece}.
static func combat_loot(node_type: String) -> Array:
	var eco := economy()
	var loot: Array = [{"type": "gold", "amount": int(eco.get("combat_gold", 8))}, {"type": "cards"}]
	if not node_type in eco.get("no_tool_rooms", []):
		if RunManager.rng("rewards").chance(RunManager.luck_tool_chance()):
			var tool_id := RunManager.roll_tool_drop(node_type)
			if tool_id != "":
				loot.append({"type": "tool", "tool_id": tool_id})
	var rarities: Dictionary = eco.get("equipment_drop_rarity", {})
	var equip_rarity := str(rarities.get(node_type, rarities.get("default", "")))
	var demo_set_due := equip_rarity != "" and RunManager.should_offer_demo_set_piece()
	if equip_rarity != "" and (demo_set_due or RunManager.rng("rewards").chance(RunManager.luck_equip_chance())):
		var instance := RunManager.roll_demo_set_piece() if demo_set_due else {}
		if instance.is_empty():
			instance = RunManager.roll_shell_drop(equip_rarity)
		if str(instance.get("base", "")) != "":
			loot.append({"type": "equipment", "instance": instance, "rarity": equip_rarity, "demo_set_piece": demo_set_due})
	return loot


## Card ids of `pool` by rarity ("common", "uncommon", "rare"); unknown
## rarities count as common.
static func rarity_pools(pool: Array) -> Dictionary:
	var out := {"common": [], "uncommon": [], "rare": []}
	for card_id in pool:
		var info := MODEL_DB.data("card", str(card_id))
		if info.is_empty():
			continue
		var rarity := str(info.get("rarity", "common")).to_lower()
		out[rarity if rarity in out else "common"].append(str(card_id))
	return out


## One draft card: rarity by the economy's roll table, one step up on a Luck
## bonus, falling back to a lower rarity when its pool is empty.
static func roll_draft_card(pools: Dictionary) -> String:
	var rng = RunManager.rng("rewards")
	var roll: float = rng.next_float()
	var picked := "common"
	for entry in economy().get("card_rarity_rolls", []):
		if not entry.has("below") or roll < float(entry["below"]):
			picked = str(entry.get("rarity", "common"))
			break
	if picked != "rare" and rng.chance(RunManager.luck_rarity_bonus()):
		picked = "rare" if picked == "uncommon" else "uncommon"
	if pools[picked].is_empty():
		if picked == "rare":
			picked = "uncommon"
		if pools[picked].is_empty():
			picked = "common"
	var pool: Array = pools[picked]
	return str(rng.pick(pool)) if not pool.is_empty() else ""


## A draft card not in `used` (bounded retries — the pools are large).
static func roll_unique_draft_card(pools: Dictionary, used: Dictionary) -> String:
	for _attempt in range(int(economy().get("draft_unique_attempts", 24))):
		var cid := roll_draft_card(pools)
		if cid != "" and not used.has(cid):
			return cid
	return roll_draft_card(pools)


## The level-up choice: up to `count` attributes in a shuffled order.
static func attribute_choices(keys: Array, count: int) -> Array:
	var shuffled := keys.duplicate()
	RunManager.rng("rewards").shuffle(shuffled)
	return shuffled.slice(0, mini(count, shuffled.size()))

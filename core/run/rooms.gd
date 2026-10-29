extends RefCounted

## Map room rules (STS2 Rooms): what the start-relic node offers a hero, what a
## "?" node does when no event is left, and what a treasure crate holds. The
## tables are content (the hero's `start_relics` / `act_start_upgrades`,
## content/economy/unknown_room.json); the map screen shows the results.

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd


static func table() -> Dictionary:
	return MODEL_DB.data("economy", "base:unknown_room")


## The floor-0 relic node for `hero_id` in act `act`:
##   {kind: "choice", relics}                 act 1, the hero's fixed starting pair
##   {kind: "upgrade", relics, replaces}      later acts, upgrade the held start relic
##   {kind: "random", source}                 a random 3-choose-1 ("starting"/"treasure")
## `replaces` maps an offered upgrade to the relic it swaps out.
static func start_relic_offer(hero_id: String, act: int) -> Dictionary:
	var hero := MODEL_DB.data("character", hero_id)
	var start: Array = hero.get("start_relics", [])
	if start.is_empty():
		return {"kind": "random", "source": "starting"}
	if act <= 1:
		return {"kind": "choice", "relics": start}
	for upgrade in hero.get("act_start_upgrades", []):
		var held := str(upgrade.get("held", ""))
		if RunManager.has_relic(held):
			var replaces := {}
			for relic_id in upgrade.get("replaces", []):
				replaces[str(relic_id)] = held
			return {"kind": "upgrade", "relics": upgrade.get("offer", []), "replaces": replaces}
	# Already upgraded (3-act runs): a normal relic pick.
	return {"kind": "random", "source": "treasure"}


## A "?" node with no event left: rolls one outcome on the `unknown_map_point`
## stream and applies its state change. Returns {kind, amount}:
##   fight · gold · scrap · heal (amount = HP actually healed) · equipment
##   (the crate: the screen grants it) · cache (amount = HP lost; the screen
##   offers a relic) · cache_empty (amount = gold, no relic or no HP to pay).
static func resolve_unknown() -> Dictionary:
	var rng = RunManager.rng("unknown_map_point")
	var roll: float = rng.next_float()
	for entry in table().get("outcomes", []):
		if entry.has("below") and roll >= float(entry["below"]):
			continue
		var kind := str(entry.get("kind", "fight"))
		match kind:
			"gold":
				var gold: int = rng.next_range(int(entry["min"]), int(entry["max"]))
				RunManager.add_gold(gold)
				return {"kind": kind, "amount": gold}
			"scrap":
				# Scrap stays in the backpack and only counts on extraction.
				var scrap: int = rng.next_range(int(entry["min"]), int(entry["max"]))
				RunManager.add_scrap_to_backpack(scrap)
				return {"kind": kind, "amount": scrap}
			"heal":
				var heal: int = rng.next_range(int(entry["min"]), int(entry["max"]))
				var before: int = RunManager.current_health
				RunManager.modify_health(heal)
				return {"kind": kind, "amount": RunManager.current_health - before}
			"cache":
				# No relic to give or no HP to pay: a little gold instead. The loss
				# never kills (capped at HP - 1) and goes through the death gate.
				if RunManager.get_unowned_relic_ids().is_empty() or RunManager.current_health <= 1:
					var gold := int(entry.get("empty_gold", 15))
					RunManager.add_gold(gold)
					return {"kind": "cache_empty", "amount": gold}
				var loss := clampi(RunManager.current_health - 1, 1, int(entry.get("max_hp_loss", 6)))
				RunManager.modify_health(-loss)
				return {"kind": kind, "amount": loss}
		return {"kind": kind, "amount": 0}
	return {"kind": "fight", "amount": 0}


## A treasure crate's equipment: uncommon or rare by the table's chance.
static func treasure_equipment() -> Dictionary:
	var rarity := "uncommon" if RunManager.rng("rewards").chance(float(table().get("treasure_equipment_uncommon_chance", 0.7))) else "rare"
	return RunManager.roll_shell_drop(rarity)


## Gold when a treasure finds no relic left.
static func treasure_empty_gold() -> int:
	var span: Array = table().get("treasure_empty_gold", [20, 45])
	return RunManager.rng("rewards").next_range(int(span[0]), int(span[1]))

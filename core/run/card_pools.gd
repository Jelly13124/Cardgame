## Card pools of a run (STS2 CardPoolModel use): the cards a hero's rewards,
## shops and discovers offer, and Discover rolls. A hero's pool is its
## character card pool without curses, basics and other heroes' exclusive cards
## (`exclusive_cards` in content/characters); a run configuration may replace
## it with a focused reward pool (`reward_pools` in content/runs). No class_name.
extends RefCounted

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
## Basic starter cards are excluded — discovering Strike/Defend is boring.
const EXCLUDE := ["base:strike", "base:defend", "base:weak_strike"]
const CARD_TYPES := ["attack", "skill", "ability"]
## Never offered as rewards.
const BASIC_CARD_IDS := ["base:strike", "base:defend"]
const ACTS = preload("uid://c7qo73muxvmd4")  # res://core/run/acts.gd


## Card ids `hero_id`'s rewards and discovers draw from (in content order).
static func reward_pool(hero_id: String) -> Array[String]:
	var focused = ACTS.run_config().get("reward_pools", {}).get(hero_id, "")
	if str(focused) != "":
		var out: Array[String] = []
		for card_id in MODEL_DB.data("card_pool", str(focused)).get("cards", []):
			var data := MODEL_DB.data("card", str(card_id))
			if not data.is_empty() and str(data.get("type", "")) != "curse":
				out.append(str(card_id))
		return out
	var pool: Array[String] = []
	var blocked := others_exclusive(hero_id)
	for card_id in RunManager.current_card_pool():
		if card_id in BASIC_CARD_IDS or blocked.has(card_id):
			continue
		if str(MODEL_DB.data("card", card_id).get("type", "")) == "curse":
			continue
		pool.append(card_id)
	return pool


## Cards of `hero_id`'s character pool a merchant can stock, by rarity.
static func shop_cards_by_rarity(hero_id: String) -> Dictionary:
	var result := {"common": [], "uncommon": [], "rare": []}
	var blocked := others_exclusive(hero_id)
	for card_id in RunManager.current_card_pool():
		if blocked.has(card_id):
			continue
		var rarity := str(MODEL_DB.data("card", card_id).get("rarity", "common"))
		if rarity in result:
			result[rarity].append(card_id)
	return result


## Exclusive cards of every OTHER hero, as a set.
static func others_exclusive(hero_id: String) -> Dictionary:
	var blocked := {}
	for model in MODEL_DB.models("character"):
		if model.id == hero_id:
			continue
		for card_id in model.data.get("exclusive_cards", []):
			blocked[str(card_id)] = true
	return blocked


## Discover: up to `count` distinct card ids matching `pool` (a card type or a
## theme tag) from the unlocked pool.
## Returns [] when nothing matches (caller shows a "nothing to discover" toast).
static func roll(pool: String, count: int, unlocked: Array) -> Array:
	var matches: Array = []
	for cid in unlocked:
		var id := str(cid)
		if id in EXCLUDE:
			continue
		var data := _load_card(id)
		if data.is_empty():
			continue
		if _matches(data, pool):
			matches.append(id)
	RunManager.rng("combat_card_generation").shuffle(matches)
	return matches.slice(0, min(count, matches.size()))


static func _matches(data: Dictionary, pool: String) -> bool:
	if pool in CARD_TYPES:
		return str(data.get("type", "")).to_lower() == pool
	# Theme tag match (a card may opt in via a `tags` array).
	var tags: Variant = data.get("tags", [])
	if typeof(tags) == TYPE_ARRAY and pool in tags:
		return true
	# Built-in theme detection so a themed pool works without tagging every card.
	# Short Circuit includes builders, Overload outlets and alternate charge payoffs.
	if pool == "short_circuit":
		for e in data.get("effects", []):
			if typeof(e) != TYPE_DICTIONARY:
				continue
			if (
				str(e.get("status", "")) == "short_circuit"
				or str(e.get("type", ""))
				in [
					"apply_short_circuit_scaled",
					"overload",
				]
			):
				return true
	return false


static func _load_card(id: String) -> Dictionary:
	return MODEL_DB.data("card", id)

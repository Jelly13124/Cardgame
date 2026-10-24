## Stateless helper that rolls Discover candidates. No class_name (project convention) — preload.
## A candidate pool is a list of unlocked card ids filtered by `pool` (a card TYPE like
## "attack"/"skill"/"ability", OR a theme tag found in the card's `tags` array).
extends RefCounted

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
## Basic starter cards are excluded — discovering Strike/Defend is boring.
const EXCLUDE := ["base:strike", "base:defend", "base:weak_strike"]
const CARD_TYPES := ["attack", "skill", "ability"]


## Roll up to `count` distinct card ids matching `pool` from the unlocked pool.
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
	matches.shuffle()
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

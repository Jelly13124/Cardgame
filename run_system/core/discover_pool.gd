## Stateless helper that rolls Discover candidates. No class_name (ADR-0006) — preload.
## A candidate pool is a list of unlocked card ids filtered by `pool` (a card TYPE like
## "attack"/"skill"/"ability", OR a theme tag found in the card's `tags` array).
extends RefCounted

const CARD_DIR := "res://battle_scene/card_info/player/"
## Basic starter cards are excluded — discovering Strike/Defend is boring.
const EXCLUDE := ["strike", "defend", "weak_strike"]
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
	# Otherwise treat `pool` as a theme tag.
	var tags: Variant = data.get("tags", [])
	return typeof(tags) == TYPE_ARRAY and pool in tags


static func _load_card(id: String) -> Dictionary:
	var path := CARD_DIR + id + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

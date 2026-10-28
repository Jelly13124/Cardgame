extends RefCounted

## One card in a combat (STS2 CardModel instance): its definition id, the run
## deck uid it came from, its resolved card dictionary (upgrade applied) and the
## combat-only changes rules make to it. Card nodes display an instance.

const EFFECT_CATALOG = preload("uid://880atc7mnnie")  # res://core/effects/effect_catalog.gd

## Definition id ("base:strike").
var model_id: String = ""
## Run deck entry uid ("" for cards created this combat).
var uid: String = ""
var upgraded: bool = false
## Resolved card data (type, cost, effects, …) as the effects read it.
var card_info: Dictionary = {}
## Energy cost for this combat (a discovered card is free); -1 = printed cost.
var cost_override: int = -1
## Set while a play of this card is queued or resolving.
var in_play: bool = false


static func make(p_model_id: String, p_info: Dictionary, p_uid := "", p_upgraded := false) -> RefCounted:
	var c = new()
	c.model_id = p_model_id
	c.card_info = p_info
	c.uid = p_uid
	c.upgraded = p_upgraded
	return c


func type() -> String:
	return str(card_info.get("type", "skill")).to_lower()


## Energy this card costs right now.
func cost() -> int:
	return cost_override if cost_override >= 0 else int(card_info.get("cost", 0))


func is_unplayable() -> bool:
	return type() == "curse" or bool(card_info.get("unplayable", false))


func exhausts() -> bool:
	for e in card_info.get("effects", []):
		if typeof(e) == TYPE_DICTIONARY and str(e.get("type", "")) == "exhaust_self":
			return true
	return false


func retains() -> bool:
	return bool(card_info.get("retain", false))


func requires_enemy_target() -> bool:
	return data_requires_enemy_target(card_info)


## Targeting is data-driven: an explicit `target` wins, else any effect type
## that targets an enemy.
static func data_requires_enemy_target(data: Dictionary) -> bool:
	var explicit_target := str(data.get("target", "")).to_lower()
	if explicit_target == "enemy":
		return true
	if explicit_target in ["none", "self", "all_enemies"]:
		return false
	for effect in data.get("effects", []):
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		if EFFECT_CATALOG.registry().targets_enemy(str(effect.get("type", ""))):
			return true
	return false

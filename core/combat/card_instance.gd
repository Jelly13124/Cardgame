extends RefCounted

## One card in a combat (STS2 CardModel instance): its definition id, the run
## deck uid it came from, its resolved card dictionary (upgrade applied) and the
## combat-only changes rules make to it. Card nodes display an instance.

## Definition id ("base:strike").
var model_id: String = ""
## Run deck entry uid ("" for cards created this combat).
var uid: String = ""
var upgraded: bool = false
## Resolved card data (type, cost, effects, …) as the effects read it.
var info: Dictionary = {}
## Energy cost for this combat (a discovered card is free); -1 = printed cost.
var cost_override: int = -1
## Set while a play of this card is queued or resolving.
var in_play: bool = false


static func make(p_model_id: String, p_info: Dictionary, p_uid := "", p_upgraded := false) -> RefCounted:
	var c = new()
	c.model_id = p_model_id
	c.info = p_info
	c.uid = p_uid
	c.upgraded = p_upgraded
	return c


func type() -> String:
	return str(info.get("type", "skill")).to_lower()


## Energy this card costs right now.
func cost() -> int:
	return cost_override if cost_override >= 0 else int(info.get("cost", 0))


func is_unplayable() -> bool:
	return type() == "curse" or bool(info.get("unplayable", false))


func exhausts() -> bool:
	for e in info.get("effects", []):
		if typeof(e) == TYPE_DICTIONARY and str(e.get("type", "")) == "exhaust_self":
			return true
	return false


func retains() -> bool:
	return bool(info.get("retain", false))

extends RefCounted

## Base for everything that reacts to combat or run phases (STS2 AbstractModel
## hooks): statuses on a creature, held relics, equipment sets, ascension
## levels, the bounty tracker. Every hook is optional — the broadcaster
## (core/combat/combat_hooks.gd) calls a listener only for the methods it
## defines. See combat_hooks.gd for the hook names and their arguments.

## The creature this listener belongs to (a status's bearer), or null.
var owner: Object = null
## The broadcaster, set when the listener joins a battle.
var hooks = null
## Content id or rule name, for sources and debugging.
var id: String = ""


## Battle command layer (combat_commands.gd), or null outside a battle.
func commands():
	return hooks.commands if hooks != null else null


static func alive(creature: Object) -> bool:
	if creature == null or not is_instance_valid(creature):
		return false
	if creature is Node and (creature as Node).is_queued_for_deletion():
		return false
	return not "health" in creature or int(creature.get("health")) > 0


static func stacks(creature: Object, status: String) -> int:
	if creature == null or not is_instance_valid(creature) or not creature.has_method("get_status_stacks"):
		return 0
	return int(creature.get_status_stacks(status))

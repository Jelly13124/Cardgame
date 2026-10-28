extends "res://core/listeners/listener.gd"

## Base of a status's behaviour (STS2 PowerModel): one instance per creature
## per active status, created by the creature's StatusEffectSystem when the
## status first gains stacks and dropped when its stacks reach 0. `owner` is
## the bearer, `id` the runtime status key, `def` its content definition.

const COMBAT_SOURCE = preload("uid://jgs131055xrk")  # res://core/combat/combat_source.gd

var def: Dictionary = {}
## The owner's StatusEffectSystem (set on creation).
var system = null


func amount() -> int:
	return stacks(owner, id)


func var_value(name: String, default: Variant) -> Variant:
	var vars: Variant = def.get("vars", {})
	return vars.get(name, default) if typeof(vars) == TYPE_DICTIONARY else default


## Side of the bearer, for combat sources.
func side() -> String:
	if owner != null and "side" in owner:
		return str(owner.side)
	return "enemy" if owner != null and "enemy_id" in owner else "player"


## Fixed Block from a power through the command layer (its hooks and caps apply).
func gain_power_block(value: int) -> void:
	var cmd = commands()
	if cmd == null or not alive(owner) or value <= 0:
		return
	var source = COMBAT_SOURCE.make("status", side(), owner, null, id)
	if await cmd.gain_block(source, owner, value, 0) > 0 and owner.has_method("play_block_pulse"):
		owner.play_block_pulse()

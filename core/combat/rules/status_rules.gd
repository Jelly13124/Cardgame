extends RefCounted

## Status modifiers and reactions: Weak (dealer, powered ×0.5), Vulnerable
## (target, powered ×1.5), Frail (powered block ×0.75), Intangible (every hit
## at most 1), Thorns (a powered hit makes the dealer take Thorns damage; the
## defender loses 1 Thorns; Serrated Barbs adds equal Short Circuit when the
## player's Thorns trigger) and Reactive Plating.

const COMBAT_SOURCE = preload("uid://jgs131055xrk")  # res://core/combat/combat_source.gd
const VALUE_PROPS = preload("uid://cccfcqt180t4x")  # res://core/combat/value_props.gd

const WEAK_MULT := 0.5
const VULNERABLE_MULT := 1.5
const FRAIL_MULT := 0.75

var hooks = null  # combat_hooks.gd, for reaction commands
var relics = null  # RelicEffectSystem or null


func modify_damage_multiplicative(calc) -> void:
	if not calc.is_powered():
		return
	if _stacks(calc.dealer, "weak") > 0:
		calc.value *= WEAK_MULT
	if _stacks(calc.target, "vulnerable") > 0:
		calc.value *= VULNERABLE_MULT


func modify_damage_cap(calc) -> void:
	if _stacks(calc.target, "intangible") > 0:
		calc.value = minf(calc.value, 1.0)


func modify_block_multiplicative(calc) -> void:
	if calc.is_powered() and _stacks(calc.target, "frail") > 0:
		calc.value *= FRAIL_MULT


func after_damage_received(result) -> void:
	if result == null or not result.has(VALUE_PROPS.POWERED):
		return
	var defender: Object = result.target
	var attacker: Object = result.dealer
	var thorns := _stacks(defender, "thorns")
	if thorns <= 0 or not _alive(attacker) or hooks == null or hooks.commands == null:
		return
	var side := "enemy" if result.source and result.source.side == "player" else "player"
	var source = COMBAT_SOURCE.make("thorns", side, defender, null, "thorns")
	var status_system = defender.get("status_system")
	if status_system:
		status_system.spend_stacks("thorns", 1, defender)
	await hooks.commands.damage(source, [attacker], thorns, 0)
	if side == "player" and relics and relics.thorns_apply_short_circuit() and _alive(attacker):
		await hooks.commands.apply_status(source, attacker, "short_circuit", thorns)


## Reactive Plating: whenever a card grants Block, gain Thorns equal to stacks.
func after_block_gained(result: Dictionary) -> void:
	var source = result.get("source")
	var creature: Object = result.get("creature")
	if source == null or not source.is_card() or hooks == null or hooks.commands == null:
		return
	var reactive := _stacks(creature, "reactive_plating")
	if reactive > 0:
		await hooks.commands.apply_status(source, creature, "thorns", reactive, "reactive_plating")


func _stacks(creature: Object, status: String) -> int:
	if creature == null or not is_instance_valid(creature) or not creature.has_method("get_status_stacks"):
		return 0
	return int(creature.get_status_stacks(status))


func _alive(creature: Object) -> bool:
	if creature == null or not is_instance_valid(creature):
		return false
	if creature is Node and (creature as Node).is_queued_for_deletion():
		return false
	return not "health" in creature or int(creature.get("health")) > 0

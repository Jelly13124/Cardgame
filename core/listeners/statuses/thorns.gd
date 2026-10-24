extends "res://core/listeners/status_listener.gd"

## Thorns: a powered hit on the bearer makes the dealer take Thorns damage and
## the bearer loses 1 stack. A relic answering `thorns_apply_short_circuit`
## (Arc Spines) also applies equal Short Circuit when the player's Thorns fire.

const VALUE_PROPS = preload("uid://cccfcqt180t4x")  # res://core/combat/value_props.gd


func after_damage_received(result) -> void:
	if result == null or result.target != owner or not result.has(VALUE_PROPS.POWERED):
		return
	var attacker: Object = result.dealer
	var thorns := amount()
	if thorns <= 0 or not alive(attacker) or commands() == null:
		return
	var source_side := "enemy" if result.source and result.source.side == "player" else "player"
	var source = COMBAT_SOURCE.make("thorns", source_side, owner, null, "thorns")
	system.spend_stacks(id, 1, owner)
	await commands().damage(source, [attacker], thorns, 0)
	if source_side == "player" and hooks.query_any("thorns_apply_short_circuit", null) and alive(attacker):
		await commands().apply_status(source, attacker, "short_circuit", thorns)

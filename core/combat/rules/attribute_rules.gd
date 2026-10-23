extends RefCounted

## Attribute modifiers: Strength adds to powered player damage, Constitution to
## powered block, Intelligence to statuses a card or tool applies to an enemy
## (`apply_status` / `apply_status_all`, never Stun). Effects whose base value
## already uses an attribute opt out with NO_STRENGTH / NO_CONSTITUTION or, for
## statuses, by using another effect type (apply_short_circuit_scaled).

const VALUE_PROPS = preload("uid://cccfcqt180t4x")  # res://core/combat/value_props.gd
const INT_EFFECT_TYPES := ["apply_status", "apply_status_all"]


func modify_damage_additive(calc) -> void:
	if not calc.is_powered() or not calc.from_player() or calc.has(VALUE_PROPS.NO_STRENGTH):
		return
	calc.value += _attr(calc.dealer, "strength")


func modify_block_additive(calc) -> void:
	if not calc.is_powered() or calc.has(VALUE_PROPS.NO_CONSTITUTION):
		return
	calc.value += _attr(calc.target, "constitution")


func modify_status_stacks(calc) -> void:
	var source = calc.source
	if source == null or source.side != "player" or not source.kind in ["card", "tool"]:
		return
	if calc.target == null or calc.target == source.dealer:
		return
	if not calc.effect_type in INT_EFFECT_TYPES or calc.status == "stun":
		return
	calc.value += _attr(source.dealer, "intelligence")


func _attr(creature: Object, attr: String) -> int:
	if creature == null or not is_instance_valid(creature) or not attr in creature:
		return 0
	return int(creature.get(attr))

extends RefCounted

## The only way combat changes HP, Block and statuses (STS2 *Cmd). Each command
## runs its value through combat_hooks (core/combat), applies the result to the
## creature (which plays the hit feedback) and broadcasts the reactions.
## Presentation that depends on the effect (notifications, pulses, pacing)
## stays in the effect handlers.

const VALUE_CALC = preload("uid://tynklfj3vjf5")  # res://core/combat/value_calc.gd
const VALUE_PROPS = preload("uid://cccfcqt180t4x")  # res://core/combat/value_props.gd
const COMBAT_SOURCE = preload("uid://jgs131055xrk")  # res://core/combat/combat_source.gd
const DAMAGE_RESULT = preload("uid://g7g4k5jk1gvd")  # res://core/combat/damage_result.gd

const FEEDBACK_SOURCE := {
	"card": "player",
	"tool": "player",
	"enemy": "enemy",
	"relic": "relic",
	"set": "relic",
	"status": "status",
	"thorns": "thorns",
	"debug": "debug",
}

var battle: Object = null  # battle scene (is_game_over)
var hooks = null  # combat_hooks.gd


## Routes `creature`'s status damage (Burn) through this command layer.
func attach(creature: Object) -> void:
	var status_system = creature.get("status_system") if creature else null
	if status_system:
		status_system.damage_router = _status_damage


func _status_damage(entity: Object, amount: int, status: String) -> void:
	var side := "player" if entity == battle.get("player") else "enemy"
	var source = COMBAT_SOURCE.make("status", side, null, null, status)
	await damage(source, [entity], amount, 0)


## Damage `target` would take from this hit, after every stage (Intangible
## included), before Block. Never changes state.
func preview_damage(
	source, target: Object, base: int, props: int, play = null, flat_bonus := 0, tags := {}
) -> int:
	var calc = VALUE_CALC.for_damage(source, target, base, props, true, play)
	calc.flat_bonus = flat_bonus
	calc.tags = tags.duplicate()
	return hooks.compute_damage(calc)


## Deals one hit to each live target in order. `tags`: "heavy" (feedback),
## "overload" (crit rule), "feedback_source" (override the feedback source).
## Stops after the game ends or after a boss dies (its adds are freed next frame).
func damage(
	source, targets: Array, base: int, props: int, play = null, flat_bonus := 0, tags := {}
) -> Array:
	var results: Array = []
	for target in targets:
		if _game_over():
			break
		if not is_alive(target):
			continue
		var calc = VALUE_CALC.for_damage(source, target, base, props, false, play)
		calc.flat_bonus = flat_bonus
		calc.tags = tags.duplicate()
		var amount: int = hooks.compute_damage(calc)
		calc.commit()
		var result = DAMAGE_RESULT.new()
		result.source = source
		result.props = props
		result.dealer = source.dealer if source else null
		result.target = target
		result.amount = amount
		result.critical = calc.critical
		var hp_before := int(target.get("health"))
		var block_before := 0 if (props & VALUE_PROPS.UNBLOCKABLE) else int(target.get("block"))
		result.blocked = mini(block_before, amount)
		result.hp_lost = mini(hp_before, amount - result.blocked)
		result.killed = hp_before > 0 and result.hp_lost >= hp_before
		result.block_broken = block_before > 0 and amount >= block_before
		var was_boss := bool(target.get("is_boss"))
		await target.take_damage(amount, false, _feedback(source, calc))
		await hooks.after_damage_given(result)
		await hooks.after_damage_received(result)
		results.append(result)
		if was_boss and result.killed:
			break
	return results


## Block actually gained after the pipeline.
func gain_block(source, creature: Object, base: int, props: int) -> int:
	if not is_alive(creature):
		return 0
	var calc = VALUE_CALC.for_block(source, creature, base, props, false)
	var amount: int = hooks.compute_block(calc)
	calc.commit()
	if amount <= 0 or not creature.has_method("add_block"):
		return 0
	creature.add_block(amount)
	await hooks.after_block_gained(
		{"source": source, "creature": creature, "amount": amount, "props": props}
	)
	return amount


## Stacks actually applied after the pipeline (Intelligence, Brutal Servo, …).
func apply_status(
	source, target: Object, status: String, stacks: int, effect_type := ""
) -> int:
	if status == "" or not is_alive(target) or not target.has_method("add_status"):
		return 0
	var calc = VALUE_CALC.for_status(source, target, status, stacks, effect_type, false)
	var amount: int = hooks.compute_status_stacks(calc)
	calc.commit()
	if amount > 0:
		target.add_status(status, amount)
	return amount


## Direct HP loss: not damage (no Block, no Thorns), but Intangible still caps it.
func lose_hp(source, creature: Object, amount: int) -> int:
	if amount <= 0 or not is_alive(creature) or not creature.has_method("lose_hp"):
		return 0
	var calc = VALUE_CALC.for_damage(source, creature, amount, VALUE_PROPS.UNBLOCKABLE, false)
	var lost: int = hooks.compute_hp_loss(calc)
	creature.lose_hp(lost)
	return lost


static func is_alive(creature: Object) -> bool:
	if creature == null or not is_instance_valid(creature):
		return false
	if creature is Node and (creature as Node).is_queued_for_deletion():
		return false
	return not "health" in creature or int(creature.get("health")) > 0


func _game_over() -> bool:
	return battle != null and is_instance_valid(battle) and bool(battle.get("is_game_over"))


func _feedback(source, calc) -> Dictionary:
	var kind: String = source.kind if source else "debug"
	var tags := {
		"source": str(calc.tags.get("feedback_source", FEEDBACK_SOURCE.get(kind, "player"))),
		"critical": calc.critical,
		"heavy": bool(calc.tags.get("heavy", false)),
	}
	if kind in ["relic", "set"]:
		tags["relic"] = source.id
	if calc.tags.has("status"):
		tags["status"] = calc.tags["status"]
	elif kind == "status":
		tags["status"] = source.id
	return tags

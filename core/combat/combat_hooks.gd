extends RefCounted

## The one place damage, block and status stacks are calculated, and the one
## broadcaster of combat reactions (STS2 `Hook`).
##
## Listeners are plain objects that implement any of:
##   modify_damage_additive(calc) / modify_damage_multiplicative(calc)
##   modify_damage_reduction(calc) / modify_damage_cap(calc)
##   modify_block_additive(calc) / modify_block_multiplicative(calc)
##   modify_status_stacks(calc)
##   after_damage_given(result) / after_damage_received(result)
##   after_attack(attack: Dictionary) / after_block_gained(result: Dictionary)
## Modifiers adjust `calc.value`. Reactions may be coroutines; they run
## depth-first in listener order. Re-entrant reactions stop at MAX_DEPTH.

const MAX_DEPTH := 16

var listeners: Array = []
## Battle-side command layer (combat_commands.gd); listeners reach it as
## `hooks.commands` to deal reaction damage or apply statuses.
var commands = null
var _depth := 0


func add_listener(listener: Object) -> void:
	if listener and not listeners.has(listener):
		listeners.append(listener)


func clear() -> void:
	listeners.clear()


func compute_damage(calc) -> int:
	if calc.is_powered():
		calc.value += calc.flat_bonus
	_modify("modify_damage_additive", calc)
	_modify("modify_damage_multiplicative", calc)
	calc.value = floorf(maxf(0.0, calc.value))
	_modify("modify_damage_reduction", calc)
	calc.value = maxf(0.0, calc.value)
	_modify("modify_damage_cap", calc)
	return int(maxf(0.0, calc.value))


## Direct HP loss is not damage: only the cap stage (Intangible) applies.
func compute_hp_loss(calc) -> int:
	_modify("modify_damage_cap", calc)
	return int(maxf(0.0, calc.value))


func compute_block(calc) -> int:
	_modify("modify_block_additive", calc)
	_modify("modify_block_multiplicative", calc)
	return int(floorf(maxf(0.0, calc.value)))


func compute_status_stacks(calc) -> int:
	_modify("modify_status_stacks", calc)
	return int(maxf(0.0, calc.value))


func after_damage_given(result) -> void:
	await _dispatch("after_damage_given", result)


func after_damage_received(result) -> void:
	await _dispatch("after_damage_received", result)


func after_attack(attack: Dictionary) -> void:
	await _dispatch("after_attack", attack)


func after_block_gained(result: Dictionary) -> void:
	await _dispatch("after_block_gained", result)


func _modify(method: String, calc) -> void:
	for listener in listeners:
		if listener.has_method(method):
			listener.call(method, calc)


func _dispatch(method: String, arg) -> void:
	if _depth >= MAX_DEPTH:
		push_error("CombatHooks: %s re-entered %d levels deep; reaction skipped" % [method, _depth])
		return
	_depth += 1
	for listener in listeners.duplicate():
		if listener.has_method(method):
			await listener.call(method, arg)
	_depth -= 1

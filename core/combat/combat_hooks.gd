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
## Optional `func() -> Array` read on every dispatch (STS2 IterateHookListeners):
## lets status listeners appear and vanish mid-combat. Unset → `listeners`.
var provider: Callable
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


## Value hook: every listener defining `method` adjusts `calc.value` in order;
## returns the final value (calc is a hook_value.gd or a value calc).
func compute(method: String, calc) -> Variant:
	_modify(method, calc)
	return calc.value


## Query hook: true at the first listener whose `method(arg)` returns true;
## later listeners are not asked (so a forced-crit source spends only once).
func query_any(method: String, arg) -> bool:
	for listener in current_listeners():
		if listener.has_method(method) and bool(listener.call(method, arg)):
			return true
	return false


## Reaction hook with up to two arguments; listeners may be coroutines.
func react(method: String, a: Variant = null, b: Variant = null) -> void:
	if _depth >= MAX_DEPTH:
		push_error("CombatHooks: %s re-entered %d levels deep; reaction skipped" % [method, _depth])
		return
	_depth += 1
	for listener in current_listeners():
		if not listener.has_method(method):
			continue
		match listener.get_method_argument_count(method):
			0:
				await listener.call(method)
			1:
				await listener.call(method, a)
			_:
				await listener.call(method, a, b)
	_depth -= 1


## Snapshot of the listeners for one dispatch.
func current_listeners() -> Array:
	if provider.is_valid():
		return provider.call()
	return listeners.duplicate()


func _modify(method: String, calc) -> void:
	for listener in current_listeners():
		if listener.has_method(method):
			listener.call(method, calc)


func _dispatch(method: String, arg) -> void:
	await react(method, arg)

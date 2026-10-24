extends RefCounted

## Player crits (multiplicative stage). Every powered player hit rolls
## RunManager.crit_chance(); Overload discharge rolls only when a listener
## answers `can_crit_overload` (Overload Protocol). Forced crits — the relic's
## first attack each turn, then listeners answering `should_force_crit`
## (Deadeye) — are spent by real hits only; a preview shows a forced crit once
## per preview play and never shows a random one. The multiplier starts at
## RunManager.CRIT_MULT and goes through `modify_crit_multiplier` (All In,
## relics). Commits notify `after_crit` / `after_non_crit`.

const HOOK_VALUE = preload("uid://npewr2krgrm6")  # res://core/combat/hook_value.gd

var relics = null  # RelicEffectSystem or null
var hooks = null  # combat_hooks.gd
var first_attack_crit_used := false


func reset_turn() -> void:
	first_attack_crit_used = false


func modify_damage_multiplicative(calc) -> void:
	if not calc.from_player() or calc.dealer == null or not is_instance_valid(calc.dealer):
		return
	if bool(calc.tags.get("overload", false)):
		_overload_crit(calc)
		return
	if not calc.is_powered() or calc.value <= 0.0:
		return
	var forced: bool = _take_forced_crit(calc)
	var crit: bool = forced or (not calc.preview and RunManager.rng("combat_crits").chance(RunManager.crit_chance()))
	if not crit:
		hooks.notify("after_non_crit", calc)
		return
	var m = HOOK_VALUE.make(float(RunManager.CRIT_MULT), {"dealer": calc.dealer})
	calc.value *= float(hooks.compute("modify_crit_multiplier", m))
	calc.critical = true
	if not calc.preview:
		calc.on_commit(func() -> void: hooks.notify("after_crit", calc))


func _overload_crit(calc) -> void:
	if calc.preview or not hooks.query_any("can_crit_overload", calc):
		return
	if RunManager.rng("combat_crits").chance(RunManager.crit_chance()):
		calc.value *= float(RunManager.CRIT_MULT)
		calc.critical = true
		calc.on_commit(func() -> void: hooks.notify("after_crit", calc))


## Whether this hit is a forced crit; real hits queue the spend.
func _take_forced_crit(calc) -> bool:
	var play = calc.play
	if not first_attack_crit_used and relics and relics.first_attack_auto_crit():
		if not calc.preview:
			calc.on_commit(func() -> void: first_attack_crit_used = true)
			return true
		if play == null or play.simulate_spend("first_attack_crit"):
			return true
	return hooks.query_any("should_force_crit", calc)

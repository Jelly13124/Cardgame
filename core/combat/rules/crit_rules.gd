extends RefCounted

## Player crits (multiplicative stage). Every powered player hit rolls
## RunManager.crit_chance(); Overload discharge rolls only under Overload
## Protocol. Forced crits — the relic's first attack each turn, then Deadeye
## stacks — are spent by real hits only; a preview shows a forced crit once per
## preview play and never shows a random one. Multiplier: 1.5, raised by relics
## (highest wins), 2.0 under All In.

var relics = null  # RelicEffectSystem or null
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
	var p: Object = calc.dealer
	var all_in := _stacks(p, "all_in") > 0
	var forced: bool = _take_forced_crit(calc)
	var crit: bool = forced or (not calc.preview and randf() < RunManager.crit_chance())
	if not crit:
		if all_in and not calc.preview:
			calc.on_commit(func() -> void: p.add_status("loaded", 2))
		return
	var mult := 2.0 if all_in else float(RunManager.CRIT_MULT)
	if not all_in and relics:
		mult = relics.crit_mult(mult)
	calc.value *= mult
	calc.critical = true
	if not calc.preview:
		calc.on_commit(_crit_side_effects.bind(p))


func _overload_crit(calc) -> void:
	var p: Object = calc.dealer
	if calc.preview or _stacks(p, "overload_protocol") <= 0:
		return
	if randf() < RunManager.crit_chance():
		calc.value *= float(RunManager.CRIT_MULT)
		calc.critical = true
		calc.on_commit(_crit_side_effects.bind(p))


## Whether this hit is a forced crit; real hits queue the spend.
func _take_forced_crit(calc) -> bool:
	var p: Object = calc.dealer
	var play = calc.play
	if not first_attack_crit_used and relics and relics.first_attack_auto_crit():
		if not calc.preview:
			calc.on_commit(func() -> void: first_attack_crit_used = true)
			return true
		if play == null or play.simulate_spend("first_attack_crit"):
			return true
	var deadeye := _stacks(p, "deadeye")
	if play and calc.preview:
		deadeye -= int(play.simulated.get("deadeye_spent", 0))
	if deadeye <= 0:
		return false
	if calc.preview:
		if play:
			play.simulated["deadeye_spent"] = int(play.simulated.get("deadeye_spent", 0)) + 1
		return true
	calc.on_commit(
		func() -> void:
			var status_system = p.get("status_system")
			if status_system:
				status_system.spend_stacks("deadeye", 1, p)
	)
	return true


func _crit_side_effects(p: Object) -> void:
	if _stacks(p, "hot_streak") > 0:
		p.add_status("loaded", 2)
	if relics:
		relics.on_player_crit(p)


func _stacks(creature: Object, status: String) -> int:
	if creature == null or not is_instance_valid(creature) or not creature.has_method("get_status_stacks"):
		return 0
	return int(creature.get_status_stacks(status))

extends "res://core/listeners/listener.gd"

## A held relic in one battle (STS2 RelicModel instance). Built once per battle
## by relic_effect_system.gd for each relic in RunManager.relics; maps each JSON
## effect's `trigger` onto the combat hooks and keeps its own state
## (`once_per_combat` spends, the first-attack Crit flag, and `counters` for
## scripted relics). A relic JSON may name `script` (a res:// path extending this
## file) to add behaviour the triggers cannot express.

const VALUE_PROPS = preload("uid://cccfcqt180t4x")  # res://core/combat/value_props.gd
const EFFECT_CONTEXT = preload("uid://bx2g3askncfr6")  # res://core/effects/effect_context.gd
const COMBAT_SOURCE = preload("uid://jgs131055xrk")  # res://core/combat/combat_source.gd

## The battle (services: player, enemy_container, effect_registry, …).
var battle: Object = null
## Relic content data (read-only).
var data: Dictionary = {}
## Free per-battle state for scripted relics.
var counters: Dictionary = {}
var _used_once: Dictionary = {}  # effect index -> true
var _first_attack_crit_used := false


func title() -> String:
	return str(data.get("title", id))


## [index, effect] pairs of this relic's effects with `trigger`.
func effects_for(trigger: String) -> Array:
	var out: Array = []
	var effects: Variant = data.get("effects", [])
	if typeof(effects) != TYPE_ARRAY:
		return out
	for i in effects.size():
		var effect: Variant = effects[i]
		if typeof(effect) == TYPE_DICTIONARY and str(effect.get("trigger", "")) == trigger:
			out.append([i, effect])
	return out


# --- battle phases -------------------------------------------------------------

## Passive stat grants at battle start (war_horn +STR, bulk_actuator STR floor).
func before_combat_start() -> void:
	var player = _player()
	if player == null:
		return
	for pair in effects_for("battle_start"):
		var effect: Dictionary = pair[1]
		var amount := int(effect.get("amount", 0))
		match str(effect.get("type", "")):
			"gain_strength":
				player.strength += amount
				if player.has_signal("stats_changed"):
					player.stats_changed.emit()
			"set_strength":
				# Raise Strength to a floor; never lowers a higher base. `max` caps
				# the set value so stacking sources can't overshoot.
				var target := amount
				if effect.has("max"):
					target = mini(target, int(effect.get("max", amount)))
				if player.strength < target:
					player.strength = target
					if player.has_signal("stats_changed"):
						player.stats_changed.emit()


## Turn-start relic actions run through the shared effect registry as relic
## sources: fixed values (no Constitution, Frail or Strength).
func after_turn_start(side: String, round_number: int) -> void:
	if side != "player":
		return
	var player = _player()
	for pair in effects_for("player_turn_start"):
		var effect: Dictionary = pair[1]
		var required_round := int(effect.get("round", 0))
		if required_round > 0 and round_number != required_round:
			continue
		if not can_use(pair):
			continue
		var amount := int(effect.get("amount", 0))
		match str(effect.get("type", "")):
			"gain_energy", "gain_block", "deal_damage_all", "gain_temp_strength":
				mark_used(pair)
				await run_effect({"type": str(effect.get("type", "")), "amount": amount})
			"apply_self_status":
				mark_used(pair)
				var stacks := int(effect.get("amount", effect.get("stacks", 1)))
				await run_effect({"type": "apply_status_self", "status": str(effect.get("status", "")), "stacks": stacks})
			"set_polarity_alternating":
				# Alternates the active polarity each player turn (round 1=Yin,
				# 2=Yang, 3=Yin…). Fires every turn — not once_per_combat.
				var polarity := "yin" if round_number % 2 == 1 else "yang"
				if player and player.has_method("reset_polarity_turn"):
					player.reset_polarity_turn(polarity)
				if battle and battle.has_method("update_polarity_hud"):
					battle.update_polarity_hud()


func after_combat_victory() -> void:
	for pair in effects_for("combat_victory"):
		var effect: Dictionary = pair[1]
		if not can_use(pair) or not str(effect.get("type", "")) in ["heal", "gain_gold"]:
			continue
		mark_used(pair)
		await run_effect({"type": str(effect.get("type", "")), "amount": int(effect.get("amount", 0))})


# --- value hooks ---------------------------------------------------------------

func modify_damage_additive(calc) -> void:
	if not calc.is_powered() or not calc.from_player():
		return
	for pair in effects_for("player_attack_damage"):
		if str(pair[1].get("type", "")) != "add_damage" or not can_use(pair):
			continue
		calc.value += int(pair[1].get("amount", 0))
		mark_on_commit(calc, pair)


## Flat reduction of powered enemy hits on the player; a once-per-combat relic
## is spent by the real hit only.
func modify_damage_reduction(calc) -> void:
	if not calc.is_powered() or calc.source == null or calc.source.side != "enemy":
		return
	if calc.target != _player():
		return
	for pair in effects_for("enemy_attack_damage"):
		if str(pair[1].get("type", "")) != "reduce_damage" or not can_use(pair):
			continue
		calc.value -= int(pair[1].get("amount", 0))
		mark_on_commit(calc, pair)


func modify_block_additive(calc) -> void:
	if not calc.is_powered() or not calc.from_player():
		return
	for pair in effects_for("player_gain_block"):
		if str(pair[1].get("type", "")) != "gain_block" or not can_use(pair):
			continue
		calc.value += int(pair[1].get("amount", 0))
		mark_on_commit(calc, pair)


## Luck-scaled 1.5x Block (crit_plating). Never rolled in preview.
func modify_block_multiplicative(calc) -> void:
	if calc.preview or not calc.is_powered() or not calc.from_player():
		return
	for pair in effects_for("player_gain_block"):
		if str(pair[1].get("type", "")) != "gain_block_crit" or not can_use(pair):
			continue
		if RunManager.rng("combat_crits").chance(RunManager.crit_chance()):
			calc.value *= 1.5
			if battle and battle.has_method("show_notification"):
				battle.show_notification("BLOCK CRIT!", Color(0.45, 0.7, 1.0))
		mark_on_commit(calc, pair)


## Every Short Circuit the player side applies gets bonus stacks (Surge Servo).
func modify_status_stacks(calc) -> void:
	if calc.status != "short_circuit" or calc.source == null or calc.source.side != "player":
		return
	for pair in effects_for("on_apply_short_circuit"):
		if str(pair[1].get("type", "")) == "add_short_circuit":
			calc.value += int(pair[1].get("amount", 0))


## Extra full-card replays for attack cards (double-fire clip +1).
func modify_attack_replays(calc) -> void:
	for pair in effects_for("on_attack_replay"):
		if str(pair[1].get("type", "")) == "attack_replay":
			calc.value += int(pair[1].get("amount", 0))


## Per-turn cap on attack cards (double-fire clip caps at 1). 0 = no cap; the
## highest cap wins.
func modify_attack_limit(calc) -> void:
	for pair in effects_for("on_attack_limit"):
		if str(pair[1].get("type", "")) == "attack_limit":
			calc.value = maxi(int(calc.value), int(pair[1].get("amount", 0)))


## First-turn extra allowance on an armed cap (Burst-Fire Clip +1).
func modify_attack_limit_first_turn(calc) -> void:
	for pair in effects_for("first_turn_allowance"):
		if str(pair[1].get("type", "")) == "bonus_allowance":
			calc.value += int(pair[1].get("amount", 0))


## Crit multiplier override (Volatile Crit Clip 175 → 1.75x); highest wins;
## skipped when a status locked the multiplier (All In).
func modify_crit_multiplier(m) -> void:
	if bool(m.fields.get("locked", false)):
		return
	for pair in effects_for("player_crit_mult"):
		if str(pair[1].get("type", "")) == "crit_mult":
			m.value = maxf(float(m.value), float(int(pair[1].get("amount", 0))) / 100.0)


# --- queries -----------------------------------------------------------------

## Turn start (combat_engine.reset_turn_crit): re-arm the first-attack Crit.
func reset_turn_state(_arg) -> void:
	_first_attack_crit_used = false


## Deadeye Crit Clip: the first player attack each turn is a guaranteed Crit.
## A preview shows it once per preview play; the real hit spends it.
func should_force_first_attack_crit(calc) -> bool:
	if _first_attack_crit_used or effects_for("first_attack_crit").filter(
		func(p): return str(p[1].get("type", "")) == "auto_crit"
	).is_empty():
		return false
	if not calc.preview:
		calc.on_commit(func() -> void: _first_attack_crit_used = true)
		return true
	var play = calc.play
	return play == null or play.simulate_spend("first_attack_crit")


## Arc Spines: the player's Thorns also apply equal Short Circuit.
func thorns_apply_short_circuit(_arg) -> bool:
	for pair in effects_for("on_thorns_damage"):
		if str(pair[1].get("type", "")) == "thorns_short_circuit":
			return true
	return false


# --- reactions -----------------------------------------------------------------

## Scavenger Lens: powered player Block deals damage to a random enemy.
func after_block_gained(result: Dictionary) -> void:
	var source = result.get("source")
	if source == null or source.side != "player" or not (int(result.get("props", 0)) & VALUE_PROPS.POWERED):
		return
	for pair in effects_for("player_gain_block"):
		if str(pair[1].get("type", "")) != "block_gain_damage" or not can_use(pair):
			continue
		mark_used(pair)
		var target = _random_alive_enemy()
		if target and commands():
			await commands().damage(relic_source(), [target], int(pair[1].get("amount", 0)), 0)


## After an attack card resolves on a live target: apply this relic's status.
func after_attack(attack: Dictionary) -> void:
	var source = attack.get("source")
	var target: Object = attack.get("target")
	if source == null or source.side != "player" or not alive(target) or commands() == null:
		return
	for pair in effects_for("player_attack"):
		var effect: Dictionary = pair[1]
		if str(effect.get("type", "")) != "apply_status" or not can_use(pair):
			continue
		mark_used(pair)
		await commands().apply_status(
			relic_source(), target, str(effect.get("status", "")),
			int(effect.get("amount", effect.get("stacks", 1))), "relic_apply_status"
		)


## Medkit Drone: heal when an enemy hit actually costs the player HP.
func after_damage_received(result) -> void:
	if result.target != _player() or result.hp_lost <= 0:
		return
	if result.source == null or result.source.side != "enemy":
		return
	for pair in effects_for("player_take_damage"):
		var effect: Dictionary = pair[1]
		if str(effect.get("type", "")) != "heal" or not can_use(pair):
			continue
		mark_used(pair)
		if result.target.has_method("heal") and result.target.heal(int(effect.get("amount", 0))) > 0:
			if battle and battle.get("presenter"):
				battle.presenter.sfx("heal")


## Ricochet Loader: add a card to hand on each player Crit.
func after_crit(_calc) -> void:
	if battle == null or not battle.has_method("add_card_to_hand"):
		return
	for pair in effects_for("on_crit"):
		var effect: Dictionary = pair[1]
		if str(effect.get("type", "")) == "add_card_to_hand":
			var cid := str(effect.get("card", ""))
			if cid != "":
				for _i in range(maxi(1, int(effect.get("amount", 1)))):
					battle.add_card_to_hand(cid)


# --- helpers -------------------------------------------------------------------

func can_use(pair: Array) -> bool:
	return not bool(pair[1].get("once_per_combat", false)) or not _used_once.has(pair[0])


func mark_used(pair: Array) -> void:
	if bool(pair[1].get("once_per_combat", false)):
		_used_once[pair[0]] = true


## Once-per-combat relics are spent by the real calculation only.
func mark_on_commit(calc, pair: Array) -> void:
	if calc.preview or not bool(pair[1].get("once_per_combat", false)):
		return
	calc.on_commit(mark_used.bind(pair))


func relic_source():
	return COMBAT_SOURCE.make("relic", "player", _player(), null, id)


## Runs one relic action through the shared effect registry.
func run_effect(effect: Dictionary) -> void:
	if battle == null or battle.get("effect_registry") == null:
		return
	var ctx = EFFECT_CONTEXT.make("combat", relic_source(), _player(), null, battle)
	await battle.effect_registry.execute(ctx, effect)


func _player():
	return battle.get("player") if battle else null


func _random_alive_enemy():
	if battle == null or battle.get("state") == null:
		return null
	var candidates: Array = battle.state.living_enemies()
	return RunManager.rng("combat_targets").pick(candidates)

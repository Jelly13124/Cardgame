extends RefCounted
class_name RelicEffectSystem

const VALUE_PROPS = preload("uid://cccfcqt180t4x")  # res://core/combat/value_props.gd
const EFFECT_CONTEXT = preload("uid://bx2g3askncfr6")  # res://core/effects/effect_context.gd
const COMBAT_SOURCE = preload("uid://jgs131055xrk")  # res://core/combat/combat_source.gd

# RunManager is a registered autoload — accessed directly, no instance plumbing.
var _battle_scene: Node
var _used_once: Dictionary = {}


func setup(battle_scene: Node) -> void:
	_battle_scene = battle_scene
	_used_once.clear()


## Turn-start relic actions run through the shared effect registry as relic
## sources: fixed values (no Constitution, Frail or Strength).
func on_player_turn_started(player: Node, round_number: int) -> void:
	for entry in _get_effect_entries("player_turn_start"):
		var effect: Dictionary = entry["effect"]
		var required_round = int(effect.get("round", 0))
		if required_round > 0 and round_number != required_round:
			continue
		if not _can_use_once(entry):
			continue
		var amount = int(effect.get("amount", 0))
		match str(effect.get("type", "")):
			"gain_energy", "gain_block", "deal_damage_all", "gain_temp_strength":
				_mark_used_once(entry)
				await _run_effect(entry, {"type": str(effect.get("type", "")), "amount": amount})
			"apply_self_status":
				# Self-buff status (e.g. thorns) every turn unless once_per_combat.
				_mark_used_once(entry)
				var stacks := int(effect.get("amount", effect.get("stacks", 1)))
				await _run_effect(
					entry,
					{"type": "apply_status_self", "status": str(effect.get("status", "")), "stacks": stacks}
				)
			"set_polarity_alternating":
				# Alternates the active polarity each player turn (round 1=Yin,
				# 2=Yang, 3=Yin…). Fires every turn — not once_per_combat.
				var polarity := "yin" if round_number % 2 == 1 else "yang"
				if player and player.has_method("reset_polarity_turn"):
					player.reset_polarity_turn(polarity)
				if _battle_scene and _battle_scene.has_method("update_polarity_hud"):
					_battle_scene.update_polarity_hud()


# ─── Combat hook listener (core/combat/combat_hooks.gd) ──────────────────────


## Relic flat damage bonus on powered player hits (player_attack_damage/add_damage).
func modify_damage_additive(calc) -> void:
	if not calc.is_powered() or not calc.from_player():
		return
	for entry in _get_effect_entries("player_attack_damage"):
		if str(entry["effect"].get("type", "")) != "add_damage" or not _can_use_once(entry):
			continue
		calc.value += int(entry["effect"].get("amount", 0))
		_mark_on_commit(calc, entry)


## Flat reduction of powered enemy hits on the player (reduce_damage); a
## once-per-combat relic is spent by the real hit only.
func modify_damage_reduction(calc) -> void:
	if not calc.is_powered() or calc.source == null or calc.source.side != "enemy":
		return
	if _battle_scene == null or calc.target != _battle_scene.get("player"):
		return
	for entry in _get_effect_entries("enemy_attack_damage"):
		if str(entry["effect"].get("type", "")) != "reduce_damage" or not _can_use_once(entry):
			continue
		calc.value -= int(entry["effect"].get("amount", 0))
		_mark_on_commit(calc, entry)


## Flat bonus Block on powered player Block (inertial_dampener).
func modify_block_additive(calc) -> void:
	if not calc.is_powered() or not calc.from_player():
		return
	for entry in _get_effect_entries("player_gain_block"):
		if str(entry["effect"].get("type", "")) != "gain_block" or not _can_use_once(entry):
			continue
		calc.value += int(entry["effect"].get("amount", 0))
		_mark_on_commit(calc, entry)


## Luck-scaled 1.5x Block (crit_plating). Never rolled in preview.
func modify_block_multiplicative(calc) -> void:
	if calc.preview or not calc.is_powered() or not calc.from_player():
		return
	for entry in _get_effect_entries("player_gain_block"):
		if str(entry["effect"].get("type", "")) != "gain_block_crit" or not _can_use_once(entry):
			continue
		if randf() < RunManager.crit_chance():
			calc.value *= 1.5
			if _battle_scene and _battle_scene.has_method("show_notification"):
				_battle_scene.show_notification("BLOCK CRIT!", Color(0.45, 0.7, 1.0))
		_mark_on_commit(calc, entry)


## Brutal Servo: every Short Circuit the player side applies gets bonus stacks.
func modify_status_stacks(calc) -> void:
	if calc.status == "short_circuit" and calc.source and calc.source.side == "player":
		calc.value += short_circuit_bonus_stacks()


## Scavenger Lens: powered player Block deals damage to a random enemy.
func after_block_gained(result: Dictionary) -> void:
	var source = result.get("source")
	if source == null or source.side != "player" or not (int(result.get("props", 0)) & VALUE_PROPS.POWERED):
		return
	for entry in _get_effect_entries("player_gain_block"):
		if str(entry["effect"].get("type", "")) != "block_gain_damage" or not _can_use_once(entry):
			continue
		_mark_used_once(entry)
		var target := _random_alive_enemy()
		if target:
			await _commands().damage(
				_relic_source(entry), [target], int(entry["effect"].get("amount", 0)), 0
			)


## After an attack card resolves on a live target: player_attack relics apply
## their status to it (Brutal Servo's bonus comes through modify_status_stacks).
func after_attack(attack: Dictionary) -> void:
	var source = attack.get("source")
	var target: Object = attack.get("target")
	if source == null or source.side != "player" or not _is_live(target):
		return
	for entry in _get_effect_entries("player_attack"):
		var effect: Dictionary = entry["effect"]
		if str(effect.get("type", "")) != "apply_status" or not _can_use_once(entry):
			continue
		_mark_used_once(entry)
		await _commands().apply_status(
			_relic_source(entry), target, str(effect.get("status", "")),
			int(effect.get("amount", effect.get("stacks", 1))), "relic_apply_status"
		)


## Medkit Drone: heal when an enemy hit actually costs the player HP.
func after_damage_received(result) -> void:
	if _battle_scene == null or result.target != _battle_scene.get("player") or result.hp_lost <= 0:
		return
	if result.source == null or result.source.side != "enemy":
		return
	for entry in _get_effect_entries("player_take_damage"):
		var effect: Dictionary = entry["effect"]
		if str(effect.get("type", "")) != "heal" or not _can_use_once(entry):
			continue
		_mark_used_once(entry)
		if result.target.has_method("heal"):
			result.target.heal(int(effect.get("amount", 0)))


func modify_enemy_attack_damage(amount: int, _attacker: Node, _defender: Node) -> int:
	var result = amount
	for entry in _get_effect_entries("enemy_attack_damage"):
		var effect: Dictionary = entry["effect"]
		if not _can_use_once(entry):
			continue
		match str(effect.get("type", "")):
			"reduce_damage":
				var reduction = int(effect.get("amount", 0))
				result = max(0, result - reduction)
				_notify("%s: -%d Damage" % [str(entry["title"]), reduction], Color(0.35, 0.9, 1.0))
				_mark_used_once(entry)
	return result


func on_combat_victory(_player: Node) -> void:
	for entry in _get_effect_entries("combat_victory"):
		var effect: Dictionary = entry["effect"]
		if not _can_use_once(entry) or not str(effect.get("type", "")) in ["heal", "gain_gold"]:
			continue
		_mark_used_once(entry)
		await _run_effect(entry, {"type": str(effect.get("type", "")), "amount": int(effect.get("amount", 0))})


## Passive stat grants fired once at battle start (war_horn +1 STR,
## bulk_actuator set STR to a floor). Called from battle_scene._start_new_game.
func on_battle_started(player: Node) -> void:
	if player == null:
		return
	for entry in _get_effect_entries("battle_start"):
		var effect: Dictionary = entry["effect"]
		var amount: int = int(effect.get("amount", 0))
		match str(effect.get("type", "")):
			"gain_strength":
				player.strength += amount
				if player.has_signal("stats_changed"):
					player.stats_changed.emit()
				_notify("%s: +%d Strength" % [str(entry["title"]), amount], Color(1.0, 0.5, 0.3))
			"set_strength":
				# Raise Strength to a floor; never lowers a higher base. `max`
				# caps the set value so stacking sources can't overshoot.
				var target := amount
				if effect.has("max"):
					target = mini(target, int(effect.get("max", amount)))
				if player.strength < target:
					player.strength = target
					if player.has_signal("stats_changed"):
						player.stats_changed.emit()
					_notify("%s: Strength %d" % [str(entry["title"]), target], Color(1.0, 0.5, 0.3))


## Fired from enemy_ai when the player takes attack damage. medkit_drone heals.
func on_player_take_damage(player: Node) -> void:
	if player == null or not is_instance_valid(player):
		return
	for entry in _get_effect_entries("player_take_damage"):
		var effect: Dictionary = entry["effect"]
		if not _can_use_once(entry):
			continue
		match str(effect.get("type", "")):
			"heal":
				if player.has_method("heal"):
					player.heal(int(effect.get("amount", 0)))
					_mark_used_once(entry)


## Total bonus Short Circuit added whenever the player applies it (Surge Servo).
## Returns 0 when no on_apply_short_circuit relic is owned.
func short_circuit_bonus_stacks() -> int:
	var bonus := 0
	for entry in _get_effect_entries("on_apply_short_circuit"):
		var effect: Dictionary = entry["effect"]
		if str(effect.get("type", "")) == "add_short_circuit":
			bonus += int(effect.get("amount", 0))
	return bonus


## Extra full-card replays granted to ATTACK cards by held relics (the double-fire
## clip grants +1). Read by combat_engine._replay_count when resolving an attack.
func attack_replay_bonus() -> int:
	var bonus := 0
	for entry in _get_effect_entries("on_attack_replay"):
		if str(entry["effect"].get("type", "")) == "attack_replay":
			bonus += int(entry["effect"].get("amount", 0))
	return bonus


## Per-turn cap on attack cards imposed by held relics (the double-fire clip caps
## at 1). 0 = no cap (normal play). The highest cap wins if multiple relics set one.
func attack_limit_per_turn() -> int:
	var limit := 0
	for entry in _get_effect_entries("on_attack_limit"):
		if str(entry["effect"].get("type", "")) == "attack_limit":
			limit = max(limit, int(entry["effect"].get("amount", 0)))
	return limit


## Player Crit damage multiplier override from held relics (Volatile Crit Clip →
## 1.75x). Returns `default_mult` when no relic overrides it; the highest override
## wins. `amount` is a percentage (175 → 1.75x). Read by combat_engine._apply_player_crit.
func crit_mult(default_mult: float) -> float:
	var result := default_mult
	for entry in _get_effect_entries("player_crit_mult"):
		if str(entry["effect"].get("type", "")) == "crit_mult":
			result = max(result, float(int(entry["effect"].get("amount", 0))) / 100.0)
	return result


## True if a held relic makes the FIRST player attack each turn a guaranteed Crit
## (Deadeye Crit Clip). combat_engine._apply_player_crit tracks the per-turn "first
## attack" itself and consults this.
func first_attack_auto_crit() -> bool:
	for entry in _get_effect_entries("first_attack_crit"):
		if str(entry["effect"].get("type", "")) == "auto_crit":
			return true
	return false


## Extra attack-allowance granted on the FIRST turn only by held relics (Burst-Fire
## Clip → +1, i.e. 2 attacks on turn 1). Read by battle_scene at player-turn start.
func first_turn_bonus_allowance() -> int:
	var bonus := 0
	for entry in _get_effect_entries("first_turn_allowance"):
		if str(entry["effect"].get("type", "")) == "bonus_allowance":
			bonus += int(entry["effect"].get("amount", 0))
	return bonus


## True if a held relic makes the player's Thorns reflection also apply equal
## Short Circuit to the attacker (Arc Spines). Read by combat_engine.
func thorns_apply_short_circuit() -> bool:
	for entry in _get_effect_entries("on_thorns_damage"):
		if str(entry["effect"].get("type", "")) == "thorns_short_circuit":
			return true
	return false


## Held relics that react to a player Crit. Ricochet Loader adds a Reload card to
## the hand on each crit. Called from combat_engine._apply_player_crit.
func on_player_crit(_player: Node) -> void:
	if _battle_scene == null:
		return
	var dm = _battle_scene.get("deck_manager")
	if dm == null or not dm.has_method("add_card_to_hand"):
		return
	for entry in _get_effect_entries("on_crit"):
		var effect: Dictionary = entry["effect"]
		if str(effect.get("type", "")) == "add_card_to_hand":
			var cid: String = str(effect.get("card", ""))
			if cid != "":
				for _i in range(maxi(1, int(effect.get("amount", 1)))):
					dm.add_card_to_hand(cid)


func _random_alive_enemy() -> Node:
	if _battle_scene == null:
		return null
	var container = _battle_scene.get("enemy_container")
	if container == null or not is_instance_valid(container):
		return null
	var alive: Array = []
	for enemy in container.get_children():
		if _is_live(enemy) and enemy.has_method("take_damage"):
			alive.append(enemy)
	return alive[randi() % alive.size()] if not alive.is_empty() else null


func _is_live(creature: Object) -> bool:
	if creature == null or not is_instance_valid(creature):
		return false
	if creature is Node and (creature as Node).is_queued_for_deletion():
		return false
	return int(creature.get("health")) > 0


func _commands():
	return _battle_scene.get("combat_commands") if _battle_scene else null


func _relic_source(entry: Dictionary):
	var player = _battle_scene.get("player") if _battle_scene else null
	return COMBAT_SOURCE.make("relic", "player", player, null, str(entry["relic_id"]))


## Runs one relic action through the shared effect registry.
func _run_effect(entry: Dictionary, effect: Dictionary) -> void:
	if _battle_scene == null or _battle_scene.get("effect_registry") == null:
		return
	var ctx = EFFECT_CONTEXT.make(
		"combat", _relic_source(entry), _battle_scene.get("player"), null, _battle_scene
	)
	await _battle_scene.effect_registry.execute(ctx, effect)


## Once-per-combat relics are spent by the real calculation only.
func _mark_on_commit(calc, entry: Dictionary) -> void:
	if calc.preview or not bool(entry["effect"].get("once_per_combat", false)):
		return
	calc.on_commit(_mark_used_once.bind(entry))


func _get_effect_entries(trigger: String) -> Array:
	var entries: Array = []
	if not RunManager.is_run_active:
		return entries

	var relic_ids = RunManager.relics
	if typeof(relic_ids) != TYPE_ARRAY:
		return entries

	for relic_id in relic_ids:
		var data: Dictionary = RunManager.get_relic_data(str(relic_id))
		var effects = data.get("effects", [])
		if typeof(effects) != TYPE_ARRAY:
			continue

		for i in range(effects.size()):
			var effect = effects[i]
			if typeof(effect) != TYPE_DICTIONARY:
				continue
			if str(effect.get("trigger", "")) != trigger:
				continue
			(
				entries
				. append(
					{
						"relic_id": str(relic_id),
						"title": str(data.get("title", str(relic_id))),
						"index": i,
						"effect": effect,
					}
				)
			)
	return entries


func _can_use_once(entry: Dictionary) -> bool:
	var effect: Dictionary = entry["effect"]
	if not bool(effect.get("once_per_combat", false)):
		return true
	return not _used_once.has(_entry_key(entry))


func _mark_used_once(entry: Dictionary) -> void:
	var effect: Dictionary = entry["effect"]
	if bool(effect.get("once_per_combat", false)):
		_used_once[_entry_key(entry)] = true


func _entry_key(entry: Dictionary) -> String:
	var effect: Dictionary = entry["effect"]
	return (
		"%s:%s:%d" % [str(entry["relic_id"]), str(effect.get("trigger", "")), int(entry["index"])]
	)


## Center-screen yellow text removed per UX feedback. Kept as no-op so
## existing call sites at relic-trigger points don't break.
func _notify(_text: String, _color: Color) -> void:
	pass

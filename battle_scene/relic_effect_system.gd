extends RefCounted
class_name RelicEffectSystem

# RunManager is a registered autoload — accessed directly, no instance plumbing.
var _battle_scene: Node
var _used_once: Dictionary = {}


func setup(battle_scene: Node) -> void:
	_battle_scene = battle_scene
	_used_once.clear()


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
			"gain_energy":
				if player and player.has_method("pay_energy"):
					player.pay_energy(-amount)
					_notify(
						"%s: +%d Energy" % [str(entry["title"]), amount], Color(0.95, 0.9, 0.25)
					)
					_mark_used_once(entry)
			"gain_block":
				if player and player.has_method("add_block"):
					player.add_block(amount)
					_notify("%s: +%d Block" % [str(entry["title"]), amount], Color(0.45, 0.7, 1.0))
					_mark_used_once(entry)
			"set_polarity_alternating":
				# Alternates the active polarity each player turn (round 1=Yin,
				# 2=Yang, 3=Yin…). Fires every turn — not once_per_combat.
				var polarity := "yin" if round_number % 2 == 1 else "yang"
				if player and player.has_method("reset_polarity_turn"):
					player.reset_polarity_turn(polarity)
				if _battle_scene and _battle_scene.has_method("update_polarity_hud"):
					_battle_scene.update_polarity_hud()
			"apply_self_status":
				# Applies a self-buff status (e.g. thorns) at turn start.
				# Fires every turn unless the relic marks once_per_combat.
				var status := str(effect.get("status", ""))
				var n := int(effect.get("amount", effect.get("stacks", 1)))
				if player and player.has_method("add_status"):
					player.add_status(status, n)
					_notify("%s: +%d %s" % [str(entry["title"]), n, status], Color(0.85, 0.4, 0.4))
					_mark_used_once(entry)
			"deal_damage_all":
				# Chip every alive enemy at turn start (e.g. cracked_battery).
				if _deal_to_all_enemies(amount):
					_notify("%s: %d to all" % [str(entry["title"]), amount], Color(1.0, 0.4, 0.3))
					_mark_used_once(entry)
			"gain_temp_strength":
				# Temporary Strength that fades at end of turn (kinetic_hammer).
				if player and player.has_method("gain_temp_strength"):
					player.gain_temp_strength(amount)
					_notify(
						"%s: +%d Strength" % [str(entry["title"]), amount], Color(1.0, 0.5, 0.3)
					)
					_mark_used_once(entry)


func modify_player_attack_damage(amount: int, _attacker: Node, _defender: Node) -> int:
	var result = amount
	for entry in _get_effect_entries("player_attack_damage"):
		var effect: Dictionary = entry["effect"]
		if not _can_use_once(entry):
			continue
		match str(effect.get("type", "")):
			"add_damage":
				result += int(effect.get("amount", 0))
				_mark_used_once(entry)
			"crit_chance":
				if randf() < RunManager.crit_chance():
					result = int(round(result * RunManager.CRIT_MULT))
					if _battle_scene and _battle_scene.has_method("show_notification"):
						_battle_scene.show_notification("CRIT!", Color(1, 0.85, 0.2))
				_mark_used_once(entry)
	return max(0, result)


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


func on_combat_victory(player: Node) -> void:
	for entry in _get_effect_entries("combat_victory"):
		var effect: Dictionary = entry["effect"]
		if not _can_use_once(entry):
			continue

		var amount = int(effect.get("amount", 0))
		match str(effect.get("type", "")):
			"heal":
				if player and player.has_method("heal"):
					player.heal(amount)
					_notify(
						"%s: healed %d HP" % [str(entry["title"]), amount], Color(0.3, 1.0, 0.45)
					)
					_mark_used_once(entry)
			"gain_gold":
				RunManager.add_resources(amount, 0)
				_notify("%s: +%d Gold" % [str(entry["title"]), amount], Color(1.0, 0.85, 0.24))
				_mark_used_once(entry)


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


## Fired from combat_engine's gain_block case with the post-multiplier block
## amount. Returns the (possibly modified) block to actually apply, so a relic
## like crit_plating can multiply it. Side-effects (scavenger_lens chip) leave
## the amount unchanged.
func on_player_gain_block(_player: Node, amount: int) -> int:
	var result := amount
	for entry in _get_effect_entries("player_gain_block"):
		var effect: Dictionary = entry["effect"]
		if not _can_use_once(entry):
			continue
		match str(effect.get("type", "")):
			"gain_block_crit":
				if randf() < RunManager.crit_chance():
					result = int(round(result * 1.5))
					if _battle_scene and _battle_scene.has_method("show_notification"):
						_battle_scene.show_notification("BLOCK CRIT!", Color(0.45, 0.7, 1.0))
				_mark_used_once(entry)
			"block_gain_damage":
				_deal_to_random_enemy(int(effect.get("amount", 0)))
				_mark_used_once(entry)
			"gain_block":
				# Flat bonus Block whenever the player gains Block (inertial_dampener).
				result += int(effect.get("amount", 0))
				_mark_used_once(entry)
	return result


## Fired from combat_engine after a player ATTACK card resolves on `target`.
## sharpened_scrap applies Bleed to the struck enemy (with the brutal_servo bonus).
func on_player_attack(target: Node) -> void:
	if target == null or not is_instance_valid(target) or not target.has_method("add_status"):
		return
	for entry in _get_effect_entries("player_attack"):
		var effect: Dictionary = entry["effect"]
		if not _can_use_once(entry):
			continue
		match str(effect.get("type", "")):
			"apply_status":
				var status := str(effect.get("status", ""))
				var n := int(effect.get("amount", effect.get("stacks", 1)))
				if status == "bleed":
					n += bleed_bonus_stacks()
				target.add_status(status, n)
				_mark_used_once(entry)


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


## Total bonus Bleed stacks added whenever the player applies Bleed (brutal_servo).
## Returns 0 when no on_apply_bleed relic is owned.
func bleed_bonus_stacks() -> int:
	var bonus := 0
	for entry in _get_effect_entries("on_apply_bleed"):
		var effect: Dictionary = entry["effect"]
		if str(effect.get("type", "")) == "add_bleed":
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


## Deal `amount` to every alive enemy. Returns true if at least one enemy was hit
## (so the caller can gate its notification / once_per_combat marking).
func _deal_to_all_enemies(amount: int) -> bool:
	if amount <= 0 or _battle_scene == null:
		return false
	var container = _battle_scene.get("enemy_container")
	if container == null or not is_instance_valid(container):
		return false
	var hit := false
	for enemy in container.get_children():
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(amount)
			hit = true
	return hit


## Deal `amount` to one random alive enemy (scavenger_lens). No-op when no
## enemies remain. The chosen enemy may die; we touch it only once.
func _deal_to_random_enemy(amount: int) -> void:
	if amount <= 0 or _battle_scene == null:
		return
	var container = _battle_scene.get("enemy_container")
	if container == null or not is_instance_valid(container):
		return
	var alive: Array = []
	for enemy in container.get_children():
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			alive.append(enemy)
	if alive.is_empty():
		return
	var target: Node = alive[randi() % alive.size()]
	if is_instance_valid(target):
		target.take_damage(amount)


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

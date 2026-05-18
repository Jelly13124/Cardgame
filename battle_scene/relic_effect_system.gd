extends RefCounted
class_name RelicEffectSystem

var _run_manager: Node
var _battle_scene: Node
var _used_once: Dictionary = {}


func setup(run_manager: Node, battle_scene: Node) -> void:
	_run_manager = run_manager
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
					_notify("%s: +%d Energy" % [str(entry["title"]), amount], Color(0.95, 0.9, 0.25))
					_mark_used_once(entry)
			"gain_block":
				if player and player.has_method("add_block"):
					player.add_block(amount)
					_notify("%s: +%d Block" % [str(entry["title"]), amount], Color(0.45, 0.7, 1.0))
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
					_notify("%s: healed %d HP" % [str(entry["title"]), amount], Color(0.3, 1.0, 0.45))
					_mark_used_once(entry)
			"gain_gold":
				if _run_manager and _run_manager.has_method("add_resources"):
					_run_manager.add_resources(amount, 0)
					_notify("%s: +%d Gold" % [str(entry["title"]), amount], Color(1.0, 0.85, 0.24))
					_mark_used_once(entry)


func _get_effect_entries(trigger: String) -> Array:
	var entries: Array = []
	if not _run_manager or not _run_manager.get("is_run_active"):
		return entries

	var relic_ids = _run_manager.get("relics")
	if typeof(relic_ids) != TYPE_ARRAY:
		return entries

	for relic_id in relic_ids:
		var data: Dictionary = _run_manager.get_relic_data(str(relic_id))
		var effects = data.get("effects", [])
		if typeof(effects) != TYPE_ARRAY:
			continue

		for i in range(effects.size()):
			var effect = effects[i]
			if typeof(effect) != TYPE_DICTIONARY:
				continue
			if str(effect.get("trigger", "")) != trigger:
				continue
			entries.append({
				"relic_id": str(relic_id),
				"title": str(data.get("title", str(relic_id))),
				"index": i,
				"effect": effect,
			})
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
	return "%s:%s:%d" % [str(entry["relic_id"]), str(effect.get("trigger", "")), int(entry["index"])]


func _notify(text: String, color: Color) -> void:
	if _battle_scene and _battle_scene.has_method("show_notification"):
		_battle_scene.show_notification(text, color)

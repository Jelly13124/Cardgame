extends RefCounted
class_name EquipmentSetSystem

const COMBAT_FX = preload("res://battle_scene/combat_fx.gd")

var _battle_scene: Node
var _active_effects: Array[Dictionary] = []


func setup(battle_scene: Node) -> void:
	_battle_scene = battle_scene
	_active_effects.clear()


## Snapshot the equipped set tiers once at combat start. Equipment cannot change
## during combat, so keeping the active effects here avoids repeated disk reads.
func on_battle_started(player: Node) -> void:
	_active_effects.clear()
	var counts: Dictionary = RunManager.get_active_set_tiers()
	for set_id_variant in counts.keys():
		var set_id := str(set_id_variant)
		var piece_count := int(counts[set_id_variant])
		var set_data: Dictionary = RunManager.get_equipment_set_data(set_id)
		for tier_variant in set_data.get("tiers", []):
			if typeof(tier_variant) != TYPE_DICTIONARY:
				continue
			var tier: Dictionary = tier_variant
			if piece_count < int(tier.get("count", 999)):
				continue
			var effect_variant: Variant = tier.get("effect", {})
			if typeof(effect_variant) != TYPE_DICTIONARY:
				continue
			var effect: Dictionary = effect_variant.duplicate(true)
			effect["set_id"] = set_id
			_active_effects.append(effect)

	# A single local callout makes the loadout visible in combat without bringing
	# back the old center-screen notification stack.
	for set_id_variant in counts.keys():
		_notify(str(set_id_variant), Color(0.35, 0.92, 0.92))

	for effect in _active_effects:
		if str(effect.get("type", "")) == "start_battle_block" and player:
			player.add_block(int(effect.get("amount", 0)))


func on_player_turn_started(player: Node, _round_number: int) -> void:
	if player == null:
		return
	for effect in _active_effects:
		var amount := int(effect.get("amount", 0))
		match str(effect.get("type", "")):
			"start_turn_block":
				player.add_block(amount)
				if player.has_method("play_block_pulse"):
					player.play_block_pulse()
				_notify(str(effect.get("set_id", "")), Color(0.45, 0.75, 1.0))
			"start_turn_energy":
				player.pay_energy(-amount)
				_notify(str(effect.get("set_id", "")), Color(0.98, 0.88, 0.28))


func modify_card_block(source_card: Node, amount: int) -> int:
	if not _is_card_type(source_card, "skill"):
		return amount
	var result := amount
	for effect in _active_effects:
		if str(effect.get("type", "")) == "skill_block_bonus":
			result += int(effect.get("amount", 0))
	return max(0, result)


func modify_card_damage(source_card: Node, amount: int) -> int:
	if not _is_card_type(source_card, "attack"):
		return amount
	var result := amount
	for effect in _active_effects:
		if str(effect.get("type", "")) == "attack_damage_bonus":
			result += int(effect.get("amount", 0))
	return max(0, result)


func on_card_damage_resolved(source_card: Node, target: Node) -> void:
	if target == null or not is_instance_valid(target) or not _is_card_type(source_card, "attack"):
		return
	for effect in _active_effects:
		if str(effect.get("type", "")) != "attack_apply_status":
			continue
		var status := str(effect.get("status", ""))
		var stacks := int(effect.get("stacks", effect.get("amount", 1)))
		if status == "" or stacks <= 0 or not target.has_method("add_status"):
			continue
		target.add_status(status, stacks)
		_notify(str(effect.get("set_id", "")), Color(0.95, 0.55, 0.28))


func _is_card_type(source_card: Node, expected: String) -> bool:
	if source_card == null or not is_instance_valid(source_card):
		return false
	var data: Variant = source_card.get("card_info")
	return typeof(data) == TYPE_DICTIONARY and str(data.get("type", "")).to_lower() == expected


func _notify(set_id: String, color: Color) -> void:
	if set_id == "" or _battle_scene == null or not is_instance_valid(_battle_scene):
		return
	var player: Node = _battle_scene.get("player")
	if player == null or not is_instance_valid(player) or not player is Node2D:
		return
	var name_key := "SET_%s_NAME" % set_id.to_upper()
	var set_name := tr(name_key)
	if set_name == name_key:
		set_name = set_id.replace("_", " ").capitalize()
	var message := tr("UI_EQUIP_SET_TRIGGER").format({"set": set_name})
	COMBAT_FX.spawn_feedback_text(
		_battle_scene, (player as Node2D).global_position + Vector2(0, -138), message, color
	)
	AudioManager.play_sfx("reward", -8.0, 1.08, 0.02)

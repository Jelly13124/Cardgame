extends RefCounted
class_name EquipmentSetSystem

const COMBAT_FX = preload("uid://dx2h4lk8uoasg")  # res://battle_scene/combat_fx.gd
const EFFECT_CONTEXT = preload("uid://bx2g3askncfr6")  # res://core/effects/effect_context.gd
const COMBAT_SOURCE = preload("uid://jgs131055xrk")  # res://core/combat/combat_source.gd

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
			await _run_effect(effect, {"type": "gain_block", "amount": int(effect.get("amount", 0))})


## Turn-start set actions run through the shared effect registry as set
## sources: fixed values (no Constitution or Frail).
func on_player_turn_started(player: Node, _round_number: int) -> void:
	if player == null:
		return
	for effect in _active_effects:
		var amount := int(effect.get("amount", 0))
		match str(effect.get("type", "")):
			"start_turn_block":
				await _run_effect(effect, {"type": "gain_block", "amount": amount})
				if player.has_method("play_block_pulse"):
					player.play_block_pulse()
				_notify(str(effect.get("set_id", "")), Color(0.45, 0.75, 1.0))
			"start_turn_energy":
				await _run_effect(effect, {"type": "gain_energy", "amount": amount})
				_notify(str(effect.get("set_id", "")), Color(0.98, 0.88, 0.28))


func _run_effect(set_effect: Dictionary, effect: Dictionary) -> void:
	if _battle_scene == null or _battle_scene.get("effect_registry") == null:
		return
	var player = _battle_scene.get("player")
	var source = COMBAT_SOURCE.make("set", "player", player, null, str(set_effect.get("set_id", "")))
	var ctx = EFFECT_CONTEXT.make("combat", source, player, null, _battle_scene)
	await _battle_scene.effect_registry.execute(ctx, effect)


# ─── Combat hook listener (core/combat/combat_hooks.gd) ──────────────────────


## attack_damage_bonus: powered damage from Attack cards.
func modify_damage_additive(calc) -> void:
	if calc.is_powered() and calc.source and calc.source.card_type() == "attack":
		calc.value += _sum("attack_damage_bonus")


## skill_block_bonus: powered Block from Skill cards.
func modify_block_additive(calc) -> void:
	if calc.is_powered() and calc.source and calc.source.card_type() == "skill":
		calc.value += _sum("skill_block_bonus")


## attack_apply_status: every hit an Attack card deals (Final Salvo and Kinetic
## Rebound included) applies the set's status to the struck enemy if it lives.
func after_damage_given(result) -> void:
	if result.source == null or result.source.card_type() != "attack" or not _is_live(result.target):
		return
	for effect in _active_effects:
		if str(effect.get("type", "")) != "attack_apply_status":
			continue
		var stacks := int(effect.get("stacks", effect.get("amount", 1)))
		var set_id := str(effect.get("set_id", ""))
		var source = COMBAT_SOURCE.make("set", "player", _battle_scene.get("player"), null, set_id)
		var applied: int = await _battle_scene.combat_commands.apply_status(
			source, result.target, str(effect.get("status", "")), stacks, "set_apply_status"
		)
		if applied > 0:
			_notify(set_id, Color(0.95, 0.55, 0.28))


func _sum(effect_type: String) -> int:
	var total := 0
	for effect in _active_effects:
		if str(effect.get("type", "")) == effect_type:
			total += int(effect.get("amount", 0))
	return total


func _is_live(creature: Object) -> bool:
	if creature == null or not is_instance_valid(creature):
		return false
	if creature is Node and (creature as Node).is_queued_for_deletion():
		return false
	return int(creature.get("health")) > 0


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

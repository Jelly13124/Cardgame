## EquipmentSetSystem snapshots active set tiers at battle start and applies
## the resulting "virtual relic-like" effects via the same trigger model as
## relic_effect_system. Reads RunManager.equipped_items + .get_active_set_tiers().
##
## Snapshot semantics: equipment cannot change during a battle (PRD), so we
## resolve which tiers are active in `on_battle_started()` and ignore later
## changes to RunManager.equipped_items.
extends RefCounted
class_name EquipmentSetSystem

var _battle_scene: Node
## Each entry: { "set_id": String, "tier_label": String, "effect": Dictionary }
var _active_effects: Array = []


func setup(battle_scene: Node) -> void:
	_battle_scene = battle_scene
	_active_effects.clear()


## Resolve active tier effects from RunManager and notify each one. Call once
## at battle start, after attribute injection.
func on_battle_started(player: Node) -> void:
	_active_effects.clear()
	if not RunManager.is_run_active:
		return

	var tiers: Dictionary = RunManager.get_active_set_tiers()
	for set_id in tiers.keys():
		var count: int = int(tiers[set_id])
		var set_data: Dictionary = RunManager.get_equipment_set_data(str(set_id))
		# Tiers are additive: a 5-piece set grants BOTH its 3-piece tier effect AND
		# its 5-piece tier effect simultaneously (standard RPG set-bonus pattern).
		# This is by design, not a bug — match every tier whose threshold is met.
		var tier_list: Variant = set_data.get("tiers", [])
		if typeof(tier_list) != TYPE_ARRAY:
			continue
		for tier in tier_list:
			if typeof(tier) != TYPE_DICTIONARY:
				continue
			if count >= int(tier.get("count", 999)):
				_active_effects.append({
					"set_id": str(set_id),
					"tier_label": str(tier.get("label", "")),
					"effect": tier.get("effect", {}),
				})

	# Apply start_battle_block effects right now
	for entry in _active_effects:
		var effect: Dictionary = entry["effect"]
		if str(effect.get("type", "")) == "start_battle_block":
			var amount: int = int(effect.get("amount", 0))
			if player and player.has_method("add_block"):
				player.add_block(amount)
				_notify("%s: +%d Block (battle start)" % [entry["tier_label"], amount], Color(0.45, 0.7, 1.0))


## Apply start_turn_block / start_turn_energy effects.
## Note: round_number is accepted for API parity with relic_effect_system but
## set effects intentionally fire every turn (no once-per-combat gating).
func on_player_turn_started(player: Node, _round_number: int) -> void:
	for entry in _active_effects:
		var effect: Dictionary = entry["effect"]
		var amount: int = int(effect.get("amount", 0))
		match str(effect.get("type", "")):
			"start_turn_block":
				if player and player.has_method("add_block"):
					player.add_block(amount)
					_notify("%s: +%d Block" % [entry["tier_label"], amount], Color(0.45, 0.7, 1.0))
			"start_turn_energy":
				if player and player.has_method("pay_energy"):
					player.pay_energy(-amount)
					_notify("%s: +%d Energy" % [entry["tier_label"], amount], Color(0.95, 0.9, 0.25))


## Add skill_block_bonus to gain_block amount when card is a skill.
func modify_card_block(card: Node, amount: int) -> int:
	if card == null or not card.card_info.get("type", "") == "skill":
		return amount
	var result = amount
	for entry in _active_effects:
		var effect: Dictionary = entry["effect"]
		if str(effect.get("type", "")) == "skill_block_bonus":
			result += int(effect.get("amount", 0))
	return result


## Add attack_damage_bonus to deal_damage amount when card is an attack.
func modify_card_damage(card: Node, amount: int) -> int:
	if card == null or not card.card_info.get("type", "") == "attack":
		return amount
	var result = amount
	for entry in _active_effects:
		var effect: Dictionary = entry["effect"]
		if str(effect.get("type", "")) == "attack_damage_bonus":
			result += int(effect.get("amount", 0))
	return result


## Apply attack_apply_status to target after damage resolves on an attack card.
func on_card_damage_resolved(card: Node, target: Node) -> void:
	if card == null or not card.card_info.get("type", "") == "attack":
		return
	if target == null or not is_instance_valid(target):
		return
	for entry in _active_effects:
		var effect: Dictionary = entry["effect"]
		if str(effect.get("type", "")) == "attack_apply_status":
			var status = str(effect.get("status", ""))
			var stacks = int(effect.get("stacks", 0))
			if status == "" or stacks <= 0:
				continue
			if target.has_method("add_status"):
				target.add_status(status, stacks)
				_notify("%s: %s +%d on target" % [entry["tier_label"], status.to_upper(), stacks], Color(0.85, 0.6, 1.0))


func _notify(text: String, color: Color) -> void:
	if _battle_scene and _battle_scene.has_method("show_notification"):
		_battle_scene.show_notification(text, color)

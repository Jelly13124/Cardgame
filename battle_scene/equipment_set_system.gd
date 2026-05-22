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
		var tier_list = set_data.get("tiers", [])
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
			var amount = int(effect.get("amount", 0))
			if player and player.has_method("add_block"):
				player.add_block(amount)
				_notify("%s: +%d Block (battle start)" % [entry["tier_label"], amount], Color(0.45, 0.7, 1.0))


## Apply start_turn_block / start_turn_energy effects.
func on_player_turn_started(player: Node, _round_number: int) -> void:
	for entry in _active_effects:
		var effect: Dictionary = entry["effect"]
		var amount = int(effect.get("amount", 0))
		match str(effect.get("type", "")):
			"start_turn_block":
				if player and player.has_method("add_block"):
					player.add_block(amount)
					_notify("%s: +%d Block" % [entry["tier_label"], amount], Color(0.45, 0.7, 1.0))
			"start_turn_energy":
				if player and player.has_method("pay_energy"):
					player.pay_energy(-amount)
					_notify("%s: +%d Energy" % [entry["tier_label"], amount], Color(0.95, 0.9, 0.25))


## Hooks for Task 6 (placeholders so combat_engine compiles after that task).
func modify_card_block(_card: Node, amount: int) -> int:
	return amount


func modify_card_damage(_card: Node, amount: int) -> int:
	return amount


func on_card_damage_resolved(_card: Node, _target: Node) -> void:
	pass


func _notify(text: String, color: Color) -> void:
	if _battle_scene and _battle_scene.has_method("show_notification"):
		_battle_scene.show_notification(text, color)

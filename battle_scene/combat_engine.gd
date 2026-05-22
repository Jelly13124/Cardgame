extends Node
## Data-driven card effect resolver. Card behavior comes from each card JSON
## "effects" array; add new effect types in _apply_effect().

# Preloaded so we don't depend on Godot's class_name registry being warm at parse time.
const STATUS_SYS = preload("res://battle_scene/status_effect_system.gd")

signal victory_declared()

const ATTRIBUTE_COLORS = {
	"gain_strength":     Color(1.0, 0.5, 0.2),
	"gain_constitution": Color(0.4, 0.7, 1.0),
	"gain_intelligence": Color(0.8, 0.4, 1.0),
	"gain_luck":         Color(1.0, 0.9, 0.2),
	"gain_charm":        Color(1.0, 0.5, 0.8),
}

const MUZZLE_FLASH_TEX = preload("res://battle_scene/assets/images/fx/gunshot/muzzle_flash.png")
const BULLET_TEX = preload("res://battle_scene/assets/images/fx/gunshot/bullet.png")
const IMPACT_TEX = preload("res://battle_scene/assets/images/fx/gunshot/impact.png")

@onready var main = get_parent()


func declare_victory() -> void:
	victory_declared.emit()


func calculate_attack_damage(base_damage: int, attacker: Node, defender: Node) -> int:
	var modified_base = base_damage
	if main and main.has_method("modify_player_attack_damage") and attacker == main.player:
		modified_base = main.modify_player_attack_damage(modified_base, attacker, defender)

	var outgoing_mult := 1.0
	var incoming_mult := 1.0
	if attacker and attacker.has_method("get_outgoing_multiplier"):
		outgoing_mult = attacker.get_outgoing_multiplier()
	if defender and defender.has_method("get_incoming_attack_multiplier"):
		incoming_mult = defender.get_incoming_attack_multiplier()
	return int(modified_base * outgoing_mult * incoming_mult)


func resolve_card_effect(card: Control, target: Node, player: Node) -> void:
	var effects: Array = card.card_info.get("effects", [])
	var type = card.card_info.get("type", "skill").to_lower()

	var card_mult: float = 1.0
	if type == "attack" and player.has_method("get_status_stacks") and player.get_status_stacks("double_damage") > 0:
		card_mult = 2.0
		player.status_system.remove_status("double_damage", player)
		main.show_notification("DOUBLE DAMAGE ACTIVE!", Color(0.2, 0.8, 1.0))

	if effects.is_empty():
		push_error("CombatEngine: card '%s' has no effects. Card JSON must define an `effects` array." % card.card_info.get("name", "<unknown>"))
		assert(false, "CombatEngine: card '%s' has no effects." % card.card_info.get("name", "<unknown>"))
		return

	if type == "attack" and target and is_instance_valid(target):
		await _animate_player_gunshot(player, target)

	for effect in effects:
		await _apply_effect(effect, target, player, card_mult)


func _apply_effect(effect: Dictionary, target: Node, player: Node, card_mult: float = 1.0) -> void:
	var effect_type: String = effect.get("type", "")
	var amount: int = int(effect.get("amount", 0))
	var scaling: String = effect.get("scaling", "")
	var multiplier: float = float(effect.get("multiplier", 1))

	if scaling != "" and scaling in player:
		amount += int(player.get(scaling))

	if multiplier != 1:
		amount = int(amount * multiplier)

	var is_damage = effect_type == "deal_damage" or effect_type == "deal_damage_all"
	if is_damage and card_mult != 1.0:
		amount = int(amount * card_mult)

	if effect_type in ATTRIBUTE_COLORS:
		var attr = effect_type.trim_prefix("gain_")
		player.set(attr, int(player.get(attr)) + amount)
		if player.has_method("notify_stats_changed"):
			player.notify_stats_changed()
		main.show_notification("%s +%d" % [attr.to_upper(), amount], ATTRIBUTE_COLORS[effect_type])
		await get_tree().create_timer(0.2).timeout
		return

	match effect_type:
		"deal_damage":
			if target and is_instance_valid(target) and target.has_method("take_damage"):
				if main.equipment_set_system and main.current_resolving_card:
					amount = main.equipment_set_system.modify_card_damage(main.current_resolving_card, amount)
				var outgoing = calculate_attack_damage(amount, player, target)
				target.take_damage(outgoing)
				_register_player_attack()
				main.show_notification("DEALT %d DAMAGE" % outgoing, Color(1.0, 0.4, 0.3))
				if main.equipment_set_system and main.current_resolving_card:
					main.equipment_set_system.on_card_damage_resolved(main.current_resolving_card, target)
			else:
				main.show_notification("NO TARGET!", Color(1, 0.5, 0.5))

		"gain_block":
			if main.equipment_set_system and main.current_resolving_card:
				amount = main.equipment_set_system.modify_card_block(main.current_resolving_card, amount)
			player.add_block(amount)
			main.show_notification("+%d BLOCK" % amount, Color(0.4, 0.6, 1.0))
			await get_tree().create_timer(0.2).timeout

		"gain_energy":
			player.pay_energy(-amount)
			main.show_notification("+%d ENERGY" % amount, Color(0.9, 0.9, 0.3))
			await get_tree().create_timer(0.1).timeout

		"draw_cards":
			main.deck_manager.draw_cards(amount)
			main.show_notification("DRAW %d" % amount, Color(0.7, 1.0, 0.7))
			await get_tree().create_timer(0.2).timeout

		"deal_damage_all":
			var per_target_amount = amount
			if main.equipment_set_system and main.current_resolving_card:
				per_target_amount = main.equipment_set_system.modify_card_damage(main.current_resolving_card, per_target_amount)
			for enemy in main.enemy_container.get_children():
				if is_instance_valid(enemy) and enemy.has_method("take_damage"):
					enemy.take_damage(calculate_attack_damage(per_target_amount, player, enemy))
					if main.equipment_set_system and main.current_resolving_card:
						main.equipment_set_system.on_card_damage_resolved(main.current_resolving_card, enemy)
			_register_player_attack()
			main.show_notification("ALL ENEMIES HIT", Color(1.0, 0.3, 0.2))
			await get_tree().create_timer(0.3).timeout

		"scale_damage_by_attacks":
			# Damage scales with attacks the player has already played this turn.
			# JSON: {"type":"scale_damage_by_attacks", "base":2, "per":2}
			var base_dmg: int = int(effect.get("base", 0))
			var per: int = int(effect.get("per", 0))
			var count: int = 0
			if main and main.turn_manager:
				count = int(main.turn_manager.attacks_played_this_turn)
			var dynamic = base_dmg + per * count
			if target and is_instance_valid(target) and target.has_method("take_damage"):
				var outgoing = calculate_attack_damage(dynamic, player, target)
				target.take_damage(outgoing)
				_register_player_attack()
				main.show_notification("DEALT %d DAMAGE" % outgoing, Color(1.0, 0.4, 0.3))
			else:
				main.show_notification("NO TARGET!", Color(1, 0.5, 0.5))
			await get_tree().create_timer(0.2).timeout

		"apply_shock":
			var s_stacks: int = int(effect.get("stacks", int(effect.get("amount", 1))))
			if target and is_instance_valid(target) and target.has_method("add_status"):
				target.add_status("shock", s_stacks)
				main.show_notification("SHOCK x%d" % s_stacks, Color(0.95, 0.95, 0.3))
			else:
				main.show_notification("NO TARGET!", Color(1, 0.5, 0.5))
			await get_tree().create_timer(0.2).timeout

		"apply_shock_all":
			var s_stacks_all: int = int(effect.get("stacks", int(effect.get("amount", 1))))
			for enemy in main.enemy_container.get_children():
				if is_instance_valid(enemy) and enemy.has_method("add_status"):
					enemy.add_status("shock", s_stacks_all)
			main.show_notification("ALL: SHOCK x%d" % s_stacks_all, Color(0.95, 0.95, 0.3))
			await get_tree().create_timer(0.2).timeout

		"exhaust_self":
			# Marker effect. The card is routed to exhaust (queue_free)
			# by battle_scene.gd after card resolution.
			pass

		"apply_status":
			var status: String = effect.get("status", "")
			var stacks: int = int(effect.get("stacks", 1))
			if target and is_instance_valid(target) and target.has_method("add_status"):
				target.add_status(status, stacks)
				main.show_notification("APPLIED %s x%d" % [STATUS_SYS.format_name(status).to_upper(), stacks], Color(0.6, 0.9, 0.3))
			else:
				main.show_notification("NO TARGET!", Color(1, 0.5, 0.5))
			await get_tree().create_timer(0.2).timeout

		"apply_status_self":
			var status: String = effect.get("status", "")
			var stacks: int = int(effect.get("stacks", 1))
			if player.has_method("add_status"):
				player.add_status(status, stacks)
				main.show_notification("APPLIED %s x%d" % [STATUS_SYS.format_name(status).to_upper(), stacks], Color(0.6, 0.9, 0.3))
			await get_tree().create_timer(0.2).timeout

		"apply_status_all":
			var status: String = effect.get("status", "")
			var stacks: int = int(effect.get("stacks", 1))
			for enemy in main.enemy_container.get_children():
				if is_instance_valid(enemy) and enemy.has_method("add_status"):
					enemy.add_status(status, stacks)
			main.show_notification("ALL: %s x%d" % [STATUS_SYS.format_name(status).to_upper(), stacks], Color(0.6, 0.9, 0.3))
			await get_tree().create_timer(0.2).timeout

		_:
			push_error("CombatEngine: unknown effect type '%s'. Add a handler in combat_engine._apply_effect() and update DataValidator.ALLOWED_EFFECT_TYPES." % effect_type)
			assert(false, "CombatEngine: unknown effect type '%s'" % effect_type)


func _animate_player_gunshot(player: Node, target: Node) -> void:
	if player and player.has_method("play_attack"):
		player.play_attack()

	var origin := _get_player_muzzle_position(player)
	var hit := _get_target_hit_position(target)
	var shot_vector := hit - origin
	var direction := Vector2.RIGHT
	if shot_vector.length_squared() > 0.001:
		direction = shot_vector.normalized()

	var muzzle = _make_fx_sprite(MUZZLE_FLASH_TEX, origin, Vector2(0.62, 0.62))
	muzzle.rotation = direction.angle()
	var bullet = _make_fx_sprite(BULLET_TEX, origin + direction * 18.0, Vector2(0.42, 0.42))
	bullet.rotation = direction.angle()

	await get_tree().create_timer(0.05).timeout
	if is_instance_valid(muzzle):
		muzzle.queue_free()

	var flight = create_tween().set_parallel(true)
	flight.tween_property(bullet, "global_position", hit, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flight.tween_property(bullet, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await flight.finished
	if is_instance_valid(bullet):
		bullet.queue_free()

	var impact = _make_fx_sprite(IMPACT_TEX, hit, Vector2(0.55, 0.55))
	var burst = create_tween().set_parallel(true)
	burst.tween_property(impact, "scale", Vector2(0.78, 0.78), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	burst.tween_property(impact, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await burst.finished
	if is_instance_valid(impact):
		impact.queue_free()


func _get_player_muzzle_position(player: Node) -> Vector2:
	if player and player.has_method("get_muzzle_global_position"):
		return player.get_muzzle_global_position()
	if player:
		return player.global_position + Vector2(98, -104)
	return Vector2.ZERO


func _get_target_hit_position(target: Node) -> Vector2:
	if target and target.has_method("get_hit_global_position"):
		return target.get_hit_global_position()
	if target:
		return target.global_position + Vector2(-60, -100)
	return Vector2.ZERO


## Increment the per-turn attack counter used by combo cards like Cascade.
func _register_player_attack() -> void:
	if main and main.turn_manager:
		main.turn_manager.attacks_played_this_turn += 1


func _make_fx_sprite(texture: Texture2D, pos: Vector2, sprite_scale: Vector2) -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.global_position = pos
	sprite.scale = sprite_scale
	sprite.z_index = 80
	main.add_child(sprite)
	return sprite

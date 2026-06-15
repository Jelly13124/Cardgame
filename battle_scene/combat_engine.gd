extends Node
## Data-driven card effect resolver. Card behavior comes from each card JSON
## "effects" array; add new effect types in _apply_effect().

# Preloaded so we don't depend on Godot's class_name registry being warm at parse time.
const STATUS_SYS = preload("res://battle_scene/status_effect_system.gd")

signal victory_declared

const ATTRIBUTE_COLORS = {
	"gain_strength": Color(1.0, 0.5, 0.2),
	"gain_constitution": Color(0.4, 0.7, 1.0),
	"gain_intelligence": Color(0.8, 0.4, 1.0),
	"gain_luck": Color(1.0, 0.9, 0.2),
	"gain_charm": Color(1.0, 0.5, 0.8),
}

const MUZZLE_FLASH_TEX = preload("res://battle_scene/assets/images/fx/gunshot/muzzle_flash.png")
const BULLET_TEX = preload("res://battle_scene/assets/images/fx/gunshot/bullet.png")
const IMPACT_TEX = preload("res://battle_scene/assets/images/fx/gunshot/impact.png")
const PLAYER_GUNSHOT_WINDUP_SECONDS := 0.22

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


## Dodge: if `target` has a Dodge stack, consume one and negate the attack.
## Returns true when the attack was dodged (caller must skip the damage).
func _check_dodge(target: Node) -> bool:
	if not (target and is_instance_valid(target) and "status_system" in target):
		return false
	if target.status_system and target.status_system.try_consume_dodge(target):
		if main and main.has_method("show_notification"):
			main.show_notification(tr("UI_COMBAT_DODGE"), Color(0.6, 0.95, 1.0))
		return true
	return false


## Thorns: when `defender` is hit, the `attacker` takes Thorns-stack damage.
func apply_thorns_reflection(attacker: Node, defender: Node) -> void:
	if not (defender and is_instance_valid(defender) and defender.has_method("get_status_stacks")):
		return
	var thorns: int = defender.get_status_stacks("thorns")
	if (
		thorns > 0
		and attacker
		and is_instance_valid(attacker)
		and attacker.has_method("take_damage")
	):
		attacker.take_damage(thorns)


func resolve_card_effect(card: Control, target: Node, player: Node) -> void:
	var effects: Array = card.card_info.get("effects", [])
	var type = card.card_info.get("type", "skill").to_lower()

	var card_mult: float = 1.0
	if (
		type == "attack"
		and player.has_method("get_status_stacks")
		and player.get_status_stacks("double_damage") > 0
	):
		card_mult = 2.0
		player.status_system.remove_status("double_damage", player)
		main.show_notification(tr("UI_COMBAT_DOUBLE_DAMAGE_ACTIVE"), Color(0.2, 0.8, 1.0))

	if effects.is_empty():
		push_error(
			(
				"CombatEngine: card '%s' has no effects. Card JSON must define an `effects` array."
				% card.card_info.get("name", "<unknown>")
			)
		)
		assert(
			false,
			"CombatEngine: card '%s' has no effects." % card.card_info.get("name", "<unknown>")
		)
		return

	# Replay N (重放): the WHOLE card resolves 1 + N times — animation, effects,
	# matched bonus, on-attack relics, and gems all re-trigger (Echo / Double-Tap
	# style). N = the card's innate `replay` plus any relic grant (double-fire clip
	# gives attack cards Replay 1). The attack-allowance is charged once per PLAY
	# (in the play path), not per replay.
	var replays: int = _replay_count(card, type)
	for _i in range(1 + replays):
		await _resolve_card_once(card, effects, type, target, player, card_mult)


## One full resolution pass of a played card: gunshot anim → effects → polarity
## matched bonus → on-attack relics → socketed gems. Called once normally, or
## 1 + N times when the card has Replay N.
func _resolve_card_once(
	card: Control, effects: Array, type: String, target: Node, player: Node, card_mult: float
) -> void:
	if type == "attack" and target and is_instance_valid(target):
		await _animate_player_gunshot(player, target)

	for effect in effects:
		# An earlier effect (or DOT) may have killed and freed the target mid-
		# resolution; never pass a freed Object into _apply_effect's typed
		# `target: Node` param. Re-validate each iteration (null == "no target").
		await _apply_effect(
			effect, target if is_instance_valid(target) else null, player, card_mult
		)

	# Polarity matched bonus — resolved after the normal effects (so any
	# flip_polarity earlier in this same card has already applied). Reuses every
	# existing effect handler, so bonuses get global STR/CON, dodge, thorns, etc.
	var polarity := str(card.card_info.get("polarity", "neutral"))
	if player and player.has_method("is_card_matched") and player.is_card_matched(polarity):
		var bonus = card.card_info.get("matched_bonus", [])
		if bonus is Array:
			for be in bonus:
				if typeof(be) == TYPE_DICTIONARY:
					await _apply_effect(
						be, target if is_instance_valid(target) else null, player, card_mult
					)

	# Relic: an attack card that landed on a target fires on-attack relics
	# (sharpened_scrap → Bleed on the struck enemy).
	if type == "attack" and target and is_instance_valid(target) and main.relic_effect_system:
		main.relic_effect_system.on_player_attack(target)
	# Socketed gems: each gem's effects resolve AFTER the card's own effects (and
	# matched bonus), reusing _apply_effect so they get the same target / global
	# STR-CON / dodge / thorns handling. ≤1 gem per card; locked once socketed.
	var gems: Array = card.get_meta("gems") if card.has_meta("gems") else []
	for gem_id in gems:
		var gdata: Dictionary = RunManager.get_gem_data(str(gem_id))
		for ge in gdata.get("effects", []):
			if typeof(ge) == TYPE_DICTIONARY:
				await _apply_effect(
					ge, target if is_instance_valid(target) else null, player, card_mult
				)


## Total extra resolutions for a played card: its innate `replay` field plus any
## relic-granted replay (double-fire clip → +1 for attack cards).
func _replay_count(card: Control, type: String) -> int:
	var n: int = int(card.card_info.get("replay", 0))
	if type == "attack" and main.relic_effect_system:
		n += main.relic_effect_system.attack_replay_bonus()
	return n


func _apply_effect(effect: Dictionary, target: Node, player: Node, card_mult: float = 1.0) -> void:
	var effect_type: String = effect.get("type", "")
	var amount: int = int(effect.get("amount", 0))
	var multiplier: float = float(effect.get("multiplier", 1))

	if multiplier != 1:
		amount = int(amount * multiplier)

	# Global attributes: STR auto-adds to all attack damage, CON to all block.
	# Card JSON carries the BASE number only — the old per-card `scaling` field is
	# gone. `scale_damage_by_attacks` (cascade) and `deal_damage_str_mult`
	# (charged_shot) compute their own damage and must NOT receive the global +STR.
	if player:
		if effect_type == "deal_damage" or effect_type == "deal_damage_all":
			amount += int(player.get("strength"))
		elif effect_type == "gain_block":
			amount += int(player.get("constitution"))

	var is_damage = effect_type == "deal_damage" or effect_type == "deal_damage_all"
	if is_damage and card_mult != 1.0:
		amount = int(amount * card_mult)

	if effect_type in ATTRIBUTE_COLORS:
		var attr = effect_type.trim_prefix("gain_")
		player.set(attr, int(player.get(attr)) + amount)
		if player.has_method("notify_stats_changed"):
			player.notify_stats_changed()
		main.show_notification(
			tr("UI_COMBAT_ATTR_GAIN").format(
				{"attr": tr("UI_COMBAT_ATTR_%s" % attr.to_upper()), "n": amount}
			),
			ATTRIBUTE_COLORS[effect_type]
		)
		await get_tree().create_timer(0.2).timeout
		return

	match effect_type:
		"deal_damage":
			if target and is_instance_valid(target) and target.has_method("take_damage"):
				if _check_dodge(target):
					pass  # attack negated by Dodge
				else:
					if main.equipment_set_system and main.current_resolving_card:
						amount = main.equipment_set_system.modify_card_damage(
							main.current_resolving_card, amount
						)
					var outgoing = calculate_attack_damage(amount, player, target)
					target.take_damage(outgoing)
					_register_player_attack()
					main.show_notification(
						tr("UI_COMBAT_DEALT_DAMAGE").format({"n": outgoing}), Color(1.0, 0.4, 0.3)
					)
					if main.equipment_set_system and main.current_resolving_card:
						main.equipment_set_system.on_card_damage_resolved(
							main.current_resolving_card, target
						)
					apply_thorns_reflection(player, target)
			else:
				main.show_notification(tr("UI_COMBAT_NO_TARGET"), Color(1, 0.5, 0.5))

		"gain_block":
			if main.equipment_set_system and main.current_resolving_card:
				amount = main.equipment_set_system.modify_card_block(
					main.current_resolving_card, amount
				)
			if player and "status_system" in player and player.status_system:
				amount = int(amount * player.status_system.get_block_multiplier())
			# Relic on-gain-block trigger: may crit-multiply the block (crit_plating)
			# and/or chip a random enemy (scavenger_lens). Use the returned amount.
			if main.relic_effect_system:
				amount = main.relic_effect_system.on_player_gain_block(player, amount)
			player.add_block(amount)
			if player.has_method("play_block_pulse"):
				player.play_block_pulse()  # grow-and-shrink, like the enemy's block
			main.show_notification(
				tr("UI_COMBAT_GAIN_BLOCK").format({"n": amount}), Color(0.4, 0.6, 1.0)
			)
			await get_tree().create_timer(0.2).timeout

		"gain_energy":
			player.pay_energy(-amount)
			main.show_notification(
				tr("UI_COMBAT_GAIN_ENERGY").format({"n": amount}), Color(0.9, 0.9, 0.3)
			)
			await get_tree().create_timer(0.1).timeout

		"draw_cards":
			main.deck_manager.draw_cards(amount)
			main.show_notification(tr("UI_COMBAT_DRAW").format({"n": amount}), Color(0.7, 1.0, 0.7))
			await get_tree().create_timer(0.2).timeout

		"deal_damage_all":
			var per_target_amount = amount
			if main.equipment_set_system and main.current_resolving_card:
				per_target_amount = main.equipment_set_system.modify_card_damage(
					main.current_resolving_card, per_target_amount
				)
			for enemy in main.enemy_container.get_children():
				if is_instance_valid(enemy) and enemy.has_method("take_damage"):
					if _check_dodge(enemy):
						continue  # this enemy dodged
					enemy.take_damage(calculate_attack_damage(per_target_amount, player, enemy))
					if main.equipment_set_system and main.current_resolving_card:
						main.equipment_set_system.on_card_damage_resolved(
							main.current_resolving_card, enemy
						)
					apply_thorns_reflection(player, enemy)
			_register_player_attack()
			main.show_notification(tr("UI_COMBAT_ALL_ENEMIES_HIT"), Color(1.0, 0.3, 0.2))
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
				if _check_dodge(target):
					pass  # attack negated by Dodge
				else:
					var outgoing = calculate_attack_damage(dynamic, player, target)
					target.take_damage(outgoing)
					_register_player_attack()
					main.show_notification(
						tr("UI_COMBAT_DEALT_DAMAGE").format({"n": outgoing}), Color(1.0, 0.4, 0.3)
					)
					apply_thorns_reflection(player, target)
			else:
				main.show_notification(tr("UI_COMBAT_NO_TARGET"), Color(1, 0.5, 0.5))
			await get_tree().create_timer(0.2).timeout

		"deal_damage_str_mult":
			# Damage scales purely off the player's STR (charged_shot: mult 2).
			# Does NOT receive the global +STR — it already scales off STR.
			# JSON: {"type":"deal_damage_str_mult", "mult":2}
			var mult: float = float(effect.get("mult", 1))
			var str_dmg: int = int(player.get("strength") * mult) if player else 0
			if target and is_instance_valid(target) and target.has_method("take_damage"):
				if _check_dodge(target):
					pass  # attack negated by Dodge
				else:
					if main.equipment_set_system and main.current_resolving_card:
						str_dmg = main.equipment_set_system.modify_card_damage(
							main.current_resolving_card, str_dmg
						)
					if card_mult != 1.0:
						str_dmg = int(str_dmg * card_mult)
					var outgoing = calculate_attack_damage(str_dmg, player, target)
					target.take_damage(outgoing)
					_register_player_attack()
					main.show_notification(
						tr("UI_COMBAT_DEALT_DAMAGE").format({"n": outgoing}), Color(1.0, 0.4, 0.3)
					)
					if main.equipment_set_system and main.current_resolving_card:
						main.equipment_set_system.on_card_damage_resolved(
							main.current_resolving_card, target
						)
					apply_thorns_reflection(player, target)
			else:
				main.show_notification(tr("UI_COMBAT_NO_TARGET"), Color(1, 0.5, 0.5))
			await get_tree().create_timer(0.2).timeout

		"apply_stun":
			var s_stacks: int = int(effect.get("stacks", int(effect.get("amount", 1))))
			if target and is_instance_valid(target) and target.has_method("add_status"):
				target.add_status("stun", s_stacks)
				main.show_notification(
					tr("UI_COMBAT_STUN_X").format({"n": s_stacks}), Color(0.95, 0.95, 0.3)
				)
			else:
				main.show_notification(tr("UI_COMBAT_NO_TARGET"), Color(1, 0.5, 0.5))
			await get_tree().create_timer(0.2).timeout

		"apply_stun_all":
			var s_stacks_all: int = int(effect.get("stacks", int(effect.get("amount", 1))))
			for enemy in main.enemy_container.get_children():
				if is_instance_valid(enemy) and enemy.has_method("add_status"):
					enemy.add_status("stun", s_stacks_all)
			main.show_notification(
				tr("UI_COMBAT_ALL_STUN_X").format({"n": s_stacks_all}), Color(0.95, 0.95, 0.3)
			)
			await get_tree().create_timer(0.2).timeout

		"flip_polarity":
			if player and player.has_method("flip_polarity"):
				var was_harmony := bool(player.harmony_active)
				player.flip_polarity()
				if player.harmony_active and not was_harmony:
					# Yin-Yang Harmony entry reward — granted once.
					player.pay_energy(-1)
					main.deck_manager.draw_cards(1)
					main.show_notification(tr("UI_COMBAT_HARMONY"), Color(1, 0.85, 0.3))
				if main.has_method("update_polarity_hud"):
					main.update_polarity_hud()
				await get_tree().create_timer(0.1).timeout

		"exhaust_self":
			# Marker effect. The card is routed to exhaust (queue_free)
			# by battle_scene.gd after card resolution.
			pass

		"apply_status":
			var status: String = effect.get("status", "")
			var stacks: int = int(effect.get("stacks", 1))
			# brutal_servo: every Bleed the player applies gets bonus stacks.
			if status == "bleed" and main.relic_effect_system:
				stacks += main.relic_effect_system.bleed_bonus_stacks()
			if target and is_instance_valid(target) and target.has_method("add_status"):
				target.add_status(status, stacks)
				main.show_notification(
					tr("UI_COMBAT_APPLIED_STATUS").format(
						{"status": STATUS_SYS.format_name_localized(status), "n": stacks}
					),
					Color(0.6, 0.9, 0.3)
				)
			else:
				main.show_notification(tr("UI_COMBAT_NO_TARGET"), Color(1, 0.5, 0.5))
			await get_tree().create_timer(0.2).timeout

		"apply_status_self":
			var status: String = effect.get("status", "")
			var stacks: int = int(effect.get("stacks", 1))
			if player.has_method("add_status"):
				player.add_status(status, stacks)
				main.show_notification(
					tr("UI_COMBAT_APPLIED_STATUS").format(
						{"status": STATUS_SYS.format_name_localized(status), "n": stacks}
					),
					Color(0.6, 0.9, 0.3)
				)
			await get_tree().create_timer(0.2).timeout

		"apply_status_all":
			var status: String = effect.get("status", "")
			var stacks: int = int(effect.get("stacks", 1))
			# brutal_servo: every Bleed the player applies gets bonus stacks.
			if status == "bleed" and main.relic_effect_system:
				stacks += main.relic_effect_system.bleed_bonus_stacks()
			for enemy in main.enemy_container.get_children():
				if is_instance_valid(enemy) and enemy.has_method("add_status"):
					enemy.add_status(status, stacks)
			main.show_notification(
				tr("UI_COMBAT_ALL_STATUS").format(
					{"status": STATUS_SYS.format_name_localized(status), "n": stacks}
				),
				Color(0.6, 0.9, 0.3)
			)
			await get_tree().create_timer(0.2).timeout

		"lose_hp":
			# Self HP cost (blood mechanic) — bypasses Block, can't be dodged.
			if player and player.has_method("lose_hp"):
				player.lose_hp(amount)
				main.show_notification(
					tr("UI_COMBAT_LOSE_HP").format({"n": amount}), Color(0.85, 0.3, 0.3)
				)
			await get_tree().create_timer(0.15).timeout

		"double_strength":
			# Limit Break — double current Strength (attribute payoff).
			if player:
				var cur_str := int(player.get("strength"))
				player.set("strength", cur_str * 2)
				if player.has_method("notify_stats_changed"):
					player.notify_stats_changed()
				main.show_notification(
					tr("UI_COMBAT_DOUBLE_STRENGTH"), ATTRIBUTE_COLORS["gain_strength"]
				)
			await get_tree().create_timer(0.2).timeout

		"deal_damage_block_mult":
			# Body Slam — deal damage equal to current Block × mult. Scales off the
			# CON-driven block pool, so it does NOT receive the global +STR.
			var bmult: float = float(effect.get("mult", 1))
			var block_dmg: int = int(player.get("block") * bmult) if player else 0
			if target and is_instance_valid(target) and target.has_method("take_damage"):
				if _check_dodge(target):
					pass  # attack negated by Dodge
				else:
					if main.equipment_set_system and main.current_resolving_card:
						block_dmg = main.equipment_set_system.modify_card_damage(
							main.current_resolving_card, block_dmg
						)
					if card_mult != 1.0:
						block_dmg = int(block_dmg * card_mult)
					var outgoing = calculate_attack_damage(block_dmg, player, target)
					target.take_damage(outgoing)
					_register_player_attack()
					main.show_notification(
						tr("UI_COMBAT_DEALT_DAMAGE").format({"n": outgoing}), Color(1.0, 0.4, 0.3)
					)
					apply_thorns_reflection(player, target)
			else:
				main.show_notification(tr("UI_COMBAT_NO_TARGET"), Color(1, 0.5, 0.5))
			await get_tree().create_timer(0.2).timeout

		"gain_gold":
			# Card/gem gold (wealthy gem). `max_per_combat` caps triggers (battle_scene).
			if main and main.has_method("try_gain_gold"):
				main.try_gain_gold(amount, int(effect.get("max_per_combat", 0)))
			await get_tree().create_timer(0.1).timeout

		"heal":
			# Card/gem self-heal (leech gem).
			if player and player.has_method("heal"):
				player.heal(amount)
				main.show_notification(
					tr("UI_COMBAT_HEAL").format({"n": amount}), Color(0.3, 1.0, 0.45)
				)
			await get_tree().create_timer(0.15).timeout

		_:
			push_error(
				(
					"CombatEngine: unknown effect type '%s'. Add a handler in combat_engine._apply_effect() and update DataValidator.ALLOWED_EFFECT_TYPES."
					% effect_type
				)
			)
			assert(false, "CombatEngine: unknown effect type '%s'" % effect_type)


func _animate_player_gunshot(player: Node, target: Node) -> void:
	if player and player.has_method("play_attack"):
		player.play_attack()

	await get_tree().create_timer(PLAYER_GUNSHOT_WINDUP_SECONDS).timeout

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
	(
		flight
		. tween_property(bullet, "global_position", hit, 0.16)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	flight.tween_property(bullet, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	await flight.finished
	if is_instance_valid(bullet):
		bullet.queue_free()

	var impact = _make_fx_sprite(IMPACT_TEX, hit, Vector2(0.55, 0.55))
	var burst = create_tween().set_parallel(true)
	(
		burst
		. tween_property(impact, "scale", Vector2(0.78, 0.78), 0.08)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	burst.tween_property(impact, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
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

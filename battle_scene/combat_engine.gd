extends Node
## Card-play orchestration: gunshot animation, Replay passes, the polarity
## matched bonus and after-attack reactions. Every effect runs through the
## shared effect registry (battle_scene/combat/combat_effects.gd) and every
## value through the combat pipeline (core/combat); this node owns no rules.

const COMBAT_SOURCE = preload("uid://jgs131055xrk")  # res://core/combat/combat_source.gd
const CARD_PLAY = preload("uid://bxaw24a7fumhm")  # res://core/combat/card_play.gd
const EFFECT_CONTEXT = preload("uid://bx2g3askncfr6")  # res://core/effects/effect_context.gd

signal victory_declared

const MUZZLE_FLASH_TEX = preload("res://battle_scene/assets/images/fx/gunshot/muzzle_flash.png")
const BULLET_TEX = preload("res://battle_scene/assets/images/fx/gunshot/bullet.png")
const PLAYER_GUNSHOT_WINDUP_SECONDS := 0.22

@onready var main = get_parent()


func declare_victory() -> void:
	victory_declared.emit()


## Reset the per-turn guaranteed-first-attack Crit (Deadeye Crit Clip).
func reset_turn_crit() -> void:
	if main.crit_rules:
		main.crit_rules.reset_turn()


## Run one effect for `source` (card, tool, relic, set or curse) through the
## shared effect registry. `target` may be null; a freed target counts as none.
func execute_effect(effect: Dictionary, target, source, play = null) -> void:
	var actor: Object = source.dealer if source and source.dealer else main.player
	var ctx = EFFECT_CONTEXT.make("combat", source, actor, _live_target(target), main, play)
	await main.effect_registry.execute(ctx, effect)


## Resolve a played card: 1 + Replay passes, each running the card's effects,
## its polarity matched bonus and the after-attack reaction. An Attack card
## counts once toward "attacks played", however many passes or hits it has.
func resolve_card_effect(card: Control, target: Node, player: Node) -> void:
	var effects: Array = card.card_info.get("effects", [])
	var type = card.card_info.get("type", "skill").to_lower()
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

	var play = CARD_PLAY.new()
	play.card = card
	play.target = target
	play.dealer = player
	var source = COMBAT_SOURCE.make("card", "player", player, card)
	for _i in range(1 + _replay_count(card, type)):
		# The target can die between passes; null = "no target" (the hit fizzles).
		await _resolve_card_once(card, effects, type, _live_target(target), source, play)
	if type == "attack" and main.turn_manager:
		main.turn_manager.attacks_played_this_turn += 1
		main.turn_manager.attacks_played_this_combat += 1


## A target Node counts as "live" only if it exists AND isn't already queued for
## deletion. queue_free() defers the real free to frame-end, so is_instance_valid()
## still returns true that same frame — a dying target would pass a naive guard and
## then be freed by a later await. Returns null for a null / freed / dying target so
## callers treat null as "no target" uniformly. The param is untyped on purpose
## (must accept a freed Object).
func _live_target(t) -> Node:
	return t if (is_instance_valid(t) and not t.is_queued_for_deletion()) else null


## One resolution pass: gunshot → effects → polarity matched bonus → after-attack.
func _resolve_card_once(
	card: Control, effects: Array, type: String, target: Node, source, play
) -> void:
	var player: Node = source.dealer
	if type == "attack" and _live_target(target):
		await _animate_player_gunshot(player, target)

	for effect in effects:
		await execute_effect(effect, target, source, play)

	# Polarity matched bonus — after the normal effects so a flip_polarity earlier
	# in this card has already applied. Bonuses use the same handlers and hit chain.
	var polarity := str(card.card_info.get("polarity", "neutral"))
	if player and player.has_method("is_card_matched") and player.is_card_matched(polarity):
		var bonus = card.card_info.get("matched_bonus", [])
		if bonus is Array:
			for be in bonus:
				if typeof(be) == TYPE_DICTIONARY:
					await execute_effect(be, target, source, play)

	if type == "attack" and _live_target(target):
		await main.combat_hooks.after_attack({"source": source, "dealer": player, "target": target})


## Total extra resolutions for a played card: its innate `replay` field plus any
## relic-granted replay (double-fire clip → +1 for attack cards).
func _replay_count(card: Control, type: String) -> int:
	var n: int = int(card.card_info.get("replay", 0))
	if type == "attack" and main.relic_effect_system:
		n += main.relic_effect_system.attack_replay_bonus()
	return n


## Enemy attacks still resolve here until they move to the shared pipeline:
## Weak on the enemy and Vulnerable on the defender.
func calculate_attack_damage(base_damage: int, attacker: Node, defender: Node) -> int:
	var outgoing_mult := 1.0
	var incoming_mult := 1.0
	if attacker and attacker.has_method("get_outgoing_multiplier"):
		outgoing_mult = attacker.get_outgoing_multiplier()
	if defender and defender.has_method("get_incoming_attack_multiplier"):
		incoming_mult = defender.get_incoming_attack_multiplier()
	return int(base_damage * outgoing_mult * incoming_mult)


## Thorns on the player reflecting an enemy hit (enemy path only, see above).
func apply_thorns_reflection(attacker: Node, defender: Node) -> void:
	if not (defender and is_instance_valid(defender) and defender.has_method("get_status_stacks")):
		return
	var thorns: int = defender.get_status_stacks("thorns")
	if thorns > 0 and attacker and is_instance_valid(attacker) and attacker.has_method("take_damage"):
		attacker.take_damage(thorns, false, {"source": "thorns", "heavy": false, "critical": false})
		if (
			defender == main.player
			and main.relic_effect_system
			and main.relic_effect_system.thorns_apply_short_circuit()
			and attacker.has_method("add_status")
		):
			attacker.add_status("short_circuit", thorns)
		var ss = defender.get("status_system")
		if ss:
			ss.spend_stacks("thorns", 1, defender)


func _animate_player_gunshot(player: Node, target: Node) -> void:
	if player and player.has_method("play_attack"):
		player.play_attack()

	await get_tree().create_timer(PLAYER_GUNSHOT_WINDUP_SECONDS).timeout

	# The target can die (queue_free) during the wind-up await; bail before we deref it
	# for the hit position. _get_target_hit_position takes a typed `target: Node` that
	# would hard-error on a freed Object (and there's nothing left to shoot at anyway).
	if _live_target(target) == null:
		return

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

	# Contact is handed off immediately to take_damage(). The shared feedback
	# controller owns the impact burst, hitstop, reaction, and damage number so
	# the projectile no longer waits through a second legacy impact animation.


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


func _make_fx_sprite(texture: Texture2D, pos: Vector2, sprite_scale: Vector2) -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.global_position = pos
	sprite.scale = sprite_scale
	sprite.z_index = 80
	main.add_child(sprite)
	return sprite

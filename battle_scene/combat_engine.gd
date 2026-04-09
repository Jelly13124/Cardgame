extends Node
## CombatEngine — Generic effect resolver.
## Card effects are fully data-driven via the "effects" array in each card's JSON.
## To add a new effect type, add a match branch in _apply_effect().
## No card-specific code lives here.

signal victory_declared()

@onready var main = get_parent()

# ─── Public API ───────────────────────────────────────────────────────────────

## Resolve all effects listed on a card.
## target: the enemy Node for dealing damage (null for non-targeted cards).
## player: the PlayerEntity.
func resolve_card_effect(card: Control, target: Node, player: Node) -> void:
	var effects: Array = card.card_info.get("effects", [])

	if effects.is_empty():
		# Fallback for cards that predate the effects system
		_legacy_fallback(card, target, player)
		return

	# Play card animation first, then resolve all effects in sequence
	var type = card.card_info.get("type", "skill").to_lower()
	if type == "attack" and target and is_instance_valid(target):
		await _animate_lunge(player, target.global_position + Vector2(-80, 0))

	for effect in effects:
		await _apply_effect(effect, target, player)

	if type == "attack" and target and is_instance_valid(target):
		await _animate_return(player)

# ─── Effect Dispatch ──────────────────────────────────────────────────────────

## Apply a single effect dictionary.
## All scaling uses the player's RPG attributes (strength, constitution, intelligence, luck, charm).
func _apply_effect(effect: Dictionary, target: Node, player: Node) -> void:
	var effect_type: String = effect.get("type", "")
	var amount: int          = int(effect.get("amount", 0))
	var scaling: String      = effect.get("scaling", "")
	var multiplier: float    = float(effect.get("multiplier", 1))

	# Base stat scaling: amount += player.<scaling>
	if scaling != "" and scaling in player:
		amount += int(player.get(scaling))

	# Optional multiplier applied AFTER scaling
	# e.g. { "amount": 0, "scaling": "intelligence", "multiplier": 2 } = 0 + INT, then ×2
	if multiplier != 1:
		amount = int(amount * multiplier)

	match effect_type:
		# ── Damage ───────────────────────────────────────────────────────────
		"deal_damage":
			if target and is_instance_valid(target) and target.has_method("take_damage"):
				# Apply weakness debuff: weakened attacker deals 0.75× damage
				var outgoing = amount
				if player.has_method("get_status_stacks") and player.get_status_stacks("weakness") > 0:
					outgoing = int(outgoing * player.status_system.get_outgoing_multiplier())
				if player.has_method("play_attack"):
					player.play_attack()
				target.take_damage(outgoing)
				main.show_notification("DEALT %d DAMAGE" % outgoing, Color(1.0, 0.4, 0.3))
			else:
				main.show_notification("NO TARGET!", Color(1, 0.5, 0.5))

		# ── Player Defence ────────────────────────────────────────────────────
		"gain_block":
			if player.has_method("play_block"):
				player.play_block()
			player.add_block(amount)
			main.show_notification("+%d BLOCK" % amount, Color(0.4, 0.6, 1.0))
			await get_tree().create_timer(0.2).timeout

		# ── Stat Buffs ────────────────────────────────────────────────────────
		"gain_strength":
			player.strength += amount
			main.show_notification("STRENGTH +%d" % amount, Color(1.0, 0.5, 0.2))
			await get_tree().create_timer(0.2).timeout

		"gain_constitution":
			player.constitution += amount
			main.show_notification("CONSTITUTION +%d" % amount, Color(0.4, 0.7, 1.0))
			await get_tree().create_timer(0.2).timeout

		"gain_intelligence":
			player.intelligence += amount
			main.show_notification("INTELLIGENCE +%d" % amount, Color(0.8, 0.4, 1.0))
			await get_tree().create_timer(0.2).timeout

		"gain_luck":
			player.luck += amount
			main.show_notification("LUCK +%d" % amount, Color(1.0, 0.9, 0.2))
			await get_tree().create_timer(0.2).timeout

		"gain_energy":
			player.pay_energy(-amount)  # negative cost = gain
			main.show_notification("+%d ENERGY" % amount, Color(0.9, 0.9, 0.3))
			await get_tree().create_timer(0.1).timeout

		"draw_cards":
			main.deck_manager.draw_cards(amount)
			main.show_notification("DRAW %d" % amount, Color(0.7, 1.0, 0.7))
			await get_tree().create_timer(0.2).timeout

		"deal_damage_all":
			# Hit every enemy in the container
			for enemy in main.enemy_container.get_children():
				if is_instance_valid(enemy) and enemy.has_method("take_damage"):
					enemy.take_damage(amount)
			main.show_notification("ALL ENEMIES: -%d" % amount, Color(1.0, 0.3, 0.2))
			await get_tree().create_timer(0.3).timeout

		# ── Status Effects ────────────────────────────────────────────────────
		## Apply a status to the targeted enemy.
		## e.g. { "type": "apply_status", "status": "poison", "stacks": 3 }
		"apply_status":
			var status: String = effect.get("status", "")
			var stacks: int    = int(effect.get("stacks", 1))
			if target and is_instance_valid(target) and target.has_method("add_status"):
				target.add_status(status, stacks)
				main.show_notification("APPLIED %s ×%d" % [status.to_upper(), stacks], Color(0.6, 0.9, 0.3))
			else:
				main.show_notification("NO TARGET!", Color(1, 0.5, 0.5))
			await get_tree().create_timer(0.2).timeout

		## Apply a status to the player.
		## e.g. { "type": "apply_status_self", "status": "strength_up", "stacks": 2 }
		"apply_status_self":
			var status: String = effect.get("status", "")
			var stacks: int    = int(effect.get("stacks", 1))
			if player.has_method("add_status"):
				player.add_status(status, stacks)
				main.show_notification("APPLIED %s ×%d" % [status.to_upper(), stacks], Color(0.6, 0.9, 0.3))
			await get_tree().create_timer(0.2).timeout

		## Apply a status to ALL enemies at once.
		"apply_status_all":
			var status: String = effect.get("status", "")
			var stacks: int    = int(effect.get("stacks", 1))
			for enemy in main.enemy_container.get_children():
				if is_instance_valid(enemy) and enemy.has_method("add_status"):
					enemy.add_status(status, stacks)
			main.show_notification("ALL: %s ×%d" % [status.to_upper(), stacks], Color(0.6, 0.9, 0.3))
			await get_tree().create_timer(0.2).timeout

		_:
			push_warning("CombatEngine: unknown effect type '%s'" % effect_type)

# ─── Animations ───────────────────────────────────────────────────────────────

var _player_start_pos: Vector2

func _animate_lunge(player: Node, toward: Vector2) -> void:
	_player_start_pos = player.global_position
	var t = create_tween()
	t.tween_property(player, "global_position", toward, 0.12).set_trans(Tween.TRANS_QUAD)
	await t.finished

func _animate_return(player: Node) -> void:
	var t = create_tween()
	t.tween_property(player, "global_position", _player_start_pos, 0.12)
	await t.finished

# ─── Victory ────────────────────────────────────────────────────────────────

func kill_unit(card: Node) -> void:
	if main.is_game_over: return
	card.queue_free()
	await get_tree().process_frame
	if main.enemy_container.get_child_count() == 0:
		emit_signal("victory_declared")

# ─── Legacy Fallback ─────────────────────────────────────────────────────────
## Handles cards without an "effects" array (backwards compatibility).

func _legacy_fallback(card: Control, target: Node, player: Node) -> void:
	var type = card.card_info.get("type", "skill").to_lower()
	match type:
		"attack":
			var dmg = int(card.card_info.get("damage", 0)) + player.strength
			if target and target.has_method("take_damage"):
				await _animate_lunge(player, target.global_position + Vector2(-80, 0))
				target.take_damage(dmg)
				main.show_notification("DEALT %d DAMAGE" % dmg, Color(1.0, 0.4, 0.3))
				await _animate_return(player)
		"skill":
			var blk = int(card.card_info.get("block", 0)) + player.constitution
			player.add_block(blk)
			main.show_notification("+%d BLOCK" % blk, Color(0.4, 0.6, 1.0))
			await get_tree().create_timer(0.2).timeout

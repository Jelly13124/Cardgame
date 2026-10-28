extends RefCounted

## The enemy turn (STS2 monster turn): each living enemy in field order starts
## its turn, runs the on_enter moves of a phase it entered, skips its move when
## stunned, then performs its next move through the effect registry ("enemy"
## context) and ends its turn. Pacing goes through the presenter.

const COMBAT_SOURCE = preload("uid://jgs131055xrk")  # res://core/combat/combat_source.gd
const EFFECT_CONTEXT = preload("uid://bx2g3askncfr6")  # res://core/effects/effect_context.gd
const INTENTS = preload("uid://crt5cmvargkpn")  # res://core/combat/intents.gd
const COMBAT_EFFECTS = preload("uid://do16of5onpg33")  # res://core/combat/combat_effects.gd

const ATTACK_LIKE := ["attack", "attack_ramp", "attack_status", "attack_all"]


static func run(combat: Object) -> void:
	if combat.is_game_over:
		return
	var presenter = combat.presenter
	combat.show_notification(_t("UI_COMBAT_ENEMY_TURN"), Color(1, 0.4, 0.4))
	await presenter.wait(0.8)
	for enemy in combat.state.living_enemies():
		if combat.is_game_over:
			return
		if not enemy.is_alive():
			continue
		enemy.start_turn()
		if combat.is_game_over:
			return
		if not enemy.is_alive():
			continue
		# A phase entered on the player's turn runs its on_enter moves now.
		for on_enter_action in enemy.moves.consume_pending_on_enter():
			if combat.is_game_over or not enemy.is_alive():
				break
			await execute_action(combat, enemy, on_enter_action)
		if combat.is_game_over:
			return
		if not enemy.is_alive():
			continue
		# Stunned: one stack is spent and the move is skipped (the pointer
		# still advances, so no backlog of skipped moves).
		if enemy.consume_stun_if_present():
			combat.show_notification(
				_t("UI_COMBAT_ENEMY_STUNNED").format({"name": enemy.enemy_name}), Color(0.95, 0.95, 0.3)
			)
			enemy.moves.consume()
			enemy.intent_changed.emit()
			enemy.end_turn()
			await presenter.wait(0.4)
			continue
		var action: Dictionary = enemy.moves.consume()
		enemy.intent_changed.emit()
		await execute_action(combat, enemy, action)
		if enemy.is_alive():
			enemy.end_turn()
		await presenter.wait(0.25)
	if combat.is_game_over:
		return
	combat.show_notification(_t("UI_COMBAT_YOUR_TURN"), Color(0.4, 0.8, 1.0))
	await presenter.wait(0.4)


## Run one enemy move. An interruptible attack is cancelled by spending one
## Stun stack; every other move runs through the effect registry, so attacks
## use the same damage pipeline as the intent badge.
static func execute_action(combat: Object, enemy: Object, action: Dictionary) -> void:
	var action_type: String = action.get("type", "attack")
	if action_type in ATTACK_LIKE and bool(action.get("interruptible", false)):
		if enemy.consume_stun_if_present():
			combat.show_notification(interrupt_message(combat, enemy, action), Color(0.95, 0.95, 0.3))
			await combat.presenter.pulse(enemy, "scale", Vector2(0.9, 1.1), Vector2.ONE, 0.1)
			return
	var source = COMBAT_SOURCE.make("enemy", "enemy", enemy)
	var ctx = EFFECT_CONTEXT.make("enemy", source, enemy, combat.player, combat)
	await combat.effect_registry.execute(ctx, action)


## "<move> — INTERRUPTED!" from the generated intent text of the cancelled move.
static func interrupt_message(combat: Object, enemy: Object, action: Dictionary) -> String:
	var move: String = INTENTS.text(action, intent_damage(combat, enemy, action), false)
	if move == "":
		move = _t("UI_COMBAT_INTERRUPT_DEFAULT_LABEL")
	return _t("UI_COMBAT_INTERRUPTED").format({"label": move})


## Damage the player would take from `action` right now (the intent number).
static func intent_damage(combat: Object, enemy: Object, action: Dictionary) -> int:
	return COMBAT_EFFECTS.preview_enemy_attack(combat, enemy, action)


static func _t(key: String) -> String:
	return TranslationServer.translate(key)

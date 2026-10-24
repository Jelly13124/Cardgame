extends RefCounted

## Combat effect handlers for the shared effect registry (core/effects). Cards,
## tools, relics, equipment sets and curses use the "combat" context: the
## handler reads `ctx.source` to know who caused the effect, and every damage,
## Block or status change goes through combat_commands.
##
## The five damage effect types only decide a base value and its props (spec
## §5); everything after that — Strength, Loaded, set and relic bonuses, crits,
## Weak/Vulnerable, Intangible, Block, on-hit reactions — is the shared hit
## chain, so the targeting preview and the hit cannot disagree.

const VALUE_PROPS = preload("uid://cccfcqt180t4x")  # res://core/combat/value_props.gd
const COMBAT_SOURCE = preload("uid://jgs131055xrk")  # res://core/combat/combat_source.gd
const VALUE_CALC = preload("uid://tynklfj3vjf5")  # res://core/combat/value_calc.gd
const CARD_PLAY = preload("uid://bxaw24a7fumhm")  # res://core/combat/card_play.gd
const EFFECT_CONTEXT = preload("uid://bx2g3askncfr6")  # res://core/effects/effect_context.gd
const STATUS_SYS = preload("uid://cq4eulp4ci8is")  # res://battle_scene/status_effect_system.gd

const COMBAT := ["combat"]
const ENEMY := ["enemy"]
const ENEMY_ATTACK_TYPES := ["attack", "attack_ramp", "attack_all", "attack_status"]
const DAMAGE_TYPES := [
	"deal_damage",
	"deal_damage_all",
	"deal_damage_str_mult",
	"deal_damage_block_mult",
	"scale_damage_by_attacks",
]
## Base value already uses Strength (or must not): no global +STR.
const NO_STRENGTH_TYPES := ["deal_damage_str_mult", "deal_damage_block_mult", "scale_damage_by_attacks"]
const ATTRIBUTE_COLORS := {
	"gain_strength": Color(1.0, 0.5, 0.2),
	"gain_constitution": Color(0.4, 0.7, 1.0),
	"gain_intelligence": Color(0.8, 0.4, 1.0),
	"gain_luck": Color(1.0, 0.9, 0.2),
	"gain_charm": Color(1.0, 0.5, 0.8),
}
const NO_TARGET_COLOR := Color(1, 0.5, 0.5)


## Each combat type registers its handler and its definition together
## (core/effects/effect_registry.gd documents the definition keys).
static func register_into(registry) -> void:
	registry.register("deal_damage", _damage_effect, COMBAT, {"target": "enemy", "upgrade": {"amount": 2}})
	registry.register("deal_damage_all", _damage_effect, COMBAT, {"target": "all", "upgrade": {"amount": 2}})
	registry.register("deal_damage_str_mult", _damage_effect, COMBAT, {"target": "enemy"})
	registry.register("deal_damage_block_mult", _damage_effect, COMBAT, {"target": "enemy"})
	registry.register("scale_damage_by_attacks", _damage_effect, COMBAT, {"target": "enemy"})
	registry.register("gain_strength", _gain_attribute, COMBAT, {"target": "self", "upgrade": {"amount": 1}})
	registry.register("gain_constitution", _gain_attribute, COMBAT, {"target": "self"})
	registry.register("gain_intelligence", _gain_attribute, COMBAT, {"target": "self", "upgrade": {"amount": 1}})
	registry.register("gain_luck", _gain_attribute, COMBAT, {"target": "self", "upgrade": {"amount": 1}})
	registry.register("gain_charm", _gain_attribute, COMBAT, {"target": "self"})
	registry.register("gain_block", _gain_block, COMBAT, {"target": "self", "upgrade": {"amount": 3}})
	registry.register("add_card_to_hand", _add_card_to_hand, COMBAT, {"target": "self", "params": ["card"]})
	registry.register("discover", _discover, COMBAT, {"target": "self", "params": ["pool"]})
	registry.register("gain_energy", _gain_energy, COMBAT, {"target": "self", "upgrade": {"amount": 1}})
	registry.register("draw_cards", _draw_cards, COMBAT, {"target": "self", "upgrade": {"amount": 1}})
	registry.register("gain_attack_allowance", _gain_attack_allowance, COMBAT, {"target": "self"})
	registry.register("restore_attack_allowance", _restore_attack_allowance, COMBAT, {"target": "self"})
	registry.register("apply_stun", _apply_stun, COMBAT, {"target": "enemy"})
	registry.register("apply_stun_all", _apply_stun_all, COMBAT, {"target": "all"})
	registry.register("flip_polarity", _flip_polarity, COMBAT, {"target": "self"})
	registry.register("exhaust_self", _exhaust_self, COMBAT, {"target": "none"})
	registry.register("apply_status", _apply_status, COMBAT, {"target": "enemy", "params": ["status"], "upgrade": {"stacks": 1}})
	registry.register("apply_short_circuit_scaled", _apply_short_circuit_scaled, COMBAT, {"target": "enemy"})
	registry.register("apply_status_self", _apply_status_self, COMBAT, {"target": "self", "params": ["status"]})
	registry.register("apply_status_all", _apply_status_all, COMBAT, {"target": "all", "params": ["status"], "upgrade": {"stacks": 1}})
	registry.register("lose_hp", _lose_hp, COMBAT, {"target": "self"})
	registry.register("lose_gold", _lose_gold, COMBAT, {"target": "self"})
	registry.register("add_curse_to_deck", _add_curse_to_deck, COMBAT, {"target": "self"})
	registry.register("double_strength", _double_strength, COMBAT, {"target": "self"})
	registry.register("overload", _overload, COMBAT, {"target": "all"})
	registry.register("gain_gold", _gain_gold, COMBAT, {"target": "self"})
	registry.register("heal", _heal, COMBAT, {"target": "self"})
	registry.register("gain_temp_strength", _gain_temp_strength, COMBAT, {"target": "self", "card": false})
	for type in ENEMY_ATTACK_TYPES:
		registry.register(type, _enemy_attack, ENEMY)
	registry.register("block", _enemy_block, ENEMY)
	registry.register("breakable_block", _enemy_block, ENEMY)
	registry.register("reflective_plating", _enemy_block, ENEMY)
	registry.register("heal", _enemy_heal, ENEMY)
	registry.register("telegraph", _enemy_telegraph, ENEMY)
	registry.register("summon", _enemy_summon, ENEMY)
	registry.register("buff_self", _enemy_buff_self, ENEMY)
	registry.register("add_curse", _enemy_add_curse, ENEMY)


# ─── Damage: base values and preview ─────────────────────────────────────────


## Base value of a damage effect before the hit chain (spec §5 table).
static func damage_base(ctx, effect: Dictionary) -> int:
	var actor: Object = ctx.actor
	match str(effect.get("type", "")):
		"deal_damage", "deal_damage_all":
			return _amount(effect)
		"deal_damage_str_mult":
			return int(effect.get("base", 0)) + int(_attr(actor, "strength") * float(effect.get("mult", 1)))
		"deal_damage_block_mult":
			return int(_attr(actor, "block") * float(effect.get("mult", 1)))
		"scale_damage_by_attacks":
			var count := 0
			var turns = ctx.services.get("turn_manager") if ctx.services else null
			if turns:
				count = int(
					turns.attacks_played_this_combat
					if str(effect.get("scope", "turn")) == "combat"
					else turns.attacks_played_this_turn
				)
			return int(effect.get("base", 0)) + int(effect.get("per", 0)) * count
	return 0


## Props of a damage effect: card damage is powered; anything else (tools,
## relics, sets) resolves at its printed number.
static func damage_props(source, effect: Dictionary) -> int:
	if source == null or not source.is_card():
		return 0
	var props := VALUE_PROPS.POWERED
	if bool(effect.get("no_str", false)) or str(effect.get("type", "")) in NO_STRENGTH_TYPES:
		props |= VALUE_PROPS.NO_STRENGTH
	return props


## Damage `card` would deal to `target` (one resolution pass), or -1 when the
## card has no damage effect. Never changes state.
static func preview_card_damage(services: Object, card: Object, target: Object) -> int:
	if card == null or not is_instance_valid(card) or not "card_info" in card:
		return -1
	var player: Object = services.get("player")
	var play = CARD_PLAY.new()
	play.preview = true
	play.card = card
	play.target = target
	play.dealer = player
	var source = COMBAT_SOURCE.make("card", "player", player, card)
	var ctx = EFFECT_CONTEXT.make("combat", source, player, target, services, play)
	var total := 0
	var has_damage := false
	for effect in card.card_info.get("effects", []):
		if typeof(effect) != TYPE_DICTIONARY or not str(effect.get("type", "")) in DAMAGE_TYPES:
			continue
		has_damage = true
		total += services.combat_commands.preview_damage(
			source, target, damage_base(ctx, effect), damage_props(source, effect), play,
			_loaded_bonus(ctx)
		)
	return total if has_damage else -1


## Card-text numbers: the pipeline preview (no target) of each damage and
## gain_block effect, keyed by effect index. `effects` defaults to the card's own
## (pass an upgrade preview's list to describe that instead). Never changes state.
static func preview_effect_values(services: Object, card: Object, effects: Array = []) -> Dictionary:
	var values := {}
	var player: Object = services.get("player")
	if effects.is_empty() and card and "card_info" in card:
		effects = card.card_info.get("effects", [])
	var play = CARD_PLAY.new()
	play.preview = true
	play.card = card
	play.dealer = player
	var source = COMBAT_SOURCE.make("card", "player", player, card)
	var ctx = EFFECT_CONTEXT.make("combat", source, player, null, services, play)
	for i in effects.size():
		var effect = effects[i]
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var type := str(effect.get("type", ""))
		if type in DAMAGE_TYPES:
			values[i] = services.combat_commands.preview_damage(
				source, null, damage_base(ctx, effect), damage_props(source, effect), play,
				_loaded_bonus(ctx)
			)
		elif type == "gain_block":
			var props := VALUE_PROPS.POWERED
			if bool(effect.get("no_con", false)):
				props |= VALUE_PROPS.NO_CONSTITUTION
			values[i] = services.combat_hooks.compute_block(
				VALUE_CALC.for_block(source, player, _amount(effect), props, true)
			)
	return values


static func _damage_effect(ctx, effect: Dictionary) -> void:
	var services: Object = ctx.services
	var type := str(effect.get("type", ""))
	var targets: Array = []
	if type == "deal_damage_all":
		targets = _alive_enemies(services)
	elif services.combat_commands.is_alive(ctx.target):
		targets = [ctx.target]
	else:
		services.show_notification(_t("UI_COMBAT_NO_TARGET"), NO_TARGET_COLOR)
		return
	var tags := {"heavy": bool(effect.get("heavy", false))}
	await services.combat_commands.damage(
		ctx.source, targets, damage_base(ctx, effect), damage_props(ctx.source, effect), ctx.play,
		_loaded_bonus(ctx), tags
	)
	if type == "deal_damage_all":
		if ctx.pace:
			AudioManager.play_sfx("attack_slash")
		await _pace(ctx, 0.3)
	elif type != "deal_damage":
		await _pace(ctx, 0.2)


## Loaded: all stacks go to the first damage effect of an Attack card play.
static func _loaded_bonus(ctx) -> int:
	if ctx.play == null or ctx.source == null or ctx.source.card_type() != "attack":
		return 0
	return ctx.play.take_loaded(ctx.actor)


# ─── Block, attributes, resources ─────────────────────────────────────────────


static func _gain_block(ctx, effect: Dictionary) -> void:
	var props := 0
	if ctx.source and ctx.source.is_card():
		props = VALUE_PROPS.POWERED
		if bool(effect.get("no_con", false)):
			props |= VALUE_PROPS.NO_CONSTITUTION
	var gained: int = await ctx.services.combat_commands.gain_block(
		ctx.source, ctx.actor, _amount(effect), props
	)
	if gained > 0 and ctx.pace:
		block_feedback(ctx.services, ctx.actor, gained)
	await _pace(ctx, 0.2)


## Card-style Block feedback: pulse, sound, notification.
static func block_feedback(services: Object, creature: Object, amount: int) -> void:
	if creature and creature.has_method("play_block_pulse"):
		creature.play_block_pulse()
	AudioManager.play_sfx("block_gain")
	services.show_notification(_t("UI_COMBAT_GAIN_BLOCK").format({"n": amount}), Color(0.4, 0.6, 1.0))


static func _gain_attribute(ctx, effect: Dictionary) -> void:
	var type := str(effect.get("type", ""))
	var attr := type.trim_prefix("gain_")
	var amount := _amount(effect)
	var player: Object = ctx.actor
	player.set(attr, int(player.get(attr)) + amount)
	if player.has_method("notify_stats_changed"):
		player.notify_stats_changed()
	ctx.services.show_notification(
		_t("UI_COMBAT_ATTR_GAIN").format({"attr": _t("UI_COMBAT_ATTR_%s" % attr.to_upper()), "n": amount}),
		ATTRIBUTE_COLORS[type]
	)
	await _pace(ctx, 0.2)


static func _gain_temp_strength(ctx, effect: Dictionary) -> void:
	if ctx.actor and ctx.actor.has_method("gain_temp_strength"):
		ctx.actor.gain_temp_strength(_amount(effect))


static func _add_card_to_hand(ctx, effect: Dictionary) -> void:
	var card_id := str(effect.get("card", ""))
	var deck_manager = ctx.services.get("deck_manager")
	if card_id == "" or deck_manager == null or not deck_manager.has_method("add_card_to_hand"):
		return
	for _i in range(maxi(1, _amount(effect))):
		deck_manager.add_card_to_hand(card_id)


## Hearthstone-style 3-choose-1; the picked card enters the current hand.
static func _discover(ctx, effect: Dictionary) -> void:
	if ctx.services.has_method("open_discover"):
		await ctx.services.open_discover(
			str(effect.get("pool", "skill")), int(effect.get("count", 3)), bool(effect.get("free", false))
		)


static func _gain_energy(ctx, effect: Dictionary) -> void:
	var amount := _amount(effect)
	ctx.actor.gain_energy(amount)
	if ctx.pace:
		ctx.services.show_notification(_t("UI_COMBAT_GAIN_ENERGY").format({"n": amount}), Color(0.9, 0.9, 0.3))
	await _pace(ctx, 0.1)


static func _draw_cards(ctx, effect: Dictionary) -> void:
	var amount := _amount(effect)
	ctx.services.deck_manager.draw_cards(amount)
	AudioManager.play_sfx("card_draw")
	ctx.services.show_notification(_t("UI_COMBAT_DRAW").format({"n": amount}), Color(0.7, 1.0, 0.7))
	await _pace(ctx, 0.2)


## +amount attacks this turn (only matters under the double-fire clip's cap).
static func _gain_attack_allowance(ctx, effect: Dictionary) -> void:
	if ctx.services.has_method("add_attack_allowance"):
		ctx.services.add_attack_allowance(_amount(effect))


## Reload: refresh the attack allowance up to the per-turn cap.
static func _restore_attack_allowance(ctx, _effect: Dictionary) -> void:
	if ctx.services.has_method("restore_attack_allowance"):
		ctx.services.restore_attack_allowance()


static func _lose_gold(ctx, effect: Dictionary) -> void:
	var amount := _amount(effect)
	RunManager.spend_gold(amount)
	ctx.services.show_notification(_t("UI_COMBAT_LOSE_GOLD").format({"n": amount}), Color(0.85, 0.7, 0.3))


## Permanent curse onto the run deck.
static func _add_curse_to_deck(_ctx, effect: Dictionary) -> void:
	var curse_id := str(effect.get("card", effect.get("curse", "base:radiation_dust")))
	for _i in range(maxi(1, _amount(effect))):
		RunManager.add_card_to_deck(curse_id)


static func _double_strength(ctx, _effect: Dictionary) -> void:
	var player: Object = ctx.actor
	player.set("strength", int(player.get("strength")) * 2)
	if player.has_method("notify_stats_changed"):
		player.notify_stats_changed()
	ctx.services.show_notification(_t("UI_COMBAT_DOUBLE_STRENGTH"), ATTRIBUTE_COLORS["gain_strength"])
	await _pace(ctx, 0.2)


## Card gold; `max_per_combat` caps triggers. Relic gold is a plain grant.
static func _gain_gold(ctx, effect: Dictionary) -> void:
	var amount := _amount(effect)
	if ctx.source and ctx.source.kind in ["card", "tool"] and ctx.services.has_method("try_gain_gold"):
		ctx.services.try_gain_gold(amount, int(effect.get("max_per_combat", 0)))
	else:
		RunManager.add_resources(amount, 0)
	await _pace(ctx, 0.1)


## The actor heals (the player for cards/relics, the enemy for its own move).
static func _heal(ctx, effect: Dictionary) -> void:
	var amount := _amount(effect)
	if ctx.actor and ctx.actor.has_method("heal"):
		ctx.actor.heal(amount)
		if ctx.pace:
			ctx.services.show_notification(_t("UI_COMBAT_HEAL").format({"n": amount}), Color(0.3, 1.0, 0.45))
	await _pace(ctx, 0.15)


## Direct HP loss bypasses Block (Intangible still caps it).
static func _lose_hp(ctx, effect: Dictionary) -> void:
	var lost: int = await ctx.services.combat_commands.lose_hp(ctx.source, ctx.actor, _amount(effect))
	ctx.services.show_notification(_t("UI_COMBAT_LOSE_HP").format({"n": lost}), Color(0.85, 0.3, 0.3))
	await _pace(ctx, 0.15)


static func _flip_polarity(ctx, _effect: Dictionary) -> void:
	var player: Object = ctx.actor
	if player == null or not player.has_method("flip_polarity"):
		return
	var was_harmony := bool(player.harmony_active)
	player.flip_polarity()
	if player.harmony_active and not was_harmony:
		# Yin-Yang Harmony entry reward — granted once.
		player.gain_energy(1)
		ctx.services.deck_manager.draw_cards(1)
		ctx.services.show_notification(_t("UI_COMBAT_HARMONY"), Color(1, 0.85, 0.3))
	if ctx.services.has_method("update_polarity_hud"):
		ctx.services.update_polarity_hud()
	await _pace(ctx, 0.1)


## Marker: battle_scene routes the card to the Exhaust pile after resolution.
static func _exhaust_self(_ctx, _effect: Dictionary) -> void:
	pass


# ─── Statuses ─────────────────────────────────────────────────────────────────


static func _apply_status(ctx, effect: Dictionary) -> void:
	var status := str(effect.get("status", ""))
	if not ctx.services.combat_commands.is_alive(ctx.target):
		ctx.services.show_notification(_t("UI_COMBAT_NO_TARGET"), NO_TARGET_COLOR)
		return
	var applied: int = await ctx.services.combat_commands.apply_status(
		ctx.source, ctx.target, status, int(effect.get("stacks", 1)), "apply_status"
	)
	_status_notification(ctx, "UI_COMBAT_APPLIED_STATUS", status, applied, Color(0.6, 0.9, 0.3))
	await _pace(ctx, 0.2)


## Short Circuit = amount + attribute × attr_mult (default Intelligence);
## Voltage Tear doubles it when the target already holds charge.
static func _apply_short_circuit_scaled(ctx, effect: Dictionary) -> void:
	var target: Object = ctx.target
	if not ctx.services.combat_commands.is_alive(target):
		ctx.services.show_notification(_t("UI_COMBAT_NO_TARGET"), NO_TARGET_COLOR)
		return
	var stacks := (
		int(effect.get("amount", 0))
		+ _attr(ctx.actor, str(effect.get("attr", "intelligence"))) * int(effect.get("attr_mult", 1))
	)
	if bool(effect.get("double_if_short_circuited", false)) and target.get_status_stacks("short_circuit") > 0:
		stacks *= 2
	var applied: int = await ctx.services.combat_commands.apply_status(
		ctx.source, target, "short_circuit", stacks, "apply_short_circuit_scaled"
	)
	_status_notification(ctx, "UI_COMBAT_APPLIED_STATUS", "short_circuit", applied, Color(0.2, 0.92, 1.0))
	await _pace(ctx, 0.2)


static func _apply_status_self(ctx, effect: Dictionary) -> void:
	var status := str(effect.get("status", ""))
	var applied: int = await ctx.services.combat_commands.apply_status(
		ctx.source, ctx.actor, status, int(effect.get("stacks", 1)), "apply_status_self"
	)
	_status_notification(ctx, "UI_COMBAT_APPLIED_STATUS", status, applied, Color(0.6, 0.9, 0.3))
	await _pace(ctx, 0.2)


static func _apply_status_all(ctx, effect: Dictionary) -> void:
	var status := str(effect.get("status", ""))
	var applied := 0
	for enemy in _alive_enemies(ctx.services):
		applied = await ctx.services.combat_commands.apply_status(
			ctx.source, enemy, status, int(effect.get("stacks", 1)), "apply_status_all"
		)
	_status_notification(ctx, "UI_COMBAT_ALL_STATUS", status, applied, Color(0.6, 0.9, 0.3))
	await _pace(ctx, 0.2)


static func _apply_stun(ctx, effect: Dictionary) -> void:
	var stacks := int(effect.get("stacks", int(effect.get("amount", 1))))
	if not ctx.services.combat_commands.is_alive(ctx.target):
		ctx.services.show_notification(_t("UI_COMBAT_NO_TARGET"), NO_TARGET_COLOR)
		return
	var applied: int = await ctx.services.combat_commands.apply_status(
		ctx.source, ctx.target, "stun", stacks, "apply_stun"
	)
	ctx.services.show_notification(_t("UI_COMBAT_STUN_X").format({"n": applied}), Color(0.95, 0.95, 0.3))
	await _pace(ctx, 0.2)


static func _apply_stun_all(ctx, effect: Dictionary) -> void:
	var stacks := int(effect.get("stacks", int(effect.get("amount", 1))))
	for enemy in _alive_enemies(ctx.services):
		await ctx.services.combat_commands.apply_status(ctx.source, enemy, "stun", stacks, "apply_stun_all")
	ctx.services.show_notification(_t("UI_COMBAT_ALL_STUN_X").format({"n": stacks}), Color(0.95, 0.95, 0.3))
	await _pace(ctx, 0.2)


# ─── Overload ─────────────────────────────────────────────────────────────────


## Every live enemy discharges all stored Short Circuit as one card-sourced,
## unpowered hit (crits only under Overload Protocol). Charge Sink converts
## the HP damage actually dealt into Block.
static func _overload(ctx, effect: Dictionary) -> void:
	var services: Object = ctx.services
	var charge_multiplier := maxi(1, int(effect.get("charge_multiplier", 1)))
	var overloaded_any := false
	var critical_any := false
	var total_hp_damage := 0
	for enemy in _alive_enemies(services):
		if services.get("is_game_over"):
			break
		var consumed := consume_short_circuit(enemy)
		if consumed <= 0:
			continue
		overloaded_any = true
		var discharged := consumed * charge_multiplier
		var results: Array = await services.combat_commands.damage(
			ctx.source, [enemy], discharged, 0, ctx.play, 0,
			{"overload": true, "heavy": discharged >= 12, "feedback_source": "status", "status": "short_circuit"}
		)
		for result in results:
			total_hp_damage += result.hp_lost
			critical_any = critical_any or result.critical
	if overloaded_any:
		AudioManager.play_sfx(
			"crit" if critical_any else "attack_hit", -1.5 if critical_any else -2.0, 1.12, 0.03
		)
	else:
		services.show_notification(_t("UI_COMBAT_NO_SHORT_CIRCUIT"), Color(0.4, 0.85, 1.0))
	if bool(effect.get("gain_block_equal_damage", false)) and total_hp_damage > 0:
		var props := VALUE_PROPS.POWERED | VALUE_PROPS.NO_CONSTITUTION
		var gained: int = await services.combat_commands.gain_block(ctx.source, ctx.actor, total_hp_damage, props)
		if gained > 0:
			block_feedback(services, ctx.actor, gained)
	await _pace(ctx, 0.2)


## Removes and returns all Short Circuit stored on `target`.
static func consume_short_circuit(target: Object) -> int:
	if target == null or not is_instance_valid(target) or not target.has_method("get_status_stacks"):
		return 0
	var stacks := int(target.get_status_stacks("short_circuit"))
	var status_system = target.get("status_system")
	if stacks > 0 and status_system:
		status_system.spend_stacks("short_circuit", stacks, target)
	return stacks


# ─── Enemy moves ("enemy" context) ────────────────────────────────────────────


## Base damage of an enemy attack move: its amount × the act multiplier
## (non-boss, rounded — part of the enemy's strength, like its HP).
static func enemy_attack_base(enemy: Object, action: Dictionary) -> int:
	return RunManager.scale_enemy_damage(int(action.get("amount", 0)), str(enemy.get("enemy_id")))


## Damage the player would take from `action` right now (intent badge).
static func preview_enemy_attack(services: Object, enemy: Object, action: Dictionary) -> int:
	var player: Object = services.get("player")
	var source = COMBAT_SOURCE.make("enemy", "enemy", enemy)
	return services.combat_commands.preview_damage(
		source, player, enemy_attack_base(enemy, action), VALUE_PROPS.POWERED
	)


static func _enemy_attack(ctx, action: Dictionary) -> void:
	var services: Object = ctx.services
	var enemy: Object = ctx.actor
	await _play_enemy_attack_once(services, enemy)
	var player: Object = ctx.target
	if not services.combat_commands.is_alive(player):
		return
	var type := str(action.get("type", "attack"))
	AudioManager.play_sfx("enemy_attack")
	var heavy := type == "attack_all" or bool(action.get("heavy", false))
	var results: Array = await services.combat_commands.damage(
		ctx.source, [player], enemy_attack_base(enemy, action), VALUE_PROPS.POWERED, null, 0,
		{"heavy": heavy}
	)
	if type == "attack_status" and not results.is_empty():
		var status := str(action.get("status", ""))
		await services.combat_commands.apply_status(
			ctx.source, player, status, int(action.get("stacks", 1)), "attack_status"
		)
		services.show_notification(
			_t("UI_COMBAT_ENEMY_HITS_STATUS").format(
				{"n": results[0].amount, "status": STATUS_SYS.format_name_localized(status)}
			),
			Color(1, 0.3, 0.3)
		)
	await services.combat_hooks.after_attack({"source": ctx.source, "dealer": enemy, "target": player})


## block / breakable_block / reflective_plating: powered enemy Block (its own
## Frail applies), plus the armed exposure or Thorns rider.
static func _enemy_block(ctx, action: Dictionary) -> void:
	var services: Object = ctx.services
	var enemy: Object = ctx.actor
	var type := str(action.get("type", "block"))
	var gained: int = await services.combat_commands.gain_block(
		ctx.source, enemy, int(action.get("amount", 0)), VALUE_PROPS.POWERED
	)
	match type:
		"breakable_block":
			if enemy.has_method("arm_breakable_armor"):
				enemy.arm_breakable_armor(str(action.get("status", "vulnerable")), int(action.get("stacks", 1)))
			services.show_notification(
				_t("UI_COMBAT_ENEMY_BREAKABLE_ARMOR").format({"n": gained}), Color(0.45, 0.72, 1.0)
			)
			await _pulse(enemy, "scale", Vector2(1.16, 1.16), Vector2.ONE, 0.1)
		"reflective_plating":
			var thorns := int(action.get("thorns", 1))
			await services.combat_commands.apply_status(ctx.source, enemy, "thorns", thorns, "reflective_plating")
			services.show_notification(
				_t("UI_COMBAT_ENEMY_REFLECTIVE_PLATING").format({"block": gained, "thorns": thorns}),
				Color(0.62, 0.86, 1.0)
			)
			await _pulse(enemy, "modulate", Color(1.25, 1.35, 1.5), Color.WHITE, 0.16)
		_:
			services.show_notification(_t("UI_COMBAT_ENEMY_DEFENDS").format({"n": gained}), Color(0.4, 0.6, 1.0))
			await _pulse(enemy, "scale", Vector2(1.2, 1.2), Vector2.ONE, 0.1)


static func _enemy_heal(ctx, action: Dictionary) -> void:
	var amount := int(action.get("amount", 0))
	if ctx.actor.has_method("heal"):
		ctx.actor.heal(amount)
	ctx.services.show_notification(_t("UI_COMBAT_ENEMY_HEALS").format({"n": amount}), Color(0.2, 1.0, 0.4))


## Flavor-only wind-up; the next (usually interruptible) move is the payoff.
static func _enemy_telegraph(ctx, _action: Dictionary) -> void:
	ctx.services.show_notification(
		_t("UI_COMBAT_ENEMY_CHARGING").format({"name": ctx.actor.get("enemy_name")}), Color(1.0, 0.7, 0.2)
	)
	await _pulse(ctx.actor, "modulate", Color(1.4, 1.1, 0.4), Color.WHITE, 0.25)


static func _enemy_summon(ctx, action: Dictionary) -> void:
	var enemy_ai = ctx.services.get("enemy_ai")
	if enemy_ai and await enemy_ai.summon_adds(ctx.actor, action) > 0:
		await _pulse(ctx.actor, "scale", Vector2(1.15, 1.15), Vector2.ONE, 0.12)


static func _enemy_buff_self(ctx, action: Dictionary) -> void:
	var status := str(action.get("status", ""))
	await ctx.services.combat_commands.apply_status(
		ctx.source, ctx.actor, status, int(action.get("stacks", 1)), "buff_self"
	)
	ctx.services.show_notification(
		_t("UI_COMBAT_ENEMY_BUFFS_SELF").format(
			{"name": ctx.actor.get("enemy_name"), "status": STATUS_SYS.format_name_localized(status)}
		),
		Color(1.0, 0.6, 0.2)
	)
	await _pulse(ctx.actor, "modulate", Color(1.5, 0.7, 0.7), Color.WHITE, 0.2)


## Shuffle a curse into the player's draw pile (this combat only).
static func _enemy_add_curse(ctx, action: Dictionary) -> void:
	var curse_id := str(action.get("curse", "base:radiation_dust"))
	for _i in range(maxi(1, int(action.get("amount", 1)))):
		ctx.services.deck_manager.add_card_to_draw(curse_id)
	ctx.services.show_notification(
		_t("UI_BATTLE_ENEMY_CURSE").format({"name": ctx.actor.get("enemy_name")}), Color(0.72, 0.5, 0.85)
	)
	await _pulse(ctx.actor, "modulate", Color(0.85, 0.6, 1.2), Color.WHITE, 0.15)


static func _play_enemy_attack_once(services: Object, enemy: Object) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.has_method("play_attack") and (
		not enemy.has_method("has_attack_animation") or enemy.has_attack_animation()
	):
		enemy.play_attack()
		if enemy.has_signal("attack_animation_finished"):
			await enemy.attack_animation_finished
			return
	if services is Node and (services as Node).is_inside_tree():
		await (services as Node).get_tree().create_timer(0.35).timeout


## Out-and-back tween on `property` of an enemy node.
static func _pulse(node: Object, property: String, peak: Variant, rest: Variant, seconds: float) -> void:
	if not (node is Node) or not is_instance_valid(node) or not (node as Node).is_inside_tree():
		return
	var tween := (node as Node).create_tween()
	tween.tween_property(node, property, peak, seconds)
	tween.tween_property(node, property, rest, seconds)
	await tween.finished


# ─── Helpers ──────────────────────────────────────────────────────────────────


static func _amount(effect: Dictionary) -> int:
	var amount := int(effect.get("amount", 0))
	var multiplier := float(effect.get("multiplier", 1))
	return int(amount * multiplier) if multiplier != 1.0 else amount


static func _attr(creature: Object, attr: String) -> int:
	if creature == null or not is_instance_valid(creature) or not attr in creature:
		return 0
	return int(creature.get(attr))


static func _alive_enemies(services: Object) -> Array:
	var out: Array = []
	var container = services.get("enemy_container")
	if container == null:
		return out
	for enemy in container.get_children():
		if services.combat_commands.is_alive(enemy) and enemy.has_method("take_damage"):
			out.append(enemy)
	return out


static func _status_notification(ctx, key: String, status: String, n: int, color: Color) -> void:
	if n <= 0:
		return
	ctx.services.show_notification(
		_t(key).format({"status": STATUS_SYS.format_name_localized(status), "n": n}), color
	)


static func _pace(ctx, seconds: float) -> void:
	if ctx.pace and ctx.services is Node and (ctx.services as Node).is_inside_tree():
		await (ctx.services as Node).get_tree().create_timer(seconds).timeout


static func _t(key: String) -> String:
	return TranslationServer.translate(key)

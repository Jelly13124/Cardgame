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
const PLAYER_GUNSHOT_WINDUP_SECONDS := 0.22

@onready var main = get_parent()

## Deadeye Crit Clip: whether this turn's guaranteed first-attack Crit is still
## available. Reset each player turn by battle_scene via reset_turn_crit().
var _first_attack_crit_used: bool = false


func declare_victory() -> void:
	victory_declared.emit()


## `preview` = true for the targeting damage preview (called every frame while
## aiming). Preview must be side-effect-free: it reads the predicted number but
## must NOT consume Deadeye's once-per-turn crit, mark feedback as critical, grant
## Hot Streak gold, or trigger Ricochet Loader. Real resolution passes false.
func calculate_attack_damage(
	base_damage: int,
	attacker: Node,
	defender: Node,
	preview: bool = false,
	feedback_tags: Dictionary = {}
) -> int:
	var modified_base = base_damage
	if main and main.has_method("modify_player_attack_damage") and attacker == main.player:
		modified_base = main.modify_player_attack_damage(modified_base, attacker, defender)
		modified_base = _apply_player_crit(modified_base, preview, feedback_tags)

	var outgoing_mult := 1.0
	var incoming_mult := 1.0
	if attacker and attacker.has_method("get_outgoing_multiplier"):
		outgoing_mult = attacker.get_outgoing_multiplier()
	if defender and defender.has_method("get_incoming_attack_multiplier"):
		incoming_mult = defender.get_incoming_attack_multiplier()
	return int(modified_base * outgoing_mult * incoming_mult)


## Roll crit for a player attack and apply the result. Crit is a Luck-driven base
## mechanic (RunManager.crit_chance). Powers (player statuses) modify it:
##   all_in     → crits deal 2x (not 1.5x) AND non-crit attacks deal 0
##   hot_streak → gain 2 gold on each crit
func _apply_player_crit(
	damage: int, preview: bool = false, feedback_tags: Dictionary = {}
) -> int:
	if damage <= 0:
		return damage
	var p = main.player
	var has_power: bool = p != null and p.has_method("get_status_stacks")
	var all_in: bool = has_power and int(p.get_status_stacks("all_in")) > 0
	# Deadeye Crit Clip: the first attack each turn is a guaranteed Crit. The
	# guarantee is spent on the first REAL damage instance — the per-frame targeting
	# preview (preview=true) shows the crit number but must not consume it.
	var relic_forced: bool = (
		not _first_attack_crit_used
		and main.relic_effect_system
		and main.relic_effect_system.first_attack_auto_crit()
	)
	var deadeye_forced: bool = (
		not relic_forced and has_power and int(p.get_status_stacks("deadeye")) > 0
	)
	var forced := relic_forced or deadeye_forced
	if forced and not preview:
		if relic_forced:
			_first_attack_crit_used = true
		elif deadeye_forced and p.status_system:
			p.status_system.spend_stacks("deadeye", 1, p)
	if forced or randf() < RunManager.crit_chance():
		# Base 1.5x, or a relic override (Volatile Crit Clip → 1.75x). All In trumps
		# both at 2x.
		var mult := 2.0 if all_in else float(RunManager.CRIT_MULT)
		if not all_in and main.relic_effect_system:
			mult = main.relic_effect_system.crit_mult(mult)
		# Side effects (feedback tag, Hot Streak gold, Ricochet Loader's free Reload)
		# belong to the real attack only — never the per-frame preview.
		if not preview:
			feedback_tags["critical"] = true
			if has_power and p.get_status_stacks("hot_streak") > 0:
				p.add_status("loaded", 2)
			if main.relic_effect_system:
				main.relic_effect_system.on_player_crit(p)
		return int(round(damage * mult))
	# Non-crit. All In zeroes non-crit attacks (all-or-nothing).
	if all_in and not preview:
		p.add_status("loaded", 2)
	return damage


## Reset the per-turn guaranteed-Crit flag (Deadeye Crit Clip). Called by
## battle_scene at the start of each player turn.
func reset_turn_crit() -> void:
	_first_attack_crit_used = false


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
		attacker.take_damage(
			thorns, false, {"source": "thorns", "heavy": false, "critical": false}
		)
		# Relic (Arc Spines): the PLAYER's Thorns also apply equal Short Circuit to the
		# attacker. Only fires for the player's own Thorns (defender == player).
		if (
			defender == main.player
			and main.relic_effect_system
			and main.relic_effect_system.thorns_apply_short_circuit()
			and attacker.has_method("add_status")
		):
			attacker.add_status("short_circuit", thorns)
		# Thorns decays on trigger (not per turn): lose 1 stack each time it reflects.
		var ss = defender.get("status_system")
		if ss:
			ss.spend_stacks("thorns", 1, defender)


func resolve_card_effect(card: Control, target: Node, player: Node) -> void:
	var effects: Array = card.card_info.get("effects", [])
	var type = card.card_info.get("type", "skill").to_lower()

	var card_mult: float = 1.0

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
	# matched bonus, and on-attack relics all re-trigger (Echo / Double-Tap
	# style). N = the card's innate `replay` plus any relic grant (double-fire clip
	# gives attack cards Replay 1). The attack-allowance is charged once per PLAY
	# (in the play path), not per replay.
	var replays: int = _replay_count(card, type)
	for _i in range(1 + replays):
		# The target can die/flee on an earlier replay pass; never pass a dead/freed
		# Object into _resolve_card_once's typed `target: Node` param. _live_target()
		# also rejects a queue_free'd-but-not-yet-freed node (same frame), so a later
		# await inside the pass can't deref it. null = "no target" → the hit fizzles.
		await _resolve_card_once(card, effects, type, _live_target(target), player, card_mult)


## A target Node counts as "live" only if it exists AND isn't already queued for
## deletion. queue_free() defers the real free to frame-end, so is_instance_valid()
## still returns true that same frame — a dying target would pass a naive guard and
## then be freed by a later await, hard-crashing any typed `target: Node` param it is
## passed to. Returns null for a null / freed / dying target so callers treat null as
## "no target" uniformly. The param is untyped on purpose (must accept a freed Object).
func _live_target(t) -> Node:
	return t if (is_instance_valid(t) and not t.is_queued_for_deletion()) else null


## One full resolution pass of a played card: gunshot anim → effects → polarity
## matched bonus → on-attack relics. Called once normally, or
## 1 + N times when the card has Replay N.
func _resolve_card_once(
	card: Control, effects: Array, type: String, target: Node, player: Node, card_mult: float
) -> void:
	if type == "attack" and _live_target(target):
		await _animate_player_gunshot(player, target)

	for effect in effects:
		# An earlier effect (or DOT) may have killed and freed the target mid-
		# resolution; never pass a freed Object into _apply_effect's typed
		# `target: Node` param. Re-validate each iteration (null == "no target").
		await _apply_effect(effect, _live_target(target), player, card_mult, card)

	# Polarity matched bonus — resolved after the normal effects (so any
	# flip_polarity earlier in this same card has already applied). Reuses every
	# existing effect handler, so bonuses get global STR/CON, dodge, thorns, etc.
	var polarity := str(card.card_info.get("polarity", "neutral"))
	if player and player.has_method("is_card_matched") and player.is_card_matched(polarity):
		var bonus = card.card_info.get("matched_bonus", [])
		if bonus is Array:
			for be in bonus:
				if typeof(be) == TYPE_DICTIONARY:
					await _apply_effect(be, _live_target(target), player, card_mult, card)

	# Relic: an attack card that landed on a target fires on-attack relics
	# (Conductive Scrap → Short Circuit on the struck enemy).
	if type == "attack" and _live_target(target) and main.relic_effect_system:
		main.relic_effect_system.on_player_attack(target)


## Total extra resolutions for a played card: its innate `replay` field plus any
## relic-granted replay (double-fire clip → +1 for attack cards).
func _replay_count(card: Control, type: String) -> int:
	var n: int = int(card.card_info.get("replay", 0))
	if type == "attack" and main.relic_effect_system:
		n += main.relic_effect_system.attack_replay_bonus()
	return n


func _feedback_tags_for(effect: Dictionary) -> Dictionary:
	return {
		"source": "player",
		"critical": false,
		"heavy": bool(effect.get("heavy", false)),
	}


func _consume_short_circuit(target: Node) -> int:
	if (
		target == null
		or not is_instance_valid(target)
		or not target.has_method("get_status_stacks")
	):
		return 0
	var stacks := int(target.get_status_stacks("short_circuit"))
	if stacks <= 0:
		return 0
	var status_system = target.get("status_system")
	if status_system:
		status_system.spend_stacks("short_circuit", stacks, target)
	return stacks


## Loaded is Bill's prepared-shot resource. The first damage effect of the next
## Attack consumes every stack and adds that much base damage. Keeping the spend
## here means utility Attacks do not waste a loaded chamber, while Dodge still
## consumes the fired shot.
func _consume_loaded_bonus(player: Node, source_card: Control = null) -> int:
	if (
		player == null
		or not is_instance_valid(player)
		or not player.has_method("get_status_stacks")
	):
		return 0
	if source_card:
		if not "card_info" in source_card:
			return 0
		if str(source_card.card_info.get("type", "")).to_lower() != "attack":
			return 0
	var stacks := int(player.get_status_stacks("loaded"))
	if stacks <= 0:
		return 0
	var status_system = player.get("status_system")
	if status_system:
		status_system.spend_stacks("loaded", stacks, player)
	return stacks


func _short_circuit_overload(stacks: int, player: Node) -> Dictionary:
	var damage := stacks
	var critical := false
	var protocol_active: bool = (
		player
		and player.has_method("get_status_stacks")
		and player.get_status_stacks("overload_protocol") > 0
	)
	if protocol_active and randf() < RunManager.crit_chance():
		damage = int(round(float(damage) * RunManager.CRIT_MULT))
		critical = true
		if player.get_status_stacks("hot_streak") > 0:
			player.add_status("loaded", 2)
		if main.relic_effect_system:
			main.relic_effect_system.on_player_crit(player)
	return {"damage": damage, "critical": critical}


## Applies the shared card-Block modifiers and feedback. Specialized card effects
## such as Charge Sink use this path so Frail, Block relics and Reactive Plating
## behave exactly like a normal gain_block effect.
func _grant_card_block(player: Node, amount: int) -> int:
	if player == null or not is_instance_valid(player) or amount <= 0:
		return 0
	if "status_system" in player and player.status_system:
		amount = int(amount * player.status_system.get_block_multiplier())
	if main.relic_effect_system:
		amount = main.relic_effect_system.on_player_gain_block(player, amount)
	if amount <= 0 or not player.has_method("add_block"):
		return 0
	player.add_block(amount)
	if player.has_method("get_status_stacks"):
		var reactive := int(player.get_status_stacks("reactive_plating"))
		if reactive > 0:
			player.add_status("thorns", reactive)
	if player.has_method("play_block_pulse"):
		player.play_block_pulse()
	AudioManager.play_sfx("block_gain")
	main.show_notification(
		tr("UI_COMBAT_GAIN_BLOCK").format({"n": amount}), Color(0.4, 0.6, 1.0)
	)
	return amount


func _apply_effect(
	effect: Dictionary,
	target: Node,
	player: Node,
	card_mult: float = 1.0,
	source_card: Control = null
) -> void:
	var effect_type: String = effect.get("type", "")
	var amount: int = int(effect.get("amount", 0))
	var multiplier: float = float(effect.get("multiplier", 1))

	if multiplier != 1:
		amount = int(amount * multiplier)

	# Global attributes: STR auto-adds to all attack damage, CON to all block.
	# Card JSON carries the BASE number only — the old per-card `scaling` field is
	# gone. `scale_damage_by_attacks` (cascade) and `deal_damage_str_mult`
	# (charged_shot) compute their own damage and must NOT receive the global +STR.
	# `no_str: true` on a damage effect opts OUT of the global +STR (fixed damage,
	# e.g. Acid Splash's corrosive hit).
	if player:
		var skip_str: bool = bool(effect.get("no_str", false))
		if (effect_type == "deal_damage" or effect_type == "deal_damage_all") and not skip_str:
			amount += int(player.get("strength"))
		elif effect_type == "gain_block" and not bool(effect.get("no_con", false)):
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
			amount += _consume_loaded_bonus(player, source_card)
			if target and is_instance_valid(target) and target.has_method("take_damage"):
				if _check_dodge(target):
					pass  # attack negated by Dodge
				else:
					if main.equipment_set_system and source_card:
						amount = main.equipment_set_system.modify_card_damage(
							source_card, amount
						)
					var feedback_tags := _feedback_tags_for(effect)
					var outgoing = calculate_attack_damage(
						amount, player, target, false, feedback_tags
					)
					await target.take_damage(outgoing, false, feedback_tags)
					_register_player_attack()
					if main.equipment_set_system and source_card:
						main.equipment_set_system.on_card_damage_resolved(
							source_card, target
						)
					apply_thorns_reflection(player, target)
			else:
				main.show_notification(tr("UI_COMBAT_NO_TARGET"), Color(1, 0.5, 0.5))

		"gain_block":
			if main.equipment_set_system and source_card:
				amount = main.equipment_set_system.modify_card_block(
					source_card, amount
				)
			_grant_card_block(player, amount)
			await get_tree().create_timer(0.2).timeout

		"add_card_to_hand":
			# Load Up: create `amount` copies of a card directly into the hand.
			var cid: String = str(effect.get("card", ""))
			if cid != "" and main.deck_manager.has_method("add_card_to_hand"):
				for _i in range(max(1, amount)):
					main.deck_manager.add_card_to_hand(cid)

		"discover":
			# Hearthstone-style: pop a 3-choose-1; the picked card enters the current hand.
			if main and main.has_method("open_discover"):
				await main.open_discover(
					str(effect.get("pool", "skill")),
					int(effect.get("count", 3)),
					bool(effect.get("free", false))
				)

		"gain_energy":
			player.pay_energy(-amount)
			main.show_notification(
				tr("UI_COMBAT_GAIN_ENERGY").format({"n": amount}), Color(0.9, 0.9, 0.3)
			)
			await get_tree().create_timer(0.1).timeout

		"draw_cards":
			main.deck_manager.draw_cards(amount)
			AudioManager.play_sfx("card_draw")
			main.show_notification(tr("UI_COMBAT_DRAW").format({"n": amount}), Color(0.7, 1.0, 0.7))
			await get_tree().create_timer(0.2).timeout

		"gain_attack_allowance":
			# +amount attacks this turn (only matters under the double-fire clip's
			# per-turn attack cap; no-op otherwise).
			if main.has_method("add_attack_allowance"):
				main.add_attack_allowance(amount)

		"restore_attack_allowance":
			# Reload card: refresh the attack allowance up to the per-turn cap (fire
			# again) without banking extra. No-op without the clip's cap.
			if main.has_method("restore_attack_allowance"):
				main.restore_attack_allowance()

		"deal_damage_all":
			var per_target_amount = amount + _consume_loaded_bonus(player, source_card)
			if main.equipment_set_system and source_card:
				per_target_amount = main.equipment_set_system.modify_card_damage(
					source_card, per_target_amount
				)
			for enemy in main.enemy_container.get_children():
				if (
					is_instance_valid(enemy)
					and not enemy.is_queued_for_deletion()
					and enemy.has_method("take_damage")
				):
					if _check_dodge(enemy):
						continue  # this enemy dodged
					var was_boss := bool(enemy.get("is_boss"))
					var feedback_tags := _feedback_tags_for(effect)
					var outgoing := calculate_attack_damage(
						per_target_amount, player, enemy, false, feedback_tags
					)
					await enemy.take_damage(outgoing, false, feedback_tags)
					if main.equipment_set_system and source_card:
						main.equipment_set_system.on_card_damage_resolved(
							source_card, enemy
						)
					apply_thorns_reflection(player, enemy)
					# Boss death ends the encounter and frees summons on the next frame.
					# Do not start another awaited hit on an add that is about to disappear.
					if main.is_game_over or (was_boss and int(enemy.get("health")) <= 0):
						break
			_register_player_attack()
			AudioManager.play_sfx("attack_slash")
			await get_tree().create_timer(0.3).timeout

		"scale_damage_by_attacks":
			# Damage scales with attacks the player has already played this turn.
			# JSON: {"type":"scale_damage_by_attacks", "base":2, "per":2}
			var base_dmg: int = int(effect.get("base", 0))
			var per: int = int(effect.get("per", 0))
			var count: int = 0
			if main and main.turn_manager:
				if str(effect.get("scope", "turn")) == "combat":
					count = int(main.turn_manager.attacks_played_this_combat)
				else:
					count = int(main.turn_manager.attacks_played_this_turn)
			var dynamic = base_dmg + per * count + _consume_loaded_bonus(player, source_card)
			if target and is_instance_valid(target) and target.has_method("take_damage"):
				if _check_dodge(target):
					pass  # attack negated by Dodge
				else:
					var feedback_tags := _feedback_tags_for(effect)
					var outgoing = calculate_attack_damage(
						dynamic, player, target, false, feedback_tags
					)
					await target.take_damage(outgoing, false, feedback_tags)
					_register_player_attack()
					apply_thorns_reflection(player, target)
			else:
				main.show_notification(tr("UI_COMBAT_NO_TARGET"), Color(1, 0.5, 0.5))
			await get_tree().create_timer(0.2).timeout

		"deal_damage_str_mult":
			# Damage scales purely off the player's STR (charged_shot: mult 2).
			# Does NOT receive the global +STR — it already scales off STR.
			# JSON: {"type":"deal_damage_str_mult", "mult":2}
			var mult: float = float(effect.get("mult", 1))
			var str_dmg: int = int(effect.get("base", 0))
			if player:
				str_dmg += int(player.get("strength") * mult)
			str_dmg += _consume_loaded_bonus(player, source_card)
			if target and is_instance_valid(target) and target.has_method("take_damage"):
				if _check_dodge(target):
					pass  # attack negated by Dodge
				else:
					if main.equipment_set_system and source_card:
						str_dmg = main.equipment_set_system.modify_card_damage(
							source_card, str_dmg
						)
					if card_mult != 1.0:
						str_dmg = int(str_dmg * card_mult)
					var feedback_tags := _feedback_tags_for(effect)
					var outgoing = calculate_attack_damage(
						str_dmg, player, target, false, feedback_tags
					)
					await target.take_damage(outgoing, false, feedback_tags)
					_register_player_attack()
					if main.equipment_set_system and source_card:
						main.equipment_set_system.on_card_damage_resolved(
							source_card, target
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
			# Intelligence boosts every status the player applies (+INT stacks).
			stacks += int(player.get("intelligence"))
			# Surge Servo: every Short Circuit application gets bonus stacks.
			if status == "short_circuit" and main.relic_effect_system:
				stacks += main.relic_effect_system.short_circuit_bonus_stacks()
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

		"apply_short_circuit_scaled":
			# Short Circuit = `amount` + an attribute (default Intelligence). Voltage
			# Tear doubles the application when the target already has stored charge.
			var attr: String = str(effect.get("attr", "intelligence"))
			var attr_mult: int = int(effect.get("attr_mult", 1))
			var circuit_stacks: int = (
				int(effect.get("amount", 0)) + int(player.get(attr)) * attr_mult
			)
			if bool(effect.get("double_if_short_circuited", false)):
				if target and is_instance_valid(target) and target.has_method("get_status_stacks"):
					if target.get_status_stacks("short_circuit") > 0:
						circuit_stacks *= 2
			# Surge Servo and friends still add their flat bonus.
			if main.relic_effect_system:
				circuit_stacks += main.relic_effect_system.short_circuit_bonus_stacks()
			if target and is_instance_valid(target) and target.has_method("add_status"):
				target.add_status("short_circuit", circuit_stacks)
				main.show_notification(
					tr("UI_COMBAT_APPLIED_STATUS").format(
						{
							"status": STATUS_SYS.format_name_localized("short_circuit"),
							"n": circuit_stacks,
						}
					),
					Color(0.2, 0.92, 1.0)
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
			# Intelligence boosts every status the player applies (+INT stacks).
			stacks += int(player.get("intelligence"))
			# Surge Servo: every Short Circuit application gets bonus stacks.
			if status == "short_circuit" and main.relic_effect_system:
				stacks += main.relic_effect_system.short_circuit_bonus_stacks()
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
			# Direct HP loss bypasses Block and cannot be dodged.
			if player and player.has_method("lose_hp"):
				player.lose_hp(amount)
				main.show_notification(
					tr("UI_COMBAT_LOSE_HP").format({"n": amount}), Color(0.85, 0.3, 0.3)
				)
			await get_tree().create_timer(0.15).timeout

		"lose_gold":
			# Curse gold-drain (Leaking Wealth). spend_gold clamps at 0 (no-op if broke).
			RunManager.spend_gold(amount)
			main.show_notification(
				tr("UI_COMBAT_LOSE_GOLD").format({"n": amount}), Color(0.85, 0.7, 0.3)
			)

		"add_curse_to_deck":
			# Permanent curse onto the run deck (for future double-edged cards).
			var curse_id: String = str(effect.get("card", effect.get("curse", "radiation_dust")))
			for _i in range(maxi(1, amount)):
				RunManager.add_card_to_deck(curse_id)

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

		"overload":
			# One global rule: every live enemy discharges all stored Short Circuit.
			# Cards may amplify that discharge or convert its actual HP damage into
			# Block without introducing another Overload effect type.
			var overloaded_any := false
			var critical_any := false
			var total_damage_dealt := 0
			var charge_multiplier := maxi(1, int(effect.get("charge_multiplier", 1)))
			for enemy in main.enemy_container.get_children():
				if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
					continue
				var consumed := _consume_short_circuit(enemy)
				if consumed <= 0 or not enemy.has_method("take_damage"):
					continue
				overloaded_any = true
				var discharged := consumed * charge_multiplier
				var overload := _short_circuit_overload(discharged, player)
				var critical := bool(overload.get("critical", false))
				critical_any = critical_any or critical
				var overload_damage := int(overload.get("damage", discharged))
				# Status feedback is detached, so calculate the resolved HP damage
				# from the pre-hit health/block values before take_damage returns.
				var hp_before := int(enemy.get("health"))
				var block_before := int(enemy.get("block"))
				total_damage_dealt += mini(hp_before, maxi(0, overload_damage - block_before))
				await enemy.take_damage(
					overload_damage,
					false,
					{
						"source": "status",
						"status": "short_circuit",
						"critical": critical,
						"heavy": discharged >= 12,
					}
				)
				if main.is_game_over:
					break
			if overloaded_any:
				AudioManager.play_sfx(
					"crit" if critical_any else "attack_hit",
					-1.5 if critical_any else -2.0,
					1.12,
					0.03
				)
			else:
				main.show_notification(tr("UI_COMBAT_NO_SHORT_CIRCUIT"), Color(0.4, 0.85, 1.0))
			if bool(effect.get("gain_block_equal_damage", false)) and total_damage_dealt > 0:
				_grant_card_block(player, total_damage_dealt)
			await get_tree().create_timer(0.2).timeout

		"deal_damage_block_mult":
			# Body Slam — deal damage equal to current Block × mult. Scales off the
			# CON-driven block pool, so it does NOT receive the global +STR.
			var bmult: float = float(effect.get("mult", 1))
			var block_dmg: int = int(player.get("block") * bmult) if player else 0
			block_dmg += _consume_loaded_bonus(player, source_card)
			if target and is_instance_valid(target) and target.has_method("take_damage"):
				if _check_dodge(target):
					pass  # attack negated by Dodge
				else:
					if main.equipment_set_system and source_card:
						block_dmg = main.equipment_set_system.modify_card_damage(
							source_card, block_dmg
						)
					if card_mult != 1.0:
						block_dmg = int(block_dmg * card_mult)
					var feedback_tags := _feedback_tags_for(effect)
					var outgoing = calculate_attack_damage(
						block_dmg, player, target, false, feedback_tags
					)
					await target.take_damage(outgoing, false, feedback_tags)
					_register_player_attack()
					apply_thorns_reflection(player, target)
			else:
				main.show_notification(tr("UI_COMBAT_NO_TARGET"), Color(1, 0.5, 0.5))
			await get_tree().create_timer(0.2).timeout

		"gain_gold":
			# Card gold. `max_per_combat` caps triggers (battle_scene).
			if main and main.has_method("try_gain_gold"):
				main.try_gain_gold(amount, int(effect.get("max_per_combat", 0)))
			await get_tree().create_timer(0.1).timeout

		"heal":
			# Card self-heal.
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


## Increment the per-turn attack counter used by combo cards like Cascade.
func _register_player_attack() -> void:
	if main and main.turn_manager:
		main.turn_manager.attacks_played_this_turn += 1
		main.turn_manager.attacks_played_this_combat += 1


func _make_fx_sprite(texture: Texture2D, pos: Vector2, sprite_scale: Vector2) -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.global_position = pos
	sprite.scale = sprite_scale
	sprite.z_index = 80
	main.add_child(sprite)
	return sprite

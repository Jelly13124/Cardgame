extends RefCounted

## Runs one combat (STS2 CombatManager): builds the state from a setup, drives
## rounds and turns, validates and queues card plays, tool uses and End Turn,
## resolves cards through the effect registry, runs the enemy turn and decides
## the outcome from the state. No scene tree: everything shown or waited for
## goes through `presenter` (the null presenter when headless). It is also the
## `services` object effect handlers and listeners receive.

const COMBAT_STATE = preload("uid://cje4i5v1ynjyn")  # res://core/combat/combat_state.gd
const COMBAT_PRESENTER = preload("uid://d2bnp6o5g3mb6")  # res://core/combat/combat_presenter.gd
const COMBAT_SERVICES = preload("uid://bcjfi8umolkqg")  # res://core/combat/combat_services.gd
const COMBAT_EFFECTS = preload("uid://do16of5onpg33")  # res://core/combat/combat_effects.gd
const ACTION_QUEUE = preload("uid://bseuowesln3j7")  # res://core/combat/action_queue.gd
const COMBAT_SOURCE = preload("uid://jgs131055xrk")  # res://core/combat/combat_source.gd
const CARD_PLAY = preload("uid://bxaw24a7fumhm")  # res://core/combat/card_play.gd
const EFFECT_CONTEXT = preload("uid://bx2g3askncfr6")  # res://core/effects/effect_context.gd
const HOOK_VALUE = preload("uid://npewr2krgrm6")  # res://core/combat/hook_value.gd
const CARD_INSTANCE = preload("uid://c50mv4hudoncd")  # res://core/combat/card_instance.gd
const MONSTERS = preload("uid://dvu3etytjqum8")  # res://core/combat/monsters.gd
const ENEMY_TURN = preload("uid://d4np8yrt1ml3v")  # res://core/combat/enemy_turn.gd
const RELIC_LISTENERS = preload("uid://b4d2o08tofxey")  # res://core/combat/relic_listeners.gd
const EQUIPMENT_SET = preload("uid://b3s8io84xovx7")  # res://core/listeners/equipment_set.gd
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const CARD_UPGRADE = preload("uid://d2e2bfj6oa3yp")  # res://core/run/card_upgrade.gd
const DISCOVER_POOL = preload("uid://c76axesxo6wit")  # res://core/run/card_pools.gd

## The fight ended: "victory" or "defeat".
signal combat_ended(outcome: String)
## A play was committed (energy paid) — once per play, not per Replay pass.
signal card_played(card: RefCounted)
## An enemy died (kill rewards, bounty).
signal enemy_died(creature: RefCounted)
## A creature joined the fight (the encounter, then summons).
signal creature_added(creature: RefCounted)
signal round_changed(round_number: int)
signal turn_started(side: String)

var state = COMBAT_STATE.new()
var presenter = COMBAT_PRESENTER.new()
var action_queue = ACTION_QUEUE.new()

# Wired by combat_services.install().
var combat_hooks: RefCounted
var combat_commands: RefCounted
var effect_registry: RefCounted
var crit_rules: RefCounted
var relic_effect_system: RefCounted = null
var equipment_set_system: RefCounted = null

## Monster ids spawned at the first player turn.
var encounter: Array = []
var _deck: Array = []
var _enemy_spawned := false
var _summon_cursor: int = 0
## End Turn was pressed and its action has not finished the turn yet.
var _ending_turn := false
## The play under resolution (it routes normally even if it wins the fight).
var _resolving: RefCounted = null

var player:
	get:
		return state.player
var is_game_over: bool:
	get:
		return state.is_over()


## `config`: {player: creature, deck: [id | {card_id, uid, upgraded}],
## encounter: [monster id], relics: bool (held relics and equipment sets
## listen; default true)}.
func setup(config: Dictionary) -> void:
	state.player = config["player"]
	encounter = config.get("encounter", [])
	if bool(config.get("relics", true)):
		relic_effect_system = RELIC_LISTENERS.new()
		relic_effect_system.setup(self)
		equipment_set_system = EQUIPMENT_SET.new()
		equipment_set_system.setup(self)
	COMBAT_SERVICES.install(self)
	combat_commands.attach(state.player)
	state.player.died.connect(_on_player_died)
	state.piles.rng = RunManager.rng("shuffle")
	_deck = config.get("deck", [])


## Battle start: start-of-combat listeners, the shuffled draw pile, round 1.
func start() -> void:
	prepare()
	await begin()


## Start-of-combat listeners and the shuffled draw pile.
func prepare() -> void:
	combat_hooks.react("before_combat_start")
	var cards: Array = []
	for entry in _deck:
		var card = make_card(entry)
		if card != null:
			cards.append(card)
	state.piles.fill_draw(cards)
	presenter.refresh()


## Round 1 starts with the player's turn.
func begin() -> void:
	state.current_round = 0
	state.attacks_played_this_turn = 0
	state.attacks_played_this_combat = 0
	state.is_player_turn = true
	await _start_round()


## A card instance for a run deck entry (an id, or {card_id, uid, upgraded}).
static func make_card(entry: Variant) -> RefCounted:
	var id := str(entry) if typeof(entry) == TYPE_STRING else str(entry.get("card_id", ""))
	if not MODEL_DB.has("card", id):
		push_error("CombatManager: unknown card '%s'" % id)
		return null
	var info: Dictionary = MODEL_DB.mutable("card", id)
	var uid := ""
	var upgraded := false
	if typeof(entry) == TYPE_DICTIONARY:
		uid = str(entry.get("uid", ""))
		upgraded = bool(entry.get("upgraded", false))
		if upgraded:
			info = CARD_UPGRADE.resolve(info)
	return CARD_INSTANCE.make(id, info, uid, upgraded)


# ─── Turns ────────────────────────────────────────────────────────────────────


func _start_round() -> void:
	state.current_round += 1
	if state.is_player_turn:
		state.attacks_played_this_turn = 0
	round_changed.emit(state.current_round)
	if state.is_player_turn:
		await _start_player_turn()


func _start_player_turn() -> void:
	if is_game_over:
		return
	presenter.sfx("turn_start")
	state.player.start_turn()
	if is_game_over:
		return
	# Reset the per-turn guaranteed-first-attack Crit (Deadeye Crit Clip).
	combat_hooks.notify("reset_turn_state", null)
	# Attack allowance for the new turn (double-fire clip arms it).
	var round_number: int = state.current_round
	state.attack_limit_per_turn = int(
		combat_hooks.compute("modify_attack_limit", HOOK_VALUE.make(0, {"round": round_number}))
	)
	if state.attack_limit_per_turn > 0 and round_number == 1:
		state.attack_limit_per_turn = int(
			combat_hooks.compute("modify_attack_limit_first_turn", HOOK_VALUE.make(state.attack_limit_per_turn))
		)
	state.attacks_left_this_turn = state.attack_limit_per_turn
	_update_attack_allowance()
	# Turn energy listeners (ascension Cold Start: -1 on the first turn).
	var energy_delta := int(combat_hooks.compute("modify_turn_energy", HOOK_VALUE.make(0, {"round": round_number})))
	if energy_delta < 0:
		state.player.pay_energy(-energy_delta)
	await combat_hooks.react("after_turn_start", "player", state.current_round)
	if is_game_over:
		return
	presenter.refresh()
	presenter.update_polarity()
	_spawn_encounter()
	_ending_turn = false
	turn_started.emit("player")
	presenter.refresh()
	draw_cards(3)


## End Turn: queued behind every play already made; holds the queue through the
## enemy turn until the player's next turn has started.
func request_end_turn() -> bool:
	if _ending_turn or not state.is_player_turn or is_game_over:
		return false
	_ending_turn = true
	presenter.refresh()
	action_queue.enqueue("end_turn", _end_turn_action)
	return true


func _end_turn_action() -> void:
	if is_game_over or not state.is_player_turn:
		return
	# Curse penalties: each in-hand curse's end_turn_in_hand effects hit the
	# player before the hand is discarded.
	for card in state.piles.hand.cards.duplicate():
		if is_game_over:
			break
		var curse_source = COMBAT_SOURCE.make("card", "player", state.player, card)
		for eff in card.card_info.get("end_turn_in_hand", []):
			if typeof(eff) == TYPE_DICTIONARY:
				await execute_effect(eff, state.player, curse_source)
	if is_game_over:
		return
	var discarded: Array = state.piles.discard_hand()
	if not discarded.is_empty():
		await presenter.hand_discarded(discarded)
	if is_game_over:
		return
	_end_side_turn("player")
	state.is_player_turn = false
	if is_game_over:
		return
	turn_started.emit("enemy")
	await ENEMY_TURN.run(self)
	if is_game_over:
		return
	_end_side_turn("enemy")
	state.is_player_turn = true
	await _start_round()


## A side's turn ended: Intangible on the other side lasts until now; the
## player's end-of-turn statuses tick.
func _end_side_turn(side: String) -> void:
	if side == "player":
		for enemy in state.living_enemies():
			enemy.status_system.on_opponent_turn_end(enemy)
		state.player.end_turn()
	else:
		state.player.status_system.on_opponent_turn_end(state.player)
	presenter.refresh()


## Cards and tools are used on the player's own turn only, and not after End
## Turn was pressed.
func accepts_player_input() -> bool:
	return state.is_player_turn and not _ending_turn and not is_game_over


# ─── Enemies ──────────────────────────────────────────────────────────────────


func _spawn_encounter() -> void:
	if _enemy_spawned:
		return
	_enemy_spawned = true
	for enemy_id in encounter:
		var enemy = add_enemy(MONSTERS.create(str(enemy_id)))
		if enemy.is_boss:
			state.encounter_has_boss = true


func add_enemy(enemy: RefCounted) -> RefCounted:
	state.enemies.append(enemy)
	combat_commands.attach(enemy)
	enemy.died.connect(_on_enemy_died.bind(enemy))
	creature_added.emit(enemy)
	presenter.creature_added(enemy)
	return enemy


## `summon` move: `count` adds cycling through `enemy_ids`, stopping at the
## field cap. Returns how many joined.
func summon_adds(enemy: Object, action: Dictionary) -> int:
	var enemy_ids: Array = action.get("enemy_ids", [])
	if enemy_ids.is_empty():
		return 0
	var summoned := 0
	for _n in range(int(action.get("count", 1))):
		if state.field_count() >= state.MAX_ENEMIES_ON_FIELD:
			break
		var add_id := str(enemy_ids[_summon_cursor % enemy_ids.size()])
		_summon_cursor += 1
		var add = add_enemy(MONSTERS.create(add_id))
		show_notification(
			TranslationServer.translate("UI_COMBAT_ENEMY_APPEARED").format({"name": add.enemy_name}),
			Color(1, 0.3, 0.3)
		)
		summoned += 1
	if summoned > 0:
		show_notification(
			TranslationServer.translate("UI_COMBAT_ENEMY_SUMMONS").format({"name": enemy.get("enemy_name")}),
			Color(0.8, 0.4, 1.0)
		)
	return summoned


## Boss-death rule: the boss dying ends the fight even with adds alive; the
## adds leave the field (no kill rewards). Otherwise the last death wins.
func _on_enemy_died(enemy: RefCounted) -> void:
	if is_game_over:
		return
	enemy_died.emit(enemy)
	if state.encounter_has_boss and not state.living_boss_present():
		for add in state.living_enemies():
			add.removed = true
			presenter.creature_removed(add)
		_end_combat("victory")
	elif state.living_enemies().is_empty():
		_end_combat("victory")


func _on_player_died() -> void:
	_end_combat("defeat")


func _end_combat(outcome: String) -> void:
	if is_game_over:
		return
	state.outcome = outcome
	action_queue.clear_pending()
	var waiting: Array = state.piles.play.cards.filter(func(c): return c != _resolving)
	for card in waiting:
		card.in_play = false
		state.piles.move(card, "discard")
	if outcome == "victory":
		combat_hooks.react("after_combat_victory")
	presenter.cards_dropped(waiting)
	presenter.combat_ended(outcome)
	combat_ended.emit(outcome)


## Debug kill: an unblockable lethal hit outside the pipeline.
func debug_kill(enemy: Object) -> void:
	var source = COMBAT_SOURCE.make("debug", "player", null)
	await combat_commands.raw_hit(source, enemy, 99999, {"source": "debug", "heavy": true, "critical": false})


# ─── Cards ────────────────────────────────────────────────────────────────────


## Whether `card` can be played right now (the playable outline): in hand, the
## player's turn, affordable, not a curse / unplayable, and for attacks an
## attack left under the double-fire clip.
func can_play_card(card: RefCounted) -> bool:
	if card == null or not state.piles.hand.has(card) or card.in_play:
		return false
	if not accepts_player_input() or not can_afford(card):
		return false
	if card.is_unplayable():
		return false
	return card.type() != "attack" or state.attack_limit_per_turn <= 0 or state.attacks_left_this_turn > 0


func can_afford(card: RefCounted) -> bool:
	return not is_game_over and state.player.energy >= card.cost()


## Plays `card` at `target` (an enemy creature for targeted cards, else null).
## Checks and costs happen now; the effects resolve through the action queue,
## after every play made before. Returns false (and the card goes back to the
## hand) when the play is refused.
func play_card(card: RefCounted, target: Object) -> bool:
	if is_game_over or card == null or card.in_play:
		return false
	if not state.piles.hand.has(card) or not accepts_player_input():
		return _refuse(card, "")
	if card.is_unplayable():
		return _refuse(card, "UI_BATTLE_CURSE_UNPLAYABLE", Color(0.72, 0.5, 0.85))
	if card.requires_enemy_target():
		if target == null or not combat_commands.is_alive(target):
			return _refuse(card, "UI_BATTLE_MUST_TARGET_ENEMY", Color(0.8, 0.4, 0.4))
	if not can_afford(card):
		return _refuse(card, "UI_BATTLE_NOT_ENOUGH_ENERGY", Color(1, 0.2, 0.2))
	if card.type() == "attack" and state.attack_limit_per_turn > 0:
		if state.attacks_left_this_turn <= 0:
			return _refuse(card, "UI_BATTLE_NO_ATTACKS_LEFT", Color(0.85, 0.55, 0.3))
		state.attacks_left_this_turn -= 1
		_update_attack_allowance()
	state.player.pay_energy(card.cost())
	var type: String = card.type()
	presenter.sfx("card_play_" + type if type in ["attack", "skill", "power"] else "card_play")
	card.in_play = true
	state.piles.move(card, "play")
	card_played.emit(card)
	combat_hooks.react("after_card_played", card.card_info)
	presenter.card_play_started(card)
	action_queue.enqueue("play_card", _resolve_played_card.bind(card, target))
	return true


func _refuse(card: RefCounted, key: String, color := Color.WHITE) -> bool:
	presenter.sfx("error")
	if key != "":
		show_notification(TranslationServer.translate(key), color)
	presenter.card_play_refused(card)
	return false


## Queued half of a play: the card moves to the play position, resolves, then
## goes to the discard or exhaust pile.
func _resolve_played_card(card: RefCounted, target: Object) -> void:
	if is_game_over:
		return  # dropped with the other waiting plays
	_resolving = card
	await presenter.card_resolving(card)
	if is_game_over:
		# The fight ended while the card slid to the play position: drop it too.
		_resolving = null
		card.in_play = false
		state.piles.move(card, "discard")
		await presenter.cards_dropped([card])
		return
	var safe_target: Object = target if combat_commands.is_alive(target) else null
	await resolve_card_effect(card, safe_target)
	_resolving = null
	card.in_play = false
	# The card's flight to its pile is not waited for: the next play may start
	# while it flies (the view puts it where the piles say once it lands).
	if card.exhausts():
		state.piles.move(card, "exhaust")
		combat_hooks.react("after_card_exhausted", null)
		state.exhausted_ids.append(card.model_id)
		presenter.card_finished(card, "exhaust")
	else:
		state.piles.move(card, "discard")
		presenter.card_finished(card, "discard")
	presenter.refresh()


## Resolve a played card: 1 + Replay passes, each running the card's effects,
## its polarity matched bonus and the after-attack reaction. An Attack counts
## once toward "attacks played", however many passes or hits it has.
func resolve_card_effect(card: RefCounted, target: Object) -> void:
	var effects: Array = card.card_info.get("effects", [])
	var type: String = card.type()
	if effects.is_empty():
		push_error("CombatManager: card '%s' has no effects. Card JSON must define an `effects` array." % card.model_id)
		assert(false, "CombatManager: card '%s' has no effects." % card.model_id)
		return
	var play = CARD_PLAY.new()
	play.card = card
	play.target = target
	play.dealer = state.player
	var source = COMBAT_SOURCE.make("card", "player", state.player, card)
	for _i in range(1 + _replay_count(card, type)):
		if combat_over():
			break
		# The target can die between passes; null = "no target" (the hit fizzles).
		await _resolve_card_once(card, effects, type, _live(target), source, play)
	if type == "attack":
		state.attacks_played_this_turn += 1
		state.attacks_played_this_combat += 1


func _resolve_card_once(card: RefCounted, effects: Array, type: String, target: Object, source, play) -> void:
	if type == "attack" and target != null:
		await presenter.card_windup(state.player, target)
	for effect in effects:
		if combat_over():
			return
		await execute_effect(effect, _live(target), source, play)
	# Polarity matched bonus — after the normal effects so a flip earlier in
	# this card has already applied.
	if state.player.is_card_matched(str(card.card_info.get("polarity", "neutral"))):
		var bonus = card.card_info.get("matched_bonus", [])
		if bonus is Array:
			for be in bonus:
				if typeof(be) == TYPE_DICTIONARY and not combat_over():
					await execute_effect(be, _live(target), source, play)
	if type == "attack" and _live(target) != null and not combat_over():
		await combat_hooks.after_attack({"source": source, "dealer": state.player, "target": target})


## Innate `replay` plus relic replays (double-fire clip → +1 for attacks).
func _replay_count(card: RefCounted, type: String) -> int:
	var n: int = int(card.card_info.get("replay", 0))
	if type == "attack":
		n += int(combat_hooks.compute("modify_attack_replays", HOOK_VALUE.make(0)))
	return n


## True once the fight is decided (between effects, a card stops early).
func combat_over() -> bool:
	return is_game_over or state.living_enemies().is_empty() and _enemy_spawned


func _live(target: Object) -> Object:
	return target if combat_commands.is_alive(target) else null


## Run one effect for `source` (card, tool, relic, set or curse) through the
## effect registry. `target` may be null.
func execute_effect(effect: Dictionary, target: Object, source, play = null) -> void:
	if is_game_over:
		return
	var actor: Object = source.dealer if source and source.dealer else state.player
	var ctx = EFFECT_CONTEXT.make("combat", source, actor, _live(target), self, play)
	await effect_registry.execute(ctx, effect)


## Damage `card` would deal to `target` in one pass (preview); -1 when it deals none.
func preview_card_damage(card: Object, target: Object) -> int:
	return COMBAT_EFFECTS.preview_card_damage(self, card, target)


# ─── Tools ────────────────────────────────────────────────────────────────────


## Use a tool: its (already scaled) effects run in the action queue, after
## every play made before. A tool that needs an enemy fizzles (unused) when its
## target died meanwhile. `on_done(used: bool)` runs when it finished.
func use_tool(tool_id: String, effects: Array, target: Object, needs_target: bool, on_done: Callable) -> void:
	action_queue.enqueue(
		"use_tool",
		func() -> void:
			var used := false
			if not is_game_over:
				if needs_target and not combat_commands.is_alive(target):
					presenter.sfx("error")
				else:
					presenter.sfx("ui_click")
					var source = COMBAT_SOURCE.make("tool", "player", state.player, null, tool_id)
					for e in effects:
						if combat_over():
							break
						await execute_effect(e, target, source)
					used = true
			if on_done.is_valid():
				on_done.call(used)
	)


# ─── Piles ────────────────────────────────────────────────────────────────────


## Draw `count` cards (reshuffling the discard pile when needed).
func draw_cards(count: int) -> void:
	if count <= 0 or is_game_over:
		return
	var events: Array = state.piles.draw_cards(count)
	presenter.refresh()
	await presenter.cards_drawn(events)


## A new card straight into the hand (Load Up's Reloads, discover, relics).
## A full hand takes no more: returns null.
func add_card_to_hand(card_id: String) -> RefCounted:
	if state.piles.hand.size() >= state.piles.HAND_LIMIT:
		show_notification("HAND FULL", Color(1, 0.4, 0.4))
		return null
	var card = make_card(card_id)
	if card == null:
		return null
	state.piles.add_new(card, "hand")
	presenter.card_created(card, "hand")
	presenter.refresh()
	return card


## A new card shuffled into the draw pile for this combat (an enemy's curse).
func add_card_to_draw(card_id: String) -> void:
	var card = make_card(card_id)
	if card == null:
		return
	state.piles.add_new(card, "draw", true)
	presenter.card_created(card, "draw")
	presenter.refresh()


## Discover: 3-choose-1 from `pool`; the pick joins the hand (free = costs 0
## this combat). Returns the picked id, or "".
func open_discover(pool: String, count: int, free: bool) -> String:
	var ids: Array = DISCOVER_POOL.roll(pool, count, MetaProgress.get_unlocked_card_pool())
	if ids.is_empty():
		show_notification(TranslationServer.translate("UI_DISCOVER_EMPTY"), Color(0.85, 0.6, 0.4))
		return ""
	var picked: String = await presenter.discover(ids, pool)
	if picked == "":
		return ""
	var card = add_card_to_hand(picked)
	if free and card != null:
		card.cost_override = 0
		presenter.refresh()
	presenter.sfx("card_draw")
	return picked


# ─── Attack allowance (double-fire clip) ──────────────────────────────────────


## +n attacks this turn. No-op when the limit isn't armed.
func add_attack_allowance(n: int) -> void:
	if state.attack_limit_per_turn <= 0:
		return
	state.attacks_left_this_turn += n
	_update_attack_allowance()


## Reload: back up to the per-turn cap (never past it); Reload listeners
## (Covering Reload) fire either way.
func restore_attack_allowance() -> void:
	presenter.sfx("reload")  # bare-ok: sfx key
	combat_hooks.react("after_reload", null)
	if state.attack_limit_per_turn <= 0:
		return
	state.attacks_left_this_turn = maxi(state.attacks_left_this_turn, state.attack_limit_per_turn)
	_update_attack_allowance()


## The allowance shows as the player's "bullet" status.
func _update_attack_allowance() -> void:
	var p = state.player
	p.status_system.remove_status("bullet", p)
	if state.attack_limit_per_turn > 0 and state.attacks_left_this_turn > 0:
		p.status_system.add_status("bullet", state.attacks_left_this_turn, p)


# ─── Services for effects and listeners ───────────────────────────────────────


## Card gold; `cap > 0` limits the triggers per combat.
func try_gain_gold(amount: int, cap: int) -> void:
	if cap > 0 and state.gold_effect_triggers >= cap:
		return
	if cap > 0:
		state.gold_effect_triggers += 1
	RunManager.add_resources(amount, 0)
	show_notification(TranslationServer.translate("UI_COMBAT_WEALTHY").format({"n": amount}), Color(1.0, 0.82, 0.29))


func show_notification(text: String, color: Color = Color.WHITE) -> void:
	presenter.notify(text, color)


func update_polarity_hud() -> void:
	presenter.update_polarity()


func show_set_callout(set_id: String, color: Color) -> void:
	presenter.set_callout(set_id, color)

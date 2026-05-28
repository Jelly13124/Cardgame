extends Node

# --- Node References ---
@onready var card_manager = $CardManager
@onready var card_factory = $CardManager/MyCardFactory
@onready var hand = $CardManager/Hand
@onready var deck = $CardManager/Deck
@onready var discard_pile = $CardManager/DiscardPile
@onready var player = $Player
@onready var enemy_container = $EnemyContainer
@onready var turn_manager = $TurnManager
@onready var combat_engine = $CombatEngine
@onready var enemy_ai = $EnemyAI
@onready var ui_manager = $BattleUIManager
@onready var end_round_button = $EndRoundButton

var deck_manager: Node  # DeckManager (deck_manager.gd) instance
var relic_effect_system: RefCounted  # RelicEffectSystem (relic_effect_system.gd) instance
var equipment_set_system: RefCounted  # EquipmentSetSystem (equipment_set_system.gd) instance
var current_resolving_card: Node = null  # Set by play_spell during _apply_effect; combat_engine reads it.
# Typed via the preloaded CARD_ANIMATOR_SCRIPT below — kept as Node so this
# file parses even before Godot has scanned the class_name registry.
var card_animator: Node  # CardAnimator (card_animator.gd) instance

# --- Game State ---
var is_game_over:  bool    = false
var is_targeting:  bool    = false
var targeting_card: Control = null
var targeting_arrow: Node2D = null
var hovered_unit:  Node    = null

const TARGETING_ARROW_SCRIPT = preload("res://battle_scene/targeting_arrow.gd")
const RELIC_EFFECT_SYSTEM = preload("res://battle_scene/relic_effect_system.gd")
const EQUIPMENT_SET_SYSTEM = preload("res://battle_scene/equipment_set_system.gd")
const CARD_ANIMATOR_SCRIPT = preload("res://battle_scene/card_animator.gd")
const DECK_MANAGER_SCRIPT = preload("res://battle_scene/deck_manager.gd")
const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
# NOTE: map_scene + home_base_scene are loaded lazily at the call site
# (not preloaded) because doing so would create a cyclic dep
# (map → battle → map) and the editor's static analysis chokes.
const HOME_BASE_PATH := "res://run_system/ui/home_base_scene.tscn"
const MAP_SCENE_PATH := "res://run_system/ui/map_scene.tscn"
const LOOT_REWARD_SCENE = preload("res://run_system/ui/loot_reward.tscn")
const EXTRACT_CHOICE_MODAL_SCRIPT = preload("res://run_system/ui/extract_choice_modal.gd")

const BOSS_VICTORY_CORE := 150
## Extract reward overrides per mid-act boss floor (keyed by RunManager.current_floor).
## Any boss floor NOT in this table falls back to a formula so adding a new
## entry to RunManager.BOSS_BY_FLOOR can't silently route to the final-boss
## "game complete" branch.
const EXTRACT_REWARDS := {
	4: {"continue": 25, "extract": 50},
	8: {"continue": 50, "extract": 90},
}


## Returns the {continue, extract} reward dict for a mid-act boss floor, or
## {} if `floor_num` is the final boss floor (no extract choice — full victory).
func _extract_rewards_for(floor_num: int) -> Dictionary:
	if floor_num == _final_boss_floor():
		return {}
	if EXTRACT_REWARDS.has(floor_num):
		return EXTRACT_REWARDS[floor_num]
	# Fallback formula so a new mid-boss added to BOSS_BY_FLOOR can't slip
	# through to the final-boss branch. Scales roughly with the existing
	# floor-4 / floor-8 values (~6 continue, ~12 extract per floor index).
	return {
		"continue": max(25, floor_num * 6),
		"extract":  max(50, floor_num * 12),
	}


func _final_boss_floor() -> int:
	var keys: Array = RunManager.BOSS_BY_FLOOR.keys()
	keys.sort()
	return int(keys[-1]) if keys.size() > 0 else -1

func _ready():
	print("BATTLE STARTING (STS Layout)")
	card_manager.debug_mode = false
	Engine.time_scale = 1.0
	
	# Instantiate DeckManager
	deck_manager = DECK_MANAGER_SCRIPT.new()
	deck_manager.battle_scene = self
	deck_manager.deck = deck
	deck_manager.discard_pile = discard_pile
	deck_manager.hand = hand
	deck_manager.card_factory = card_factory
	add_child(deck_manager)

	# Instantiate CardAnimator — owns play / discard / exhaust tweens
	card_animator = CARD_ANIMATOR_SCRIPT.new()
	card_animator.setup(self)
	add_child(card_animator)

	# Apply textured wasteland button skin to the End Round button.
	if end_round_button:
		T.apply_button_theme(end_round_button)
		
	# Connect TurnManager
	turn_manager.round_changed.connect(_on_round_changed)
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.turn_ended.connect(_on_turn_ended)
	
	# Connect Player Signals
	if player:
		player.health_changed.connect(_on_player_health_changed)
		player.energy_changed.connect(_on_player_energy_changed)
		player.block_changed.connect(_on_player_block_changed)
		player.stats_changed.connect(_update_ui_labels)
		player.status_changed.connect(_update_ui_labels)
		player.died.connect(_game_over)
	
	# Combat Engine Signals
	combat_engine.victory_declared.connect(_victory)
	
	_start_new_game()
	
	set_process(true)

# ─── Input ────────────────────────────────────────────────────────────────────

## _input fires before any Control node.
## ONLY intercepts right-click during targeting — never keyboard events,
## so Q/E pile-viewer shortcuts can still reach BattleUIManager.
func _input(event: InputEvent) -> void:
	# Debug-only: right-click any enemy (outside targeting) → instant-kill.
	# Routes through the normal take_damage path so the died signal fires and
	# combat_engine declares victory once the last enemy is gone. Guarded on
	# OS.is_debug_build() so it's stripped from exported builds.
	if OS.is_debug_build() and not is_targeting and event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var mouse_pos = get_viewport().get_mouse_position()
		var enemy = _get_unit_at_position(mouse_pos)
		if enemy and is_instance_valid(enemy) and enemy.has_method("take_damage"):
			show_notification("DEBUG: killed %s" % enemy.name, Color(1, 0.4, 1))
			enemy.take_damage(99999)
			get_viewport().set_input_as_handled()
			return

	if not is_targeting:
		return
	# Only handle mouse buttons, never keyboard
	if not (event is InputEventMouseButton):
		return
	if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_spell_targeting()
		get_viewport().set_input_as_handled()
	elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if targeting_card and is_instance_valid(targeting_card):
			confirm_spell_targeting(targeting_card)
		else:
			_cancel_spell_targeting()
		get_viewport().set_input_as_handled()

# ─── Process ──────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if not is_targeting:
		if hovered_unit:
			_set_hover_effect(hovered_unit, false)
			hovered_unit = null
		return
	
	var mouse_pos = get_viewport().get_mouse_position()
	var unit_under_mouse = _get_unit_at_position(mouse_pos)
	
	if unit_under_mouse != hovered_unit:
		if hovered_unit: _set_hover_effect(hovered_unit, false)
		hovered_unit = unit_under_mouse
		if hovered_unit: _set_hover_effect(hovered_unit, true)
	
	if targeting_arrow and targeting_arrow.has_method("set_target_valid"):
		targeting_arrow.set_target_valid(hovered_unit != null)

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _set_hover_effect(unit: Node, active: bool) -> void:
	if not is_instance_valid(unit): return
	var scale_target = Vector2(1.2, 1.2) if active else Vector2(1.0, 1.0)
	var modulate_target = Color(1.5, 1.2, 1.2) if active else Color.WHITE
	var tween = create_tween().set_parallel(true)
	tween.tween_property(unit, "scale", scale_target, 0.1)
	tween.tween_property(unit, "modulate", modulate_target, 0.1)

## Returns the enemy node under a screen position (viewport coords).
## EnemyEntity sprite is AnimatedSprite2D: 64px × 3.0 scale = 192×192.
## Anchored at feet: local pos (0, -96) → spans x:[-96, 96], y:[-192, 0].
func _get_unit_at_position(pos: Vector2) -> Node:
	for enemy in enemy_container.get_children():
		if not is_instance_valid(enemy): continue
		var ep = enemy.global_position
		# Body rect matches the 192×192 scaled sprite anchored at feet
		var body_rect = Rect2(ep.x - 96, ep.y - 192, 192, 192)
		if body_rect.has_point(pos):
			return enemy
		# Fallback: catch clicks near the HUD/center area
		if ep.distance_to(pos) < 110.0:
			return enemy
	return null

func show_notification(text: String, color: Color = Color.WHITE):
	ui_manager.show_notification(text, color)

# ─── Turn Events ──────────────────────────────────────────────────────────────

func _on_turn_started(side: String) -> void:
	if is_game_over: return
	if side == "enemy":
		enemy_ai.execute_enemy_turn()
		return
	
	# Player turn start: reset block + energy via player.start_turn()
	player.start_turn()
	if is_game_over:
		return
	# Ascension A3+: first turn of each combat starts with -1 energy.
	if RunManager.ascension >= 3 and turn_manager.current_round == 1:
		player.pay_energy(1)
	if relic_effect_system:
		relic_effect_system.on_player_turn_started(player, turn_manager.current_round)
	if equipment_set_system:
		equipment_set_system.on_player_turn_started(player, turn_manager.current_round)
	_update_ui_labels()
	enemy_ai.spawn_enemy_units()
	
	if turn_manager.current_round == 1:
		deck_manager.first_round_draw()
	else:
		deck_manager.draw_cards(3)

## STS rule: at END of player turn, reset block/energy. Hand discard is handled
## upstream in `_on_end_round_button_pressed` so the animation fully completes
## before turn_manager switches sides.
func _on_turn_ended(side: String) -> void:
	if side == "player":
		player.end_turn()
		_update_ui_labels()


## End-of-turn discard cascade: each remaining hand card flies to the discard
## pile with a small stagger. Without this, dropping them straight into the
## discard pile (hide_cards=true) would make them vanish on the same frame
## they're added, with no visual cue that they were discarded.
func _animate_hand_discard(cards: Array) -> void:
	const STAGGER := 0.07
	const FLIGHT_DURATION := 0.36  # matches fly_to_discard tween length + buffer
	for i in range(cards.size()):
		var card = cards[i]
		if not is_instance_valid(card):
			continue
		# Detach from hand first so the surviving cards re-fan around the gap.
		if card.card_container and card.card_container.has_card(card):
			card.card_container.remove_card(card)
		# Fire-and-forget: each fly_to_discard runs in parallel via its own tween.
		card_animator.fly_to_discard(card)
		if i < cards.size() - 1:
			await _wait(STAGGER)
	# Wait for the LAST card's flight before parking everything in discard.
	await _wait(FLIGHT_DURATION)
	for card in cards:
		if is_instance_valid(card):
			discard_pile.add_card(card)
			card.modulate.a = 1.0  # restore alpha after fly_to_discard faded it

func _on_round_changed(_round: int) -> void: _update_ui_labels()
func _on_player_health_changed(_hp: int) -> void: _update_ui_labels()
func _on_player_energy_changed(_energy: int) -> void: _update_ui_labels()
func _on_player_block_changed(_block: int) -> void: _update_ui_labels()

func _update_ui_labels():
	if player:
		ui_manager.update_labels(player.energy, player.max_energy)
		refresh_hand_ui()
	# Player status (vulnerable etc.) affects every enemy's intent display.
	_refresh_all_enemy_intents()

## Tells every alive enemy to recompute its intent badge. Cheap; called on
## any UI refresh so weak/vulnerable changes show immediately.
func _refresh_all_enemy_intents() -> void:
	if not enemy_container: return
	for enemy in enemy_container.get_children():
		if is_instance_valid(enemy) and enemy.has_method("update_intent_display"):
			enemy.update_intent_display()

func refresh_hand_ui():
	for card in hand.get_cards():
		if card.has_method("update_display"):
			card.update_display()

## Initialise a new battle from RunManager state (or defaults if no run is active).
func _start_new_game():
	is_game_over = false

	relic_effect_system = RELIC_EFFECT_SYSTEM.new()
	relic_effect_system.setup(self)
	equipment_set_system = EQUIPMENT_SET_SYSTEM.new()
	equipment_set_system.setup(self)

	# ── Player HP & Attributes ──────────────────────────────────────────────
	if RunManager.is_run_active:
		player.max_health  = RunManager.max_health
		player.health      = RunManager.current_health
		var attrs = RunManager.player_attributes
		player.strength     = int(attrs.get("strength",     3))
		player.constitution = int(attrs.get("constitution", 3))
		player.intelligence = int(attrs.get("intelligence", 3))
		player.luck         = int(attrs.get("luck",         3))
		player.charm        = int(attrs.get("charm",        3))
		# Enemy roster comes from the map encounter data stored in RunManager
		if RunManager.current_encounter.size() > 0:
			enemy_ai.enemy_roster = RunManager.current_encounter

	# Snapshot active equipment set tiers (and apply start_battle_block)
	if equipment_set_system:
		equipment_set_system.on_battle_started(player)

	# ── Deck & Turn ──────────────────────────────────────────────────────────
	deck_manager.reset_deck()
	turn_manager.start_new_game()

func _on_end_round_button_pressed():
	if turn_manager.is_player_turn:
		# Discard hand BEFORE switching turns. turn_manager.end_turn() emits
		# turn_ended synchronously and immediately switches sides; awaiting an
		# animation inside the signal handler doesn't block that switch, so the
		# next player draw would race against the in-flight discard and see an
		# empty discard pile (breaking reshuffle when deck < draw count).
		var remaining = hand.get_cards().duplicate()
		var to_discard: Array = []
		for c in remaining:
			if is_instance_valid(c) and bool(c.card_info.get("retain", false)):
				continue
			to_discard.append(c)
		if to_discard.size() > 0:
			await _animate_hand_discard(to_discard)
		turn_manager.end_turn()

func _victory():
	if is_game_over: return
	is_game_over = true
	if relic_effect_system:
		relic_effect_system.on_combat_victory(player)
	# Victory path: persist HP without firing the death gate, even if the
	# player ended the fight at 0 HP (chip damage / mutual kill). Otherwise
	# modify_health(negative) would trigger _handle_run_loss → run_ended(false),
	# and the subsequent end_run_victory() at the boss branch would no-op.
	_write_hp_to_run_manager(false)
	# VICTORY! banner removed per UX feedback — the loot modal / extract
	# choice / home-base transition is sufficient signal that the fight is won.
	await get_tree().create_timer(3.0).timeout

	# Boss victory routing:
	#   - mid-act boss → extract choice modal (rewards from _extract_rewards_for)
	#   - final boss   → grant BOSS_VICTORY_CORE and return to home base
	#   - non-boss     → normal loot modal
	if RunManager.last_battle_node_type == "boss":
		var floor_num: int = RunManager.current_floor
		var rewards: Dictionary = _extract_rewards_for(floor_num)
		if not rewards.is_empty():
			_show_extract_choice(floor_num, rewards)
			return
		# Final boss path.
		MetaProgress.add_core(BOSS_VICTORY_CORE)
		RunManager.end_run_victory(BOSS_VICTORY_CORE, "victory")
		get_tree().change_scene_to_file(HOME_BASE_PATH)
		return
	_show_loot_modal()


func _show_extract_choice(floor_num: int, rewards: Dictionary) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 200
	add_child(canvas)
	var modal = EXTRACT_CHOICE_MODAL_SCRIPT.new()
	modal.floor_num = floor_num
	modal.reward_continue = int(rewards.get("continue", 0))
	modal.reward_extract = int(rewards.get("extract", 0))
	modal.chosen.connect(_on_extract_chosen.bind(rewards, canvas))
	canvas.add_child(modal)


func _on_extract_chosen(extract: bool, rewards: Dictionary, canvas: CanvasLayer) -> void:
	if is_instance_valid(canvas):
		canvas.queue_free()
	if extract:
		var earned: int = int(rewards.get("extract", 0))
		MetaProgress.add_core(earned)
		RunManager.end_run_victory(earned, "extracted")
		get_tree().change_scene_to_file(HOME_BASE_PATH)
	else:
		# Continue: grant push-on Core then drop into normal loot flow so
		# the player still gets gold + a card pick out of the boss kill.
		MetaProgress.add_core(int(rewards.get("continue", 0)))
		_show_loot_modal()


func _show_loot_modal() -> void:
	# Wrap in a CanvasLayer with high `layer` so the modal renders above
	# battle_scene's TopBar/Inspect/PileViewer CanvasLayers (layers 30/100/101)
	# AND eats mouse events so cards in hand don't react to hover.
	var canvas := CanvasLayer.new()
	canvas.layer = 200
	add_child(canvas)
	var modal = LOOT_REWARD_SCENE.instantiate()
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.closed.connect(_on_loot_closed.bind(canvas))
	canvas.add_child(modal)


func _on_loot_closed(canvas: CanvasLayer) -> void:
	if is_instance_valid(canvas):
		canvas.queue_free()
	get_tree().change_scene_to_file(MAP_SCENE_PATH)


func _game_over():
	if is_game_over: return
	is_game_over = true
	# Defeat path: route through the death gate so _handle_run_loss fires
	# and run_ended(false) is emitted.
	_write_hp_to_run_manager(true)
	# DEFEAT... banner removed per UX feedback — the player.health → 0 +
	# HUD bar drop + transition to home base communicates defeat clearly.
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file(HOME_BASE_PATH)

## Writes player.health back to RunManager so it persists between battles.
##   triggering_defeat=true  → defeat path: route through modify_health so the
##                              death gate fires (_handle_run_loss → run_ended(false))
##   triggering_defeat=false → victory / inter-battle path: write + emit signal
##                              directly, NEVER fire the death gate even at 0 HP.
##                              Critical: victory paths must use this so a chip-
##                              kill mutual-death doesn't pre-empt end_run_victory.
func _write_hp_to_run_manager(triggering_defeat: bool = false) -> void:
	if not (RunManager.is_run_active and player and is_instance_valid(player)):
		return
	var target_hp: int = clampi(int(player.health), 0, RunManager.max_health)
	if triggering_defeat:
		var delta: int = target_hp - RunManager.current_health
		RunManager.modify_health(delta)
	else:
		# Direct write + manual emit — bypasses death gate by design.
		RunManager.current_health = target_hp
		RunManager.emit_signal("health_changed", target_hp, RunManager.max_health)

func modify_player_attack_damage(amount: int, attacker: Node, defender: Node) -> int:
	if relic_effect_system:
		return relic_effect_system.modify_player_attack_damage(amount, attacker, defender)
	return amount

func modify_enemy_attack_damage(amount: int, attacker: Node, defender: Node) -> int:
	if relic_effect_system:
		return relic_effect_system.modify_enemy_attack_damage(amount, attacker, defender)
	return amount

# ─── Energy ───────────────────────────────────────────────────────────────────

func can_afford(cards: Array) -> bool:
	if is_game_over or not player: return false
	var total_cost = 0
	for card in cards: total_cost += int(card.card_info.get("cost", 0))
	return player.energy >= total_cost

func spend_energy(cards: Array) -> void:
	var total_cost = 0
	for card in cards: total_cost += int(card.card_info.get("cost", 0))
	player.pay_energy(total_cost)

# ─── Card Play ────────────────────────────────────────────────────────────────

## Play a card. target_node is the enemy to hit (null for skill/ability).
## Multiple cards can be in flight simultaneously — animations overlap. A
## per-card `_in_play` meta lock prevents the same card from being resolved
## twice (e.g. double-click, double drop).
func play_spell(card: Control, target_node: Node):
	if is_game_over: return
	if not is_instance_valid(card): return

	# Per-card lock — different cards can play in parallel, but the SAME
	# card can't be played twice before its first resolution finishes.
	if card.has_meta("_in_play"):
		return
	card.set_meta("_in_play", true)

	var type = card.card_info.get("type", "skill").to_lower()

	if type == "attack":
		if not target_node or not is_instance_valid(target_node):
			show_notification("MUST TARGET ENEMY", Color(0.8, 0.4, 0.4))
			hand.add_card(card)
			card.remove_meta("_in_play")
			return

	# Deduct cost; remove from current container if still tracked there
	spend_energy([card])
	if card.card_container and card.card_container.has_card(card):
		card.card_container.remove_card(card)

	card_animator.prepare_for_play(card)
	await card_animator.fly_to_play_area(card, target_node)

	# Resolve combat effects (may await animations). current_resolving_card
	# lets combat_engine + equipment_set_system identify the card behind each
	# effect (needed to know whether a gain_block came from a "skill" card etc.).
	current_resolving_card = card
	await combat_engine.resolve_card_effect(card, target_node, player)
	current_resolving_card = null

	# Release the per-card play lock NOW. The play is logically complete —
	# what's left below is pure animation/routing. If we don't release here,
	# the meta survives the trip through discard → reshuffle → deck → hand,
	# and the card silently refuses to play on its next draw.
	if is_instance_valid(card):
		card.remove_meta("_in_play")

	# Route to discard, OR remove from circulation if exhaust_self is among
	# the card's effects.
	var should_exhaust := _card_has_exhaust(card)
	if is_instance_valid(card):
		if card.card_container and card.card_container.has_card(card):
			card.card_container.remove_card(card)
		if should_exhaust:
			await card_animator.fly_to_exhaust(card)
			if is_instance_valid(card):
				card.queue_free()
		else:
			await card_animator.fly_to_discard(card)
			if is_instance_valid(card):
				discard_pile.add_card(card)
				card.modulate.a = 1.0  # restore alpha after discard

	_update_ui_labels()
	refresh_hand_ui()

## Returns true if the card has an `exhaust_self` effect entry.
func _card_has_exhaust(card: Control) -> bool:
	if not is_instance_valid(card):
		return false
	var effects: Array = card.card_info.get("effects", [])
	for e in effects:
		if typeof(e) == TYPE_DICTIONARY and str(e.get("type", "")) == "exhaust_self":
			return true
	return false

# ─── Targeting ────────────────────────────────────────────────────────────────

func start_spell_targeting(card: Control) -> void:
	if not can_afford([card]):
		show_notification("NOT ENOUGH ENERGY", Color(1, 0.2, 0.2))
		return

	is_targeting = true
	targeting_card = card

	if not targeting_arrow:
		targeting_arrow = TARGETING_ARROW_SCRIPT.new()
		add_child(targeting_arrow)

	var arrow_origin = card.global_position + Vector2(card.size.x * 0.5, card.size.y * 0.25)
	targeting_arrow.start(arrow_origin)


## Returns the single alive enemy node if exactly one exists. Otherwise null
## (zero enemies → no target; multiple enemies → player still chooses).
## PUBLIC — read by play_card to decide arrow-vs-drag flow and by
## card_play_zone to auto-target attacks dropped into the zone.
func sole_alive_enemy() -> Node:
	return _sole_alive_enemy()


func _sole_alive_enemy() -> Node:
	if not enemy_container:
		return null
	var alive: Array = []
	for enemy in enemy_container.get_children():
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			alive.append(enemy)
			if alive.size() > 1:
				return null  # short-circuit, more than one
	if alive.size() == 1:
		return alive[0]
	return null

func _cancel_spell_targeting() -> void:
	if hovered_unit:
		_set_hover_effect(hovered_unit, false)
		hovered_unit = null
	is_targeting = false
	targeting_card = null
	if targeting_arrow:
		targeting_arrow.stop()
		targeting_arrow.queue_free()
		targeting_arrow = null

## Called by PlayCard._handle_mouse_released() for attack cards.
## Fires attack at hovered enemy. Always requires hovering over an enemy.
func confirm_spell_targeting(card: Control) -> void:
	if not is_targeting or targeting_card != card:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return

	var unit_at_release = _get_unit_at_position(get_viewport().get_mouse_position())
	if unit_at_release != hovered_unit:
		if hovered_unit: _set_hover_effect(hovered_unit, false)
		hovered_unit = unit_at_release
		if hovered_unit: _set_hover_effect(hovered_unit, true)

	if hovered_unit and is_instance_valid(hovered_unit):
		var t = hovered_unit
		_cancel_spell_targeting()
		if hand.has_card(card):
			hand.remove_card(card)
		play_spell(card, t)
	else:
		show_notification("NO TARGET", Color(1, 0.6, 0.2))
		_cancel_spell_targeting()

# ─── Misc ─────────────────────────────────────────────────────────────────────

func _wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds).timeout

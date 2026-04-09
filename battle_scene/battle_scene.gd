extends Node

# --- Node References ---
@onready var card_manager = $CardManager
@onready var card_factory = $CardManager/MyCardFactory
@onready var hand = $CardManager/Hand
@onready var deck = $CardManager/Deck
@onready var discard_pile = $CardManager/DiscardPile
@onready var black_hole_pile = $CardManager/BlackHolePile
@onready var player = $Player
@onready var enemy_container = $EnemyContainer
@onready var turn_manager = $TurnManager
@onready var combat_engine = $CombatEngine
@onready var enemy_ai = $EnemyAI
@onready var ui_manager = $BattleUIManager

var deck_manager: Node

# --- Game State ---
var is_game_over:  bool    = false
var is_resolving:  bool    = false  # Prevents double-firing play_spell during await
var is_targeting:  bool    = false
var targeting_card: Control = null
var targeting_arrow: Node2D = null
var hovered_unit:  Node    = null

const TARGETING_ARROW_SCRIPT = preload("res://battle_scene/targeting_arrow.gd")

func _ready():
	print("BATTLE STARTING (STS Layout)")
	card_manager.debug_mode = false
	Engine.time_scale = 1.0
	
	# Instantiate DeckManager
	deck_manager = preload("res://battle_scene/deck_manager.gd").new()
	deck_manager.battle_scene = self
	deck_manager.deck = deck
	deck_manager.discard_pile = discard_pile
	deck_manager.hand = hand
	deck_manager.card_factory = card_factory
	add_child(deck_manager)
		
	# Connect TurnManager
	turn_manager.round_changed.connect(_on_round_changed)
	turn_manager.energy_changed.connect(_on_energy_changed)
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.turn_ended.connect(_on_turn_ended)
	
	# Connect Player Signals
	if player:
		player.health_changed.connect(_on_player_health_changed)
		player.energy_changed.connect(_on_player_energy_changed)
		player.block_changed.connect(_on_player_block_changed)
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
	if not is_targeting:
		return
	# Only handle mouse buttons, never keyboard
	if not (event is InputEventMouseButton):
		return
	if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
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

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _set_hover_effect(unit: Node, active: bool) -> void:
	if not is_instance_valid(unit): return
	var scale_target = Vector2(1.2, 1.2) if active else Vector2(1.0, 1.0)
	var modulate_target = Color(1.5, 1.2, 1.2) if active else Color.WHITE
	var tween = create_tween().set_parallel(true)
	tween.tween_property(unit, "scale", scale_target, 0.1)
	tween.tween_property(unit, "modulate", modulate_target, 0.1)

## Returns the enemy node under a screen position (viewport coords).
## EnemyEntity sprite is AnimatedSprite2D: 64px × 2.0 scale = 128×128, at offset (-64, -128).
func _get_unit_at_position(pos: Vector2) -> Node:
	for enemy in enemy_container.get_children():
		if not is_instance_valid(enemy): continue
		var ep = enemy.global_position
		# Body rect matches the 128×128 scaled sprite at (-64, -128) from entity origin
		var body_rect = Rect2(ep.x - 64, ep.y - 128, 128, 128)
		if body_rect.has_point(pos):
			return enemy
		# Fallback: also catch clicks near the HUD above the sprite
		if ep.distance_to(pos) < 90.0:
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
	_update_ui_labels()
	enemy_ai.spawn_enemy_units()
	
	if turn_manager.current_round == 1:
		deck_manager.first_round_draw()
	else:
		deck_manager.draw_cards(3)

## STS rule: at END of player turn, discard all remaining hand cards.
func _on_turn_ended(side: String) -> void:
	if side == "player":
		var remaining = hand.get_cards().duplicate()
		if remaining.size() > 0:
			# Use move_cards so card_container references transfer properly
			discard_pile.move_cards(remaining)

func _on_round_changed(_round: int) -> void: _update_ui_labels()
func _on_energy_changed(_cur: int, _max: int) -> void: _update_ui_labels()
func _on_player_health_changed(_hp: int) -> void: _update_ui_labels()
func _on_player_energy_changed(_energy: int) -> void: _update_ui_labels()
func _on_player_block_changed(_block: int) -> void: _update_ui_labels()

func _update_ui_labels():
	if player:
		ui_manager.update_labels(player.energy, player.max_energy)

## Initialise a new battle from RunManager state (or defaults if no run is active).
func _start_new_game():
	is_game_over = false
	is_resolving = false

	var rm = get_node_or_null("/root/RunManager")

	# ── Player HP & Attributes ──────────────────────────────────────────────
	if rm and rm.get("is_run_active"):
		player.max_health  = rm.max_health
		player.health      = rm.current_health
		var attrs = rm.get("player_attributes") if rm.get("player_attributes") else {}
		player.strength     = int(attrs.get("strength",     3))
		player.constitution = int(attrs.get("constitution", 3))
		player.intelligence = int(attrs.get("intelligence", 3))
		player.luck         = int(attrs.get("luck",         3))
		player.charm        = int(attrs.get("charm",        3))
		# Enemy roster comes from the map encounter data stored in RunManager
		var roster = rm.get("current_encounter") if rm.get("current_encounter") else []
		if roster.size() > 0:
			enemy_ai.enemy_roster = roster
	
	# ── Deck & Turn ──────────────────────────────────────────────────────────
	deck_manager.reset_deck()
	turn_manager.start_new_game()

func _on_end_round_button_pressed():
	if turn_manager.is_player_turn:
		turn_manager.end_turn()

func _victory():
	if is_game_over: return
	is_game_over = true
	_write_hp_to_run_manager()
	show_notification("VICTORY!", Color(0.2, 1.0, 0.2))
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://run_system/ui/loot_reward.tscn")

func _game_over():
	if is_game_over: return
	is_game_over = true
	_write_hp_to_run_manager()  # Write 0 HP so RunManager knows player died
	show_notification("DEFEAT...", Color(1, 0.1, 0.1))
	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()

## Writes the player's current HP back to RunManager so it persists between battles.
## Called on both victory and defeat.
func _write_hp_to_run_manager() -> void:
	var rm = get_node_or_null("/root/RunManager")
	if rm and rm.get("is_run_active") and player and is_instance_valid(player):
		rm.current_health = player.health

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
func play_spell(card: Control, target_node: Node):
	if is_game_over: return
	if not is_instance_valid(card): return
	
	var type = card.card_info.get("type", "skill").to_lower()
	
	if type == "attack":
		if not target_node or not is_instance_valid(target_node):
			show_notification("MUST TARGET ENEMY", Color(0.8, 0.4, 0.4))
			hand.add_card(card)
			return
	
	# is_resolving lock — prevents double-playing the same card
	# (e.g. if the player clicks very fast while an await is in progress)
	if is_resolving:
		show_notification("WAIT...", Color(0.8, 0.8, 0.8))
		return
	is_resolving = true
	
	# Deduct cost; remove from current container if still tracked there
	spend_energy([card])
	if card.card_container and card.card_container.has_card(card):
		card.card_container.remove_card(card)
	
	# Resolve combat effects (may await animations)
	await combat_engine.resolve_card_effect(card, target_node, player)
	
	# Move to discard after effect finishes
	if is_instance_valid(card):
		if card.card_container and card.card_container.has_card(card):
			card.card_container.remove_card(card)
		discard_pile.add_card(card)
	
	is_resolving = false
	_update_ui_labels()

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
	
	targeting_arrow.start(card.global_position + card.size / 2.0)

func _cancel_spell_targeting() -> void:
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

func inspect_card(card: Control) -> void: ui_manager.inspect_card(card)
func _on_inspect_overlay_gui_input(event: InputEvent) -> void: ui_manager._on_inspect_overlay_gui_input(event)
func show_pile_viewer(title: String, pile_container: Node): ui_manager.show_pile_viewer(title, pile_container)
func hide_pile_viewer(): ui_manager.hide_pile_viewer()

func _wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds).timeout

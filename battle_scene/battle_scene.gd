extends Node

@warning_ignore("unused_signal")
signal unit_stats_changed(unit: Control, atk: int, hp: int, is_permanent: bool)

# --- Node References ---
# These variables link the script to the nodes in the scene tree.
@onready var card_manager = $CardManager
@onready var card_factory = $CardManager/MyCardFactory
@onready var hand = $CardManager/Hand
@onready var deck = $CardManager/Deck
@onready var discard_pile = $CardManager/DiscardPile
@onready var black_hole_pile = $CardManager/BlackHolePile
@onready var rows = _get_battle_rows()
@onready var player_hero = $PlayerHeroHUD
@onready var turn_manager = $TurnManager
@onready var combat_engine = $CombatEngine
@onready var enemy_ai = $EnemyAI
@onready var ui_manager = $BattleUIManager

var deck_manager: Node

# --- Game State Variables ---
var is_game_over: bool = false
var is_in_combat_phase: bool = false

# --- Spell Targeting State ---
var is_targeting: bool = false
var targeting_card: Control = null
var targeting_arrow: Node2D = null
var hovered_unit: Control = null
var hovered_row: Control = null
var targeting_overlay: Control = null
var targeting_type: String = "unit" # "unit", "row", "none"
var targeting_start_pos: Vector2 = Vector2.ZERO
var targeting_start_time: int = 0
const TARGETING_ARROW_SCRIPT = preload("res://battle_scene/targeting_arrow.gd")

# --- Manual Attack Targeting State ---
var is_manual_attacking: bool = false
var manual_attacker: Control = null


func _ready():
	print("GAME STARTING")
	card_manager.debug_mode = true
	
	Engine.time_scale = 1.0
	
	var rows_array = _get_battle_rows()
	if rows_array.size() >= 2:
		rows_array[0].row_side = "enemy"
		rows_array[1].row_side = "player"
		
	# Instantiate DeckManager
	deck_manager = preload("res://battle_scene/deck_manager.gd").new()
	deck_manager.battle_scene = self
	deck_manager.deck = deck
	deck_manager.discard_pile = discard_pile
	deck_manager.hand = hand
	deck_manager.card_factory = card_factory
	add_child(deck_manager)
		
	var run_manager = get_node_or_null("/root/RunManager")
	if run_manager and not run_manager.is_connected("run_ended", _on_run_ended):
		run_manager.connect("run_ended", _on_run_ended)
		
	# Connect TurnManager signals
	turn_manager.round_changed.connect(_on_round_changed)
	turn_manager.energy_changed.connect(_on_energy_changed)
	turn_manager.turn_started.connect(_on_turn_started)
	
	_start_new_game()
	
	# Create blocking overlay for targeting
	targeting_overlay = Control.new()
	targeting_overlay.name = "TargetingOverlay"
	targeting_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	targeting_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	targeting_overlay.visible = false
	targeting_overlay.gui_input.connect(_on_targeting_overlay_gui_input)
	
	# Add to CardManager to ensure it's above cards and properly sized
	card_manager.add_child(targeting_overlay)
	
	# Hero Setup
	_setup_heroes()
	
	# Connect signals for Robot Bill Passive
	if not unit_stats_changed.is_connected(_on_unit_stats_changed):
		unit_stats_changed.connect(_on_unit_stats_changed)
	
	# Connect CombatEngine signals
	combat_engine.victory_declared.connect(_victory)
	
	set_process(true)
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_X:
			ui_manager.show_pile_viewer("Black Hole", black_hole_pile)

func _setup_heroes():
	var run_manager = get_node_or_null("/root/RunManager")
	var p_hp = 30
	
	if run_manager:
		p_hp = run_manager.get("player_hp") if "player_hp" in run_manager else 30
		
	var player_tex = load("res://battle_scene/assets/images/cards/player/heroes/hero_robot_bill.png")
	
	player_hero.setup({
		"name": "Robot Bill",
		"health": p_hp,
		"attack": 5,
		"side": "player",
		"texture": player_tex
	})

func _on_unit_stats_changed(unit: Control, _atk: int, _hp: int, _is_permanent: bool):
	# Robot Bill Passive: Whenever a friendly robot gains stats, gain +1 Attack.
	if player_hero and unit.has_method("is_player_unit") and unit.is_player_unit():
		var race = unit.card_info.get("race", "").to_lower()
		if race == "robot":
			player_hero.atk += 1
			show_notification("ROBOT BILL: +1 ATK", Color(0.2, 0.9, 0.2))
	
	combat_engine.check_victory_condition()

func on_hero_ability_triggered(hero: Node):
	if hero.get("side") == "player":
		# Bill's 0-cost ability: Deal X dmg to a unit (X = hero attack)
		start_hero_ability_targeting(hero)

func start_hero_ability_targeting(hero: Node):
	is_targeting = true
	targeting_card = hero
	targeting_type = "unit"
	
	# Create the targeting arrow
	targeting_arrow = TARGETING_ARROW_SCRIPT.new()
	add_child(targeting_arrow)
	targeting_arrow.start(hero.global_position + hero.size/2)
	
	if targeting_overlay:
		targeting_overlay.visible = true
		targeting_overlay.move_to_front()
	
	show_notification("SELECT UNIT TO SNIPE (%d DMG)" % hero.get("atk"), Color(1, 0.8, 0.2))

func _on_hero_died(hero: Node):
	if hero.get("side") == "player":
		_game_over()
	else:
		_victory()

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, false).timeout

func _process(_delta: float) -> void:
	if is_manual_attacking:
		var current_mouse_pos = get_viewport().get_mouse_position()
		if targeting_arrow:
			targeting_arrow.queue_redraw()
			
		var target_under_mouse = _get_unit_at_position(current_mouse_pos)
		if target_under_mouse and target_under_mouse.card_info.get("side", "player") == "enemy":
			if target_under_mouse != hovered_unit:
				if hovered_unit: _set_hover_effect(hovered_unit, false)
				hovered_unit = target_under_mouse
				_set_hover_effect(hovered_unit, true)
		else:
			if hovered_unit:
				_set_hover_effect(hovered_unit, false)
				hovered_unit = null
		return

	if not is_targeting:
		if hovered_unit:
			_set_hover_effect(hovered_unit, false)
			hovered_unit = null
		return
	
	var mouse_pos = get_viewport().get_mouse_position()
	var unit_under_mouse = _get_unit_at_position(mouse_pos)
	var row_under_mouse = _get_row_at_position(mouse_pos)
	
	# --- UNIT TARGETING ---
	if targeting_type == "unit":
		if unit_under_mouse != hovered_unit:
			if hovered_unit:
				_set_hover_effect(hovered_unit, false)
			
			hovered_unit = unit_under_mouse
			
			if hovered_unit:
				_set_hover_effect(hovered_unit, true)
	
	# --- ROW TARGETING ---
	elif targeting_type == "row":
		if row_under_mouse != hovered_row:
			if hovered_row and hovered_row.has_method("set_highlight"):
				hovered_row.set_highlight(false)
			
			hovered_row = row_under_mouse
			
			if hovered_row and hovered_row.has_method("set_highlight"):
				hovered_row.set_highlight(true)

	# --- NO TARGETING (Global) ---
	# No specific highlight needed, arrow just follows mouse.

func _set_hover_effect(unit: Control, active: bool) -> void:
	if not is_instance_valid(unit): return
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	if active:
		tween.tween_property(unit, "scale", unit.original_scale * 1.2, 0.1)
		tween.tween_property(unit, "modulate", Color(1.2, 1.2, 1.2), 0.1)
	else:
		tween.tween_property(unit, "scale", unit.original_scale, 0.1)
		if unit.has_method("refresh_visual_state"):
			unit.refresh_visual_state(tween, 0.1)
		else:
			tween.tween_property(unit, "modulate", Color.WHITE, 0.1)


# Displays a message via UI manager
func show_notification(text: String, color: Color = Color.WHITE):
	ui_manager.show_notification(text, color)


# Handles round progression, energy resets, and draws cards
func _on_turn_started(side: String) -> void:
	if is_game_over: return
	if side == "enemy":
		enemy_ai.execute_enemy_turn()
		return
	
	_update_ui_labels()
	enemy_ai.spawn_enemy_units() # Enemies spawn before the player does anything
	
	if player_hero:
		player_hero.can_use_ability = true

	
	if turn_manager.current_round == 1:
		deck_manager.first_round_draw()
	else:
		deck_manager.draw_cards(2)

	# Trigger Turn Start abilities
	for row in _get_battle_rows():
		for card in row.get_cards():
			if is_instance_valid(card) and "keyword_instances" in card:
				for kw in card.keyword_instances:
					if kw.has_method("on_turn_start"):
						kw.on_turn_start(row)

func _on_round_changed(_round: int) -> void:
	_update_ui_labels()

func _on_energy_changed(_cur: int, _max: int) -> void:
	_update_ui_labels()


# --- Spawning moved to enemy_ai.gd ---

# --- End Deck Management routines moved to deck_manager.gd ---


# Refreshes the text display for Energy and Rounds
func _update_ui_labels():
	ui_manager.update_labels(turn_manager.current_energy, turn_manager.max_energy)

func gain_energy(amount: int) -> void:
	turn_manager.gain_energy(amount)

func _start_new_game():
	is_game_over = false
	deck_manager.reset_deck()
	turn_manager.start_new_game()


# --- Remaining Core Game Logic ---


func _get_battle_rows() -> Array:
	var list = []
	var field = card_manager.get_node("BattleField")
	for child in field.get_children():
		if child.is_in_group("battle_row"):
			list.append(child)
	return list


func _on_end_round_button_pressed():
	if turn_manager.is_player_turn:
		turn_manager.end_turn()

# --- Enemy turn execution moved to enemy_ai.gd ---


# --- Unit attack logic moved to combat_engine.gd ---

# --- Victory check moved to combat_engine.gd ---

func game_over(player_won: bool):
	if is_game_over: return
	is_game_over = true
	
	if player_won:
		show_notification("VICTORY! ENEMY HERO DESTROYED", Color(0.2, 0.8, 0.2))
		await _wait(3.0)
		_victory()
	else:
		show_notification("DEFEAT! HERO DESTROYED", Color(1, 0, 0))
		await _wait(3.0)
		_game_over()
		await _wait(3.0)
		var run_manager = get_node_or_null("/root/RunManager")
		if run_manager and run_manager.has_method("end_run"):
			run_manager.end_run(false)
		else:
			get_tree().reload_current_scene()

# --- Game Mechanics ---

## Moves a card from its current spot to the Graveyard.
## If the card is the Mother Ship, it triggers Game Over.
## Moves a card from its current spot to the Graveyard.
func kill_unit(card: Control):
	combat_engine.kill_unit(card)


func _victory():
	if is_game_over: return
	is_game_over = true
	show_notification("VICTORY! ALL ENEMIES DEFEATED", Color(0.2, 1.0, 0.2))
	
	var run_manager = get_node_or_null("/root/RunManager")
	if run_manager:
		if run_manager.has_method("add_resources"):
			run_manager.add_resources(50, 10)
		
	await _wait(3.0)
	if run_manager and run_manager.has_method("end_run"):
		run_manager.end_run(true)
	else:
		get_tree().change_scene_to_file("res://run_system/ui/card_draft_reward.tscn")

func _on_run_ended(victory: bool):
	if victory:
		_victory()
	else:
		_game_over()

# Stops the game and shows the failure message
func _game_over():
	if is_game_over: return
	is_game_over = true
	show_notification("GAME OVER - HERO DEFEATED", Color(1, 0.1, 0.1))
	await _wait(3.0)
	get_tree().change_scene_to_file("res://run_system/ui/starter_deck_builder.tscn")


## Handles spell casting. 
## Deducts energy and returns the spell card to the deck (draw pile).
func play_spell(card: Control, drop_position: Vector2):
	if is_game_over: return
	
	var target_type = card.card_info.get("target_type", "row")
	var target_unit = null
	
	if target_type == "unit":
		target_unit = _get_unit_at_position(drop_position)
		if target_unit == null:
			show_notification("NO TARGET FOUND", Color(0.8, 0.4, 0.4))
			# Return to hand (this is handled by the framework if move_cards fails in SpellPlayZone,
			# but here we specifically need to NOT consume the card if we are already in play_spell)
			# Actually, play_spell is called AFTER move_cards successfully "consumed" it.
			# So we must return it to hand manually.
			if card.card_container:
				card.card_container.remove_card(card)
			hand.add_card(card)
			return

	elif target_type == "row":
		# Logic for row-targeted spells dropped via drag-and-drop
		var target_row = _get_row_at_position(drop_position)
		if target_row:
			target_unit = target_row # Pass row as target
		else:
			# If dropped in empty space, maybe "global" behavior or cancel?
			# For now, require hitting a row for "row" type spells
			show_notification("INVALID TARGET", Color(0.8, 0.4, 0.4))
			if card.card_container:
				card.card_container.remove_card(card)
			hand.add_card(card)
			return

	if card.card_container:
		card.card_container.remove_card(card)
	
	# Spend energy based on the card's "cost" property in JSON
	spend_energy([card])
	
	_resolve_spell_effect(card, target_unit)
	
	# Handled played spells
	if card.card_container:
		card.card_container.remove_card(card)
		
	if combat_engine._has_keyword(card, "one-time"):
		black_hole_pile.add_card(card)
	else:
		discard_pile.add_card(card)
		
	_update_ui_labels()


func _resolve_spell_effect(card: Control, target: Control = null):
	await combat_engine.resolve_spell_effect(card, target)


func _find_frontmost_unit(_lane_ignore: int, player_side: bool) -> Card:
	# For spells: pick a random row's frontline
	var rows_list = _get_battle_rows()
	var potential = []
	for row in rows_list:
		if player_side:
			for i in range(3, -1, -1):
				var unit = row.get_card_at_slot(i)
				if unit:
					potential.append(unit)
					break
		else:
			for i in range(0, 8):
				var unit = row.get_card_at_slot(i)
				if unit:
					potential.append(unit)
					break
	if potential.size() > 0:
		return potential.pick_random()
	return null


func _get_unit_at_position(pos: Vector2) -> Card:
	for row in _get_battle_rows():
		for card in row.get_cards():
			if is_instance_valid(card) and card.get_global_rect().has_point(pos):
				return card
	return null


func _get_row_at_position(pos: Vector2) -> Control:
	for row in _get_battle_rows():
		if row.get_global_rect().has_point(pos):
			return row
	return null


# --- Energy Management ---

# Returns true if the player has enough current_energy to play the selected cards
func can_afford(cards: Array) -> bool:
	if is_game_over: return false
	
	var total_cost = 0
	for card in cards:
		total_cost += int(card.card_info.get("cost", 0))
	return turn_manager.can_afford(total_cost)


# Subtracts the energy cost and updates the screen text
func spend_energy(cards: Array) -> void:
	var total_cost = 0
	for card in cards:
		total_cost += int(card.card_info.get("cost", 0))
	turn_manager.spend_energy(total_cost)


# --- Spell Targeting System ---

## Enters targeting mode for a unit-targeted spell.
## Spawns a visual arrow from the card to the mouse cursor.
func start_spell_targeting(card: Control) -> void:
	if is_targeting:
		_cancel_spell_targeting()
	
	is_targeting = true
	targeting_card = card
	targeting_type = card.card_info.get("target_type", "unit")
	
	# Highlight the selected spell card
	card.modulate = Color(0.7, 0.9, 1.3)
	
	# Create the targeting arrow
	targeting_arrow = Node2D.new()
	targeting_arrow.set_script(TARGETING_ARROW_SCRIPT)
	add_child(targeting_arrow)
	
	# Start the arrow from the center of the card
	var card_center = card.global_position + card.card_size / 2.0
	targeting_arrow.start(card_center)
	
	# Track start for hybrid Drag/Click behavior
	targeting_start_pos = get_viewport().get_mouse_position()
	targeting_start_time = Time.get_ticks_msec()
	
	# Enable blocking overlay
	if targeting_overlay:
		targeting_overlay.visible = true
		targeting_overlay.move_to_front() # Ensure it blocks everything
		
	show_notification("SELECT A TARGET", Color(1, 0.8, 0.2))


## Cancels the current targeting mode without casting.
func _cancel_spell_targeting() -> void:
	if not is_targeting:
		return
	
	# Remove arrow
	if targeting_arrow and is_instance_valid(targeting_arrow):
		targeting_arrow.stop()
		targeting_arrow.queue_free()
		targeting_arrow = null
	
	# Un-highlight the card
	if targeting_card and is_instance_valid(targeting_card):
		targeting_card.modulate = Color.WHITE
	
	targeting_card = null
	is_targeting = false
	if hovered_unit:
		_set_hover_effect(hovered_unit, false)
		hovered_unit = null

	if hovered_row and hovered_row.has_method("set_highlight"):
		hovered_row.set_highlight(false)
		hovered_row = null
	
	# Disable blocking overlay
	if targeting_overlay:
		targeting_overlay.visible = false
		
	show_notification("TARGETING CANCELLED", Color(0.6, 0.6, 0.6))


## Completes spell targeting by resolving the spell on the target found at mouse position.
func _complete_spell_targeting() -> void:
	if not is_targeting or targeting_card == null:
		return
	
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Resolve target based on type
	var final_target = null
	var is_valid_target = false

	if targeting_type == "unit":
		final_target = _get_unit_at_position(mouse_pos)
		if final_target:
			is_valid_target = true
			
	elif targeting_type == "row":
		final_target = _get_row_at_position(mouse_pos)
		if final_target:
			is_valid_target = true
			
	elif targeting_type == "none":
		# Global spells don't need a specific target object
		final_target = null
		is_valid_target = true
	
	if not is_valid_target:
		show_notification("INVALID TARGET", Color(0.8, 0.4, 0.4))
		_cancel_spell_targeting() # Handles all cleanup including overlay + hover reset
		return
	
	# BUG-01 fix: save references BEFORE cancel wipes them, then delegate
	# all state cleanup to _cancel_spell_targeting() — the single source of truth.
	# We suppress its "TARGETING CANCELLED" notification by casting immediately after.
	var card = targeting_card
	_cancel_spell_targeting()
	
	# Override the cancel notification with the cast result
	_execute_spell_with_target(card, final_target)


# --- Manual Attack Actions ---
func start_manual_attack(attacker: Control):
	if is_game_over: return
	if attacker.card_info.get("side", "player") != "player": return
	
	is_manual_attacking = true
	manual_attacker = attacker
	
	if not targeting_arrow:
		targeting_arrow = TARGETING_ARROW_SCRIPT.new()
		add_child(targeting_arrow)
		
	# Move origin down from the center to roughly the bottom of the oval token (y + 100)
	targeting_arrow.origin = attacker.global_position + Vector2(80, 100) * attacker.scale
	targeting_arrow.is_active = true
	targeting_arrow.visible = true
	# Make sure overlay is active to capture release
	if targeting_overlay:
		targeting_overlay.visible = true

func _complete_manual_attack():
	is_manual_attacking = false
	if targeting_arrow:
		targeting_arrow.queue_free()
		targeting_arrow = null
		
	# Hide overlay
	if targeting_overlay:
		targeting_overlay.visible = false
		
	if manual_attacker == null or hovered_unit == null:
		if manual_attacker:
			# Reset visual state
			manual_attacker.modulate = Color(1.0, 1.0, 1.0)
		manual_attacker = null
		return
		
	if hovered_unit and (hovered_unit.card_info.get("side", "player") == "enemy"):
		# If target is an enemy unit
		var has_taunt_enemy = false
		for row in _get_battle_rows():
			for card in row.get_cards():
				if is_instance_valid(card) and card.card_info.get("side", "player") == "enemy":
					if combat_engine._has_keyword(card, "taunt"):
						has_taunt_enemy = true
						break
			if has_taunt_enemy:
				break
				
		if has_taunt_enemy and not combat_engine._has_keyword(hovered_unit, "taunt"):
			show_notification("MUST TARGET TAUNT UNIT!", Color(1, 0.3, 0.3))
			manual_attacker.modulate = Color(1.0, 1.0, 1.0)
			manual_attacker = null
			hovered_unit = null
			return

		# Verify attacker can act
		if not manual_attacker.get("can_attack"):
			show_notification("ALREADY ATTACKED", Color(0.8, 0.4, 0.4))
			manual_attacker.modulate = Color(1.0, 1.0, 1.0)
			manual_attacker = null
			hovered_unit = null
			return
			
		# Execute Attack
		manual_attacker.can_attack = false
		if manual_attacker.has_method("refresh_visual_state"):
			manual_attacker.refresh_visual_state()
		else:
			manual_attacker.modulate = Color(0.5, 0.5, 0.5) # Fallback
			
		await combat_engine.perform_attack(manual_attacker, hovered_unit)
			
	manual_attacker = null

func _cancel_manual_attack():
	is_manual_attacking = false
	if targeting_arrow:
		targeting_arrow.queue_free()
		targeting_arrow = null
		
	if targeting_overlay:
		targeting_overlay.visible = false
		
	if hovered_unit:
		_set_hover_effect(hovered_unit, false)
		hovered_unit = null
		
	manual_attacker = null


# --- Inspection UI moved to battle_ui_manager.gd ---

func inspect_card(card: Control) -> void:
	ui_manager.inspect_card(card)

func _on_inspect_overlay_gui_input(event: InputEvent) -> void:
	# Keep this as a bridge if the signal is still connected to the main script
	# But better to connect it directly to ui_manager in the editor.
	ui_manager._on_inspect_overlay_gui_input(event)

func _input(_event: InputEvent) -> void:
	if is_game_over: return

# --- Pile viewing moved to battle_ui_manager.gd ---

func show_pile_viewer(title: String, pile_container: CardContainer):
	ui_manager.show_pile_viewer(title, pile_container)

func hide_pile_viewer():
	ui_manager.hide_pile_viewer()


func _execute_spell_with_target(card: Control, target: Object) -> void:
	if is_game_over: return

	# CHECK: Is this a Hero Ability (Snipe) or a Spell Card?
	if card == player_hero:
		if is_instance_valid(target) and target.has_method("take_damage"):
			var damage = player_hero.get("atk")
			target.take_damage(damage)
			show_notification("SNIPE! -%d" % damage, Color(1, 0.5, 0))
			# Bill's snipe is 0-cost, so no energy spent here.
			# But if we want to limit it to once per turn:
			player_hero.set("can_use_ability", false)
		return

	if card.card_container:
		card.card_container.remove_card(card)
	
	# Spend energy
	spend_energy([card])
	
	await _resolve_spell_effect(card, target)
	
	# Handle played spells
	if card.card_container:
		card.card_container.remove_card(card)
		
	if combat_engine._has_keyword(card, "one-time"):
		black_hole_pile.add_card(card)
	else:
		discard_pile.add_card(card)


## Handles input on the blocking overlay
func _on_targeting_overlay_gui_input(event: InputEvent) -> void:
	if is_manual_attacking:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				_complete_manual_attack()
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				_cancel_manual_attack()
		return

	if not is_targeting:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Already targeting, clicking again usually means "Complete" (Toggle mode)
				_complete_spell_targeting()
			else:
				# Mouse RELEASED
				# Check if we dragged significantly or held for a while
				var current_pos = get_viewport().get_mouse_position()
				var drag_dist = current_pos.distance_to(targeting_start_pos)
				var hold_time = Time.get_ticks_msec() - targeting_start_time
				
				# If user dragged > 20px OR held > 200ms, treat release as "Cast"
				# Otherwise, treat it as a "Click" (initiate targeting) and wait for second click
				if drag_dist > 20 or hold_time > 200:
					_complete_spell_targeting()
					
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_spell_targeting()

# Removed _unhandled_input logic as it is replaced by overlay


# --- UI Signals ---

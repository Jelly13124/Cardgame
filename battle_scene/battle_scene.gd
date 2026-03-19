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
# @onready var graveyard = $CardManager/Graveyard # Removed from scene
@onready var rows = _get_battle_rows()

var deck_manager: Node

# UI Label References
@onready var energy_label = $EnergyLabel
@onready var round_label = $RoundLabel
@onready var notify_label = $NotificationLabel
@onready var pile_viewer_layer = $PileViewerLayer
@onready var pile_viewer_title = $PileViewerLayer/TitleLabel
@onready var pile_viewer_grid = $PileViewerLayer/ScrollContainer/GridContainer

# --- Game State Variables ---
var current_energy: int = 0
var max_energy: int = 3
var current_round: int = 0
var notify_tween: Tween # Used for the fade-out animation of notifications
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
	# Initialize UI: Make sure the notification label starts invisible
	if notify_label:
		notify_label.modulate.a = 0
		
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
	
	set_process(true)

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


# Displays a message in the center of the screen that fades away
func show_notification(text: String, color: Color = Color.WHITE):
	if not notify_label: return
	
	notify_label.text = text
	notify_label.add_theme_color_override("font_color", color)
	notify_label.modulate.a = 1.0 # Make fully visible
	
	# Reset any existing animation
	if notify_tween and notify_tween.is_valid():
		notify_tween.kill()
	
	# Create a new animation sequence: Wait 1.5s, then fade out over 0.5s
	notify_tween = create_tween()
	notify_tween.tween_interval(1.5)
	notify_tween.tween_property(notify_label, "modulate:a", 0.0, 0.5)


# Resets the game to round 1
func _start_new_game():
	is_game_over = false
	current_round = 0
	deck_manager.reset_deck()
	# Player health is now the sole win/loss condition
	
	_start_next_round()


# Advanced to the next round, resets energy, and draws cards
func _start_next_round():
	if is_game_over: return
	
	current_round += 1
	current_energy = max_energy
	_update_ui_labels()
	
	_spawn_enemy_units() # Enemies spawn before the player does anything, even on round 1
	
	if current_round == 1:
		deck_manager.first_round_draw() # Special draw for the start of the game
	else:
		deck_manager.draw_cards(2) # Draw 2 cards every round

	# Trigger Turn Start abilities (e.g. Leader buff)
	for row in _get_battle_rows():
		for card in row.get_cards():
			if is_instance_valid(card) and "keyword_instances" in card:
				for kw in card.keyword_instances:
					if kw.has_method("on_turn_start"):
						kw.on_turn_start(row)


func _spawn_enemy_units():
	var rows_list = _get_battle_rows()
	if rows_list.size() < 2: return
	
	# Increase difficulty: more bots as rounds progress
	var spawn_count = 1
	if current_round > 2: spawn_count = 2
	if current_round > 5: spawn_count = 3
	
	var enemy_types = ["alien_soldier", "alien_sniper", "alien_killer"]
	
	for i in range(spawn_count):
		var spawn_row = rows_list[0]
			
		if spawn_row.get_card_count() < 7:
			var random_type = enemy_types[randi() % enemy_types.size()]
			var card = card_factory.create_card(random_type, spawn_row)
			if card:
				card.card_info["side"] = "enemy"
				card.refresh_ui()
	
	# Boss Round: Spawn Boss at Round 5, 10, 20...
	if current_round % 10 == 0 or current_round == 5:
		show_notification("BOSS WARNING: OMEGA BOT DETECTED!", Color(1, 0, 0))
		var spawn_row = rows_list[0]
		var boss = card_factory.create_card("unit_boss_mk1", spawn_row)
		if boss:
			boss.card_info["side"] = "enemy"
			boss.card_info["is_boss"] = true
			boss.refresh_ui()

# --- End Deck Management routines moved to deck_manager.gd ---


# Refreshes the text display for Energy and Rounds
func _update_ui_labels():
	if energy_label:
		energy_label.text = "Energy: %d / %d" % [current_energy, max_energy]

func gain_energy(amount: int) -> void:
	current_energy += amount
	if current_energy > max_energy:
		current_energy = max_energy
	_update_ui_labels() # BUG-02 fix: use the central label updater; round did not change


# --- Remaining Core Game Logic ---


func _get_battle_rows() -> Array:
	var list = []
	var field = card_manager.get_node("BattleField")
	for child in field.get_children():
		if child.is_in_group("battle_row"):
			list.append(child)
	return list


func _on_end_round_button_pressed():
	_execute_enemy_turn()

func _execute_enemy_turn():
	if is_in_combat_phase or is_game_over: return
	is_in_combat_phase = true
	Engine.time_scale = 1.0
	
	# Disable interaction during combat and Trigger End Turn abilities
	for row in _get_battle_rows():
		for card in row.get_cards():
			card.can_be_interacted_with = false
			
			if is_instance_valid(card) and "keyword_instances" in card:
				for kw in card.keyword_instances:
					if kw.has_method("on_turn_end"):
						kw.on_turn_end(row)
	
	show_notification("ENEMY TURN", Color(1, 0.4, 0.4))
	await _wait(1.0)
	
	# Enemy AI: Attack random targets
	var rows_list = _get_battle_rows()
	if rows_list.size() >= 2:
		var enemy_rows = [rows_list[0]]
		var player_rows = [rows_list[1]]
		
		for e_row in enemy_rows:
			var e_cards = e_row.get_cards()
			for e_unit in e_cards:
				# Check if still valid (could be killed by spikes/etc)
				if not is_instance_valid(e_unit) or e_unit.get_parent() == null: continue
				if e_unit.card_info.get("side", "player") == "enemy":
					# Gather valid targets again in case someone died
					var valid_targets = []
					for p_row in player_rows:
						for card in p_row.get_cards():
							if is_instance_valid(card) and card.card_info.get("side", "player") == "player":
								valid_targets.append(card)
							
					# Filter for TAUNT
					var taunt_targets = []
					for t in valid_targets:
						if _has_keyword(t, "taunt"):
							taunt_targets.append(t)
							
					if taunt_targets.size() > 0:
						valid_targets = taunt_targets
							
					if valid_targets.size() > 0:
						var target = valid_targets[randi() % valid_targets.size()]
						if is_instance_valid(e_unit) and is_instance_valid(target):
							await _perform_attack(e_unit, target)
							await _wait(0.2)
					else:
						# No targets! Direct face damage
						var a_atk = int(e_unit.card_info.get("attack", 0))
						take_unblocked_damage(a_atk, false)
						
						# Simple attack animation forwards and backwards
						var a_pos = e_unit.global_position
						var tween = create_tween()
						var strike_pos = a_pos + Vector2(0, 100) # Jump down towards screen bottom
						tween.tween_property(e_unit, "global_position", strike_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
						await tween.finished
						
						var back_tween = create_tween()
						back_tween.tween_property(e_unit, "global_position", a_pos, 0.15)
						await back_tween.finished
						await _wait(0.2)
	
	if is_game_over: return
	
	show_notification("YOUR TURN", Color(0.4, 0.8, 1.0))
	await _wait(0.5)
	
	is_in_combat_phase = false
	Engine.time_scale = 1.0
	
	# Reset player attacks
	if rows_list.size() >= 2:
		var p_rows = [rows_list[1]]
		for p_row in p_rows:
			for card in p_row.get_cards():
				if is_instance_valid(card) and card.card_info.get("side", "player") == "player":
					card.can_attack = true
					card.modulate = Color(1.0, 1.0, 1.0)
					card.can_be_interacted_with = true
	
	_start_next_round()


func _has_keyword(unit: Control, kw_name: String) -> bool:
	if not "keyword_instances" in unit: return false
	for kw in unit.keyword_instances:
		if kw.name.to_lower() == kw_name.to_lower():
			return true
	return false

func _perform_attack(attacker: Control, defender: Control):
	if not is_instance_valid(attacker) or not is_instance_valid(defender): return

	var a_pos = attacker.global_position
	var d_pos = defender.global_position
	
	# Pre-calculate combat math
	var a_atk = int(attacker.card_info.get("attack", 0))
	var d_atk = int(defender.card_info.get("attack", 0))
	
	# Temporarily render above everything using CanvasItem z_index
	var old_z = attacker.z_index
	attacker.z_index = 100
	
	# Force the card into MOVING state so its drop sensors/mouse filters are disabled
	if attacker.has_method("change_state"):
		attacker.change_state(DraggableObject.DraggableState.MOVING)
	
	# Execute lunge animation
	var tween = create_tween()
	var strike_pos = d_pos - (d_pos - a_pos).normalized() * 20
	tween.tween_property(attacker, "global_position", strike_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	
	# Instantly begin returning to original slot before ANY damage resolution triggers container updates
	if is_instance_valid(attacker):
		var back_tween = create_tween()
		back_tween.tween_property(attacker, "global_position", a_pos, 0.15)
		
		# Now that we are safely on our way back visually, we can trigger the damage callbacks
		# Reciprocal Combat: Both units deal damage to each other.
		if is_instance_valid(defender) and defender.has_method("take_damage"):
			defender.take_damage(a_atk)
			
		if d_atk > 0 and is_instance_valid(attacker) and attacker.has_method("take_damage"):
			attacker.take_damage(d_atk)
			
		await back_tween.finished
		
		# Restore z_index safely
		if is_instance_valid(attacker):
			attacker.z_index = old_z
			if attacker.has_method("change_state"):
				attacker.change_state(DraggableObject.DraggableState.IDLE)
				
			# Ensure it is exactly back exactly where it needs to be in its row
			var original_parent = attacker.card_container
			if original_parent and original_parent.has_method("_update_target_positions"):
				original_parent._update_target_positions()
	else:
		# BUG-04 fix: attacker died during the lunge — still deal damage and wait
		# before returning so the caller coroutine doesn't unblock too early.
		if is_instance_valid(defender) and defender.has_method("take_damage"):
			defender.take_damage(a_atk)
		await _wait(0.15)
		# Note: no state restoration needed — the card was freed by kill_unit().

func _get_hero(is_player: bool) -> Control:
	for row in rows:
		if (is_player and row.row_side == "player") or (not is_player and row.row_side == "enemy"):
			for child in row.get_children():
				if child is Control and child.has_method("get") and "card_info" in child:
					if child.card_info.get("type", "") == "hero":
						return child
	return null

func take_unblocked_damage(amount: int, is_player_attacking: bool):
	if is_game_over: return
	
	var target_hero = _get_hero(not is_player_attacking)
	if target_hero and target_hero.has_method("take_damage"):
		target_hero.take_damage(amount)
		show_notification("HERO HIT! -" + str(amount), Color(1, 0.2, 0.2))
	else:
		# If no hero exists to take damage, fallback to game over to prevent softlocks
		game_over(is_player_attacking)

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
		var run_manager = get_node_or_null("/root/RunManager")
		if run_manager and run_manager.has_method("end_run"):
			run_manager.end_run(false)
		else:
			get_tree().reload_current_scene()

# --- Game Mechanics ---

## Moves a card from its current spot to the Graveyard.
## If the card is the Mother Ship, it triggers Game Over.
func kill_unit(card: Control):
	if is_game_over: return
	
	if card.card_info.get("type", "") == "hero":
		var is_player = card.card_info.get("side", "player") == "player"
		game_over(not is_player)

	if card.card_container:
		card.card_container.remove_card(card)
	
	if card.card_info.get("side", "player") == "player":
		if card.has_method("reset_to_base_state"):
			card.reset_to_base_state()
		discard_pile.add_card(card)
	else:
		card.queue_free() # Simply delete enemy units
		
	show_notification("UNIT DESTROYED", Color(1, 0.2, 0.2))


func _victory():
	is_game_over = true
	show_notification("VICTORY!", Color(0.2, 1.0, 0.2))
	
	var run_manager = get_node_or_null("/root/RunManager")
	if run_manager:
		run_manager.add_resources(50, 10)
		
	await _wait(2.0)
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
	
	# All played spells go to discard pile
	if card.card_container:
		card.card_container.remove_card(card)
	discard_pile.add_card(card)


func _resolve_spell_effect(card: Control, target: Control = null):
	var spell_name = card.card_info.get("name", "")
	var script_path = "res://battle_scene/spells/logic/%s.gd" % spell_name
	
	if FileAccess.file_exists(script_path):
		var spell_script = load(script_path)
		if spell_script:
			var logic_instance = spell_script.new()
			if logic_instance and logic_instance.has_method("execute"):
				var context = {
					"main": self ,
					"card": card,
					"target": target
				}
				await logic_instance.execute(context)
			else:
				push_error("Spell logic script '%s' does not have execute method!" % script_path)
		else:
			push_error("Failed to load spell script: %s" % script_path)
	else:
		push_warning("No logic script found for spell: %s at %s" % [spell_name, script_path])


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
	return current_energy >= total_cost


# Subtracts the energy cost and updates the screen text
func spend_energy(cards: Array) -> void:
	var total_cost = 0
	for card in cards:
		total_cost += int(card.card_info.get("cost", 0))
	current_energy -= total_cost
	_update_ui_labels()


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
		
	if hovered_unit.card_info.get("side", "player") == "enemy":
		# Enforce TAUNT rule
		var has_taunt_enemy = false
		for row in _get_battle_rows():
			for card in row.get_cards():
				if is_instance_valid(card) and card.card_info.get("side", "player") == "enemy":
					if _has_keyword(card, "taunt"):
						has_taunt_enemy = true
						break
			if has_taunt_enemy:
				break
				
		if has_taunt_enemy and not _has_keyword(hovered_unit, "taunt"):
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
			
		await _perform_attack(manual_attacker, hovered_unit)
			
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


# --- Inspection UI ---

var inspected_card: Control = null

func inspect_card(card: Control) -> void:
	if is_game_over: return
	if has_node("InspectLayer"):
		var layer = $InspectLayer
		var pivot = $InspectLayer/InspectOverlay/InspectPivot
		layer.visible = true
		
		# Clear existing if any
		if inspected_card:
			inspected_card.queue_free()
		
		# create_card expects a CardContainer; pass null to spawn it un-parented (factory attaches it to root)
		inspected_card = card_factory.create_card(card.card_info.get("name", "error"), null)
		if inspected_card:
			inspected_card.reparent(pivot)
			# Overwrite the newly spawned card's stats with the current combat base stats of the token, ignoring transient damage
			if "attack" in inspected_card and "health" in inspected_card:
				var base_buffed_atk = card.get("base_attack") if "base_attack" in card else 0
				var base_buffed_hp = card.get("base_health") if "base_health" in card else 0
				
				# Ensure null protection
				if base_buffed_atk == null: base_buffed_atk = 0
				if base_buffed_hp == null: base_buffed_hp = 0
				
				inspected_card.base_attack = base_buffed_atk
				inspected_card.base_health = base_buffed_hp
				inspected_card.attack = base_buffed_atk
				inspected_card.health = base_buffed_hp
				if inspected_card.has_method("_update_card_ui"):
					inspected_card._update_card_ui()
			
			inspected_card.set_view_mode("card")
			if inspected_card.has_method("set_inspect_scale"):
				inspected_card.set_inspect_scale(2.5)
			else:
				inspected_card.scale = Vector2(2.5, 2.5)
				
			# Screen center (960, 540) minus half the scaled card size (200, 275)
			inspected_card.global_position = Vector2(760, 265)
			
			# Disable dragging and hover effects on the inspect card
			inspected_card.can_be_interacted_with = false
			inspected_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			inspected_card.refresh_ui()

func _on_inspect_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if inspected_card:
			inspected_card.queue_free()
			inspected_card = null
		if has_node("InspectLayer"):
			$InspectLayer.visible = false

func _input(event: InputEvent) -> void:
	if is_game_over: return
	
	if event.is_action_pressed("ui_cancel"):
		if has_node("InspectLayer") and $InspectLayer.visible:
			_on_inspect_overlay_gui_input(event) # Re-use existing hide logic
		elif pile_viewer_layer and pile_viewer_layer.visible:
			hide_pile_viewer()
	
	# Q to View Deck
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			if pile_viewer_layer.visible and pile_viewer_title.text == "Draw Pile":
				hide_pile_viewer()
			else:
				show_pile_viewer("Draw Pile", deck)
				
		# E to View Discard
		elif event.keycode == KEY_E:
			if pile_viewer_layer.visible and pile_viewer_title.text == "Discard Pile":
				hide_pile_viewer()
			else:
				show_pile_viewer("Discard Pile", discard_pile)

func show_pile_viewer(title: String, pile_container: CardContainer):
	if not pile_viewer_layer: return
	
	pile_viewer_title.text = title
	
	# Clear existing cards
	for child in pile_viewer_grid.get_children():
		child.queue_free()
		
	# Populate with cards from the pile
	for card_data in pile_container.get_cards():
		var card_instance = card_factory.create_card(card_data.card_info.get("name", "error"), null)
		if card_instance:
			if card_instance.get_parent():
				card_instance.get_parent().remove_child(card_instance)
				
			card_instance.card_info = card_data.card_info.duplicate()
			card_instance.set_view_mode("card")
			card_instance.scale = Vector2(0.8, 0.8) # Smaller scale for pile viewer
			card_instance.can_be_interacted_with = false
			card_instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_instance.refresh_ui()
			pile_viewer_grid.add_child(card_instance)
			
	pile_viewer_layer.visible = true

func hide_pile_viewer():
	if not pile_viewer_layer: return
	pile_viewer_layer.visible = false
	for child in pile_viewer_grid.get_children():
		child.queue_free()


func _execute_spell_with_target(card: Control, target: Object) -> void:
	if is_game_over: return

	if card.card_container:
		card.card_container.remove_card(card)
	
	# Spend energy
	spend_energy([card])
	
	await _resolve_spell_effect(card, target)
	
	# All played spells go to discard pile
	if card.card_container:
		card.card_container.remove_card(card)
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

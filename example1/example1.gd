extends Node

# --- Node References ---
# These variables link the script to the nodes in the scene tree.
@onready var card_manager = $CardManager
@onready var card_factory = $CardManager/MyCardFactory
@onready var hand = $CardManager/Hand
@onready var deck = $CardManager/Deck
@onready var graveyard = $CardManager/Graveyard # Piles like Graveyard and Deck are 'Pile' nodes
@onready var col_1 = $CardManager/BattleField/Column1 # The leftmost column where the Mothership stays

# UI Label References
@onready var energy_label = $EnergyLabel
@onready var round_label = $RoundLabel
@onready var notify_label = $NotificationLabel

# --- Game State Variables ---
var current_energy: int = 0
var max_energy: int = 3
var current_round: int = 0
var notify_tween: Tween           # Used for the fade-out animation of notifications
var is_game_over: bool = false


func _ready():
	# Initialize UI: Make sure the notification label starts invisible
	if notify_label:
		notify_label.modulate.a = 0
	
	# Wait for a frame to let the UI layout settle before spawning the Mother Ship.
	# This ensures Column positions are calculated correctly for the initial move.
	await get_tree().process_frame
	_start_new_game()


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
	_reset_deck()
	
	# MANDATORY STEP: Deploy the Mother Ship at the very start
	# col_1 is the leftmost column. 
	# The BattleColumn script ensures the ship stays in the middle slot.
	var ship = card_factory.create_card("building_mothership", col_1)
	if ship:
		# Important: This blocks the player from dragging the Mothership
		ship.can_be_interacted_with = false
	
	_start_next_round()


# Advanced to the next round, resets energy, and draws cards
func _start_next_round():
	if is_game_over: return
	
	current_round += 1
	current_energy = max_energy
	_update_ui_labels()
	
	if current_round == 1:
		_first_round_draw() # Special draw for the start of the game
	else:
		_draw_cards(2) # Draw 2 cards every round
		_spawn_enemy_units() # Spawn some random enemies to fight


func _spawn_enemy_units():
	# Get NEW enemy columns (Indices 4, 5, 6, 7 -> Cols 5, 6, 7, 8)
	# Spawning logic: Always spawn at the BACK (Column 8 / Index 7)
	# to allow them to march forward.
	var field = card_manager.get_node("BattleField")
	var spawn_col_idx = 7 # Column 8
	if spawn_col_idx < field.get_child_count():
		var target_col = field.get_child(spawn_col_idx)
		
		# Increase difficulty: more bots as rounds progress
		var spawn_count = 1
		if current_round > 2: spawn_count = 2
		if current_round > 5: spawn_count = 3
		
		# Boss Round: Spawn Boss at Round 5, 10, 20...
		if current_round % 10 == 0 or current_round == 5:
			show_notification("BOSS WARNING: OMEGA BOT DETECTED!", Color(1, 0, 0))
			var _boss = card_factory.create_card("unit_boss_mk1", target_col)
		else:
			for i in range(spawn_count):
				if target_col.get_card_count() < 5:
					var _bot = card_factory.create_card("unit_bot_mk1", target_col)


# Special opening hand logic
func _first_round_draw():
	# Always give the player the Hero card first
	var _hero = card_factory.create_card("hero_robot_bill", hand)
	_draw_cards(3) # Then draw 3 random cards


# Moves a specific number of cards from the top of the Deck to the Hand
func _draw_cards(count: int):
	var cards = deck.get_top_cards(count)
	if cards.size() > 0:
		hand.move_cards(cards)


# Refreshes the text display for Energy and Rounds
func _update_ui_labels():
	if energy_label:
		energy_label.text = "Energy: %d / %d" % [current_energy, max_energy]
	if round_label:
		round_label.text = "Round: %d" % current_round


# Clears the deck and refills it with a fresh, shuffled list of cards
func _reset_deck():
	var list = _get_randomized_card_list()
	deck.clear_cards()
	for card_name in list:
		card_factory.create_card(card_name, deck)
	deck.shuffle()


# Returns the master list of all available cards in the deck
func _get_randomized_card_list() -> Array:
	var list = [
		"unit_bot_mk1", "unit_bot_mk1", "unit_bot_mk1",
		"unit_bot_mk2", "unit_bot_mk2",
		"spell_zap", "spell_zap",
		"spell_overdrive",
		"building_turret", "building_turret",
		"custom_unit_1", "custom_unit_2", "custom_unit_3"
	]
	var full_deck = []
	# Triple the list to create a 39-card deck for longer games
	for i in range(3):
		full_deck.append_array(list)
	full_deck.shuffle()
	return full_deck


func _get_battle_columns() -> Array:
	var cols = []
	var field = card_manager.get_node("BattleField")
	for child in field.get_children():
		if child is BattleColumn:
			cols.append(child)
	return cols


func _on_end_round_button_pressed():
	_run_combat_phase()


func _run_combat_phase():
	# Disable interaction during combat
	for col in _get_battle_columns():
		for card in col.get_cards():
			card.can_be_interacted_with = false
	
	show_notification("COMBAT START", Color(1, 0.5, 0.2))
	await get_tree().create_timer(0.5).timeout
	
	# Process each lane (0 to 4)
	for lane_index in range(5):
		await _resolve_lane_combat(lane_index)
	
	show_notification("COMBAT END", Color(1, 0.8, 0.2))
	await get_tree().create_timer(0.5).timeout
	
	_move_enemies_phase()
	_start_next_round()


func _move_enemies_phase():
	# Marching Logic: Enemies move one column to the LEFT if space is empty
	# Iterate columns 4, 5, 6, 7 (Indices 4-7 correspond to Columns 5-8)
	# We process from Left (4) to Right (7) so we don't move the same unit multiple times?
	# No, we must process from Left-most enemy column (Index 4) to Right-most (Index 7).
	# Wait, if Index 4 moves to Index 3 (Player side), that's an invasion!
	# But for now, let's keep them in enemy territory or "invade" if we want.
	# Monster Train: They march until they hit the Pyre.
	# Let's say indices 4-7 are enemy cols. Player cols are 0-3.
	# If a unit is in Index 4, and Index 3 is empty... it invades?
	# For simplicity: Enemies only march WITHIN enemy territory for now (Col 8 -> 7 -> 6 -> 5).
	# Actually, if they are frontliners (Col 5), they fight.
	# Let's make them march towards the player.
	
	var columns = _get_battle_columns()
	# Iterate through enemy columns from Left (Index 4) to Right (Index 7)
	# Actually, usually you want to move the front-most ones first? No, if Col 4 moves to 3, Col 5 can move to 4.
	# So we iterate from Left (closest to player) to Right.
	
	# Iterate through all columns from the left-most player territory (Index 1) to the spawn point (Index 7)
	# Target index 0 is reserved for the Mother Ship.
	for col_idx in range(2, 8): 
		if col_idx >= columns.size(): break
		
		var current_col = columns[col_idx]
		var target_col_idx = col_idx - 1
		
		# Don't move if target is out of bounds (shouldn't happen if 4->3 is allowed)
		if target_col_idx < 0: continue
		
		var target_col = columns[target_col_idx]
		
		# Check units in current column
		# We need to iterate a copy because we might modify the list by moving cards
		var moving_units = current_col.get_cards().duplicate()
		for card in moving_units:
			if card.card_info.get("side", "player") == "player": continue # Only enemies march
			if card.card_info.get("name", "") == "building_mothership": continue
			
			# Attempt to move to target column if space is available
			# The battle_column logic _card_can_be_added might block it if full, 
			# but we can force move or check capacity.
			# For now, let's try to move.
			
			# Monster Train logic: Units move to the next floor. 
			# Here: Move to next column.
			
			# We only move if the SLOT in the next column is free?
			# Or just dump them in? BattleColumn auto-arranges. 
			# Let's just try to move them.
			if target_col.get_card_count() < 5:
				current_col.remove_card(card)
				target_col.add_card(card)
				
	# Animate bumps or something? transitions handles it.


func _resolve_lane_combat(lane_index: int):
	var columns = _get_battle_columns()
	# Column indices: 0,1,2 (Player) | 3,4,5 (Enemy)
	
	# Start multi-unit combat resolution
	while true:
		var p_units = []
		var e_units = []
		
		# Refresh lists because units might have died in previous loop
		for i in range(columns.size()):
			var col = columns[i]
			var unit = _get_unit_at_lane(col, lane_index)
			if unit and is_instance_valid(unit) and unit.card_container != graveyard:
				if unit.card_info.get("side", "player") == "player":
					p_units.append({"unit": unit, "col": i})
				else:
					e_units.append({"unit": unit, "col": i})
		
		# Find current frontlines
		var p_front = null
		if p_units.size() > 0:
			p_front = p_units[0]["unit"]
			var max_col = p_units[0]["col"]
			for p in p_units:
				if p["col"] > max_col:
					max_col = p["col"]
					p_front = p["unit"]
					
		var e_front = null
		if e_units.size() > 0:
			e_front = e_units[0]["unit"]
			var min_col = e_units[0]["col"]
			for e in e_units:
				if e["col"] < min_col:
					min_col = e["col"]
					e_front = e["unit"]
		
		# Resolve phase
		if p_front and e_front:
			var is_relentless = p_front.card_info.get("is_boss", false) or e_front.card_info.get("is_boss", false)
			
			if is_relentless:
				show_notification("RELENTLESS COMBAT!", Color(1, 0, 0))
				while is_instance_valid(p_front) and is_instance_valid(e_front) and p_front.card_container != graveyard and e_front.card_container != graveyard:
					await _perform_attack(p_front, e_front)
					await get_tree().create_timer(0.3).timeout
			else:
				await _perform_attack(p_front, e_front)
				await get_tree().create_timer(0.2).timeout
			
			# Continue loop to next units if someone died
		elif e_front:
			# No player units left to block - check for Mother Ship strike
			var col_idx = -1
			for i in range(columns.size()):
				if _get_unit_at_lane(columns[i], lane_index) == e_front:
					col_idx = i
					break
			
			if col_idx >= 1:
				if lane_index == 2: # Mother Ship lane
					var m_ship = null
					var col1 = columns[0]
					var possible_ship = _get_unit_at_lane(col1, 2)
					if possible_ship and possible_ship.card_info.get("name", "") == "building_mothership":
						m_ship = possible_ship
					
					if m_ship:
						await _perform_attack(e_front, m_ship)
			break # Enemy attacked base or nothing left
		else:
			break # No enemies or no units
	
	# Small delay between lanes
	await get_tree().create_timer(0.2).timeout


func _get_unit_at_lane(column: BattleColumn, lane_index: int) -> Card:
	# BattleColumn stores cards in _held_cards. 
	# The layout logic in _update_target_positions handles the mapping.
	# Mothership is always slot 2 (lane 2).
	# Other cards occupy available_slots = [0, 1, 3, 4]
	
	var mothership_card = null
	var other_cards = []
	for card in column.get_cards():
		if card.card_info.get("name", "") == "building_mothership":
			mothership_card = card
		else:
			other_cards.append(card)
			
	if lane_index == 2:
		return mothership_card
	
	var available_slots = [0, 1, 3, 4]
	if not mothership_card:
		available_slots = [0, 1, 2, 3, 4]
		
	var slot_to_unit_index = available_slots.find(lane_index)
	if slot_to_unit_index != -1 and slot_to_unit_index < other_cards.size():
		return other_cards[slot_to_unit_index]
		
	return null


func _perform_attack(attacker: Card, defender: Card):
	# Visual feedback: Simple bump
	var a_pos = attacker.global_position
	var d_pos = defender.global_position
	var mid = (a_pos + d_pos) / 2
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(attacker, "global_position", mid, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(defender, "global_position", mid + (d_pos - a_pos).normalized() * 50, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	
	# Resolve damage
	var a_atk = int(attacker.card_info.get("attack", 0))
	var d_atk = int(defender.card_info.get("attack", 0))
	
	if defender.has_method("take_damage"):
		defender.take_damage(a_atk)
	if attacker.has_method("take_damage"):
		attacker.take_damage(d_atk)
		
	# Back to positions (only for survivors)
	var survivors = []
	if is_instance_valid(attacker) and attacker.card_container != graveyard:
		survivors.append(attacker)
	if is_instance_valid(defender) and defender.card_container != graveyard:
		survivors.append(defender)
		
	if survivors.size() > 0:
		var back_tween = create_tween()
		back_tween.set_parallel(true)
		if attacker in survivors:
			back_tween.tween_property(attacker, "global_position", a_pos, 0.1)
		if defender in survivors:
			back_tween.tween_property(defender, "global_position", d_pos, 0.1)
		await back_tween.finished


# --- Game Mechanics ---

## Moves a card from its current spot to the Graveyard.
## If the card is the Mother Ship, it triggers Game Over.
func kill_unit(card: Card):
	if is_game_over: return
	
	if card.card_info.get("name", "") == "building_mothership":
		_game_over()
		return

	if card.card_container:
		card.card_container.remove_card(card)
	graveyard.add_card(card)
	show_notification("UNIT DESTROYED", Color(1, 0.2, 0.2))


# Stops the game and shows the failure message
func _game_over():
	is_game_over = true
	show_notification("GAME OVER - MOTHERSHIP DESTROYED", Color(1, 0.1, 0.1))


## Handles spell casting. 
## Deducts energy and returns the spell card to the deck (draw pile).
func play_spell(card: Card):
	if is_game_over: return
	
	if card.card_container:
		card.card_container.remove_card(card)
	
	# Spend energy based on the card's "cost" property in JSON
	spend_energy([card])
	
	_resolve_spell_effect(card)
	
	# Spells go back to deck and deck shuffles as requested
	deck.add_card(card)
	deck.shuffle()


func _resolve_spell_effect(card: Card):
	var spell_name = card.card_info.get("name", "")
	
	match spell_name:
		"spell_zap":
			# Find a target: Frontmost enemy in a random lane
			var potential_targets = []
			for lane in range(5):
				var unit = _find_frontmost_unit(lane, false) # false = enemy
				if unit:
					potential_targets.append(unit)
			
			if potential_targets.size() > 0:
				var target = potential_targets.pick_random()
				show_notification("ZAP! 2 DAMAGE", Color(1, 1, 0))
				target.take_damage(2)
			else:
				show_notification("ZAP FAILED - NO TARGETS", Color(0.5, 0.5, 0.5))
				
		"spell_overdrive":
			# Buff a random friendly unit on the field
			var friendly_units = []
			for col in _get_battle_columns():
				if col.is_player_column:
					for unit in col.get_cards():
						if unit.card_info.get("name", "") != "building_mothership":
							friendly_units.append(unit)
			
			if friendly_units.size() > 0:
				var target = friendly_units.pick_random()
				var old_atk = int(target.card_info.get("attack", 0))
				target.card_info["attack"] = float(old_atk + 2)
				target.refresh_ui()
				show_notification("OVERDRIVE! +2 ATTACK", Color(1, 0, 1))
			else:
				show_notification("OVERDRIVE FAILED - NO TARGETS", Color(0.5, 0.5, 0.5))


func _find_frontmost_unit(lane_index: int, player_side: bool) -> Card:
	var columns = _get_battle_columns()
	if player_side:
		# Player frontline is right-most (Index 3 down to 0)
		for i in range(3, -1, -1):
			var unit = _get_unit_at_lane(columns[i], lane_index)
			if unit: return unit
	else:
		# Enemy frontline is left-most (Index 4 to 7)
		for i in range(4, 8):
			if i >= columns.size(): break
			var unit = _get_unit_at_lane(columns[i], lane_index)
			if unit: return unit
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


# --- UI Signals ---

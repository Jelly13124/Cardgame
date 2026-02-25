extends Node

signal unit_stats_changed(unit: Control, atk: int, hp: int, is_permanent: bool)

# --- Node References ---
# These variables link the script to the nodes in the scene tree.
@onready var card_manager = $CardManager
@onready var card_factory = $CardManager/MyCardFactory
@onready var hand = $CardManager/Hand
@onready var deck = $CardManager/Deck
# @onready var graveyard = $CardManager/Graveyard # Removed from scene
@onready var rows = _get_battle_rows()

# UI Label References
@onready var energy_label = $EnergyLabel
@onready var round_label = $RoundLabel
@onready var notify_label = $NotificationLabel
@onready var speed_button = $SpeedButton

# --- Game State Variables ---
var current_energy: int = 0
var max_energy: int = 3
var current_round: int = 0
var notify_tween: Tween # Used for the fade-out animation of notifications
var is_game_over: bool = false
var speed_options: Array[float] = [0.25, 0.5, 1.0, 2.0]
var speed_labels: Array[String] = ["x 1/2", "x 1", "x 2", "x 4"]
var current_speed_idx: int = 1
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
	if speed_button:
		speed_button.text = "Speed: " + speed_labels[current_speed_idx]
	
	var rows_array = _get_battle_rows()
	if rows_array.size() >= 3:
		rows_array[0].row_side = "enemy"
		rows_array[1].row_side = "enemy"
		rows_array[2].row_side = "player"
		
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
		var mouse_pos = get_viewport().get_mouse_position()
		if targeting_arrow:
			targeting_arrow.queue_redraw()
			
		var unit_under_mouse = _get_unit_at_position(mouse_pos)
		if unit_under_mouse and unit_under_mouse.card_info.get("side", "player") == "enemy":
			if unit_under_mouse != hovered_unit:
				if hovered_unit: _set_hover_effect(hovered_unit, false)
				hovered_unit = unit_under_mouse
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
	_reset_deck()
	# Deploy the Mother Ship in the center of the player row (REMOVED)
	# Mothership UI is removed; Player health is now the sole win/loss condition
	
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

	# Trigger Turn Start abilities (e.g. Leader buff)
	for row in _get_battle_rows():
		for card in row.get_cards():
			if is_instance_valid(card) and "keyword_instances" in card:
				for kw in card.keyword_instances:
					if kw.has_method("on_turn_start"):
						kw.on_turn_start(row)


func _spawn_enemy_units():
	var rows_list = _get_battle_rows()
	if rows_list.size() < 3: return
	
	# Increase difficulty: more bots as rounds progress
	var spawn_count = 1
	if current_round > 2: spawn_count = 2
	if current_round > 5: spawn_count = 3
	
	var enemy_types = ["alien_soldier", "alien_sniper", "alien_killer", "unit_reaper"]
	
	for i in range(spawn_count):
		var spawn_row = rows_list[0] if randi() % 2 == 0 else rows_list[1]
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


# Special opening hand logic
func _first_round_draw():
	# Always give the player the Hero card first
	var _hero = card_factory.create_card("hero_robot_bill", hand)
	
	# Draw up to 3 random UNITS specifically for the first round
	var units_found = []
	var all_deck_cards = deck.get_cards()
	# Reverse to get from 'top' of pile if needed, but deck is shuffled
	for i in range(all_deck_cards.size() - 1, -1, -1):
		var card = all_deck_cards[i]
		if card.card_info.get("type", "") == "unit":
			units_found.append(card)
			if units_found.size() >= 3:
				break
				
	if units_found.size() > 0:
		hand.move_cards(units_found)


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
	var list = []
	var run_manager = get_node_or_null("/root/RunManager")
	if run_manager and run_manager.is_run_active:
		list = run_manager.player_deck.duplicate()
	else:
		list = _get_randomized_card_list()
		
	rectify_deck_if_small(list)
	
	deck.clear_cards()
	for item in list:
		var card_name = item if typeof(item) == TYPE_STRING else item["card_id"]
		var card = card_factory.create_card(card_name, deck)
		if card and typeof(item) == TYPE_DICTIONARY:
			card.set_meta("uid", item["uid"])
			if card is UnitCard:
				var b_atk = item.get("bonus_attack", 0)
				var b_hp = item.get("bonus_health", 0)
				if b_atk > 0 or b_hp > 0:
					card.add_permanent_stats(b_atk, b_hp)
	deck.shuffle()

func rectify_deck_if_small(list: Array):
	# Fallback if deck is too small (e.g drafted a single card test deck)
	while list.size() < 10:
		list.append_array(list.duplicate())


# Returns the master list of all available cards in the deck
func _get_randomized_card_list() -> Array:
	var list = [
		"spell_zap", "spell_zap",
		"spell_draft", "spell_air_raid",
		"unit_robot_leader", "unit_robot_leader"
	]
	var full_deck = []
	# Triple the list to create a 39-card deck for longer games
	for i in range(3):
		full_deck.append_array(list)
	full_deck.shuffle()
	return full_deck


func _get_battle_rows() -> Array:
	var list = []
	var field = card_manager.get_node("BattleField")
	for child in field.get_children():
		if child.is_in_group("battle_row"):
			list.append(child)
	return list


func _on_end_round_button_pressed():
	_execute_enemy_turn()

func _on_speed_button_pressed():
	current_speed_idx = (current_speed_idx + 1) % speed_options.size()
	if is_in_combat_phase:
		Engine.time_scale = speed_options[current_speed_idx]
	if speed_button:
		speed_button.text = "Speed: " + speed_labels[current_speed_idx]

func _execute_enemy_turn():
	if is_in_combat_phase or is_game_over: return
	is_in_combat_phase = true
	Engine.time_scale = speed_options[current_speed_idx]
	
	# Disable interaction during combat
	for row in _get_battle_rows():
		for card in row.get_cards():
			card.can_be_interacted_with = false
	
	show_notification("ENEMY TURN", Color(1, 0.4, 0.4))
	await _wait(1.0)
	
	# Enemy AI: Attack random targets
	var rows_list = _get_battle_rows()
	if rows_list.size() >= 3:
		var enemy_rows = [rows_list[0], rows_list[1]]
		var player_row = rows_list[2]
		
		for e_row in enemy_rows:
			var e_cards = e_row.get_cards()
			for e_unit in e_cards:
				# Check if still valid (could be killed by spikes/etc)
				if not is_instance_valid(e_unit) or e_unit.get_parent() == null: continue
				if e_unit.card_info.get("side", "player") == "enemy":
					# Gather valid targets again in case someone died
					var valid_targets = []
					for card in player_row.get_cards():
						if is_instance_valid(card) and card.card_info.get("side", "player") == "player":
							valid_targets.append(card)
							
					if valid_targets.size() > 0:
						var target = valid_targets[randi() % valid_targets.size()]
						var attack_count = 2 if _has_keyword(e_unit, "wind") else 1
						if is_instance_valid(e_unit) and is_instance_valid(target):
							await _perform_attack(e_unit, target)
							await _wait(0.2)
					else:
						# No targets! Direct face damage
						var a_atk = int(e_unit.card_info.get("attack", 0))
						var run_manager = get_node_or_null("/root/RunManager")
						if run_manager:
							run_manager.modify_health(-a_atk)
							show_notification("FACE HIT! -" + str(a_atk), Color(1, 0.2, 0.2))
							
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
	
	show_notification("YOUR TURN", Color(0.4, 0.8, 1.0))
	await _wait(0.5)
	
	is_in_combat_phase = false
	Engine.time_scale = 1.0
	
	# Reset player attacks
	if rows_list.size() >= 3:
		for card in rows_list[2].get_cards():
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
	# Visual feedback: Simple bump
	var a_pos = attacker.global_position
	var d_pos = defender.global_position
	
	var tween = create_tween()
	# Move attacker to slightly in front of defender
	var strike_pos = d_pos - (d_pos - a_pos).normalized() * 20
	tween.tween_property(attacker, "global_position", strike_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	
	# Resolve damage
	var a_atk = int(attacker.card_info.get("attack", 0))
	var d_atk = int(defender.card_info.get("attack", 0))
	
	if defender.has_method("take_damage"):
		defender.take_damage(a_atk)
		
	if is_instance_valid(attacker) and attacker.has_method("take_damage"):
		attacker.take_damage(d_atk)
		
	# Back to positions (only for survivors)
	var survivors = []
	if is_instance_valid(attacker) and attacker.get_parent() != null:
		survivors.append(attacker)
	if is_instance_valid(defender) and defender.get_parent() != null:
		survivors.append(defender)
		
	if survivors.size() > 0:
		var back_tween = create_tween()
		if attacker in survivors:
			back_tween.tween_property(attacker, "global_position", a_pos, 0.15)
		await back_tween.finished
# --- Game Mechanics ---

## Moves a card from its current spot to the Graveyard.
## If the card is the Mother Ship, it triggers Game Over.
func kill_unit(card: Control):
	if is_game_over: return
	
	if card.card_info.get("is_boss", false):
		_victory()

	if card.card_container:
		card.card_container.remove_card(card)
	card.queue_free() # Simply delete the unit
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
	
	# Spells go back to deck and deck shuffles as requested
	deck.add_card(card)
	deck.shuffle()


func _resolve_spell_effect(card: Control, target: Control = null):
	var spell_name = card.card_info.get("name", "")
	var script_path = "res://battle_scene/spells/logic/%s.gd" % spell_name
	
	if FileAccess.file_exists(script_path):
		var spell_script = load(script_path)
		if spell_script:
			var logic_instance = spell_script.new()
			if logic_instance and logic_instance.has_method("execute"):
				var context = {
					"main": self,
					"card": card,
					"target": target
				}
				logic_instance.execute(context)
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
		# Always valid if clicking in the game window (or specifically battlefield?)
		# For now, just assume any click in targeting mode is valid for "none" type
		final_target = null # No specific target object needed for global spells
		is_valid_target = true
	
	# Remove arrow first
	if targeting_arrow and is_instance_valid(targeting_arrow):
		targeting_arrow.stop()
		targeting_arrow.queue_free()
		targeting_arrow = null
	
	# Un-highlight the card
	if targeting_card and is_instance_valid(targeting_card):
		targeting_card.modulate = Color.WHITE
	
	if not is_valid_target:
		# Don't cancel immediately on release in empty space IF we were holding (old logic),
		# but for Click-Toggle, clicking empty space SHOULD cancel.
		show_notification("INVALID TARGET", Color(0.8, 0.4, 0.4))
		_cancel_spell_targeting() # Use the standardized cancel method to clean up overlay
		return
	
	# Cast the spell on the target
	var card = targeting_card
	
	# Cleanup targeting state (overlay, arrow, vars)
	# We call _cancel_spell_targeting logic manually or just reset specific things?
	# Better to reset specific things to avoid "TARGETING CANCELLED" message overriding "SPELL CAST"
	
	# Remove arrow
	if targeting_arrow and is_instance_valid(targeting_arrow):
		targeting_arrow.stop()
		targeting_arrow.queue_free()
		targeting_arrow = null
	
	# Un-highlight
	if targeting_card and is_instance_valid(targeting_card):
		targeting_card.modulate = Color.WHITE
		
	if hovered_unit:
		_set_hover_effect(hovered_unit, false)
		hovered_unit = null

	if hovered_row and hovered_row.has_method("set_highlight"):
		hovered_row.set_highlight(false)
		hovered_row = null
		
	if targeting_overlay:
		targeting_overlay.visible = false
		
	targeting_card = null
	is_targeting = false
	
	# Execute the spell at the current position with the resolved target
	_execute_spell_with_target(card, final_target)


# --- Manual Attack Actions ---
func start_manual_attack(attacker: Control):
	if is_game_over: return
	
	is_manual_attacking = true
	manual_attacker = attacker
	
	if not targeting_arrow:
		targeting_arrow = TARGETING_ARROW_SCRIPT.new()
		add_child(targeting_arrow)
		
	targeting_arrow.origin = attacker.global_position
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
		
	if targeting_overlay:
		targeting_overlay.visible = false
		
	var target = hovered_unit
	if hovered_unit:
		_set_hover_effect(hovered_unit, false)
		hovered_unit = null
	
	if is_instance_valid(target) and target.card_info.get("side", "player") == "enemy":
		if manual_attacker and is_instance_valid(manual_attacker):
			manual_attacker.can_attack = false
			manual_attacker.modulate = Color(0.6, 0.6, 0.6) # Highlight as exhausted
			_perform_attack(manual_attacker, target)
			
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


func _execute_spell_with_target(card: Control, target: Object) -> void:
	if is_game_over: return

	if card.card_container:
		card.card_container.remove_card(card)
	
	# Spend energy
	spend_energy([card])
	
	_resolve_spell_effect(card, target)
	
	# Spells go back to deck
	deck.add_card(card)
	deck.shuffle()


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

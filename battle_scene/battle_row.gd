class_name BattleRow
extends CardContainer

## BattleRow - A standardized 8-slot horizontal container for a single "floor" of combat.
## Slots 0-3: Player territory (Left)
## Slots 4-7: Enemy territory (Right)

@export var row_index: int = 0

const TOTAL_SLOTS = 8
var slot_width: float = 230.0 # Approximate width per slot (1870 / 8)
var start_x: float = 20.0
var center_y: float = 70.0

func _init() -> void:
	super._init()
	enable_drop_zone = true

func _ready() -> void:
	super._ready()
	add_to_group("battle_row")
	# Full row sensor
	if drop_zone:
		drop_zone.set_sensor(Vector2(1870, 140), Vector2.ZERO, null, false)
		
		# Define partitions for the 4 player slots (LOCAL COORDINATES)
		# Slots boundaries: 240, 470, 700, 935 (Center)
		# NOTE: We keep partitions in DropZone for internal logic, 
		# but BattleRow handles the index mapping manually for precision.
		drop_zone.set_vertical_partitions([230, 460, 690, 920, 1150, 1380, 1610])

func _card_can_be_added(cards: Array) -> bool:
	var main = get_tree().current_scene
	
	for card in cards:
		var side = card.card_info.get("side", "player")
		var _is_player = (side == "player")
		
		# Check capacity for player side (Slots 0-3)
		var player_unit_count = 0
		for held in _held_cards:
			if held.card_info.get("side", "player") == "player":
				player_unit_count += 1
		
		# Rule 1: Only Units/Heroes can be deployed to battle rows (No Spells)
		var card_type = card.card_info.get("type", "unit")
		if card_type != "unit" and card_type != "hero":
			if main and main.has_method("show_notification"):
				main.show_notification("ONLY UNITS ALLOWED", Color(1, 0.4, 0.4))
			return false

		# If we are adding a player unit, ensure we don't exceed 4
		if side == "player" and player_unit_count >= 4:
			if main and main.has_method("show_notification"):
				main.show_notification("ROW SIDE FULL", Color(1, 0.4, 0.4))
			print("Drop failed: Row side full (Count: %d)" % player_unit_count)
			return false
			
	# Energy check (if from hand)
	if main and main.has_method("can_afford"):
		var from_hand = false
		for card in cards:
			if card.card_container and card.card_container is Hand:
				from_hand = true
				break
		if from_hand and not main.can_afford(cards):
			if main.has_method("show_notification"):
				main.show_notification("NOT ENOUGH ENERGY", Color(0.2, 0.6, 1))
			return false
			
	return true

## Override layout to position cards in their respective slots
func _update_target_positions() -> void:
	var p_units = []
	var e_units = []
	for card in _held_cards:
		if card.card_info.get("side", "player") == "player":
			p_units.append(card)
		else:
			e_units.append(card)
	
	# 1. Position Player Units
	# Track which spots are taken
	var taken_slots = {}
	for card in p_units:
		var slot = card.get_meta("battle_slot", -1)
		if slot != -1:
			taken_slots[slot] = card
			
	# Assign slots to those who don't have one
	for card in p_units:
		if card.get_meta("battle_slot", -1) == -1:
			for s in range(4):
				if not taken_slots.has(s):
					card.set_meta("battle_slot", s)
					taken_slots[s] = card
					break
	
	# Actually position them
	for card in p_units:
		var slot = card.get_meta("battle_slot", -1)
		if slot != -1 and slot < 4:
			_position_card_at_slot(card, slot)
		
	# 2. Position Enemy Units (Filling 4, 5, 6, 7)
	# Enemies start at 4 (Front) and fill back to 7.
	for i in range(e_units.size()):
		var slot = 4 + i
		if slot > 7: break
		e_units[i].set_meta("battle_slot", slot)
		_position_card_at_slot(e_units[i], slot)

func _position_card_at_slot(card: Card, slot_index: int) -> void:
	var target_pos = global_position + Vector2(start_x + (slot_index * slot_width) + (slot_width / 2), center_y)
	# Center alignment adjustment for cards
	target_pos -= Vector2(80, 110) * 0.6 # Adjust based on 0.6 scale
	
	card.move(target_pos, 0)
	card.scale = Vector2(0.6, 0.6)
	card.original_scale = Vector2(0.6, 0.6)
	card.show_front = true
	
	# Interaction lock for enemies
	if card.card_info.get("side", "player") == "enemy":
		card.can_be_interacted_with = false
	else:
		card.can_be_interacted_with = true
		
	if card.has_method("set_view_mode"):
		card.set_view_mode("token")

## Helper to get unit in a specific slot
func get_card_at_slot(slot: int) -> Card:
	for card in _held_cards:
		if card.get_meta("battle_slot", -1) == slot:
			return card
	return null

func move_cards(cards: Array, index: int = -1, with_history: bool = true) -> bool:
	var hand_cards = []
	
	var drop_slot = index
	
	# If dropping via drag-and-drop, calculate slot from mouse position
	if drop_slot == -1:
		var local_mouse_x = get_local_mouse_position().x
		
		# STRICT CHECK: Only allow drops on the Player Side (Left ~935px)
		if local_mouse_x >= 935:
			if debug_mode: print("[BattleRow] Rejected: Can only deploy to Player Side.")
			var main = get_tree().current_scene
			if main and main.has_method("show_notification"):
				main.show_notification("INVALID ZONE", Color(0.8, 0.4, 0.4))
			return false
			
		drop_slot = int(clamp(floor((local_mouse_x - 10) / slot_width), 0, 3))
	
	# Double check: Only allow slots 0-3 for player deployment
	if drop_slot > 3:
		return false
	
	if debug_mode:
		print("[BattleRow %d] move_cards fired. Assigned slot: %d" % [row_index, drop_slot])
	
	for card in cards:
		if card.card_container is Hand:
			hand_cards.append(card)
			card.set_meta("just_deployed", true)
			# Force side to player when played from hand
			if card is UnitCard:
				card.card_info["side"] = "player"
				card.refresh_ui()
			
			# Store the chosen slot
			card.set_meta("battle_slot", drop_slot)
	
	# Pass the raw index to CardContainer to handle internal logistics
	var success = super.move_cards(cards, index, with_history)
	
	if success and hand_cards.size() > 0:
		var main = get_tree().current_scene
		if main and main.has_method("spend_energy"):
			main.spend_energy(hand_cards)
	return success

func on_card_move_done(card: Card):
	# When a card is successfully moved to a BattleRow, 
	# we ensure it's in Token mode.
	if card is UnitCard:
		card.set_view_mode("token")
		if card.get_meta("just_deployed", false):
			card.set_meta("just_deployed", false)
			var slot = card.get_meta("battle_slot", -1)
			if "keyword_instances" in card:
				for kw in card.keyword_instances:
					if kw.has_method("on_deploy"):
						kw.on_deploy(self, slot)

func remove_card(card: Card) -> bool:
	var result = super.remove_card(card)
	if result:
		card.scale = Vector2(1, 1)
		card.original_scale = Vector2(1, 1)
		if card.has_method("set_view_mode"):
			card.set_view_mode("card")
	return result

func set_highlight(active: bool) -> void:
	if has_node("HighlightRect"):
		$HighlightRect.visible = active

class_name BattleRow
extends CardContainer

## BattleRow - A standardized 8-slot horizontal container for a single "floor" of combat.
## Slots 0-3: Player territory (Left)
## Slots 4-7: Enemy territory (Right)

@export var row_index: int = 0
@export var row_side: String = "player" # "player" or "enemy"

const TOTAL_SLOTS = 7 # Center them 1870 / 230 = ~8, so 7 is nicely centered
var slot_width: float = 230.0
var start_x: float = 130.0
var center_y: float = 130.0

func _init() -> void:
	super._init()
	enable_drop_zone = true

func _ready() -> void:
	super._ready()
	add_to_group("battle_row")
	# Full row sensor
	if drop_zone:
		drop_zone.set_sensor(Vector2(1870, 260), Vector2.ZERO, null, false)
		
		# Full row partitions across the 7 slots
		drop_zone.set_vertical_partitions([130 + 230 * 1, 130 + 230 * 2, 130 + 230 * 3, 130 + 230 * 4, 130 + 230 * 5, 130 + 230 * 6])

func _card_can_be_added(cards: Array) -> bool:
	var main = get_tree().current_scene
	
	for card in cards:
		var side = card.card_info.get("side", "player")
		var _is_player = (side == "player")
		# New Logic: Enforce Row Side
		if side != row_side:
			if main and main.has_method("show_notification"):
				main.show_notification("INVALID ROW SIDE", Color(1, 0.4, 0.4))
			return false
		
		# Check capacity for the whole row (Max TOTAL_SLOTS)
		var unit_count = _held_cards.size()
		
		# If we are adding a unit, ensure we don't exceed max slots
		if unit_count >= TOTAL_SLOTS:
			if main and main.has_method("show_notification"):
				main.show_notification("ROW FULL", Color(1, 0.4, 0.4))
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
	var units = []
	for card in _held_cards:
		units.append(card)
	
	# Track which spots are taken
	var taken_slots = {}
	for card in units:
		var slot = card.get_meta("battle_slot", -1)
		if slot != -1:
			taken_slots[slot] = card
			
	# Assign slots to those who don't have one
	for card in units:
		if card.get_meta("battle_slot", -1) == -1:
			for s in range(TOTAL_SLOTS):
				if not taken_slots.has(s):
					card.set_meta("battle_slot", s)
					taken_slots[s] = card
					break
	
	# Actually position them
	for card in units:
		var slot = card.get_meta("battle_slot", -1)
		if slot != -1 and slot < TOTAL_SLOTS:
			_position_card_at_slot(card, slot)

func _position_card_at_slot(card: Card, slot_index: int) -> void:
	var target_pos = global_position + Vector2(start_x + (slot_index * slot_width) + (slot_width / 2), center_y)
	# Center alignment adjustment for cards
	target_pos -= Vector2(80, 110) # Adjust based on 1.0 scale (160x220 raw size)
	
	card.move(target_pos, 0)
	card.scale = Vector2(1.0, 1.0)
	card.original_scale = Vector2(1.0, 1.0)
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
		drop_slot = int(clamp(floor((local_mouse_x - 130) / slot_width), 0, TOTAL_SLOTS - 1))
	
	# Double check slot isn't out of bounds
	if drop_slot >= TOTAL_SLOTS:
		return false
	
	# Check if slot is occupied (we can only deploy to empty slots)
	if get_card_at_slot(drop_slot) != null:
		if debug_mode: print("[BattleRow] slot %d is occupied!" % drop_slot)
		var main = get_tree().current_scene
		if main and main.has_method("show_notification"):
			main.show_notification("SLOT OCCUPIED", Color(1, 0.4, 0.4))
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

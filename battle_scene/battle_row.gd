class_name BattleRow
extends CardContainer

## BattleRow - A horizontal container for one side of combat.
## Each row belongs to a single side ("player" or "enemy").
## Units are laid out evenly across up to TOTAL_SLOTS positions.

@export var row_index: int = 0
@export var row_side: String = "player" # "player" or "enemy"

const TOTAL_SLOTS = 7 # Max cards allowed in a single row
var slot_width: float = 230.0
# We calculate center based on 1870 total width
var row_width: float = 1870.0
var center_y: float = 130.0

func _init() -> void:
	super._init()
	enable_drop_zone = true

func _ready() -> void:
	super._ready()
	add_to_group("battle_row")
	# Full row sensor
	if drop_zone:
		drop_zone.set_sensor(Vector2(row_width, 260), Vector2.ZERO, null, false)
		
		# Clear vertical partitions since we are now dynamically calculating drop zones
		drop_zone.set_vertical_partitions([])

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
	
	# Sort units by their current assigned battle slot, or by global position X if new
	units.sort_custom(func(a, b):
		var slot_a = a.get_meta("battle_slot", -1)
		var slot_b = b.get_meta("battle_slot", -1)
		if slot_a != -1 and slot_b != -1:
			return slot_a < slot_b
		return a.global_position.x < b.global_position.x
	)
	
	# Re-assign sequential strictly 0..n indices to guarantee no gaps
	for i in range(units.size()):
		units[i].set_meta("battle_slot", i)
	
	# Actually position them centered
	var unit_count = units.size()
	if unit_count == 0: return
	
	var total_span = (unit_count - 1) * slot_width
	var center_x = row_width / 2.0
	var start_x = center_x - (total_span / 2.0)
	
	for i in range(units.size()):
		var card = units[i]
		_position_card_at_scaled(card, start_x + (i * slot_width))

func _position_card_at_scaled(card: Card, target_x: float) -> void:
	var target_pos = global_position + Vector2(target_x, center_y)
	# Center alignment adjustment for anchor offset at 1.2 scale
	target_pos -= Vector2(80, 110) * 1.2 # Adjust based on 1.2 scale
	
	card.move(target_pos, 0)
	card.scale = Vector2(1.2, 1.2)
	card.original_scale = Vector2(1.2, 1.2)
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
	
	# If dropping via drag-and-drop, calculate insertion slot dynamically
	if drop_slot == -1:
		var local_mouse_x = get_local_mouse_position().x
		var units = []
		for c in _held_cards: units.append(c)
		units.sort_custom(func(a, b): return a.get_meta("battle_slot", -1) < b.get_meta("battle_slot", -1))
		
		drop_slot = units.size() # Default to appending
		var unit_count = units.size()
		if unit_count > 0:
			var total_span = (unit_count - 1) * slot_width
			var start_x = (row_width / 2.0) - (total_span / 2.0)
			
			for i in range(unit_count):
				var card_x = start_x + (i * slot_width)
				if local_mouse_x < card_x:
					drop_slot = i
					break
	
	# Double check slot isn't out of bounds (cap at max units)
	if drop_slot > TOTAL_SLOTS:
		return false
	
	if debug_mode:
		print("[BattleRow %d] move_cards fired. Splicing into slot: %d" % [row_index, drop_slot])
	
	# Shift existing cards up to make room
	for c in _held_cards:
		var cur_slot = c.get_meta("battle_slot", -1)
		if cur_slot >= drop_slot:
			c.set_meta("battle_slot", cur_slot + 1)
	
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
		
		# Only reset attack capabilities if this is a newly deployed card,
		# not just a card being shifted due to array reorganizations
		if card.get_meta("just_deployed", false):
			card.can_attack = true
			card.modulate = Color(1.0, 1.0, 1.0)
			
			card.set_meta("just_deployed", false)
			var slot = card.get_meta("battle_slot", -1)
			if "keyword_instances" in card:
				for kw in card.keyword_instances:
					if kw.has_method("on_deploy"):
						kw.on_deploy(self , slot)

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

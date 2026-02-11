class_name BattleSpot
extends Pile

@export var is_player_spot: bool = true

func _ready() -> void:
	super._ready()
	# Set these to ensure the single card stays centered and doesn't move
	layout = PileDirection.UP
	stack_display_gap = 0
	max_stack_display = 1
	restrict_to_top_card = false

func _card_can_be_added(cards: Array) -> bool:
	# Only allow player to drop on player spots
	if not is_player_spot:
		return false
		
	# Max 1 card per spot - NO STACKING
	if _held_cards.size() > 0 or cards.size() > 1:
		return false
	
	# Check Energy in Example1 (the scene root)
	var main = get_tree().current_scene
	if main and main.has_method("can_afford"):
		# Only check energy if coming from Hand (playing the card)
		var from_hand = false
		for card in cards:
			if card.card_container is Hand:
				from_hand = true
				break
		
		if from_hand:
			return main.can_afford(cards)
			
	return true

## Override move_cards to deduct energy
func move_cards(cards: Array, index: int = -1, with_history: bool = true) -> bool:
	var hand_cards = []
	for card in cards:
		if card.card_container is Hand:
			hand_cards.append(card)
	
	var success = super.move_cards(cards, index, with_history)
	
	if success and hand_cards.size() > 0:
		var main = get_tree().current_scene
		if main and main.has_method("spend_energy"):
			main.spend_energy(hand_cards)
			
	return success

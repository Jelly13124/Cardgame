extends CardContainer
class_name CardPlayZone

func _ready():
	sensor_size = Vector2(3000, 700)
	sensor_position = Vector2(-500, -100)
	super._ready()

func _card_can_be_added(cards: Array) -> bool:
	var main = get_tree().current_scene
	if main and main.has_method("can_afford"):
		return main.can_afford(cards)
	return true

# Override move_cards — this fires the moment the framework accepts the drop.
# We intercept here instead of on_card_move_done, because CardContainer
# (unlike Pile) never calls card.move() so _on_move_done never fires.
func move_cards(cards: Array, _index: int = -1, _with_history: bool = true) -> bool:
	var main = get_tree().current_scene
	for card in cards:
		if main and main.has_method("play_spell"):
			# null target = skill/ability card, no enemy needed
			main.play_spell(card, null)
	# Return true so the framework removes the card from the hand
	return true

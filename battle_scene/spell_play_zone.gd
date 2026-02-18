class_name SpellPlayZone
extends CardContainer

## Specialized container for "casting" spells.
## When a card is dropped here, it checks if it's a spell and triggers play_spell.
func _card_can_be_added(cards: Array) -> bool:
	var main = get_tree().current_scene
	
	for card in cards:
		# Only spells can be dropped here
		if card.card_info.get("type", "") != "spell":
			return false
		
		# Check energy
		if main and main.has_method("can_afford"):
			if not main.can_afford([card]):
				if main.has_method("show_notification"):
					main.show_notification("NOT ENOUGH ENERGY", Color(0.2, 0.6, 1))
				return false
				
	return true

## Instead of actually "holding" the card, we trigger the spell effect
func move_cards(cards: Array, _index: int = -1, _with_history: bool = true) -> bool:
	if not _card_can_be_added(cards):
		return false
		
	var main = get_tree().current_scene
	if main and main.has_method("play_spell"):
		var drop_pos = get_global_mouse_position()
		for card in cards:
			main.play_spell(card, drop_pos)
			
	return true

## Visual layout: we don't display cards here, they are "consumed"
func _update_target_positions() -> void:
	pass

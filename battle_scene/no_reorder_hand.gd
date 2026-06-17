## Battle hand that disables in-hand drag reordering.
##
## The base card-framework Hand reorders a card when you drag it sideways and drop
## it back into the hand (hand.gd `move_cards`). In this StS-style game you drag a
## card UP onto a target to play it, so sideways reordering is only ever an
## accidental, confusing side effect. We keep every other Hand behaviour and just
## neutralise the single-card in-hand "move" — the card snaps back to its slot.
##
## No class_name (ADR-0006); extends the addon Hand via path.
extends "res://addons/card-framework/hand.gd"


func move_cards(cards: Array, index: int = -1, with_history: bool = true) -> bool:
	# A single card that's ALREADY held by this hand being "moved" is an in-hand
	# reorder attempt — repaint in place instead of swapping/shifting the row.
	if cards.size() == 1 and _held_cards.has(cards[0]):
		update_card_ui()
		_restore_mouse_interaction(cards)
		return true
	return super.move_cards(cards, index, with_history)

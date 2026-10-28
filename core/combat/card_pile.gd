extends RefCounted

## An ordered pile of card instances (STS2 CardPile). The top of the pile is
## the END of `cards` (the order the card framework draws from).

var name: String = ""
var cards: Array = []


static func named(p_name: String) -> RefCounted:
	var p = new()
	p.name = p_name
	return p


func size() -> int:
	return cards.size()


func is_empty() -> bool:
	return cards.is_empty()


func has(card) -> bool:
	return cards.has(card)


func top():
	return null if cards.is_empty() else cards[cards.size() - 1]

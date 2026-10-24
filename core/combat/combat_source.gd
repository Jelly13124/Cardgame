extends RefCounted

## Who caused a value: card, tool, relic, set, enemy, status, thorns, event or
## debug. `side` is the team the cause belongs to ("player", "enemy" or
## "neutral"); `dealer` is the creature acting (may be null for relics); `card`
## is the card node for card sources; `id` names a relic, set or status.

## Source kinds whose hits play detached feedback (no attacker lunge / card
## readout): statuses, relics, Thorns reflections and debug damage.
const DETACHED_FEEDBACK_KINDS := ["status", "relic", "thorns", "debug"]

var kind: String = ""
var side: String = "neutral"
var dealer: Object = null
var card: Object = null
var id: String = ""


static func make(
	p_kind: String, p_side: String, p_dealer: Object = null, p_card: Object = null, p_id: String = ""
) -> RefCounted:
	var source = new()
	source.kind = p_kind
	source.side = p_side
	source.dealer = p_dealer
	source.card = p_card
	source.id = p_id
	return source


func is_card() -> bool:
	return kind == "card"


## Lower-case card type ("attack", "skill", …) of a card source, else "".
func card_type() -> String:
	if card == null or not is_instance_valid(card) or not "card_info" in card:
		return ""
	return str(card.card_info.get("type", "")).to_lower()

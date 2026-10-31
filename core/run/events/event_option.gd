extends RefCounted

## One choice on an event page (STS2 EventOption). Built by the EventModel,
## read by the event UI. An option without a valid `on_chosen` is locked.
## No class_name — preload.

var key: String
var text_key: String
var on_chosen: Callable
## Shown on a locked option ("Charm 5").
var lock_reason: String = ""
## Success chance of a luck option; -1 for any other option.
var chance: float = -1.0
## Hover tips reusing the relic and card tooltips.
var relic_id: String = ""
var card_id: String = ""
var will_kill_player: bool = false
var is_proceed: bool = false
## The run facade, for attribute gates (set by EventModel.option).
var owner


func is_locked() -> bool:
	return not on_chosen.is_valid() or lock_reason != ""


## Lock the option while an attribute is below its threshold, e.g.
## `requires({"charm": 5})`. Chainable.
func requires(attrs: Dictionary) -> RefCounted:
	for attr in attrs:
		var need := int(attrs[attr])
		var have: int = owner._attr(str(attr)) if owner != null else 0
		if have < need:
			lock_reason = "%s %d" % [str(attr).capitalize(), need]
			break
	return self

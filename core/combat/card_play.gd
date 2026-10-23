extends RefCounted

## State of one card play shared by all of its effects and replay passes.
## Loaded is taken by the first damage effect of the play; a preview play
## simulates every spend so it shows what the real play will do without
## changing anything.

var card: Object = null
var target: Object = null
var dealer: Object = null
var preview: bool = false
var loaded_taken: bool = false
## Preview-only record of spends ("deadeye", "first_attack_crit", …).
var simulated: Dictionary = {}


## Loaded stacks for this damage effect: all of them for the play's first
## damage effect, 0 afterwards. A real play spends them.
func take_loaded(p_dealer: Object) -> int:
	if loaded_taken or p_dealer == null or not p_dealer.has_method("get_status_stacks"):
		return 0
	loaded_taken = true
	var stacks := int(p_dealer.get_status_stacks("loaded"))
	if stacks > 0 and not preview:
		var status_system = p_dealer.get("status_system")
		if status_system:
			status_system.spend_stacks("loaded", stacks, p_dealer)
	return stacks


## Preview bookkeeping: true the first time `key` is spent in this preview.
func simulate_spend(key: String) -> bool:
	if simulated.has(key):
		return false
	simulated[key] = true
	return true

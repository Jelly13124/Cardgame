extends "res://core/listeners/status_listener.gd"

## Deadeye: the bearer's next attack is a guaranteed Crit; each forced Crit
## spends 1 stack. A preview counts the stacks it would spend on the play so a
## multi-hit preview shows exactly as many forced Crits as the stacks allow.


func should_force_crit(calc) -> bool:
	if calc.dealer != owner:
		return false
	var n := amount()
	var play = calc.play
	if play and calc.preview:
		n -= int(play.simulated.get("deadeye_spent", 0))
	if n <= 0:
		return false
	if calc.preview:
		if play:
			play.simulated["deadeye_spent"] = int(play.simulated.get("deadeye_spent", 0)) + 1
		return true
	var s = system
	var bearer: Object = owner
	var key := id
	calc.on_commit(func() -> void: s.spend_stacks(key, 1, bearer))
	return true

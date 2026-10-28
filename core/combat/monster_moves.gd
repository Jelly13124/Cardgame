extends RefCounted

## An enemy's move sequence (STS2 MonsterMoveStateMachine): the action pattern
## cycles each turn; `attack_ramp` moves grow with their named counter; HP
## threshold phases swap the pattern once each and queue their on_enter moves
## for the enemy's next turn.

## Ramp damage stops growing here (no int overflow on long fights).
const MAX_SAFE_RAMP_DAMAGE := 1 << 60

## Moves ({type, amount, …}) in order.
var action_pattern: Array = []
var _action_index: int = 0
## Times each ramp counter advanced; outlives the pattern cursor so an attack
## keeps growing after the pattern loops.
var _ramp_action_uses: Dictionary = {}
## {hp_below, on_enter, action_pattern}, sorted by DESCENDING hp_below so the
## deepest crossed phase wins.
var phases: Array = []
## Indices of phases already entered — each fires at most once.
var _entered_phases: Dictionary = {}
## on_enter moves of a phase entered on the player's turn; run at the start of
## the enemy's next turn.
var _pending_on_enter: Array = []


## Moves from a monster definition (a writable copy: patterns are per-instance).
static func from_data(data: Dictionary) -> RefCounted:
	var m = new()
	m.action_pattern = data.get("action_pattern", [])
	var raw_phases = data.get("phases", [])
	if typeof(raw_phases) == TYPE_ARRAY and not raw_phases.is_empty():
		var sorted_phases: Array = raw_phases.duplicate()
		sorted_phases.sort_custom(
			func(a, b): return float(a.get("hp_below", 0.0)) > float(b.get("hp_below", 0.0))
		)
		m.phases = sorted_phases
	return m


## The next move without advancing (ramp amount already grown).
func peek() -> Dictionary:
	if action_pattern.is_empty():
		return {"type": "attack", "amount": 6}
	var pattern_index := _action_index % action_pattern.size()
	var action: Dictionary = action_pattern[pattern_index].duplicate(true)
	if str(action.get("type", "")) == "attack_ramp":
		var counter_id := str(action.get("counter", "pattern_%d" % pattern_index))
		var uses := int(_ramp_action_uses.get(counter_id, 0))
		var value := int(action.get("amount", 1))
		var multiplier := maxi(2, int(action.get("multiplier", 2)))
		for _i in range(uses):
			if value > MAX_SAFE_RAMP_DAMAGE / multiplier:
				value = MAX_SAFE_RAMP_DAMAGE
				break
			value *= multiplier
		action["amount"] = value
	return action


## The next move, advancing the pointer (and its ramp counter).
func consume() -> Dictionary:
	var pattern_index: int = _action_index % maxi(1, action_pattern.size())
	var a := peek()
	if str(a.get("type", "")) == "attack_ramp":
		var counter_id := str(a.get("counter", "pattern_%d" % pattern_index))
		_ramp_action_uses[counter_id] = int(_ramp_action_uses.get(counter_id, 0)) + 1
	_action_index = (_action_index + 1) % maxi(1, action_pattern.size())
	return a


## After damage: enter the DEEPEST un-entered phase whose threshold HP has just
## crossed (shallower crossed ones are marked entered and never fire). Returns
## true when the pattern changed. Dead enemies never change phase.
func check_phases(health: int, max_health: int) -> bool:
	if phases.is_empty() or health <= 0 or max_health <= 0:
		return false
	var hp_ratio := float(health) / float(max_health)
	var target_index := -1
	for i in range(phases.size()):
		if not _entered_phases.has(i) and hp_ratio < float(phases[i].get("hp_below", 0.0)):
			target_index = i  # sorted descending: the last crossed one is the deepest
	if target_index < 0:
		return false
	for i in range(phases.size()):
		if not _entered_phases.has(i) and hp_ratio < float(phases[i].get("hp_below", 0.0)):
			_entered_phases[i] = true
	var phase: Dictionary = phases[target_index]
	var on_enter = phase.get("on_enter", [])
	if typeof(on_enter) == TYPE_ARRAY and not on_enter.is_empty():
		_pending_on_enter.append_array(on_enter)
	var new_pattern = phase.get("action_pattern", [])
	if typeof(new_pattern) == TYPE_ARRAY and not new_pattern.is_empty():
		action_pattern = new_pattern
		_action_index = 0
		_ramp_action_uses.clear()
		return true
	return false


## Drain the queued on_enter moves.
func consume_pending_on_enter() -> Array:
	var pending := _pending_on_enter
	_pending_on_enter = []
	return pending

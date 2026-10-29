extends RefCounted

## Moving on the act map (STS2 MapTravel): which nodes the run can enter from
## where it stands, and entering one (position, floor and walked path in the
## run state, core/run/run_state.gd). `by_id`: node id -> map node.


## The start floor before any move; afterwards the current node's children.
static func accessible(state, by_id: Dictionary, node: Dictionary) -> bool:
	if state.current_node_id == "":
		return int(node.floor) == 0
	var current: Dictionary = by_id.get(state.current_node_id, {})
	return not current.is_empty() and node.id in current.get("children", [])


## Enter `node`: {ok} or {ok: false, reason: "unreachable"}.
static func enter(state, by_id: Dictionary, node: Dictionary) -> Dictionary:
	if not accessible(state, by_id, node):
		return {"ok": false, "reason": "unreachable"}
	state.current_node_id = str(node.id)
	state.current_floor = int(node.floor)
	if not str(node.id) in state.visited_node_ids:
		state.visited_node_ids.append(str(node.id))
	return {"ok": true}

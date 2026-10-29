extends Node

## UI changes run and profile state through services that return a result
## (S7-02): the base inventory (core/meta/base_inventory.gd) equips, unequips,
## adds and removes base-owned gear and says why it refused; map travel
## (core/run/map_travel.gd) moves the run to a reachable node.

const BASE_INVENTORY = preload("uid://p4f5t8025pe2")  # res://core/meta/base_inventory.gd
const MAP_TRAVEL = preload("uid://0qgp786g5ulg")  # res://core/run/map_travel.gd
const PROFILE_STATE = preload("uid://1lid0vwtvi7n")  # res://core/meta/profile_state.gd
const RUN_STATE = preload("uid://cguglvtfurhlo")  # res://core/run/run_state.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	_test_base_inventory()
	_test_map_travel()
	if failures.is_empty():
		print("[OK] inventory services passed")
		get_tree().quit(0)
		return
	push_error("inventory services failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _item(base: String) -> Dictionary:
	return {"base": base, "rarity": "common", "affixes": [], "cursed": false, "set_id": ""}


func _test_base_inventory() -> void:
	var p = PROFILE_STATE.new()
	var head := _item("base:gear_head_common")
	var head2 := _item("base:gear_head_rare")
	_expect(BASE_INVENTORY.add(p, head, 2)["ok"], "an item joins the base backpack")
	_expect(BASE_INVENTORY.equip(p, "chest", head) == {"ok": false, "reason": "wrong_slot"}, "a head piece does not fit the chest")
	_expect(BASE_INVENTORY.equip(p, "head", _item("base:gear_hands_common")).get("reason") == "wrong_slot", "slot checked first")
	_expect(BASE_INVENTORY.equip(p, "head", head)["ok"], "the head piece is worn")
	_expect(p.base_loadout.is_empty() and p.base_equipped["head"] == head, "it left the backpack for the slot")
	_expect(BASE_INVENTORY.equip(p, "head", head2) == {"ok": false, "reason": "not_in_backpack"}, "a stale drag is refused")
	BASE_INVENTORY.add(p, head2, 2)
	_expect(BASE_INVENTORY.equip(p, "head", head2)["ok"] and p.base_loadout == [head], "the worn piece swaps back into the backpack")
	BASE_INVENTORY.add(p, _item("base:gear_chest_common"), 2)
	_expect(BASE_INVENTORY.unequip(p, "head", 2) == {"ok": false, "reason": "backpack_full"}, "unequipping into a full backpack is refused")
	_expect(BASE_INVENTORY.add(p, _item("base:gear_hands_common"), 2) == {"ok": false, "reason": "backpack_full"}, "adding to a full backpack is refused")
	var removed: Dictionary = BASE_INVENTORY.remove_at(p, 0)
	_expect(removed["ok"] and removed["item"] == head, "removing returns the item")
	_expect(BASE_INVENTORY.unequip(p, "head", 2)["ok"] and not p.base_equipped.has("head"), "unequipping frees the slot")
	p.base_equipped["chest"] = _item("base:gear_head_common")  # malformed: wrong slot
	p.base_loadout.append({})
	_expect(BASE_INVENTORY.sanitize(p) and not p.base_equipped.has("chest") and not p.base_loadout.has({}), "malformed entries are dropped")


func _test_map_travel() -> void:
	var s = RUN_STATE.new()
	s.map_data = [
		{"id": "f0_s1", "floor": 0, "slot": 1, "type": "relic", "children": ["f1_s0"]},
		{"id": "f1_s0", "floor": 1, "slot": 0, "type": "enemy", "children": []},
		{"id": "f1_s2", "floor": 1, "slot": 2, "type": "enemy", "children": []},
	]
	var by_id := {}
	for n in s.map_data:
		by_id[n.id] = n
	_expect(MAP_TRAVEL.accessible(s, by_id, by_id["f0_s1"]) and not MAP_TRAVEL.accessible(s, by_id, by_id["f1_s0"]), "only the start is reachable first")
	_expect(MAP_TRAVEL.enter(s, by_id, by_id["f1_s0"]) == {"ok": false, "reason": "unreachable"}, "an unreachable node is refused")
	_expect(MAP_TRAVEL.enter(s, by_id, by_id["f0_s1"])["ok"], "the start is entered")
	_expect(s.current_node_id == "f0_s1" and s.current_floor == 0 and s.visited_node_ids == ["f0_s1"], "position and path are recorded")
	_expect(MAP_TRAVEL.accessible(s, by_id, by_id["f1_s0"]) and not MAP_TRAVEL.accessible(s, by_id, by_id["f1_s2"]), "children of the current node are reachable")

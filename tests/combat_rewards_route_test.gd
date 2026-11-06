extends Node

## A won fight reports only its result; the run layer
## (core/run/combat_rewards.gd) grants the rewards and picks the route:
## normal → loot, elite → loot + Scrap, non-final boss → extract choice with
## the act's rewards, final boss → demo complete (run ends).

const COMBAT_REWARDS = preload("uid://sn83hwnx1w3b")  # res://core/run/combat_rewards.gd
const REWARDS = preload("uid://dao6ryap2ksxs")  # res://core/run/rewards.gd
const MERCHANT_INVENTORY = preload("uid://dgj1md8jt0tg7")  # res://core/run/merchant/merchant_inventory.gd
const CARD_POOLS = preload("uid://c76axesxo6wit")  # res://core/run/card_pools.gd
const MARKET = preload("uid://brturtmxacges")  # res://core/meta/market.gd
const ACTS = preload("uid://c7qo73muxvmd4")  # res://core/run/acts.gd
const ROOMS = preload("uid://cxmgdj3654rrj")  # res://core/run/rooms.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	RunManager.start_new_run("base:cowboy_bill", [], 0, "ROUTES0001")
	var scrap_before := RunManager.total_run_scrap()
	var caps_before: int = RunManager._run_caps
	_expect(COMBAT_REWARDS.settle_victory("enemy", 1, {"caps": 6})["route"] == "loot", "a normal fight goes to the loot screen")
	_expect(RunManager._run_caps - caps_before == 6, "a normal fight pays its printed 6 Caps")
	_expect(RunManager.total_run_scrap() == scrap_before, "a normal fight drops no Scrap")
	caps_before = RunManager._run_caps
	_expect(COMBAT_REWARDS.settle_victory("elite", 1, {"caps": 18, "scrap": 11})["route"] == "loot", "an elite goes to the loot screen")
	_expect(RunManager._run_caps - caps_before == 18, "an elite pays its printed 18 Caps")
	var elite_scrap := RunManager.total_run_scrap() - scrap_before
	_expect(elite_scrap == 11, "an elite drops its printed 11 Scrap (%d)" % elite_scrap)
	_expect(ROOMS.rest_heal_amount(80) == 20, "a campfire heals a quarter of max HP")
	# A fight rolled from a "?" room is not the node's own room: it pays a fight's Caps.
	RunManager.map_data = [{"id": "q", "floor": 1, "slot": 0, "type": "unknown", "children": [] as Array[String], "rewards": {}},
		{"id": "e", "floor": 1, "slot": 1, "type": "enemy", "children": [] as Array[String], "rewards": {"caps": 6}}]
	RunManager._reindex_map()
	RunManager.current_node_id = "q"
	RunManager.last_battle_node_type = "enemy"
	_expect(RunManager.battle_rewards() == {"caps": 6}, "a fight from a ? room pays a fight's Caps (%s)" % RunManager.battle_rewards())
	RunManager.current_node_id = "e"
	_expect(RunManager.battle_rewards() == {"caps": 6}, "a route fight pays its printed rewards")

	ACTS.active_run = "base:full"
	var route: Dictionary = COMBAT_REWARDS.settle_victory("boss", 1, {})
	_expect(route["route"] == "extract_choice", "a non-final boss offers the extract choice (%s)" % route["route"])
	var rewards: Dictionary = route.get("rewards", {})
	_expect(
		int(rewards.get("continue", 0)) == 26 and int(rewards.get("extract", 0)) == 40,
		"act 1's extract rewards come from its data (%s)" % rewards
	)
	_expect(COMBAT_REWARDS.choose_extract(false, route["rewards"]) == "loot" and RunManager.current_act == 2, "pushing on enters act 2")
	ACTS.active_run = ACTS.ACTIVE_RUN

	RunManager.current_act = 1
	route = COMBAT_REWARDS.settle_victory("boss", 1, {})
	_expect(route["route"] == "demo_complete", "the demo's final boss completes the run (%s)" % route["route"])
	_expect(not RunManager.is_run_active, "the run ended")
	RunManager.clear_run_save()
	_expect(_stock("STOCKSEED1") == _stock("STOCKSEED1"), "the same seed gives the same loot, shop and market stock")
	_expect(_stock("STOCKSEED1") != _stock("STOCKSEED2"), "another seed gives other stock")
	if failures.is_empty():
		print("[OK] combat rewards route passed")
		get_tree().quit(0)
		return
	push_error("combat rewards route failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _stock(seed_string: String) -> String:
	RunManager.start_new_run("base:cowboy_bill", [], 0, seed_string)
	var hero := str(RunManager.current_hero_id)
	var out := [
		REWARDS.combat_loot("enemy").map(func(e): return [e["type"], e.get("tool_id", ""), e.get("instance", {}).get("base", "")]),
		REWARDS.roll_unique_draft_card(REWARDS.rarity_pools(CARD_POOLS.reward_pool(hero)), {}),
		MERCHANT_INVENTORY.create(RunManager).to_dict(),
		MARKET.roll_equip_stock(),
		MARKET.roll_tool_stock(),
	]
	RunManager.is_run_active = false
	RunManager.clear_run_save()
	return JSON.stringify(out)

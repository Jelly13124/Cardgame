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
	var meta_caps_before: int = MetaProgress.caps
	_expect(COMBAT_REWARDS.settle_victory("enemy", 1, {"gold": 8})["route"] == "loot", "a normal fight goes to the loot screen")
	_expect(RunManager.state.get("run_caps") == null, "there is no hidden run caps counter")
	_expect(MetaProgress.caps == meta_caps_before, "a fight banks nothing by itself")
	_expect(RunManager.total_run_scrap() == scrap_before, "a normal fight drops no Scrap")
	_expect(REWARDS.combat_loot("enemy", 8)[0] == {"type": "gold", "amount": 8}, "the loot gold row pays the printed 8")
	_expect(COMBAT_REWARDS.settle_victory("elite", 1, {})["route"] == "loot", "an elite goes to the loot screen")
	var elite_scrap := RunManager.total_run_scrap() - scrap_before
	_expect(elite_scrap >= 8 and elite_scrap <= 16, "an elite rolls 8–16 Scrap (%d)" % elite_scrap)
	_expect(ROOMS.rest_heal_amount(80) == 20, "a campfire heals a quarter of max HP")
	# Gold is a lookup by the fought room type; no map node is needed.
	var want := {"enemy": {"gold": 8}, "elite": {"gold": 18}, "unknown": {"gold": 8}, "boss": {}}
	for room in want:
		RunManager.last_battle_node_type = room
		_expect(RunManager.battle_rewards() == want[room], "a won %s pays %s (%s)" % [room, want[room], RunManager.battle_rewards()])

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
	var gold_before := RunManager.total_gold()
	route = COMBAT_REWARDS.settle_victory("boss", 1, {})
	_expect(RunManager.total_gold() - gold_before == 45 or not RunManager.is_run_active, "the boss adds 45 gold")
	_expect(route["route"] == "demo_complete", "the demo's final boss completes the run (%s)" % route["route"])
	_expect(not RunManager.is_run_active, "the run ended")
	RunManager.clear_run_save()
	_check_boss_overflow()
	_expect(REWARDS.combat_loot("boss", 0).all(func(e): return e["type"] != "gold"), "a fight paying no Caps shows no Caps row")
	_check_owed_caps_banked()
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
		REWARDS.combat_loot("enemy", 8).map(func(e): return [e["type"], e.get("tool_id", ""), e.get("instance", {}).get("base", "")]),
		REWARDS.roll_unique_draft_card(REWARDS.rarity_pools(CARD_POOLS.reward_pool(hero)), {}),
		MERCHANT_INVENTORY.create(RunManager).to_dict(),
		MARKET.roll_equip_stock(),
		MARKET.roll_tool_stock(),
	]
	RunManager.is_run_active = false
	RunManager.clear_run_save()
	return JSON.stringify(out)


## boss gold overflow is banked: with every usable cell full, the 45 boss gold
## that does not fit is carried in legacy_caps for settlement.
func _check_boss_overflow() -> void:
	RunManager.start_new_run("base:cowboy_bill", [], 0, "BOSSFULL01")
	for i in range(RunManager.effective_backpack_size()):
		RunManager.backpack[i] = {"kind": "scrap", "amount": 30}
	ACTS.active_run = "base:full"
	COMBAT_REWARDS.settle_victory("boss", 1, {})
	_expect(RunManager.state.legacy_caps == 45, "boss gold that does not fit is kept for settlement (%d)" % RunManager.state.legacy_caps)
	ACTS.active_run = ACTS.ACTIVE_RUN
	RunManager.is_run_active = false
	RunManager.clear_run_save()


## Owed caps (boss overflow, an old save's hidden caps) bank 1:1 with the
## backpack's gold when the run is extracted.
func _check_owed_caps_banked() -> void:
	RunManager.start_new_run("base:cowboy_bill", [], 0, "OWEDCAPS01")
	for i in range(RunManager.effective_backpack_size()):
		RunManager.backpack[i] = {"kind": "scrap", "amount": 30}
	RunManager.backpack[0] = {"kind": "gold", "amount": 20}
	RunManager.state.legacy_caps = 45
	var before: int = MetaProgress.caps
	RunManager.call("_settle_backpack", true, "extracted")
	_expect(MetaProgress.caps - before == 65, "extraction banks backpack Caps plus owed caps (%d)" % (MetaProgress.caps - before))
	MetaProgress.caps = before
	RunManager.is_run_active = false
	RunManager.clear_run_save()

extends Node

## Acts, maps and encounters as data change nothing: for two seeds and acts
## 1–3, the generated maps, the encounter picks and the act multipliers equal
## the golden recorded from the code before (tests/fixtures/run_structure_golden.json).

const GOLDEN := "res://tests/fixtures/run_structure_golden.json"  # path-ok: data fixture read as text
## Boss scaling, an A5 map and seeded loot / draft / shop / market sequences,
## recorded from the code before phase 6 (c423e2e).
const GOLDEN2 := "res://tests/fixtures/run_structure_golden2.json"  # path-ok: data fixture read as text
const ACTS = preload("uid://c7qo73muxvmd4")  # res://core/run/acts.gd
const REWARDS = preload("uid://dao6ryap2ksxs")  # res://core/run/rewards.gd
const SHOP_STOCK = preload("uid://bxjesomogv04a")  # res://core/run/shop_stock.gd
const CARD_POOLS = preload("uid://c76axesxo6wit")  # res://core/run/card_pools.gd
const MARKET = preload("uid://brturtmxacges")  # res://core/meta/market.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	for seed_string in golden:
		RunManager.start_new_run("base:cowboy_bill", [], 0, seed_string)
		for act in [1, 2, 3]:
			var want: Dictionary = golden[seed_string][str(act)]
			RunManager.current_act = act
			RunManager.generate_map()
			var nodes: Array = []
			for n in RunManager.map_data:
				nodes.append([n.id, n.type, Array(n.children)])
			_expect(_same(nodes, want["map"]), "%s act %d map unchanged" % [seed_string, act])
			var picks: Array = []
			for f in range(RunManager.floors_per_act()):
				for t in ["enemy", "unknown", "elite", "boss"]:
					picks.append([f, t, Array(RunManager.select_encounter(t, f))])
			_expect(_same(picks, want["encounters"]), "%s act %d encounter picks unchanged" % [seed_string, act])
			_expect(RunManager.scale_enemy_hp(100, "base:scrap_rat") == int(want["hp"]), "act %d HP multiplier unchanged" % act)
			_expect(RunManager.scale_enemy_damage(10, "base:scrap_rat") == int(want["dmg"]), "act %d damage multiplier unchanged" % act)
		RunManager.is_run_active = false
		RunManager.clear_run_save()
	_check_golden2(JSON.parse_string(FileAccess.get_file_as_string(GOLDEN2)))
	_check_full_config_bosses()
	if failures.is_empty():
		print("[OK] run structure golden passed")
		get_tree().quit(0)
		return
	push_error("run structure golden failed: %s" % "; ".join(failures))
	get_tree().quit(1)


## Equal after a JSON round trip (the fixture's numbers parse as floats).
static func _same(got: Variant, want: Variant) -> bool:
	return JSON.stringify(JSON.parse_string(JSON.stringify(got))) == JSON.stringify(want)


func _check_golden2(golden: Dictionary) -> void:
	RunManager.start_new_run("base:cowboy_bill", [], 0, "GOLDSTOCK1")
	var scaling := []
	for act in [1, 2, 3]:
		RunManager.current_act = act
		scaling.append([
			RunManager.scale_enemy_hp(100, "base:ash_warden"),
			RunManager.scale_enemy_damage(10, "base:junkyard_tyrant"),
			RunManager.scale_enemy_hp(100, "base:armored_patrol"),
		])
	_expect(_same(scaling, golden["boss_scaling"]), "bosses skip act scaling, elites do not: %s" % [scaling])
	RunManager.current_act = 1
	for seed_string in golden["stocks"]:
		RunManager.start_new_run("base:cowboy_bill", [], 0, seed_string)
		var hero := str(RunManager.current_hero_id)
		var seq := []
		for node_type in ["enemy", "elite"]:
			RunManager.last_battle_node_type = node_type
			seq.append(REWARDS.combat_loot(node_type).map(_loot_row))
			var pools := REWARDS.rarity_pools(MetaProgress.get_unlocked_card_pool())
			seq.append([REWARDS.roll_unique_draft_card(pools, {}), REWARDS.roll_unique_draft_card(pools, {})])
		var shop: Dictionary = SHOP_STOCK.roll(
			CARD_POOLS.shop_cards_by_rarity(hero), RunManager.tool_pool(), _unowned_shop_relics()
		)
		seq.append([shop["cards"], shop["tools"], shop["relics"], shop["remove_price"]])
		seq.append([MARKET.roll_equip_stock(), MARKET.roll_tool_stock()])
		_expect(_same(seq, golden["stocks"][seed_string]), "%s loot, draft, shop and market stock unchanged" % seed_string)
	RunManager.start_new_run("base:cowboy_bill", [], 5, "GOLDENA5MP")
	RunManager.current_act = 1
	RunManager.generate_map()
	_expect(
		_same(RunManager.map_data.map(func(n): return [n.id, n.type, Array(n.children)]), golden["a5_map"]),
		"the A5 (elite bias) map is unchanged"
	)
	RunManager.is_run_active = false
	RunManager.clear_run_save()


## The old loot row shape: [type, tool_id, item_id, rarity].
func _loot_row(e: Dictionary) -> Array:
	match str(e["type"]):
		"tool":
			return ["tool", e["tool_id"], "", str(RunManager.get_tool_data(e["tool_id"]).get("rarity", "common"))]
		"equipment":
			var inst: Dictionary = e["instance"]
			return ["equipment", "", str(inst.get("base", "")), str(inst.get("rarity", e["rarity"]))]
	return [e["type"], "", "", ""]


## The shop's relic candidates (ui/shop/shop_scene.gd _list_unowned_relics).
func _unowned_shop_relics() -> Array:
	var out: Array = []
	for relic_id in RunManager.current_relic_pool():
		if relic_id in RunManager.relics:
			continue
		if str(RunManager.get_relic_data(relic_id).get("rarity", "common")) == "unique":
			continue
		out.append(relic_id)
	return out


## The full game's bosses per act (the old ACT_BOSSES table).
func _check_full_config_bosses() -> void:
	ACTS.active_run = "base:full"
	RunManager.start_new_run("base:cowboy_bill", [], 0, "FULLBOSSES")
	var bosses := []
	for act in [1, 2, 3]:
		RunManager.current_act = act
		bosses.append(RunManager.select_encounter("boss", 11)[0])
	_expect(bosses == ["base:rust_titan", "base:ash_warden", "base:junkyard_tyrant"], "full game bosses per act: %s" % [bosses])
	_expect(RunManager.acts_total() == 3, "the full game has three acts")
	ACTS.active_run = ACTS.ACTIVE_RUN
	RunManager.is_run_active = false
	RunManager.clear_run_save()

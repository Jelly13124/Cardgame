extends Node

## Run and profile state are plain data (core/run/run_state.gd,
## core/meta/profile_state.gd): a save of each restores the same state, and a
## merchant's rolled stock is part of the run, so reopening it after a reload
## shows the same goods.

const ACTS = preload("uid://c7qo73muxvmd4")  # res://core/run/acts.gd
const RUN_SAVE = preload("uid://dkhd2poukjb61")  # res://core/save/run_save.gd
const PROFILE_SAVE = preload("uid://cox1wehu1m6on")  # res://core/save/profile_save.gd
const RUN_STATE = preload("uid://cguglvtfurhlo")  # res://core/run/run_state.gd
const PROFILE_STATE = preload("uid://1lid0vwtvi7n")  # res://core/meta/profile_state.gd
const SHOP = preload("uid://dr8unxxfi0w51")  # res://ui/shop/shop_scene.tscn

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	MetaProgress.set_active_slot(1)
	RunManager.start_new_run("base:cowboy_bill", [], 0, "ROUNDTRIP1")
	RunManager.add_relic("base:crit_clip")
	RunManager.add_equip_to_backpack(RunManager.make_equip_instance("base:gear_head_rare", "rare"))
	var saved := RUN_SAVE.to_dict(RunManager.state, 1234)
	var restored = RUN_STATE.new()
	RUN_SAVE.apply(restored, JSON.parse_string(JSON.stringify(saved)))
	_expect(
		_json(RUN_SAVE.to_dict(restored, 1234)) == _json(saved),
		"a run save restores the same run state"
	)
	MetaProgress.caps = 321
	MetaProgress.stash.append(RunManager.make_equip_instance("base:gear_weapon_rare", "rare"))
	var profile_saved := PROFILE_SAVE.to_dict(MetaProgress.profile)
	var profile = PROFILE_STATE.new()
	PROFILE_SAVE.apply(profile, JSON.parse_string(JSON.stringify(profile_saved)), 99)
	_expect(profile.caps == 321 and profile.stash.size() == MetaProgress.stash.size(), "a profile save restores the same profile")
	_expect(RunManager.pending_loadout == MetaProgress.profile.base_loadout, "the base loadout lives in the profile")

	# A merchant: open, remember the stock, save and load, reopen.
	RunManager.current_node_id = "f5_s1"
	var first: Array = await _shop_cards()
	RunManager.state.shop_stock["f5_s1"]["cards"][0]["sold"] = true  # bought before the reload
	RunManager.save_run()
	_expect(RunManager.load_run(), "the run loads back")
	var second: Array = await _shop_cards()
	_expect(not first.is_empty() and first == second, "reopening the merchant after a reload shows the same stock: %s vs %s" % [first, second])
	_expect(bool(RunManager.state.shop_stock["f5_s1"]["cards"][0].get("sold", false)), "a bought offer stays sold after the reload")
	# A new act and a new run never see an old merchant's stock (node ids repeat).
	RunManager.state.shop_stock["f5_s1"] = {"cards": [], "tools": [], "relics": [], "remove_price": 1}
	ACTS.active_run = "base:full"  # the demo has one act
	_expect(RunManager.advance_act(), "the full game advances to act 2")
	ACTS.active_run = ACTS.ACTIVE_RUN
	_expect(RunManager.state.shop_stock.is_empty(), "a new act starts with no merchant stock")
	RunManager.state.shop_stock["f5_s1"] = {"cards": [], "tools": [], "relics": [], "remove_price": 1}
	RunManager.start_new_run("base:cowboy_bill", [], 0, "ROUNDTRIP2")
	_expect(RunManager.state.shop_stock.is_empty(), "a new run starts with no merchant stock")
	_expect(not MetaProgress.add_to_stash("base:gear_hands_common"), "the stash refuses a bare item id")
	RunManager.is_run_active = false
	RunManager.clear_run_save()
	if failures.is_empty():
		print("[OK] state round trip passed")
		get_tree().quit(0)
		return
	push_error("state round trip failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _shop_cards() -> Array:
	var shop = SHOP.instantiate()
	add_child(shop)
	await get_tree().process_frame
	var cards: Array = shop._stock_cards.map(func(e): return str(e["card_id"]))
	shop.queue_free()
	await get_tree().process_frame
	return cards


## JSON text after a parse round trip (ints and floats compare alike).
static func _json(d: Dictionary) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(d)), "", true)

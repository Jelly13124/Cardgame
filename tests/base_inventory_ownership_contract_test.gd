extends Node

const MARKET_SCREEN = preload("res://run_system/ui/buildings/market_screen.gd")

var failures: PackedStringArray = []
var _original_slot := 0
var _meta_snapshot: Dictionary = {}
var _run_snapshot: Dictionary = {}


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	_snapshot_state()
	# Isolate every save_progress() call from the user's real profiles.
	Settings.active_slot = 99
	MetaProgress.delete_slot(99)
	MetaProgress.call("_reset_to_defaults")
	_reset_run_gear()

	_test_atomic_stash_transfers()
	_test_window_transfer_wiring()
	_test_base_reward_destination()
	_test_market_purchase_destination()
	_test_success_settlement()
	_test_defeat_settlement()
	_test_profile_round_trip()
	_test_start_run_consumes_owned_carry()

	_restore_state()
	MetaProgress.delete_slot(99)
	if failures.is_empty():
		print("[OK] Base backpack ownership and settlement contracts passed")
		get_tree().quit(0)
		return
	push_error("Base inventory ownership contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _test_atomic_stash_transfers() -> void:
	MetaProgress.stash.clear()
	RunManager.pending_loadout.clear()
	RunManager.pending_equipped.clear()
	var stored := _equip("gear_head_common", "common")
	MetaProgress.stash.append(stored)

	_expect(
		MetaProgress.move_stash_to_base_backpack(stored),
		"explicit stash-to-backpack transfer succeeds"
	)
	_expect(MetaProgress.stash.is_empty(), "stash-to-backpack removes storage ownership")
	_expect(
		RunManager.pending_loadout.size() == 1,
		"stash-to-backpack adds exactly one owned carry entry"
	)

	# A full stash must reject the reverse transfer without deleting the carried item.
	MetaProgress.stash.clear()
	for _i in range(MetaProgress.effective_stash_cap()):
		MetaProgress.stash.append(_equip("gear_chest_common", "common"))
	var carry_before: Array = RunManager.pending_loadout.duplicate(true)
	_expect(
		not MetaProgress.move_base_backpack_to_stash(stored),
		"full stash rejects backpack-to-stash transfer"
	)
	_expect(
		RunManager.pending_loadout == carry_before,
		"failed backpack-to-stash transfer leaves carry untouched"
	)
	_expect(
		MetaProgress.stash.size() == MetaProgress.effective_stash_cap(),
		"failed backpack-to-stash transfer leaves stash untouched"
	)

	MetaProgress.stash.pop_back()
	_expect(
		MetaProgress.move_base_backpack_to_stash(stored),
		"backpack-to-stash succeeds after capacity opens"
	)
	_expect(RunManager.pending_loadout.is_empty(), "successful storage removes base carry")
	_expect(
		MetaProgress.stash.size() == MetaProgress.effective_stash_cap(),
		"successful storage adds exactly one stash entry"
	)

	var worn := _equip("gear_weapon_uncommon", "uncommon")
	RunManager.pending_equipped["weapon"] = worn
	_expect(
		not MetaProgress.move_base_slot_to_stash("weapon"),
		"full stash rejects base-slot transfer"
	)
	_expect(
		RunManager.pending_equipped.has("weapon"),
		"failed slot-to-stash transfer leaves the worn item untouched"
	)
	MetaProgress.stash.pop_back()
	_expect(
		MetaProgress.move_base_slot_to_stash("weapon"),
		"slot-to-stash succeeds after capacity opens"
	)
	_expect(
		not RunManager.pending_equipped.has("weapon"),
		"successful slot-to-stash clears the base slot"
	)


func _test_window_transfer_wiring() -> void:
	var character_source := FileAccess.get_file_as_string(
		"res://run_system/ui/window/character_window.gd"
	)
	var stash_source := FileAccess.get_file_as_string("res://run_system/ui/window/stash_window.gd")
	_expect(
		character_source.contains("MetaProgress.move_stash_to_base_backpack(entry)"),
		"character backpack uses the atomic stash-to-carry API"
	)
	_expect(
		stash_source.contains("MetaProgress.move_base_backpack_to_stash(entry)"),
		"stash window uses the atomic carry-to-stash API"
	)
	_expect(
		stash_source.contains("MetaProgress.move_base_slot_to_stash(slot)"),
		"stash window uses the atomic slot-to-stash API"
	)


func _test_base_reward_destination() -> void:
	MetaProgress.stash = [_equip("gear_head_common", "common")]
	RunManager.pending_loadout.clear()
	var reward := _equip("gear_accessory_uncommon", "uncommon")
	var stash_before: Array = MetaProgress.stash.duplicate(true)
	_expect(
		MetaProgress.add_to_base_backpack(reward),
		"base equipment reward can enter the owned backpack"
	)
	_expect(MetaProgress.stash == stash_before, "base reward never changes stash")
	_expect(
		_base_ids(RunManager.pending_loadout) == ["gear_accessory_uncommon"],
		"base reward is owned by the base backpack"
	)


func _test_market_purchase_destination() -> void:
	var market := MARKET_SCREEN.new()
	MetaProgress.caps = 1000
	MetaProgress.stash = [_equip("gear_weapon_common", "common")]
	RunManager.pending_loadout.clear()
	var stash_before: Array = MetaProgress.stash.duplicate(true)
	market.call("_on_buy_equipment", "gear_head_common", "common", 60, null)
	_expect(MetaProgress.caps == 940, "market equipment purchase spends Caps")
	_expect(MetaProgress.stash == stash_before, "market purchase never auto-stores equipment")
	_expect(
		_base_ids(RunManager.pending_loadout) == ["gear_head_common"],
		"market purchase enters the owned base backpack"
	)

	RunManager.pending_loadout.clear()
	for _i in range(RunManager.effective_backpack_size()):
		RunManager.pending_loadout.append(_equip("gear_chest_common", "common"))
	var carry_before: Array = RunManager.pending_loadout.duplicate(true)
	var caps_before := MetaProgress.caps
	market.call("_on_buy_equipment", "gear_head_common", "common", 60, null)
	_expect(MetaProgress.caps == caps_before, "full backpack refunds market purchase Caps")
	_expect(RunManager.pending_loadout == carry_before, "full backpack keeps existing carry intact")
	_expect(MetaProgress.stash == stash_before, "failed market purchase still leaves stash untouched")
	market.free()


func _test_success_settlement() -> void:
	MetaProgress.caps = 0
	MetaProgress.scrap = 0
	MetaProgress.stash = [_equip("gear_head_common", "common")]
	RunManager.pending_loadout.clear()
	RunManager.pending_equipped.clear()
	_reset_run_gear()
	var carried := _equip("gear_chest_uncommon", "uncommon")
	var worn := _equip("gear_weapon_rare", "rare")
	RunManager.backpack[0] = {"kind": "gold", "amount": 25}
	RunManager.backpack[1] = {"kind": "scrap", "amount": 12}
	RunManager.backpack[2] = {"kind": "equip", "item": carried}
	RunManager.equipped_items["weapon"] = worn
	RunManager.set("_run_caps", 6)
	var stash_before: Array = MetaProgress.stash.duplicate(true)

	RunManager.call("_settle_backpack", true, "extracted")

	_expect(MetaProgress.stash == stash_before, "successful return never changes stash")
	_expect(MetaProgress.scrap == 12, "successful return banks carried Scrap")
	_expect(MetaProgress.caps == 8, "successful return banks run Caps plus converted Gold")
	_expect(
		_base_ids(RunManager.pending_loadout) == ["gear_chest_uncommon"],
		"successful return moves backpack gear into owned base backpack"
	)
	_expect(
		RunManager.equip_base(RunManager.pending_equipped.get("weapon", {}))
		== "gear_weapon_rare",
		"successful return preserves worn gear in the owned base slot"
	)


func _test_defeat_settlement() -> void:
	MetaProgress.scrap = 0
	MetaProgress.stash = [_equip("gear_accessory_common", "common")]
	MetaProgress.upgrades.clear()  # base safe-cell count = 2
	RunManager.pending_loadout.clear()
	RunManager.pending_equipped.clear()
	_reset_run_gear()
	RunManager.backpack[0] = {
		"kind": "equip", "item": _equip("gear_hands_uncommon", "uncommon")
	}
	RunManager.backpack[1] = {"kind": "scrap", "amount": 7}
	RunManager.backpack[2] = {"kind": "equip", "item": _equip("gear_head_rare", "rare")}
	RunManager.equipped_items["weapon"] = _equip("gear_weapon_common", "common")
	var stash_before: Array = MetaProgress.stash.duplicate(true)

	RunManager.call("_settle_backpack", false, "defeat")

	_expect(MetaProgress.stash == stash_before, "defeat settlement never changes stash")
	_expect(MetaProgress.scrap == 7, "defeat banks Scrap from safe cells")
	_expect(
		_base_ids(RunManager.pending_loadout) == ["gear_hands_uncommon"],
		"defeat preserves only safe-cell equipment in the base backpack"
	)
	_expect(
		RunManager.pending_equipped.is_empty(),
		"defeat does not preserve worn equipment outside safe cells"
	)


func _test_profile_round_trip() -> void:
	var carried := _equip("gear_chest_rare", "rare")
	var worn := _equip("gear_head_uncommon", "uncommon")
	RunManager.pending_loadout.assign([carried])
	RunManager.pending_equipped = {"head": worn}
	MetaProgress.save_progress()
	RunManager.pending_loadout.clear()
	RunManager.pending_equipped.clear()
	MetaProgress.load_progress()
	_expect(
		_base_ids(RunManager.pending_loadout) == ["gear_chest_rare"],
		"profile reload restores owned base backpack"
	)
	_expect(
		RunManager.equip_base(RunManager.pending_equipped.get("head", {}))
		== "gear_head_uncommon",
		"profile reload restores owned base equipment slots"
	)


func _test_start_run_consumes_owned_carry() -> void:
	MetaProgress.stash = [_equip("gear_accessory_rare", "rare")]
	var stash_before: Array = MetaProgress.stash.duplicate(true)
	RunManager.pending_loadout.assign([_equip("gear_hands_common", "common")])
	RunManager.pending_equipped = {"head": _equip("gear_head_common", "common")}

	RunManager.start_new_run("cowboy_bill", [], 0)

	_expect(
		"gear_hands_common" in RunManager.backpack_equip_ids(),
		"start_new_run consumes base backpack gear into run backpack"
	)
	_expect(
		RunManager.equip_base(RunManager.equipped_items.get("head", {})) == "gear_head_common",
		"start_new_run consumes base worn gear into the matching run slot"
	)
	_expect(RunManager.pending_loadout.is_empty(), "consumed base backpack is empty")
	_expect(RunManager.pending_equipped.is_empty(), "consumed base slots are empty")
	_expect(MetaProgress.stash == stash_before, "starting a run never removes stash entries")


func _equip(base_id: String, rarity: String) -> Dictionary:
	return RunManager.make_equip_instance(base_id, rarity)


func _base_ids(entries: Array) -> Array[String]:
	var ids: Array[String] = []
	for entry in entries:
		ids.append(RunManager.equip_base(entry))
	return ids


func _reset_run_gear() -> void:
	RunManager.backpack.clear()
	RunManager.backpack.resize(RunManager.MAX_INVENTORY)
	for slot in RunManager.EQUIPMENT_SLOTS:
		RunManager.equipped_items[slot] = {}


func _snapshot_state() -> void:
	_original_slot = Settings.active_slot
	_meta_snapshot = {
		"caps": MetaProgress.caps,
		"scrap": MetaProgress.scrap,
		"stash": MetaProgress.stash.duplicate(true),
		"upgrades": MetaProgress.upgrades.duplicate(true),
		"run_history": MetaProgress.run_history.duplicate(true),
	}
	_run_snapshot = {
		"backpack": RunManager.backpack.duplicate(true),
		"equipped": RunManager.equipped_items.duplicate(true),
		"pending_loadout": RunManager.pending_loadout.duplicate(true),
		"pending_equipped": RunManager.pending_equipped.duplicate(true),
		"is_run_active": RunManager.is_run_active,
	}


func _restore_state() -> void:
	MetaProgress.caps = int(_meta_snapshot.caps)
	MetaProgress.scrap = int(_meta_snapshot.scrap)
	MetaProgress.stash.assign(_meta_snapshot.stash)
	MetaProgress.upgrades = _meta_snapshot.upgrades.duplicate(true)
	MetaProgress.run_history.assign(_meta_snapshot.run_history)
	RunManager.backpack.assign(_run_snapshot.backpack)
	RunManager.equipped_items = _run_snapshot.equipped.duplicate(true)
	RunManager.pending_loadout.assign(_run_snapshot.pending_loadout)
	RunManager.pending_equipped = _run_snapshot.pending_equipped.duplicate(true)
	RunManager.is_run_active = bool(_run_snapshot.is_run_active)
	Settings.active_slot = _original_slot

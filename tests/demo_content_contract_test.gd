extends Node

const META_PROGRESS_PATH := "res://run_system/core/meta_progress.gd"
const RUN_MANAGER_PATH := "res://run_system/core/run_manager.gd"
const TUTORIAL_PATH := "res://battle_scene/ui/tutorial_tips.gd"
const BATTLE_PATH := "res://battle_scene/battle_scene.gd"
const RESULT_PATH := "res://run_system/ui/result_screen.gd"
const HERO_PATH := "res://run_system/data/heroes/cowboy_bill.json"
const BASE_UPGRADE_DIR := "res://run_system/data/base_upgrades/"
const EQUIPMENT_SET_SCRIPT = preload("res://battle_scene/equipment_set_system.gd")

class FakeCard:
	extends Control
	var card_info: Dictionary = {}

class FakeTarget:
	extends Node
	var statuses: Dictionary = {}

	func add_status(status: String, stacks: int) -> void:
		statuses[status] = int(statuses.get(status, 0)) + stacks

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	_test_demo_shape()
	_test_focused_card_pool()
	_test_event_deck()
	_test_set_onboarding_track()
	_test_set_instance_integrity()
	_test_equipment_set_effects()
	_test_removed_mechanics()
	_test_tutorial_completion()
	_test_result_cta_guard()
	_test_run_timer_resume_contract()
	_test_bill_identity()
	if failures.is_empty():
		print("[OK] Demo content contract passed")
		get_tree().quit(0)
		return
	push_error("Demo content contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _test_demo_shape() -> void:
	_expect(RunManager.DEMO_BUILD, "public build keeps demo gating enabled")
	_expect(RunManager.DEMO_MAX_ACTS == 1, "demo contains one authored act")
	_expect(RunManager.acts_total() == 1, "demo-aware act count is one")
	_expect(RunManager.DEMO_BOSS == "rust_titan", "Rust Titan is the fixed demo boss")
	_expect(RunManager.current_act_boss() == "rust_titan", "runtime boss selection is fixed")


func _test_focused_card_pool() -> void:
	var original_hero := RunManager.current_hero_id
	RunManager.current_hero_id = "cowboy_bill"
	var pool := MetaProgress.get_unlocked_card_pool()
	RunManager.current_hero_id = original_hero
	_expect(pool.size() == 36, "Bill's demo reward pool stays focused at 36 cards")
	for signature in ["piston_jab", "covering_reload", "hemorrhage", "limit_break"]:
		_expect(signature in pool, "focused pool contains Bill card %s" % signature)
	for diluted in ["strike", "defend", "radiation_dust"]:
		_expect(diluted not in pool, "focused pool excludes %s" % diluted)
	var unique := {}
	for card_id in pool:
		unique[str(card_id)] = true
	_expect(unique.size() == pool.size(), "focused reward pool contains no duplicates")


func _test_event_deck() -> void:
	var original_events: Array = RunManager._random_events.duplicate(true)
	var original_seen: Array[String] = RunManager._seen_random_event_ids.duplicate()
	RunManager._random_events = [
		{"id": "contract_a"},
		{"id": "contract_b"},
		{"id": "contract_c"},
	]
	RunManager._seen_random_event_ids.clear()
	var dealt := {}
	for _i in range(3):
		dealt[str(RunManager.pick_random_event().get("id", ""))] = true
	_expect(dealt.size() == 3, "random events do not repeat before the deck is exhausted")
	RunManager._random_events = original_events
	RunManager._seen_random_event_ids = original_seen


func _test_set_onboarding_track() -> void:
	var original_act := RunManager.current_act
	var original_floor := RunManager.current_floor
	var original_set := RunManager.demo_featured_set_id
	var original_claimed: Array[String] = RunManager.demo_set_piece_ids_claimed.duplicate()
	RunManager.current_act = 1
	RunManager.demo_featured_set_id = "weak_hunter"
	RunManager.demo_set_piece_ids_claimed.clear()
	var claimed_ids: Array[String] = []
	for floor_idx in RunManager.DEMO_SET_TRACK_FLOORS:
		RunManager.current_floor = floor_idx
		_expect(RunManager.should_offer_demo_set_piece(), "set milestone activates on floor %d" % floor_idx)
		var piece := RunManager.roll_demo_set_piece()
		_expect(not piece.is_empty(), "set milestone rolls an equipment piece")
		_expect(str(piece.get("rarity", "")) == "set", "set milestone always materializes at set rarity")
		_expect(
			RunManager.equip_affixes(piece).size() == 3,
			"set milestone always materializes with three affixes"
		)
		var item_id := RunManager.equip_base(piece)
		_expect(item_id not in claimed_ids, "set onboarding offers distinct pieces")
		claimed_ids.append(item_id)
		RunManager.mark_demo_set_piece_claimed(piece)
	_expect(claimed_ids.size() == 3, "demo exposes a playable three-piece set before the boss")
	_expect(not RunManager.should_offer_demo_set_piece(), "set track stops after three claimed pieces")
	RunManager.current_act = original_act
	RunManager.current_floor = original_floor
	RunManager.demo_featured_set_id = original_set
	RunManager.demo_set_piece_ids_claimed = original_claimed


func _test_set_instance_integrity() -> void:
	# Old profiles may still store a bare equipment id. Reading one of those ids
	# must not recreate the retired "common set" display state.
	var legacy_set := RunManager.as_equip_instance("weak_hunter_helm")
	_expect(str(legacy_set.get("set_id", "")) == "weak_hunter", "legacy set id is preserved")
	_expect(str(legacy_set.get("rarity", "")) == "set", "legacy set strings normalize to set rarity")
	_expect(
		RunManager.equip_affixes(legacy_set).size() == 3,
		"legacy set strings normalize to exactly three affixes"
	)
	var legacy_dict := {
		"base": "weak_hunter_helm",
		"rarity": "common",
		"affixes": [{"type": "attr_luck", "value": 1}],
		"cursed": false,
		"set_id": "weak_hunter",
	}
	var normalized_dict := RunManager.as_equip_instance(legacy_dict)
	_expect(str(normalized_dict.get("rarity", "")) == "set", "legacy set dictionaries normalize")
	_expect(
		RunManager.equip_affixes(normalized_dict).size() == 3,
		"legacy set dictionaries recover their missing affixes"
	)


func _test_equipment_set_effects() -> void:
	var system = EQUIPMENT_SET_SCRIPT.new()
	var effects: Array[Dictionary] = [
		{"type": "skill_block_bonus", "amount": 2, "set_id": "contract"},
		{"type": "attack_damage_bonus", "amount": 3, "set_id": "contract"},
		{"type": "attack_apply_status", "status": "weak", "stacks": 1, "set_id": "contract"},
	]
	system._active_effects = effects
	var attack := FakeCard.new()
	attack.card_info = {"type": "attack"}
	var skill := FakeCard.new()
	skill.card_info = {"type": "skill"}
	var target := FakeTarget.new()
	_expect(system.modify_card_damage(attack, 5) == 8, "set attack bonus modifies attack cards")
	_expect(system.modify_card_damage(skill, 5) == 5, "set attack bonus ignores skill cards")
	_expect(system.modify_card_block(skill, 5) == 7, "set block bonus modifies skill cards")
	_expect(system.modify_card_block(attack, 5) == 5, "set block bonus ignores attack cards")
	system.on_card_damage_resolved(attack, target)
	_expect(target.statuses.get("weak", 0) == 1, "set attack status applies after resolved damage")
	attack.free()
	skill.free()
	target.free()


func _test_removed_mechanics() -> void:
	for removed in ["med_bay", "starter_boost", "scrap_workshop"]:
		_expect(
			not FileAccess.file_exists(BASE_UPGRADE_DIR + removed + ".json"),
			"retired upgrade data is removed: %s" % removed
		)
	var run_source := FileAccess.get_file_as_string(RUN_MANAGER_PATH)
	var meta_source := FileAccess.get_file_as_string(META_PROGRESS_PATH)
	_expect(not run_source.contains('_get_meta_effect_value("med_bay")'), "retired Med Bay effect is not applied")
	_expect(not run_source.contains('_get_meta_effect_value("starter_boost")'), "retired starter boost is not applied")
	_expect(meta_source.contains("_migrate_removed_profile_state"), "old profiles receive the retired-upgrade migration")
	var original_caps := MetaProgress.caps
	var original_upgrades: Dictionary = MetaProgress.upgrades.duplicate(true)
	MetaProgress.caps = 10
	MetaProgress.upgrades = {"med_bay": 2, "scrap_workshop": 1, "command_center": 1}
	var migrated := bool(MetaProgress._migrate_removed_profile_state({"starter_deck_override": []}))
	_expect(migrated, "retired profile fields trigger migration")
	_expect(MetaProgress.caps == 220, "retired levels refund their exact 210 Caps")
	_expect(not MetaProgress.upgrades.has("med_bay"), "migration erases retired Med Bay levels")
	_expect(not MetaProgress.upgrades.has("scrap_workshop"), "migration erases retired discount levels")
	_expect(MetaProgress.upgrades.get("command_center", 0) == 1, "migration preserves active upgrades")
	MetaProgress.caps = original_caps
	MetaProgress.upgrades = original_upgrades


func _test_tutorial_completion() -> void:
	var tutorial_source := FileAccess.get_file_as_string(TUTORIAL_PATH)
	var battle_source := FileAccess.get_file_as_string(BATTLE_PATH)
	_expect(tutorial_source.contains("signal completed"), "tutorial exposes an explicit completion signal")
	_expect(tutorial_source.contains("completed.emit()"), "tutorial completes only after the last tip")
	var tutorial_body := _function_body(battle_source, "func _maybe_show_tutorial")
	_expect(tutorial_body.contains("tips.completed.connect"), "battle listens for real tutorial completion")
	_expect(
		tutorial_body.find("MetaProgress.mark_tutorial_seen()") > tutorial_body.find("tips.completed.connect"),
		"tutorial is persisted after completion rather than on open"
	)


func _test_result_cta_guard() -> void:
	var source := FileAccess.get_file_as_string(RESULT_PATH)
	_expect(not source.contains('const STORE_URL := "https://store.steampowered.com/"'), "result screen has no fake generic Steam CTA")
	_expect(source.contains("STORE_URL_SETTING"), "result screen supports a real store-page setting")
	_expect(source.contains('begins_with("https://store.steampowered.com/app/")'), "only a real Steam app URL enables the CTA")
	_expect(source.contains("RESULT_SUMMARY_DETAILS"), "result screen reports deck, relic and gear counts")


func _test_run_timer_resume_contract() -> void:
	var source := FileAccess.get_file_as_string(RUN_MANAGER_PATH)
	var save_body := _function_body(source, "func save_run")
	var load_body := _function_body(source, "func load_run")
	_expect(save_body.contains('"run_elapsed_msec"'), "run saves persist elapsed duration")
	_expect(
		load_body.contains("Time.get_ticks_msec() - saved_elapsed_msec"),
		"run loads rebuild the process-local timer from persisted elapsed duration"
	)


func _test_bill_identity() -> void:
	var hero = JSON.parse_string(FileAccess.get_file_as_string(HERO_PATH))
	_expect(typeof(hero) == TYPE_DICTIONARY, "Bill hero definition parses")
	if typeof(hero) == TYPE_DICTIONARY:
		var description := str(hero.get("description", "")).to_lower()
		_expect(description.contains("robot"), "Bill is explicitly a damaged robot")
		_expect(description.contains("western"), "Bill's surviving western memory is explicit")


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var finish := source.find("\nfunc ", start + signature.length())
	return source.substr(start) if finish < 0 else source.substr(start, finish - start)

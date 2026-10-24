extends Node

const TEST_SAVE_ROOT = preload("uid://c5pfll7nw68un")  # res://tests/support/test_save_root.gd

const META_PROGRESS_PATH := "res://run_system/core/meta_progress.gd"  # path-ok: reads source text
const RUN_MANAGER_PATH := "res://run_system/core/run_manager.gd"  # path-ok: reads source text
const TUTORIAL_PATH := "res://battle_scene/ui/tutorial_tips.gd"  # path-ok: reads source text
const BATTLE_PATH := "res://battle_scene/battle_scene.gd"  # path-ok: reads source text
const RESULT_PATH := "res://run_system/ui/result_screen.gd"  # path-ok: reads source text
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const EQUIPMENT_SET_SCRIPT = preload("uid://b3s8io84xovx7")  # res://battle_scene/equipment_set_system.gd
const FAKE_BATTLE = preload("uid://j25pi73kmisn")  # res://tests/support/fake_battle.gd
const COMBAT_SOURCE = preload("uid://jgs131055xrk")  # res://core/combat/combat_source.gd
const VALUE_CALC = preload("uid://tynklfj3vjf5")  # res://core/combat/value_calc.gd
const VALUE_PROPS = preload("uid://cccfcqt180t4x")  # res://core/combat/value_props.gd

class FakeCard:
	extends Control
	var card_info: Dictionary = {}

var failures: PackedStringArray = []


func _ready() -> void:
	TEST_SAVE_ROOT.use("demo_content_contract_test")
	call_deferred("_run")


func _exit_tree() -> void:
	TEST_SAVE_ROOT.release()


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
	await _test_equipment_set_effects()
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
	_expect(RunManager.DEMO_BOSS == "base:rust_titan", "Rust Titan is the fixed demo boss")
	_expect(RunManager.current_act_boss() == "base:rust_titan", "runtime boss selection is fixed")


func _test_focused_card_pool() -> void:
	var original_hero := RunManager.current_hero_id
	RunManager.current_hero_id = "base:cowboy_bill"
	var pool := MetaProgress.get_unlocked_card_pool()
	RunManager.current_hero_id = original_hero
	_expect(pool.size() == 28, "Bill's demo reward pool stays focused at 28 cards")
	for signature in ["base:piston_jab", "base:covering_reload", "base:hemorrhage", "base:limit_break"]:
		_expect(signature in pool, "focused pool contains Bill card %s" % signature)
	for diluted in [
		"base:strike",
		"base:defend",
		"base:radiation_dust",
		"crowbar_smash",
		"pipe_swing",
		"breach_charge",
		"bulkhead_bleed",
		"base:combat_stim",
		"focusing_blow",
		"hemo_drive",
		"last_breath",
		"siphon_valve",
	]:
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
	RunManager.demo_featured_set_id = "base:weak_hunter"
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
	var legacy_set := RunManager.as_equip_instance("base:weak_hunter_helm")
	_expect(str(legacy_set.get("set_id", "")) == "base:weak_hunter", "legacy set id is preserved")
	_expect(str(legacy_set.get("rarity", "")) == "set", "legacy set strings normalize to set rarity")
	_expect(
		RunManager.equip_affixes(legacy_set).size() == 3,
		"legacy set strings normalize to exactly three affixes"
	)
	var legacy_dict := {
		"base": "base:weak_hunter_helm",
		"rarity": "common",
		"affixes": [{"type": "attr_luck", "value": 1}],
		"cursed": false,
		"set_id": "base:weak_hunter",
	}
	var normalized_dict := RunManager.as_equip_instance(legacy_dict)
	_expect(str(normalized_dict.get("rarity", "")) == "set", "legacy set dictionaries normalize")
	_expect(
		RunManager.equip_affixes(normalized_dict).size() == 3,
		"legacy set dictionaries recover their missing affixes"
	)


func _test_equipment_set_effects() -> void:
	var battle = FAKE_BATTLE.new()
	add_child(battle)
	var system = EQUIPMENT_SET_SCRIPT.new()
	system.setup(battle)
	system._active_effects.append({"type": "skill_block_bonus", "amount": 2, "set_id": "contract"})
	system._active_effects.append({"type": "attack_damage_bonus", "amount": 3, "set_id": "contract"})
	system._active_effects.append(
		{"type": "attack_apply_status", "status": "weak", "stacks": 1, "set_id": "contract"}
	)
	battle.equipment_set_system = system
	battle.setup()
	var attack := FakeCard.new()
	attack.card_info = {"type": "attack"}
	var skill := FakeCard.new()
	skill.card_info = {"type": "skill"}
	var target = battle.add_enemy()
	var attack_source = COMBAT_SOURCE.make("card", "player", battle.player, attack)
	var skill_source = COMBAT_SOURCE.make("card", "player", battle.player, skill)
	var powered: int = VALUE_PROPS.POWERED
	var commands = battle.combat_commands
	_expect(commands.preview_damage(attack_source, target, 5, powered) == 8, "set attack bonus modifies attack cards")
	_expect(commands.preview_damage(skill_source, target, 5, powered) == 5, "set attack bonus ignores skill cards")
	_expect(_preview_block(battle, skill_source, 5) == 7, "set block bonus modifies skill cards")
	_expect(_preview_block(battle, attack_source, 5) == 5, "set block bonus ignores attack cards")
	await commands.damage(attack_source, [target], 5, powered)
	_expect(target.get_status_stacks("weak") == 1, "set attack status applies after resolved damage")
	attack.free()
	skill.free()
	battle.free()


func _preview_block(battle, source, base: int) -> int:
	return battle.combat_hooks.compute_block(
		VALUE_CALC.for_block(source, battle.player, base, VALUE_PROPS.POWERED, true)
	)


func _test_removed_mechanics() -> void:
	for removed in ["med_bay", "starter_boost", "scrap_workshop"]:
		_expect(
			MODEL_DB.resolve("base_upgrade", removed) == "",
			"retired upgrade data is removed: %s" % removed
		)
	var run_source := FileAccess.get_file_as_string(RUN_MANAGER_PATH)
	var meta_source := FileAccess.get_file_as_string(META_PROGRESS_PATH)
	for retired_card in RunManager.RETIRED_CARD_IDS:
		_expect(
			MODEL_DB.resolve("card", retired_card) == "",
			"retired card data is removed: %s" % retired_card
		)
	_expect(run_source.contains("RETIRED_CARD_IDS"), "old run saves strip retired card IDs")
	_expect(
		RunManager.CARD_ID_MIGRATIONS.get("vent_plating", "") == "base:kinetic_baffle",
		"old Kinetic Baffle card IDs migrate without deleting the card"
	)
	_expect(not run_source.contains('_get_meta_effect_value("med_bay")'), "retired Med Bay effect is not applied")
	_expect(not run_source.contains('_get_meta_effect_value("starter_boost")'), "retired starter boost is not applied")
	_expect(meta_source.contains("_migrate_removed_profile_state"), "old profiles receive the retired-upgrade migration")
	var original_caps := MetaProgress.caps
	var original_upgrades: Dictionary = MetaProgress.upgrades.duplicate(true)
	MetaProgress.caps = 10
	MetaProgress.upgrades = {"med_bay": 2, "scrap_workshop": 1, "base:command_center": 1}
	var migrated := bool(MetaProgress._migrate_removed_profile_state({"starter_deck_override": []}))
	_expect(migrated, "retired profile fields trigger migration")
	_expect(MetaProgress.caps == 220, "retired levels refund their exact 210 Caps")
	_expect(not MetaProgress.upgrades.has("med_bay"), "migration erases retired Med Bay levels")
	_expect(not MetaProgress.upgrades.has("scrap_workshop"), "migration erases retired discount levels")
	_expect(MetaProgress.upgrades.get("base:command_center", 0) == 1, "migration preserves active upgrades")
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
	var hero = MODEL_DB.data("character", "base:cowboy_bill")
	_expect(typeof(hero) == TYPE_DICTIONARY, "Bill hero definition parses")
	if typeof(hero) == TYPE_DICTIONARY:
		var description := str(hero.get("description", "")).to_lower()
		_expect(description.contains("robot"), "Bill is explicitly a damaged robot")
		_expect(description.contains("western"), "Bill's surviving western memory is explicit")
		_expect(hero.get("animate_idle", true) == false, "Bill uses a static combat rest pose")


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var finish := source.find("\nfunc ", start + signature.length())
	return source.substr(start) if finish < 0 else source.substr(start, finish - start)

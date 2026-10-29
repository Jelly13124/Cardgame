extends Node

## Saves carry a schema version and migrate once, on load, through a chain of
## steps (core/save/run_save.gd, profile_save.gd): every historical sample in
## tests/fixtures/saves reaches the current shape — namespaced ids, equipment
## always instances, retired content and fields gone — unknown ids are kept, a
## current save migrates to itself, the original is backed up once and the
## migrated save is written back.

const RUN_SAVE = preload("uid://dkhd2poukjb61")  # res://core/save/run_save.gd
const PROFILE_SAVE = preload("uid://cox1wehu1m6on")  # res://core/save/profile_save.gd
const MIGRATION_CHAIN = preload("uid://bmeya57dgtty2")  # res://core/save/migration_chain.gd
const CONTENT_ID_MIGRATION = preload("uid://27jpcb0ubw68")  # res://core/save/content_id_migration.gd
const SAVE_IO = preload("uid://seo0j510xyq1")  # res://core/save/save_io.gd
const RUN_V1 := "res://tests/fixtures/saves/run_v1.json"
const RUN_V3 := "res://tests/fixtures/saves/run_v3.json"
const META_V1 := "res://tests/fixtures/saves/meta_v1.json"
const META_V2 := "res://tests/fixtures/saves/meta_v2.json"

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _fixture(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _run() -> void:
	_test_chains()
	_test_run_v1()
	_test_run_v3()
	_test_meta_v1()
	_test_meta_v2()
	_test_backup_once()
	await _test_load_run_end_to_end()
	_test_no_read_time_conversion()
	if failures.is_empty():
		print("[OK] save migration passed")
		get_tree().quit(0)
		return
	push_error("save migration failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _test_chains() -> void:
	_expect(RUN_SAVE.chain().problems().is_empty(), "run chain covers v1..v%d: %s" % [RUN_SAVE.CURRENT, RUN_SAVE.chain().problems()])
	_expect(PROFILE_SAVE.chain().problems().is_empty(), "profile chain is sound: %s" % [PROFILE_SAVE.chain().problems()])
	var gap = MIGRATION_CHAIN.make("probe", 1, 4).add(1, func(d): return d).add(3, func(d): return d)
	_expect(gap.problems() == PackedStringArray(["probe: no step from v2"]), "a gap is reported: %s" % [gap.problems()])
	var dup = MIGRATION_CHAIN.make("probe", 1, 2).add(1, func(d): return d).add(1, func(d): return d)
	_expect(not dup.problems().is_empty(), "a duplicate step is reported")


func _is_instance(x: Variant) -> bool:
	return typeof(x) == TYPE_DICTIONARY and str(x.get("base", "")).begins_with("base:")


func _test_run_v1() -> void:
	var run := RUN_SAVE.migrate(_fixture(RUN_V1))
	_expect(int(run["schema_version"]) == 4 and not run.has("v"), "run save reaches schema v4")
	_expect(run["current_hero_id"] == "base:cowboy_bill", "hero id migrated")
	_expect(not run.has("current_hero_data"), "no copy of the hero data is saved")
	var deck_ids: Array = run["player_deck"].map(func(e): return e["card_id"])
	_expect(deck_ids == ["base:reload", "base:strike", "ghost_card"], "deck ids migrated, unknown kept, retired dropped: %s" % [deck_ids])
	_expect(int(run["player_deck"][0]["uid"]) == 1, "deck uids kept")
	var head: Dictionary = run["equipped_items"]["head"]
	_expect(head["base"] == "base:gear_head_common", "equipped instance base migrated")
	_expect(head["affixes"] == [{"type": "attr_luck", "value": 1.0}], "affixes untouched")
	_expect(_is_instance(run["equipped_items"]["chest"]) and run["equipped_items"]["chest"]["base"] == "base:gear_chest_common",
		"a legacy string slot became an instance")
	_expect(run["equipped_items"]["weapon"] == {}, "empty slot stays empty")
	var bag: Array = run["backpack"]  # bare-ok: v1 legacy id
	_expect(bag[0]["item"]["base"] == "base:warden_axe" and bag[0]["item"]["set_id"] == "base:warden", "backpack instance migrated")
	_expect(bag[0]["item"]["rarity"] == "set" and bag[0]["item"]["affixes"].size() == 3, "a set piece is normalized once")
	_expect(bag[1]["kind"] == "equip" and _is_instance(bag[1]["item"]) and not bag[1].has("id"), "a legacy equip cell holds an instance")
	_expect(bag[2]["id"] == "base:med_kit", "tool cell id migrated")
	_expect(bag[3] == {"kind": "gold", "amount": 40.0}, "gold cell untouched")
	_expect(bag[4] == null, "empty cell stays empty")
	_expect(run["relics"] == ["base:bounty_tags", "base:crit_clip"], "relics migrated")
	_expect(run["tool_inventory"] == ["base:smoke_bomb", ""], "tool slots migrated, empty kept")
	_expect(run["current_encounter"] == ["base:scrap_rat", "base:hex_drone"], "encounter migrated")
	_expect(run["seen_random_event_ids"] == ["base:adrenaline_shot"], "seen events migrated as events")
	_expect(run["demo_set_piece_ids_claimed"] == ["base:weak_hunter_helm"], "claimed pieces migrated")
	_expect(int(run["run_elapsed_msec"]) == 0 and not run.has("run_started_msec"), "the timer resumes from the elapsed time only")
	_expect(RUN_SAVE.migrate(run) == run, "migrating a current run save is the identity")


func _test_run_v3() -> void:
	var raw := _fixture(RUN_V3)
	_expect(RUN_SAVE.version_of(raw) == 3, "the v3 sample is a v3 save")
	var run := RUN_SAVE.migrate(raw)
	_expect(int(run["schema_version"]) == 4, "the v3 sample reaches v4")
	_expect(run["rng"] == raw["rng"], "the RNG state is kept")
	for slot in run["equipped_items"]:
		var v: Variant = run["equipped_items"][slot]
		_expect(v == {} or _is_instance(v), "slot %s holds an instance or nothing" % slot)
	_expect(run["map_data"] == raw["map_data"] and run["player_deck"] == raw["player_deck"], "map and deck are untouched")


func _test_meta_v1() -> void:
	var meta := PROFILE_SAVE.migrate(_fixture(META_V1))
	_expect(int(meta["schema_version"]) == 3 and not meta.has("content_v"), "profile reaches schema v3")
	_expect(meta["upgrades"] == {"base:backpack": 2.0, "base:blacksmith": 1.0}, "upgrade keys migrated, removed upgrade erased: %s" % [meta["upgrades"]])
	_expect(int(meta["caps"]) == 170, "the removed upgrade's Caps are refunded (120 + 50): %s" % meta["caps"])
	_expect(meta["stash"].size() == 2 and meta["stash"].all(_is_instance), "every stash entry is an instance")
	_expect(meta["stash"][1]["base"] == "base:gear_head_uncommon", "a legacy stash string became an instance")
	_expect(meta["base_loadout"][0]["base"] == "base:gear_chest_uncommon", "base loadout migrated")
	_expect(meta["base_equipped"]["head"]["base"] == "base:gear_head_rare", "base equipped migrated")
	_expect(meta["active_bounties"] == [{"id": "base:elite_purge", "progress": 1.0}], "active bounties migrated")
	_expect(meta["bounty_shelf"] == ["base:scavenger_haul", "base:war_profiteer"], "bounty shelf migrated")
	_expect(meta["cards_seen"] == {"base:reload": true, "base:hemorrhage": true}, "codex migrated")
	_expect(meta["run_history"][0]["hero_id"] == "base:cowboy_bill", "history hero migrated")
	_expect(int(meta["buildings"].get("blacksmith", 0)) == 1, "building ids are not content and stay as they are")  # bare-ok: v1 legacy id
	_expect(int(meta["buildings"].get("outpost", 0)) == 2, "the legacy blacksmith upgrade seeds the Outpost at tier 2")
	_expect(PROFILE_SAVE.migrate(meta) == meta, "migrating a current profile is the identity")


func _test_meta_v2() -> void:
	var raw := _fixture(META_V2)
	_expect(PROFILE_SAVE.version_of(raw) == 2, "the v2 sample is a v2 profile")
	var meta := PROFILE_SAVE.migrate(raw)
	_expect(not meta.has("bounty_free_claimed"), "a retired field is dropped")
	# Each migration backs up its own source version (an older .v1.bak from an
	# earlier migration must not stop this one).
	SAVE_IO.write_json("backup_probe.json", raw)
	var probe := SAVE_IO.path("backup_probe.json")
	var f := FileAccess.open(probe + ".v1.bak", FileAccess.WRITE)
	f.store_string("{}")
	f.close()
	_expect(CONTENT_ID_MIGRATION.backup_once("backup_probe.json", raw, 2), "a v2 save gets its own backup")
	_expect(FileAccess.file_exists(probe + ".v2.bak"), "the backup is named after the source version")
	_expect(meta["stash"].all(_is_instance), "every stash entry is an instance")
	_expect(int(meta["caps"]) == int(raw["caps"]), "no refund without removed upgrades")


func _test_backup_once() -> void:
	# The live file may be corrupt (SaveIO recovered from .bak1): the backup must
	# hold the data that was actually loaded, not the live bytes.
	var probe := SAVE_IO.path("migration_probe.json")
	var f := FileAccess.open(probe, FileAccess.WRITE)
	f.store_string("{ truncated")
	f.close()
	_expect(CONTENT_ID_MIGRATION.backup_once("migration_probe.json", {"v": 1, "first": true}, 1), "first backup written")
	_expect(not CONTENT_ID_MIGRATION.backup_once("migration_probe.json", {"v": 1, "first": false}, 1), "second backup skipped")
	var backup: Variant = JSON.parse_string(FileAccess.get_file_as_string(probe + ".v1.bak"))
	_expect(typeof(backup) == TYPE_DICTIONARY and bool(backup.get("first", false)), "backup keeps the loaded data")


func _test_load_run_end_to_end() -> void:
	var path: String = RunManager._run_save_path()
	SAVE_IO.write_json(path, _fixture(RUN_V1))
	_expect(RunManager.load_run(), "v1 run save loads")
	_expect(RunManager.relics.size() > 0 and RunManager.relics[0] == "base:bounty_tags", "loaded relics are full ids")
	_expect(RunManager.current_hero_id == "base:cowboy_bill", "loaded hero is a full id")
	_expect(RunManager.equipped_items.values().all(func(v): return v == {} or _is_instance(v)), "loaded slots hold instances")
	_expect(FileAccess.file_exists(SAVE_IO.path(path + ".v1.bak")), "run save backed up before migration")
	var written: Dictionary = SAVE_IO.read_json(path).get("data", {})
	_expect(int(written.get("schema_version", 0)) == RUN_SAVE.CURRENT, "the migrated save is written back at v%d" % RUN_SAVE.CURRENT)
	RunManager.is_run_active = false
	RunManager.clear_run_save()
	await get_tree().process_frame


## Runtime code handles only the current shape: the read-time equipment
## converter is gone everywhere (S6-02).
func _test_no_read_time_conversion() -> void:
	var hits: PackedStringArray = []
	_scan("res://", hits)
	_expect(hits.is_empty(), "no read-time equipment conversion left: %s" % [hits])


func _scan(dir: String, hits: PackedStringArray) -> void:
	for sub in DirAccess.get_directories_at(dir):
		if sub in [".godot", ".git", "addons", ".superpowers", "tests"]:
			continue
		_scan(dir.path_join(sub), hits)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") and FileAccess.get_file_as_string(dir.path_join(f)).contains("as_equip" + "_instance"):
			hits.append(dir.path_join(f))

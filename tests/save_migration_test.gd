extends Node

## v1 saves (bare content IDs) migrate to namespaced IDs on load. Unknown or
## retired IDs are kept verbatim so nothing the player owned is dropped by the
## migration itself; the live file is backed up once before it is rewritten.

const SAVE_MIGRATION = preload("uid://27jpcb0ubw68")  # res://core/content/save_migration.gd
const SAVE_IO = preload("uid://seo0j510xyq1")  # res://core/save/save_io.gd
const RUN_V1 := "res://tests/fixtures/saves/run_v1.json"
const META_V1 := "res://tests/fixtures/saves/meta_v1.json"

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
	_test_run_migration()
	_test_meta_migration()
	_test_backup_once()
	await _test_load_run_end_to_end()
	if failures.is_empty():
		print("[OK] save migration passed")
		get_tree().quit(0)
		return
	push_error("save migration failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _test_run_migration() -> void:
	var run := SAVE_MIGRATION.migrate_run(_fixture(RUN_V1))
	_expect(int(run["v"]) == SAVE_MIGRATION.RUN_VERSION and SAVE_MIGRATION.RUN_VERSION == 3, "run save version is 3")
	_expect(run["current_hero_id"] == "base:cowboy_bill", "hero id migrated")
	_expect(str(run["current_hero_data"].get("id", "")) == "base:cowboy_bill", "hero data re-read from ModelDb")
	_expect(run["current_hero_data"].has("card_pool"), "hero data comes from current content")
	var deck_ids: Array = run["player_deck"].map(func(e): return e["card_id"])
	_expect(deck_ids == ["base:reload", "base:strike", "ghost_card", "combat_stim"],  # bare-ok: v1 legacy id
		"deck ids migrated, unknown kept: %s" % [deck_ids])
	_expect(int(run["player_deck"][0]["uid"]) == 1, "deck uids kept")
	var head: Dictionary = run["equipped_items"]["head"]
	_expect(head["base"] == "base:gear_head_common", "equipped instance base migrated")
	_expect(head["affixes"] == [{"type": "attr_luck", "value": 1.0}], "affixes untouched")
	_expect(run["equipped_items"]["chest"] == "base:gear_chest_common", "legacy string slot migrated")
	_expect(run["equipped_items"]["weapon"] == {}, "empty slot stays empty")
	var bag: Array = run["backpack"]  # bare-ok: v1 legacy id
	_expect(bag[0]["item"]["base"] == "base:warden_axe", "backpack instance base migrated")
	_expect(bag[0]["item"]["set_id"] == "base:warden", "backpack instance set_id migrated")
	_expect(bag[1]["id"] == "base:gear_hands_rare", "legacy equip cell id migrated")
	_expect(bag[2]["id"] == "base:med_kit", "tool cell id migrated")
	_expect(bag[3] == {"kind": "gold", "amount": 40.0}, "gold cell untouched")
	_expect(bag[4] == null, "empty cell stays empty")
	_expect(run["relics"] == ["base:bounty_tags", "base:crit_clip"], "relics migrated")
	_expect(run["tool_inventory"] == ["base:smoke_bomb", ""], "tool slots migrated, empty kept")
	_expect(run["current_encounter"] == ["base:scrap_rat", "base:hex_drone"], "encounter migrated")
	_expect(run["seen_random_event_ids"] == ["base:adrenaline_shot"], "seen events migrated as events")
	_expect(run["demo_featured_set_id"] == "base:weak_hunter", "featured set migrated")
	_expect(run["demo_set_piece_ids_claimed"] == ["base:weak_hunter_helm"], "claimed pieces migrated")
	_expect(SAVE_MIGRATION.migrate_run(run) == run, "migrating a current save is the identity")


func _test_meta_migration() -> void:
	var meta := SAVE_MIGRATION.migrate_meta(_fixture(META_V1))
	_expect(int(meta["content_v"]) == SAVE_MIGRATION.META_CONTENT_VERSION and SAVE_MIGRATION.META_CONTENT_VERSION == 2,
		"meta content version is 2")
	_expect(meta["upgrades"] == {"base:backpack": 2.0, "base:blacksmith": 1.0, "med_bay": 1.0},
		"upgrade keys migrated, removed upgrade kept for refund: %s" % [meta["upgrades"]])
	_expect(meta["stash"][0]["base"] == "base:gear_weapon_rare" and meta["stash"][1] == "base:gear_head_uncommon",
		"stash migrated")
	_expect(meta["base_loadout"][0]["base"] == "base:gear_chest_uncommon", "base loadout migrated")
	_expect(meta["base_equipped"]["head"]["base"] == "base:gear_head_rare", "base equipped migrated")
	_expect(meta["active_bounties"] == [{"id": "base:elite_purge", "progress": 1.0}], "active bounties migrated")
	_expect(meta["bounty_shelf"] == ["base:scavenger_haul", "base:war_profiteer"], "bounty shelf migrated")
	_expect(meta["cards_seen"] == {"base:reload": true, "base:hemorrhage": true}, "codex migrated")
	_expect(meta["run_history"][0]["hero_id"] == "base:cowboy_bill", "history hero migrated")
	_expect(meta["buildings"] == {"blacksmith": 1.0}, "building ids are not content and stay as they are")  # bare-ok: v1 legacy id
	_expect(SAVE_MIGRATION.migrate_meta(meta) == meta, "migrating a v2 meta is the identity")


func _test_backup_once() -> void:
	# The live file may be corrupt (SaveIO recovered from .bak1): the backup must
	# hold the v1 data that was actually loaded, not the live bytes.
	var probe := SAVE_IO.path("migration_probe.json")
	var f := FileAccess.open(probe, FileAccess.WRITE)
	f.store_string("{ truncated")
	f.close()
	_expect(SAVE_MIGRATION.backup_once("migration_probe.json", {"v": 1, "first": true}), "first backup written")
	_expect(not SAVE_MIGRATION.backup_once("migration_probe.json", {"v": 1, "first": false}), "second backup skipped")
	var backup: Variant = JSON.parse_string(FileAccess.get_file_as_string(probe + ".v1.bak"))
	_expect(typeof(backup) == TYPE_DICTIONARY and bool(backup.get("first", false)), "backup keeps the loaded v1 data")


func _test_load_run_end_to_end() -> void:
	var path: String = RunManager._run_save_path()
	SAVE_IO.write_json(path, _fixture(RUN_V1))
	_expect(RunManager.load_run(), "v1 run save loads")
	_expect(RunManager.relics.size() > 0 and RunManager.relics[0] == "base:bounty_tags", "loaded relics are full ids")
	_expect(RunManager.current_hero_id == "base:cowboy_bill", "loaded hero is a full id")
	var deck_ids: Array = RunManager.player_deck.map(func(e): return e["card_id"])
	_expect(not deck_ids.has("combat_stim"), "retired card stripped after migration")  # bare-ok: v1 legacy id
	_expect(FileAccess.file_exists(SAVE_IO.path(path + ".v1.bak")), "run save backed up before migration")
	RunManager.is_run_active = false
	RunManager.clear_run_save()
	await get_tree().process_frame

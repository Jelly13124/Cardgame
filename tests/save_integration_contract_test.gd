extends Node

## Profile, run and settings saves all go through SaveIO: they honour
## SaveIO.root, survive a corrupt live file, keep old-format saves readable and
## delete their backups together with the slot.

const SAVE_IO = preload("uid://seo0j510xyq1")  # res://core/save/save_io.gd
const TEST_ROOT := "user://__test__/integration/"

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	SAVE_IO.root = TEST_ROOT
	_clear_dir(TEST_ROOT)
	test_legacy_profile_loads_unchanged()
	test_profile_survives_corrupt_main()
	test_run_save_roundtrip()
	test_delete_slot_removes_backups()
	test_settings_roundtrip()
	test_late_run_saves_are_plain_json()
	RunManager.clear_run_save()
	RunManager.is_run_active = false
	_clear_dir(TEST_ROOT)
	SAVE_IO.root = "user://"
	if failures.is_empty():
		print("[OK] Save integration contract passed")
		get_tree().quit(0)
		return
	push_error("Save integration contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _abs(relative: String) -> String:
	return TEST_ROOT.path_join(relative)


func _write_raw(relative: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(_abs(relative).get_base_dir())
	var f := FileAccess.open(_abs(relative), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _has_file_starting_with(dir_relative: String, prefix: String) -> bool:
	var dir_path := _abs(dir_relative)
	if not DirAccess.dir_exists_absolute(dir_path):
		return false
	for f in DirAccess.get_files_at(dir_path):
		if f.begins_with(prefix):
			return true
	return false


func _clear_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for d in DirAccess.get_directories_at(path):
		_clear_dir(path.path_join(d))
		DirAccess.remove_absolute(path.path_join(d))


func test_legacy_profile_loads_unchanged() -> void:
	_write_raw(
		"slot_1/meta.json",
		JSON.stringify({"caps": 120, "scrap": 30, "buildings": {"forge": 2}})
	)
	MetaProgress.set_active_slot(1)
	_expect(MetaProgress.caps == 120, "legacy profile: caps 120 (got %d)" % MetaProgress.caps)
	_expect(MetaProgress.scrap == 30, "legacy profile: scrap 30 (got %d)" % MetaProgress.scrap)
	_expect(
		MetaProgress.get_building_tier("forge") == 2,
		"legacy profile: forge tier 2 (got %d)" % MetaProgress.get_building_tier("forge")
	)


func test_profile_survives_corrupt_main() -> void:
	MetaProgress.set_active_slot(1)
	MetaProgress.caps = 50
	MetaProgress.save_progress()
	MetaProgress.caps = 70
	MetaProgress.save_progress()
	_write_raw("slot_1/meta.json", "{broken")
	MetaProgress.load_progress()
	_expect(MetaProgress.caps == 50, "corrupt profile: caps restored from backup (got %d)" % MetaProgress.caps)
	_expect(
		_has_file_starting_with("slot_1", "meta.json.corrupt-"),
		"corrupt profile: corrupt copy preserved"
	)


func test_run_save_roundtrip() -> void:
	MetaProgress.set_active_slot(1)
	RunManager.start_new_run("cowboy_bill")
	RunManager.current_floor = 3
	RunManager.save_run()
	_expect(FileAccess.file_exists(_abs("slot_1/run_save.json")), "run save: written under SaveIO.root")
	RunManager.current_floor = 9
	_expect(RunManager.load_run(), "run save: load_run returns true")
	_expect(RunManager.current_floor == 3, "run save: floor restored (got %d)" % RunManager.current_floor)


func test_delete_slot_removes_backups() -> void:
	MetaProgress.set_active_slot(1)
	MetaProgress.save_progress()
	MetaProgress.save_progress()
	RunManager.save_run()
	MetaProgress.delete_slot(1)
	_expect(not FileAccess.file_exists(_abs("slot_1/meta.json")), "delete slot: meta.json removed")
	_expect(not FileAccess.file_exists(_abs("slot_1/meta.json.bak1")), "delete slot: meta backup removed")
	_expect(not FileAccess.file_exists(_abs("slot_1/run_save.json")), "delete slot: run save removed")


func test_settings_roundtrip() -> void:
	Settings.music_volume = 0.2
	Settings.save_settings()
	_expect(FileAccess.file_exists(_abs("settings.json")), "settings: written under SaveIO.root")
	Settings.music_volume = 0.9
	Settings.load_settings()
	_expect(is_equal_approx(Settings.music_volume, 0.2), "settings: music volume restored (got %s)" % Settings.music_volume)


func test_late_run_saves_are_plain_json() -> void:
	MetaProgress.set_active_slot(1)
	RunManager.start_new_run("cowboy_bill")
	for tier in ["common", "uncommon", "rare"]:
		RunManager.add_equip_to_backpack(RunManager.roll_shell_drop(tier))
	RunManager.add_relic("barbed_plating")
	RunManager.add_tool("blood_kit")
	MetaProgress.add_to_stash(RunManager.roll_shell_drop("rare"))
	MetaProgress.refresh_bounty_shelf_if_stale()
	if not MetaProgress.bounty_shelf.is_empty():
		MetaProgress.take_bounty(str(MetaProgress.bounty_shelf[0]))
	RunManager.save_run()
	_expect(
		SAVE_IO.last_non_json_paths.is_empty(),
		"late run save: only JSON values (got %s)" % ", ".join(SAVE_IO.last_non_json_paths)
	)
	MetaProgress.save_progress()
	_expect(
		SAVE_IO.last_non_json_paths.is_empty(),
		"late profile save: only JSON values (got %s)" % ", ".join(SAVE_IO.last_non_json_paths)
	)
	_expect(RunManager.load_run(), "late run save: loads back")
	_expect(RunManager.relics.has("barbed_plating"), "late run save: relic restored")

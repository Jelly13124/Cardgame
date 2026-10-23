extends Node

## Contract for core/save/save_io.gd: atomic writes, rotating backups, recovery
## from corrupt files without ever destroying them, and legacy-file reads.

const SAVE_IO = preload("uid://seo0j510xyq1")  # res://core/save/save_io.gd
const TEST_ROOT := "user://__test__/save_io/"

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
	for test in [
		"test_roundtrip",
		"test_write_creates_missing_directories",
		"test_backups_rotate",
		"test_corrupt_main_recovers_from_bak1",
		"test_all_corrupt_keeps_copy",
		"test_stale_tmp_is_ignored_and_replaced",
		"test_legacy_file_without_backups",
		"test_missing",
		"test_delete_keeps_corrupt_copies",
		"test_unserializable_write_keeps_original",
	]:
		_clear_dir(TEST_ROOT)
		call(test)
	_clear_dir(TEST_ROOT)
	SAVE_IO.root = "user://"
	if failures.is_empty():
		print("[OK] SaveIO contract passed")
		get_tree().quit(0)
		return
	push_error("SaveIO contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


# ─── Helpers ──────────────────────────────────────────────────────────────────


func _abs(relative: String) -> String:
	return TEST_ROOT.path_join(relative)


func _write_raw(relative: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(_abs(relative).get_base_dir())
	var f := FileAccess.open(_abs(relative), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _read_raw(relative: String) -> String:
	if not FileAccess.file_exists(_abs(relative)):
		return ""
	return FileAccess.get_file_as_string(_abs(relative))


func _parsed(relative: String) -> Variant:
	return JSON.parse_string(_read_raw(relative))


func _files_starting_with(dir_relative: String, prefix: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir_path := TEST_ROOT.path_join(dir_relative) if dir_relative != "" else TEST_ROOT
	if not DirAccess.dir_exists_absolute(dir_path):
		return out
	for f in DirAccess.get_files_at(dir_path):
		if f.begins_with(prefix):
			out.append(f)
	return out


func _clear_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for d in DirAccess.get_directories_at(path):
		_clear_dir(path.path_join(d))
		DirAccess.remove_absolute(path.path_join(d))


# ─── Tests ────────────────────────────────────────────────────────────────────


func test_roundtrip() -> void:
	_expect(SAVE_IO.write_json("x.json", {"a": 1}) == OK, "roundtrip: write returns OK")
	var r: Dictionary = SAVE_IO.read_json("x.json")
	_expect(r.get("status") == SAVE_IO.OK_STATUS, "roundtrip: status OK")
	_expect(int(r.get("data", {}).get("a", 0)) == 1, "roundtrip: data.a == 1")
	_expect(r.get("source") == "x.json", "roundtrip: source is the main file")


func test_write_creates_missing_directories() -> void:
	_expect(SAVE_IO.write_json("slot_3/meta.json", {"k": true}) == OK, "mkdir: write returns OK")
	_expect(FileAccess.file_exists(_abs("slot_3/meta.json")), "mkdir: file exists in new directory")


func test_backups_rotate() -> void:
	for v in [1, 2, 3]:
		SAVE_IO.write_json("x.json", {"v": v})
	_expect(int(_parsed("x.json").get("v", 0)) == 3, "rotate: main holds v3")
	_expect(int(_parsed("x.json.bak1").get("v", 0)) == 2, "rotate: bak1 holds v2")
	_expect(int(_parsed("x.json.bak2").get("v", 0)) == 1, "rotate: bak2 holds v1")


func test_corrupt_main_recovers_from_bak1() -> void:
	SAVE_IO.write_json("x.json", {"v": 1})
	SAVE_IO.write_json("x.json", {"v": 2})
	_write_raw("x.json", "{broken")
	var r: Dictionary = SAVE_IO.read_json("x.json")
	_expect(r.get("status") == SAVE_IO.RECOVERED, "recover: status RECOVERED")
	_expect(int(r.get("data", {}).get("v", 0)) == 1, "recover: data comes from bak1 (v1)")
	_expect(_files_starting_with("", "x.json.corrupt-").size() == 1, "recover: corrupt copy kept")


func test_all_corrupt_keeps_copy() -> void:
	_write_raw("x.json", "{main broken")
	_write_raw("x.json.bak1", "{bak1 broken")
	_write_raw("x.json.bak2", "{bak2 broken")
	var r: Dictionary = SAVE_IO.read_json("x.json")
	_expect(r.get("status") == SAVE_IO.CORRUPT, "all corrupt: status CORRUPT")
	_expect(r.get("data") == {}, "all corrupt: data is empty")
	var copies := _files_starting_with("", "x.json.corrupt-")
	_expect(copies.size() == 1, "all corrupt: one corrupt copy kept")
	if copies.size() == 1:
		_expect(_read_raw(copies[0]) == "{main broken", "all corrupt: copy holds the original main file")


func test_stale_tmp_is_ignored_and_replaced() -> void:
	SAVE_IO.write_json("x.json", {"v": 1})
	_write_raw("x.json.tmp", "garbage")
	var r: Dictionary = SAVE_IO.read_json("x.json")
	_expect(int(r.get("data", {}).get("v", 0)) == 1, "stale tmp: read ignores .tmp")
	_expect(SAVE_IO.write_json("x.json", {"v": 2}) == OK, "stale tmp: write succeeds")
	_expect(not FileAccess.file_exists(_abs("x.json.tmp")), "stale tmp: .tmp removed after write")
	_expect(int(_parsed("x.json").get("v", 0)) == 2, "stale tmp: main updated")


func test_legacy_file_without_backups() -> void:
	_write_raw("x.json", JSON.stringify({"legacy": true}))
	var r: Dictionary = SAVE_IO.read_json("x.json")
	_expect(r.get("status") == SAVE_IO.OK_STATUS, "legacy: status OK without backups")
	_expect(bool(r.get("data", {}).get("legacy", false)), "legacy: data read")
	SAVE_IO.write_json("x.json", {"legacy": false})
	_expect(bool(_parsed("x.json.bak1").get("legacy", false)), "legacy: first write backs up the old main file")


func test_missing() -> void:
	var r: Dictionary = SAVE_IO.read_json("nope.json")
	_expect(r.get("status") == SAVE_IO.MISSING, "missing: status MISSING")
	_expect(r.get("data") == {}, "missing: data is empty")
	_expect(not SAVE_IO.exists("nope.json"), "missing: exists() is false")


func test_delete_keeps_corrupt_copies() -> void:
	SAVE_IO.write_json("x.json", {"v": 1})
	SAVE_IO.write_json("x.json", {"v": 2})
	_write_raw("x.json", "{broken")
	SAVE_IO.read_json("x.json")  # produces x.json.corrupt-*
	SAVE_IO.delete("x.json")
	_expect(not FileAccess.file_exists(_abs("x.json")), "delete: main removed")
	_expect(not FileAccess.file_exists(_abs("x.json.bak1")), "delete: bak1 removed")
	_expect(not SAVE_IO.exists("x.json"), "delete: exists() is false")
	_expect(_files_starting_with("", "x.json.corrupt-").size() == 1, "delete: corrupt copy kept")


func test_unserializable_write_keeps_original() -> void:
	SAVE_IO.write_json("x.json", {"v": 1})
	var err: Error = SAVE_IO.write_json("x.json", {"bad": Callable(self, "_run")})
	_expect(err != OK, "unserializable: write returns an error")
	_expect(int(_parsed("x.json").get("v", 0)) == 1, "unserializable: main file unchanged")
	_expect(not FileAccess.file_exists(_abs("x.json.tmp")), "unserializable: no .tmp left behind")

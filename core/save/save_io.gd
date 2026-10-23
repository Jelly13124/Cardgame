extends RefCounted

## Atomic JSON save files with rotating backups.
##
## Every save in the game goes through this module. A write never touches the
## live file until the new content has been written to `<file>.tmp` and parsed
## back successfully; the previous versions are kept as `<file>.bak1` and
## `<file>.bak2`. A read falls back to the backups when the live file is
## corrupt, and a corrupt file is always preserved as `<file>.corrupt-<time>`
## instead of being deleted or overwritten.
##
## Pure static helper: no autoloads, no nodes. Tests point `root` at a scratch
## directory so they never touch real profiles.

const OK_STATUS := 0
const MISSING := 1
const RECOVERED := 2
const CORRUPT := 3

const _BACKUP_SUFFIXES := [".bak1", ".bak2"]

## Base directory for every relative save path.
static var root: String = "user://"


static func path(relative: String) -> String:
	return root.path_join(relative)


## True when the live file or any backup exists.
static func exists(relative: String) -> bool:
	var base := path(relative)
	if FileAccess.file_exists(base):
		return true
	for suffix in _BACKUP_SUFFIXES:
		if FileAccess.file_exists(base + suffix):
			return true
	return false


## Writes `data` as JSON. Returns OK, or an error with the live file untouched.
static func write_json(relative: String, data: Variant) -> Error:
	if not _is_json_safe(data):
		return ERR_INVALID_DATA
	var base := path(relative)
	var dir_err := DirAccess.make_dir_recursive_absolute(base.get_base_dir())
	if dir_err != OK and not DirAccess.dir_exists_absolute(base.get_base_dir()):
		return dir_err
	var text := JSON.stringify(data, "  ")
	var tmp := base + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	f.close()
	if _parse_file(tmp) == null:
		DirAccess.remove_absolute(tmp)
		return ERR_FILE_CORRUPT
	_rotate_backups(base)
	var err := DirAccess.rename_absolute(tmp, base)
	if err != OK:
		DirAccess.remove_absolute(tmp)
	return err


## Reads a save. Returns {"status", "data", "source"}; `source` is the relative
## name of the file the data came from ("" when nothing was readable).
static func read_json(relative: String) -> Dictionary:
	var base := path(relative)
	var candidates := [relative]
	for suffix in _BACKUP_SUFFIXES:
		candidates.append(relative + suffix)
	var any_present := false
	var main_corrupt := false
	for i in candidates.size():
		var candidate: String = candidates[i]
		var abs_path := path(candidate)
		if not FileAccess.file_exists(abs_path):
			continue
		any_present = true
		var parsed: Variant = _parse_file(abs_path)
		if parsed != null:
			if main_corrupt:
				_preserve_corrupt(base)
			var status := OK_STATUS if i == 0 else RECOVERED
			return {"status": status, "data": parsed, "source": candidate}
		if i == 0:
			main_corrupt = true
	if not any_present:
		return {"status": MISSING, "data": {}, "source": ""}
	if FileAccess.file_exists(base):
		_preserve_corrupt(base)
	return {"status": CORRUPT, "data": {}, "source": ""}


## Removes the live file, its temp file and backups. Corrupt copies are kept.
static func delete(relative: String) -> void:
	var base := path(relative)
	for suffix in ["", ".tmp"] + _BACKUP_SUFFIXES:
		if FileAccess.file_exists(base + suffix):
			DirAccess.remove_absolute(base + suffix)


# ─── Internals ────────────────────────────────────────────────────────────────


static func _parse_file(abs_path: String) -> Variant:
	var text := FileAccess.get_file_as_string(abs_path)
	if text.is_empty():
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data


static func _rotate_backups(base: String) -> void:
	var bak1: String = base + _BACKUP_SUFFIXES[0]
	var bak2: String = base + _BACKUP_SUFFIXES[1]
	if FileAccess.file_exists(bak1):
		if FileAccess.file_exists(bak2):
			DirAccess.remove_absolute(bak2)
		DirAccess.rename_absolute(bak1, bak2)
	if FileAccess.file_exists(base):
		# A corrupt live file is never rotated into the backups.
		if _parse_file(base) != null:
			DirAccess.rename_absolute(base, bak1)
		else:
			_preserve_corrupt(base)


## Moves the live file aside as `<file>.corrupt-<unix time>[-n]`, never overwriting.
static func _preserve_corrupt(base: String) -> void:
	if not FileAccess.file_exists(base):
		return
	var stamp := "%s.corrupt-%d" % [base, int(Time.get_unix_time_from_system())]
	var target := stamp
	var n := 2
	while FileAccess.file_exists(target):
		target = "%s-%d" % [stamp, n]
		n += 1
	DirAccess.rename_absolute(base, target)


static func _is_json_safe(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_ARRAY:
			for item in value:
				if not _is_json_safe(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if not (key is String or key is StringName or key is int) or not _is_json_safe(value[key]):
					return false
			return true
		TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			return true
	return false

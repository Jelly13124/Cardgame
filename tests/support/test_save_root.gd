extends RefCounted

## Points every save (profile, run, settings) at a per-test scratch directory so
## tests never touch a developer's real profiles, and cleans it up afterwards.
##
##   func _ready() -> void:
##       TEST_SAVE_ROOT.use("my_test")
##   func _exit_tree() -> void:
##       TEST_SAVE_ROOT.release()

const SAVE_IO = preload("res://core/save/save_io.gd")
const BASE := "user://__test__/"


static func use(test_name: String) -> void:
	SAVE_IO.root = BASE.path_join(test_name) + "/"
	_clear_dir(SAVE_IO.root)


static func release() -> void:
	if SAVE_IO.root.begins_with(BASE):
		_clear_dir(SAVE_IO.root)
		DirAccess.remove_absolute(SAVE_IO.root)
	SAVE_IO.root = "user://"


static func _clear_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for d in DirAccess.get_directories_at(path):
		_clear_dir(path.path_join(d))
		DirAccess.remove_absolute(path.path_join(d))

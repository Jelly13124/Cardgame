extends Node

## Run randomness comes from RunManager's seeded streams: the same seed gives
## the same run, the streams survive save/load, old saves get a fresh seed, and
## gameplay code never calls the global RNG.

const RUN_RNG_SET = preload("uid://ealvw2c6utr7")  # res://core/rng/run_rng_set.gd
const SAVE_IO = preload("uid://seo0j510xyq1")  # res://core/save/save_io.gd
const SCAN_ROOTS := ["res://battle_scene", "res://run_system", "res://core"]
const SCAN_SKIP := ["card_animator.gd", "audio_manager.gd"]

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _snapshot() -> Dictionary:
	var encounters: Array = []
	for i in 5:
		encounters.append(RunManager.select_encounter("enemy", 2))
	var drops: Array = []
	for i in 3:
		drops.append(RunManager.roll_shell_drop("common"))
	return {"map": JSON.stringify(RunManager.map_data), "encounters": encounters, "drops": drops,
		"event": str(RunManager.pick_random_event().get("id", ""))}


func _run() -> void:
	RunManager.start_new_run("base:cowboy_bill", [], 0, "testseed01")
	_expect(RunManager.run_seed() == "TESTSEED01", "run seed is canonical: %s" % RunManager.run_seed())
	var first := _snapshot()
	RunManager.start_new_run("base:cowboy_bill", [], 0, "TESTSEED01")
	var second := _snapshot()
	_expect(first["map"] == second["map"], "same seed, same map")
	_expect(first["encounters"] == second["encounters"], "same seed, same encounters")
	_expect(JSON.stringify(first["drops"]) == JSON.stringify(second["drops"]), "same seed, same equipment drops")
	_expect(first["event"] == second["event"], "same seed, same first event")
	RunManager.start_new_run("base:cowboy_bill", [], 0, "OTHERSEED9")
	_expect(_snapshot()["map"] != first["map"], "different seed, different map")

	RunManager.start_new_run("base:cowboy_bill", [], 0)
	_expect(RUN_RNG_SET.is_valid_seed(RunManager.run_seed()) and RunManager.run_seed().length() == 10,
		"empty seed picks a random seed")

	_test_save_round_trip()
	_test_v2_save()
	_test_outside_run()
	_scan_global_rng()

	RunManager.is_run_active = false
	RunManager.clear_run_save()
	if failures.is_empty():
		print("[OK] run rng contract passed")
		get_tree().quit(0)
		return
	push_error("run rng contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _test_save_round_trip() -> void:
	RunManager.start_new_run("base:cowboy_bill", [], 0, "SAVEME0001")
	RunManager.is_run_active = true
	for name in ["rewards", "shuffle", "combat_crits"]:
		for i in 7:
			RunManager.rng(name).next_int(100)
	RunManager.save_run()
	var expected: Array = []
	var twin = RUN_RNG_SET.from_dict(RunManager.run_rng.to_dict())
	for name in ["rewards", "shuffle", "combat_crits"]:
		expected.append(twin.stream(name).next_int(1 << 30))
	RunManager.run_rng = null
	_expect(RunManager.load_run(), "run save loads")
	var actual: Array = []
	for name in ["rewards", "shuffle", "combat_crits"]:
		actual.append(RunManager.rng(name).next_int(1 << 30))
	_expect(actual == expected, "streams continue after save/load")
	_expect(RunManager.run_seed() == "SAVEME0001", "seed survives save/load")


func _test_v2_save() -> void:
	var path: String = RunManager._run_save_path()
	var data: Dictionary = SAVE_IO.read_json(path).get("data", {})
	data["v"] = 2
	data.erase("rng")
	SAVE_IO.write_json(path, data)
	RunManager.run_rng = null
	_expect(RunManager.load_run(), "v2 save without rng loads")
	_expect(RUN_RNG_SET.is_valid_seed(RunManager.run_seed()), "v2 save gets a fresh seed")


func _test_outside_run() -> void:
	RunManager.is_run_active = false
	RunManager.run_rng = null
	var v: int = RunManager.rng("shops").next_int(10)
	_expect(v >= 0 and v < 10, "rng works outside a run")
	_expect(RunManager.run_rng == null, "outside-run draws do not create the run set")


func _scan_global_rng() -> void:
	var re := RegEx.create_from_string("(?<![.\\w])(randi|randf|randi_range|randf_range|randomize)\\(|\\.shuffle\\(\\)|\\.pick_random\\(\\)")
	var files: Array[String] = []
	for root in SCAN_ROOTS:
		_collect(root, files)
	for path in files:
		if path.get_file() in SCAN_SKIP or path.begins_with("res://core/rng/"):
			continue
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var line: String = lines[i]
			if line.strip_edges().begins_with("#") or line.contains("# rng-ok:"):
				continue
			if re.search(line.get_slice("#", 0)) != null:
				failures.append("%s:%d uses the global RNG" % [path, i + 1])


func _collect(dir_path: String, out: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir_path):
		_collect(dir_path.path_join(sub), out)
	for f in DirAccess.get_files_at(dir_path):
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))

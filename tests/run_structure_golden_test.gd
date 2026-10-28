extends Node

## Acts, maps and encounters as data change nothing: for two seeds and acts
## 1–3, the generated maps, the encounter picks and the act multipliers equal
## the golden recorded from the code before (tests/fixtures/run_structure_golden.json).

const GOLDEN := "res://tests/fixtures/run_structure_golden.json"  # path-ok: data fixture read as text

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	for seed_string in golden:
		RunManager.start_new_run("base:cowboy_bill", [], 0, seed_string)
		for act in [1, 2, 3]:
			var want: Dictionary = golden[seed_string][str(act)]
			RunManager.current_act = act
			RunManager.generate_map(RunManager.FLOORS_PER_ACT, 4)
			var nodes: Array = []
			for n in RunManager.map_data:
				nodes.append([n.id, n.type, Array(n.children)])
			_expect(_same(nodes, want["map"]), "%s act %d map unchanged" % [seed_string, act])
			var picks: Array = []
			for f in range(RunManager.FLOORS_PER_ACT):
				for t in ["enemy", "unknown", "elite", "boss"]:
					picks.append([f, t, Array(RunManager.select_encounter(t, f))])
			_expect(_same(picks, want["encounters"]), "%s act %d encounter picks unchanged" % [seed_string, act])
			_expect(RunManager.scale_enemy_hp(100, "base:scrap_rat") == int(want["hp"]), "act %d HP multiplier unchanged" % act)
			_expect(RunManager.scale_enemy_damage(10, "base:scrap_rat") == int(want["dmg"]), "act %d damage multiplier unchanged" % act)
		RunManager.is_run_active = false
		RunManager.clear_run_save()
	if failures.is_empty():
		print("[OK] run structure golden passed")
		get_tree().quit(0)
		return
	push_error("run structure golden failed: %s" % "; ".join(failures))
	get_tree().quit(1)


## Equal after a JSON round trip (the fixture's numbers parse as floats).
static func _same(got: Variant, want: Variant) -> bool:
	return JSON.stringify(JSON.parse_string(JSON.stringify(got))) == JSON.stringify(want)

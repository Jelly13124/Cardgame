extends Node

## A fourth act is data alone (S5-01): a content dir adds an act, an
## encounter and a run configuration listing four acts — no code changes — and
## the run counts four acts, builds act 4's map, picks its encounters and boss
## and scales its enemies.

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const ACTS = preload("uid://c7qo73muxvmd4")  # res://core/run/acts.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	MODEL_DB.inject_dir("res://tests/fixtures/act4_mod/", "testmod")
	_expect(MODEL_DB.load_errors().is_empty(), "fixture loads cleanly: %s" % [MODEL_DB.load_errors()])
	ACTS.active_run = "testmod:four"
	RunManager.start_new_run("base:cowboy_bill", [], 0, "FOURTHACT1")
	_expect(RunManager.acts_total() == 4, "the run has four acts (%d)" % RunManager.acts_total())
	for _i in range(3):
		_expect(RunManager.advance_act(), "advancing to the next act")
	_expect(RunManager.current_act == 4 and RunManager.is_final_act(), "act 4 is the final act")
	_expect(RunManager.map_data.size() > 0 and RunManager.map_data[RunManager.map_data.size() - 1].type == "boss", "act 4's map ends in its boss")
	_expect(RunManager.current_act_boss() == "base:junkyard_tyrant", "act 4's boss comes from its data")
	_expect(RunManager.select_encounter("enemy", 0) == ["base:rust_brute", "base:rust_brute"], "act 4's own encounter is picked on floor 0")
	_expect(RunManager.scale_enemy_hp(100, "base:scrap_rat") == 175, "act 4's HP multiplier applies")
	_expect(ACTS.extract_rewards(3) != {} and ACTS.extract_rewards(4) == {}, "act 3 now offers extraction; act 4 ends the run")
	ACTS.active_run = ACTS.ACTIVE_RUN
	RunManager.is_run_active = false
	RunManager.clear_run_save()
	if failures.is_empty():
		print("[OK] fourth act passed")
		get_tree().quit(0)
		return
	push_error("fourth act failed: %s" % "; ".join(failures))
	get_tree().quit(1)

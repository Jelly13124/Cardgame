extends Node

## Bounty progress listens to typed run events: each emitter advances its
## objective exactly once, and no flow code reports bounty strings any more.

const BOUNTY_TRACKER = preload("uid://dufyeowl6elem")  # res://core/listeners/bounty_tracker.gd
const DATA_VALIDATOR = preload("uid://bdhbhkhs5p4v3")  # res://core/content/data_validator.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var log: Array = []
	var tracker = BOUNTY_TRACKER.new()
	tracker.progress = func(kind: String, amount: int) -> void: log.append([kind, amount])
	var saved: Array = RunManager.run_listeners
	RunManager.run_listeners = [tracker]
	RunManager.is_run_active = true

	RunManager.enemy_killed(null)
	RunManager.combat_won("elite")
	RunManager.combat_won("boss")
	RunManager.combat_won("enemy")
	RunManager.card_played({"type": "attack"})
	RunManager.card_played({"type": "skill"})
	RunManager.gold_earned(7)
	RunManager.card_upgraded({"card_id": "base:strike"})
	RunManager.run_extracted()
	_expect(log == [
		["kill_enemies", 1], ["kill_elites", 1], ["kill_boss", 1], ["play_attack_cards", 1],
		["earn_gold", 7], ["upgrade_cards", 1], ["extract_alive", 1],
	], "each event advances its objective once: %s" % [log])
	_expect(DATA_VALIDATOR.allowed_bounty_objectives() == BOUNTY_TRACKER.OBJECTIVES, "validator objectives come from the tracker")

	log.clear()
	RunManager.is_run_active = false
	RunManager.enemy_killed(null)
	_expect(log.is_empty(), "no progress outside a run")
	RunManager.run_listeners = saved

	var stray: Array = []
	for root in ["res://battle_scene", "res://run_system", "res://core"]:
		_scan(root, stray)
	_expect(stray.is_empty(), "no bounty_event( calls remain: %s" % [stray])

	if failures.is_empty():
		print("[OK] bounty events passed")
		get_tree().quit(0)
		return
	push_error("bounty events failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _scan(dir_path: String, out: Array) -> void:
	for sub in DirAccess.get_directories_at(dir_path):
		_scan(dir_path.path_join(sub), out)
	for f in DirAccess.get_files_at(dir_path):
		if f.ends_with(".gd") and FileAccess.get_file_as_string(dir_path.path_join(f)).contains("bounty_event("):
			out.append(dir_path.path_join(f))

extends Node

## Encounter strength (core/run/encounters.gd): the summed max HP of an
## encounter's monsters against the mean of its floor band — under 85% is weak,
## over 115% is strong, otherwise normal; anything unknown is normal.

const ENCOUNTERS = preload("uid://mlx3xqfjwlpq")  # res://core/run/encounters.gd
const ACTS = preload("uid://c7qo73muxvmd4")  # res://core/run/acts.gd
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var act: Dictionary = ACTS.act(1)
	var seen := {}
	for floor_idx in [1, 3, 5, 9]:
		var pool: Array = ENCOUNTERS.band_pool(act, floor_idx)
		var hp := {}
		var total := 0.0
		for enc in pool:
			var sum := 0
			for m in ENCOUNTERS.monsters_of(str(enc)):
				sum += int(MODEL_DB.data("monster", m).get("max_health", 0))
			hp[enc] = sum
			total += sum
		var mean := total / float(pool.size())
		for enc in pool:
			var want := "normal"
			if hp[enc] < mean * 0.85:
				want = "weak"
			elif hp[enc] > mean * 1.15:
				want = "strong"
			var got: String = ENCOUNTERS.strength(act, floor_idx, str(enc))
			_expect(got == want, "floor %d %s is %s (got %s)" % [floor_idx, enc, want, got])
			seen[got] = true
	_expect(seen.size() >= 2, "act 1 bands produce at least two strengths (%s)" % [seen.keys()])
	_expect(ENCOUNTERS.strength(act, 1, "base:no_such") == "normal", "unknown encounter is normal")
	_expect(ENCOUNTERS.monsters_of("base:scrap_rat_pair").size() == 2, "a pair encounter has two monsters")
	if failures.is_empty():
		print("[OK] encounter strength passed")
		get_tree().quit(0)
		return
	push_error("encounter strength failed: %s" % "; ".join(failures))
	get_tree().quit(1)

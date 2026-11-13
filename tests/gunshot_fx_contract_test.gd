extends Node

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var source := FileAccess.get_file_as_string("res://ui/battle/gunshot_fx.gd")  # path-ok: timing contract reads source text to pin authored duration
	_expect(
		source.find("const PLAYER_GUNSHOT_FLASH_SECONDS := 0.16") >= 0,
		"muzzle flash has a visible 0.16 second authored window"
	)
	_expect(
		source.find("create_timer(PLAYER_GUNSHOT_FLASH_SECONDS)") >= 0,
		"muzzle flash lifetime is independent from the wind-up"
	)
	_expect(
		source.find("tween_property(bullet, \"global_position\", hit, 0.16)") >= 0,
		"bullet flight remains 0.16 seconds"
	)
	_expect(
		source.find("await flight.finished") >= 0 and source.find("queue_free()") >= 0,
		"bullet still completes before contact feedback continues"
	)
	if failures.is_empty():
		print("[OK] gunshot timing contract")
		get_tree().quit(0)
		return
	push_error("gunshot timing contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)

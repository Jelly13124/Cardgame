extends Node

const TRANSITION_SCRIPT = preload("res://run_system/core/scene_transition.gd")
const TRANSITION_SCRIPT_PATH := "res://run_system/core/scene_transition.gd"
const THREAD_LOAD_FIXTURE := "res://tests/ui_sts2_hud_contract_test.tscn"

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var transition := TRANSITION_SCRIPT.new()
	add_child(transition)
	await get_tree().process_frame

	_test_minimal_black_overlay(transition)
	await _test_blackout_motion(transition)
	await _test_threaded_scene_load(transition)

	transition.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("[OK] STS2 scene transition contract passed")
		get_tree().quit(0)
		return
	push_error("STS2 scene transition contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _test_minimal_black_overlay(transition: CanvasLayer) -> void:
	_expect(transition.get_child_count() == 1, "transition only builds one blackout overlay")
	_expect(
		transition.find_children("*", "TextureRect", true, false).is_empty(),
		"transition removes the old full-screen loading illustration"
	)
	_expect(
		transition.find_children("*", "Label", true, false).is_empty(),
		"transition removes loading copy and spinner glyphs"
	)
	var overlay := transition.get_child(0) as ColorRect if transition.get_child_count() > 0 else null
	_expect(overlay != null, "transition keeps a ColorRect blackout overlay")
	if overlay:
		_expect(overlay.color == Color(0, 0, 0, 0), "blackout overlay starts transparent black")


func _test_blackout_motion(transition: CanvasLayer) -> void:
	_expect(transition.has_method("_begin_transition"), "transition can atomically enter its busy state")
	_expect(transition.has_method("_fade_to_black"), "transition exposes the blackout motion")
	_expect(transition.has_method("_fade_from_black"), "transition exposes the reveal motion")
	if not (
		transition.has_method("_begin_transition")
		and transition.has_method("_fade_to_black")
		and transition.has_method("_fade_from_black")
	):
		return

	var started: bool = transition.call("_begin_transition")
	var duplicate_started: bool = transition.call("_begin_transition")
	_expect(started, "first transition request acquires the blackout overlay")
	_expect(not duplicate_started, "a second transition request is rejected while busy")
	await transition.call("_fade_to_black")
	var overlay := transition.get_child(0) as ColorRect
	_expect(is_equal_approx(overlay.color.a, 1.0), "blackout motion reaches opaque black")
	_expect(overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "blackout blocks input")
	await transition.call("_fade_from_black")
	_expect(is_equal_approx(overlay.color.a, 0.0), "reveal motion returns to transparent")
	_expect(not overlay.visible, "reveal hides the dormant overlay")
	_expect(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "reveal restores input")


func _test_threaded_scene_load(transition: CanvasLayer) -> void:
	var source := FileAccess.get_file_as_string(TRANSITION_SCRIPT_PATH)
	_expect(
		source.contains("ResourceLoader.load_threaded_request"),
		"path transitions request scenes on Godot's background loader"
	)
	_expect(
		source.contains("ResourceLoader.load_threaded_get_status"),
		"path transitions poll threaded loading without blocking the fade"
	)
	_expect(not source.contains("loading_bg.png"), "transition no longer references loading_bg.png")
	_expect(not source.contains("loading_spinner.png"), "transition no longer references loading_spinner.png")

	_expect(
		transition.has_method("_load_scene_threaded"),
		"transition exposes its threaded scene-loading coroutine"
	)
	if transition.has_method("_load_scene_threaded"):
		var packed = await transition.call("_load_scene_threaded", THREAD_LOAD_FIXTURE)
		_expect(packed is PackedScene, "threaded loader returns the requested PackedScene")

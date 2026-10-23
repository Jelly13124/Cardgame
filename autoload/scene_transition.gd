## SceneTransition (autoload) — STS2-style scene swaps.
##
## Core-loop transitions deliberately avoid a separate loading screen: the current
## scene fades to black, the scene swap happens behind that blackout, and the next
## scene fades in once it has entered the tree. Path-based swaps use Godot's
## threaded ResourceLoader so the blackout tween can keep rendering while resource
## dependencies are read from disk.
##
## Use `SceneTransition.change_to(path)` or `.change_to_packed(packed)` instead of
## calling `get_tree().change_scene_to_*()` directly. The overlay lives in this
## autoload CanvasLayer, so it survives replacement of the current scene.
extends CanvasLayer

const FADE_OUT := 0.18
const FADE_IN := 0.24

var _rect: ColorRect
var _busy := false


func _ready() -> void:
	layer = 250  # above every in-scene CanvasLayer
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep fading while the tree is paused
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.visible = false
	add_child(_rect)


## Fade to black while the target scene loads in the background, swap, then reveal.
func change_to(path: String) -> void:
	if not _begin_transition():
		return

	# Start I/O before the fade so short loads disappear entirely behind the motion.
	var request_error := ResourceLoader.load_threaded_request(path, "PackedScene")
	var request_started := request_error == OK or request_error == ERR_BUSY
	await _fade_to_black()
	var packed := await _load_scene_threaded(path, request_started)
	if packed == null:
		push_error("SceneTransition: failed to load scene: %s (error %d)" % [path, request_error])
		await _fade_from_black()
		return

	var change_error := get_tree().change_scene_to_packed(packed)
	if change_error != OK:
		push_error("SceneTransition: failed to change scene: %s (error %d)" % [path, change_error])
		await _fade_from_black()
		return
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_from_black()


## Same visual transition for a PackedScene that is already resident in memory.
func change_to_packed(packed: PackedScene) -> void:
	await _run(func() -> void: get_tree().change_scene_to_packed(packed))


## Load a PackedScene without blocking the main thread. When `request_started` is
## true, the caller already queued the request so loading overlaps the fade-out.
func _load_scene_threaded(path: String, request_started := false) -> PackedScene:
	if not request_started:
		var request_error := ResourceLoader.load_threaded_request(path, "PackedScene")
		if request_error != OK and request_error != ERR_BUSY:
			return null

	while true:
		var status := ResourceLoader.load_threaded_get_status(path)
		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				await get_tree().process_frame
			ResourceLoader.THREAD_LOAD_LOADED:
				return ResourceLoader.load_threaded_get(path) as PackedScene
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				return null
			_:
				return null
	return null


## Acquire the persistent blackout overlay. Re-entrant requests are ignored so a
## double-click cannot stack scene swaps.
func _begin_transition() -> bool:
	if _busy:
		return false
	_busy = true
	_rect.visible = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	return true


func _fade_to_black() -> void:
	var fade_out := create_tween()
	fade_out.tween_property(_rect, "color:a", 1.0, FADE_OUT).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	await fade_out.finished


func _fade_from_black() -> void:
	var fade_in := create_tween()
	fade_in.tween_property(_rect, "color:a", 0.0, FADE_IN).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	await fade_in.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.visible = false
	_busy = false


## Shared fade-out → swap → fade-in for already-loaded PackedScenes.
func _run(swap: Callable) -> void:
	if not _begin_transition():
		return
	await _fade_to_black()
	swap.call()
	# Let the new scene enter the tree and settle before revealing it.
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_from_black()

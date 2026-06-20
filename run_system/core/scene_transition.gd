## SceneTransition (autoload) — fade-to-black scene swaps so screens cross-fade
## instead of hard-cutting. Use `SceneTransition.change_to(path)` or
## `.change_to_packed(packed)` in place of `get_tree().change_scene_to_*()`.
## Reference directly as `SceneTransition` (autoload convention; ADR-0006).
##
## The fade overlay is a CanvasLayer child of root, so it survives the scene swap
## and hides the hard cut underneath. Tweens are bound to THIS node (not the
## SceneTree) on purpose — a SceneTree-bound tween would be killed by the swap.
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


## Fade to black, change to the scene at `path`, fade back in.
func change_to(path: String) -> void:
	await _run(func() -> void: get_tree().change_scene_to_file(path))


## Same as change_to() for a preloaded PackedScene.
func change_to_packed(packed: PackedScene) -> void:
	await _run(func() -> void: get_tree().change_scene_to_packed(packed))


## Shared fade-out → swap → fade-in. Re-entrant calls are ignored so a double-click
## (or a transition firing mid-transition) can't stack scene swaps.
func _run(swap: Callable) -> void:
	if _busy:
		return
	_busy = true
	_rect.visible = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP  # eat input during the fade
	var fade_out := create_tween()
	fade_out.tween_property(_rect, "color:a", 1.0, FADE_OUT).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	await fade_out.finished
	swap.call()
	# Let the new scene enter the tree + run a frame before we reveal it.
	await get_tree().process_frame
	await get_tree().process_frame
	var fade_in := create_tween()
	fade_in.tween_property(_rect, "color:a", 0.0, FADE_IN).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	await fade_in.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.visible = false
	_busy = false

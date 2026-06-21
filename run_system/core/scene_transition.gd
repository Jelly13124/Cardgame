## SceneTransition (autoload) — fade-to-black scene swaps so screens cross-fade
## instead of hard-cutting. Use `SceneTransition.change_to(path)` or
## `.change_to_packed(packed)` in place of `get_tree().change_scene_to_*()`.
## Reference directly as `SceneTransition` (autoload convention; ADR-0006).
##
## The fade overlay is a CanvasLayer child of root, so it survives the scene swap
## and hides the hard cut underneath. Tweens are bound to THIS node (not the
## SceneTree) on purpose — a SceneTree-bound tween would be killed by the swap.
##
## During the black hold a loading indicator (spinner + "加载中") fills the screen
## so a slow load (the battle scene preloads its card pool) isn't a dead black
## frame. The spinner uses the Codex art at SPINNER_TEX_PATH when present, else a
## rotating gear glyph. NOTE: a synchronous scene load blocks the main thread, so
## the spinner can't smoothly animate *through* the heaviest instantiation frame —
## it still gives the screen a clear "loading" state instead of pure black.
extends CanvasLayer

const FADE_OUT := 0.18
const FADE_IN := 0.24
const SPINNER_TEX_PATH := "res://run_system/assets/images/ui/loading_spinner.png"
const LOADING_BG_PATH := "res://run_system/assets/images/ui/loading_bg.png"

var _rect: ColorRect
var _bg: TextureRect
var _loading: Control
var _spinner: Control
var _spin_tween: Tween
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
	_build_bg()
	_build_loading()


## Optional full-screen loading-screen art behind the spinner (dimmed so the
## spinner + text read on top). Falls back to plain black when the Codex art at
## LOADING_BG_PATH is absent. Sits above the black rect, below the spinner.
func _build_bg() -> void:
	_bg = TextureRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_bg.modulate = Color(0.82, 0.82, 0.82)  # lightly dim the backdrop so the spinner pops
	_bg.visible = false
	if ResourceLoader.exists(LOADING_BG_PATH):
		_bg.texture = load(LOADING_BG_PATH)
	add_child(_bg)


## Centered spinner + label, on top of the black rect, hidden until a load is in
## flight. Its own visibility is independent of the rect's fade alpha.
func _build_loading() -> void:
	_loading = Control.new()
	_loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading.visible = false
	add_child(_loading)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading.add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	# Spinner: Codex art (rotated) if delivered, else a rotating gear glyph.
	if ResourceLoader.exists(SPINNER_TEX_PATH):
		var tex := TextureRect.new()
		tex.texture = load(SPINNER_TEX_PATH)
		tex.custom_minimum_size = Vector2(96, 96)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tex.pivot_offset = Vector2(48, 48)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_spinner = tex
	else:
		var glyph := Label.new()
		glyph.text = "⚙"
		glyph.custom_minimum_size = Vector2(96, 96)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.add_theme_font_size_override("font_size", 72)
		glyph.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
		glyph.pivot_offset = Vector2(48, 48)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_spinner = glyph
	box.add_child(_spinner)

	var label := Label.new()
	label.text = "加载中…" if Settings.language == "zh" else "Loading…"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.86, 0.78, 0.60))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("outline_size", 3)
	box.add_child(label)


func _start_spinner() -> void:
	if _bg.texture != null:
		_bg.visible = true
	_loading.visible = true
	if _spin_tween and _spin_tween.is_valid():
		_spin_tween.kill()
	_spinner.rotation = 0.0
	_spin_tween = create_tween().set_loops()
	_spin_tween.tween_property(_spinner, "rotation", TAU, 0.9).from(0.0)


func _stop_spinner() -> void:
	if _spin_tween and _spin_tween.is_valid():
		_spin_tween.kill()
	_loading.visible = false
	_bg.visible = false


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
	# Screen is black — show the loading indicator and render a frame so it's on
	# screen before the (blocking) scene swap.
	_start_spinner()
	await get_tree().process_frame
	swap.call()
	# Let the new scene enter the tree + run a frame before we reveal it.
	await get_tree().process_frame
	await get_tree().process_frame
	_stop_spinner()
	var fade_in := create_tween()
	fade_in.tween_property(_rect, "color:a", 0.0, FADE_IN).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	await fade_in.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.visible = false
	_busy = false

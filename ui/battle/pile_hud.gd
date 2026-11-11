## Icon and count feedback; the owning pile/button keeps a stable input rectangle.
extends Control

const T = preload("uid://dfcqloc58bvde")  # res://ui/common/theme/wasteland_theme.gd
const IN_SECONDS := 0.5
const OUT_SECONDS := 0.5
const HIDDEN_POSITION := Vector2(0, 180)

var _visuals: Control
var _transition: Tween
var _count_home := Vector2.ZERO
var _transitioning := false
var _presented := true
var _hovered := false
var _count: Label
var _motion: Tween
var _external_count := false


func configure(input: Control, kind: String, count_size: int = 26, framework_count: Label = null) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pivot_offset = Vector2(40, 40)
	z_index = 25
	_visuals = Control.new()
	_visuals.name = "Visuals"
	_visuals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visuals.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_visuals)
	var icon := TextureRect.new()
	icon.name = "PileIcon"
	icon.texture = T.combat_tex(kind)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visuals.add_child(icon)
	_external_count = framework_count != null
	_count = framework_count if _external_count else Label.new()
	_count.name = "CountLabel"
	_count.pivot_offset = Vector2(40, 40)
	if not _external_count:
		_count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count.add_theme_font_override("font", T.combat_font(700))
	_count.add_theme_font_size_override("font_size", count_size)
	_count.add_theme_color_override("font_color", T.COMBAT_HP_TEXT)
	_count.add_theme_color_override("font_outline_color", T.COMBAT_HP_OUTLINE)
	_count.add_theme_constant_override("outline_size", 12)
	if not _external_count:
		_visuals.add_child(_count)
	_count_home = _count.position
	input.mouse_entered.connect(_on_entered)
	input.mouse_exited.connect(_on_exited)
	input.focus_entered.connect(_on_entered)
	input.focus_exited.connect(_on_exited)


func set_count(count: int) -> void:
	_count.text = str(count)


func _on_entered() -> void:
	_hovered = true
	if _presented and not _transitioning:
		_animate_scale(1.25, 0.05)


func _on_exited() -> void:
	_hovered = false
	_animate_scale(1.0, 0.5)


func _animate_scale(target: float, seconds: float) -> void:
	if _motion and _motion.is_valid():
		_motion.kill()
	_motion = create_tween().set_parallel(true)
	_motion.tween_property(self, "scale", Vector2.ONE * target, seconds).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if _external_count:
		_motion.tween_property(_count, "scale", Vector2.ONE * target, seconds).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func anim_in() -> void:
	_begin_transition(true)


func anim_out() -> void:
	_begin_transition(false)


func _begin_transition(entering: bool) -> void:
	if _transition and _transition.is_valid():
		_transition.kill()
	if _motion and _motion.is_valid():
		_motion.kill()
	_transitioning = true
	_presented = entering
	scale = Vector2.ONE
	if _external_count:
		_count.scale = Vector2.ONE
	if entering:
		_visuals.position = HIDDEN_POSITION
		if _external_count:
			_count.position = _count_home + HIDDEN_POSITION
	var destination := Vector2.ZERO if entering else HIDDEN_POSITION
	var seconds := IN_SECONDS if entering else OUT_SECONDS
	var transition := Tween.TRANS_EXPO if entering else Tween.TRANS_BACK
	var easing := Tween.EASE_OUT if entering else Tween.EASE_IN
	_transition = create_tween().set_parallel(true).set_trans(transition).set_ease(easing)
	_transition.tween_property(_visuals, "position", destination, seconds)
	if _external_count:
		_transition.tween_property(_count, "position", _count_home + destination, seconds)
	_transition.finished.connect(_finish_transition)


func _finish_transition() -> void:
	_transitioning = false
	if _presented and _hovered:
		_animate_scale(1.25, 0.05)

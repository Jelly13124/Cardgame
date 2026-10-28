extends Node2D

## Targeting arrow after STS2's NTargetingArrow: 19 chevron segments along a
## quadratic curve from the card to the cursor, growing toward the head. White
## while aiming at nothing; enemy red with a springy head when over a target.
## The system cursor is hidden while aiming and always restored on stop.
## Drawn in code (flat fill + dark outline) until dedicated art exists.

const SEGMENT_COUNT := 19
const ENEMY_COLOR := Color("E61E1B")
const IDLE_COLOR := Color.WHITE
const OUTLINE_COLOR := Color(0.06, 0.03, 0.02, 0.85)
## Chevron size at scale 1; segments are drawn at 0.28 → 0.42 of it.
const SEGMENT_SIZE := Vector2(110.0, 72.0)
const SEGMENT_SCALE_START := 0.28
const SEGMENT_SCALE_END := 0.42
const HEAD_SIZE := Vector2(58.0, 48.0)
const HEAD_IDLE_SCALE := 0.95
const HEAD_HOVER_SCALE := 1.05

var origin: Vector2 = Vector2.ZERO
var is_active: bool = false
var target_is_valid: bool = false
## True while this arrow has hidden the system cursor (it must restore it).
var cursor_hidden: bool = false

var _segments := PackedVector2Array()
var _segment_angles := PackedFloat32Array()
var _segment_scales := PackedFloat32Array()
var _head_position := Vector2.ZERO
var _head_angle := 0.0
var _head_scale := HEAD_IDLE_SCALE
var _head_tween: Tween


func _ready() -> void:
	z_index = 400
	z_as_relative = false
	set_process(true)


func _exit_tree() -> void:
	_restore_cursor()


func start(from_position: Vector2) -> void:
	origin = from_position
	is_active = true
	target_is_valid = false
	_head_scale = HEAD_IDLE_SCALE
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	cursor_hidden = true
	_update_curve(get_global_mouse_position())
	queue_redraw()


func stop() -> void:
	is_active = false
	target_is_valid = false
	visible = false
	if _head_tween:
		_head_tween.kill()
	_head_scale = HEAD_IDLE_SCALE
	_restore_cursor()
	queue_redraw()


func set_target_valid(value: bool) -> void:
	if target_is_valid == value:
		return
	target_is_valid = value
	if _head_tween:
		_head_tween.kill()
	if value and is_inside_tree():
		_head_tween = create_tween()
		_head_tween.tween_method(_set_head_scale, _head_scale, HEAD_HOVER_SCALE, 1.0).set_ease(
			Tween.EASE_OUT
		).set_trans(Tween.TRANS_ELASTIC)
	else:
		_head_scale = HEAD_HOVER_SCALE if value else HEAD_IDLE_SCALE
	queue_redraw()


func current_color() -> Color:
	return ENEMY_COLOR if target_is_valid else IDLE_COLOR


## Global positions of the 19 segments from the last update.
func segment_positions() -> PackedVector2Array:
	return _segments


func head_position() -> Vector2:
	return _head_position


func head_scale() -> float:
	return _head_scale


func _process(_delta: float) -> void:
	if is_active:
		_update_curve(get_global_mouse_position())
		queue_redraw()


## STS2 UpdateArrowPosition: the control point sits behind the start, and for a
## card low on screen it lies past the head so the arrow arcs up and over.
func _update_curve(target: Vector2) -> void:
	var from := origin
	var control := Vector2.ZERO
	control.x = from.x - (target.x - from.x) * 0.25
	if from.y > get_viewport_rect().size.y * 0.5:
		control.y = target.y + (target.y - from.y) * 0.5
	else:
		control.y = target.y * 0.75 + from.y * 0.25
	var direction := (target - control).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	_head_position = target
	_head_angle = direction.angle()
	var end := target - direction * HEAD_SIZE.x * 0.55

	_segments.resize(SEGMENT_COUNT)
	_segment_angles.resize(SEGMENT_COUNT)
	_segment_scales.resize(SEGMENT_COUNT)
	for i in range(SEGMENT_COUNT):
		_segments[i] = _quadratic(from, control, end, float(i) / 20.0)
		_segment_scales[i] = minf(
			lerpf(SEGMENT_SCALE_START, SEGMENT_SCALE_END, float(i) * 2.0 / float(SEGMENT_COUNT)),
			SEGMENT_SCALE_END
		)
	for i in range(SEGMENT_COUNT):
		var ahead: Vector2 = _segments[i + 1] if i + 1 < SEGMENT_COUNT else end
		_segment_angles[i] = (ahead - _segments[i]).angle()


func _draw() -> void:
	if not is_active or _segments.is_empty():
		return
	var color := current_color()
	for i in range(SEGMENT_COUNT):
		var chevron := _chevron(SEGMENT_SIZE * _segment_scales[i])
		_draw_shape(chevron, _segments[i] - global_position, _segment_angles[i], color)
	var head := _head_shape(HEAD_SIZE * _head_scale)
	_draw_shape(head, _head_position - global_position, _head_angle, color)


func _draw_shape(points: PackedVector2Array, at: Vector2, angle: float, color: Color) -> void:
	var placed := PackedVector2Array()
	for p in points:
		placed.append(at + p.rotated(angle))
	draw_colored_polygon(placed, color)
	placed.append(placed[0])
	draw_polyline(placed, OUTLINE_COLOR, 3.0, true)


## A forward-pointing chevron centred on the origin (pointing along +x).
func _chevron(s: Vector2) -> PackedVector2Array:
	return PackedVector2Array(
		[
			Vector2(-s.x * 0.5, -s.y * 0.5),
			Vector2(s.x * 0.05, -s.y * 0.5),
			Vector2(s.x * 0.5, 0.0),
			Vector2(s.x * 0.05, s.y * 0.5),
			Vector2(-s.x * 0.5, s.y * 0.5),
			Vector2(-s.x * 0.05, 0.0),
		]
	)


## The arrow head, tip at the origin (the cursor), pointing along +x.
func _head_shape(s: Vector2) -> PackedVector2Array:
	return PackedVector2Array(
		[
			Vector2.ZERO,
			Vector2(-s.x, -s.y * 0.5),
			Vector2(-s.x * 0.68, 0.0),
			Vector2(-s.x, s.y * 0.5),
		]
	)


func _set_head_scale(value: float) -> void:
	_head_scale = value
	queue_redraw()


func _restore_cursor() -> void:
	if cursor_hidden:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		cursor_hidden = false


static func _quadratic(p0: Vector2, control: Vector2, p1: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * p0 + 2.0 * u * t * control + t * t * p1

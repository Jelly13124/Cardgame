extends Node2D

var origin: Vector2 = Vector2.ZERO
var is_active: bool = false
var target_is_valid: bool = false

const COLOR_IDLE := Color(0.28, 0.95, 0.36, 0.9)
const COLOR_VALID := Color(1.0, 0.18, 0.12, 0.96)
const COLOR_OUTLINE := Color(0.04, 0.0, 0.0, 0.62)
const COLOR_HIGHLIGHT := Color(1.0, 0.96, 0.78, 0.78)

var line_width: float = 6.0
var arrow_size: float = 26.0
var segments: int = 42
var max_bend: float = 105.0
var _time: float = 0.0


func _ready() -> void:
	z_index = 400
	z_as_relative = false
	set_process(true)


func start(from_position: Vector2) -> void:
	origin = from_position
	is_active = true
	target_is_valid = false
	visible = true
	queue_redraw()


func stop() -> void:
	is_active = false
	target_is_valid = false
	visible = false
	queue_redraw()


func set_target_valid(value: bool) -> void:
	if target_is_valid == value:
		return
	target_is_valid = value
	queue_redraw()


func _process(delta: float) -> void:
	if is_active:
		_time += delta
		queue_redraw()


func _draw() -> void:
	if not is_active:
		return

	var mouse_pos = get_global_mouse_position()
	var start_pos = origin - global_position
	var end_pos = mouse_pos - global_position
	var points = _build_curve(start_pos, end_pos)
	var main_color = _main_color()

	if points.size() >= 2:
		draw_polyline(points, COLOR_OUTLINE, line_width + 8.0, true)
		draw_polyline(points, main_color, line_width, true)
		_draw_flow_markers(points)
		_draw_arrowhead(points, main_color)

	_draw_target_ring(end_pos, main_color)


func _main_color() -> Color:
	return COLOR_VALID if target_is_valid else COLOR_IDLE


func _build_curve(start_pos: Vector2, end_pos: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var delta = end_pos - start_pos
	var distance = start_pos.distance_to(end_pos)

	if distance < 1.0:
		points.append(start_pos)
		points.append(end_pos)
		return points

	var curve_normal = Vector2(-delta.y, delta.x).normalized()
	if curve_normal.y > 0.0:
		curve_normal *= -1.0

	var horizontal_factor = clampf(abs(delta.x) / 520.0, 0.0, 1.0)
	var upward_factor = clampf((start_pos.y - end_pos.y) / 460.0, 0.0, 1.0)
	var bend = clampf(distance * lerpf(0.08, 0.18, horizontal_factor), 12.0, max_bend)
	bend *= lerpf(1.0, 0.42, upward_factor)

	var control_a = start_pos.lerp(end_pos, 0.36) + curve_normal * bend
	var control_b = start_pos.lerp(end_pos, 0.74) + curve_normal * bend * 0.75

	for i in range(segments + 1):
		var t = float(i) / float(segments)
		points.append(_cubic_bezier(start_pos, control_a, control_b, end_pos, t))

	return points


func _draw_flow_markers(points: PackedVector2Array) -> void:
	var gap = 5
	var offset = int(_time * 18.0) % gap
	for i in range(offset, points.size(), gap):
		var dot_color = COLOR_HIGHLIGHT
		dot_color.a = 0.35 + 0.35 * float(i) / float(max(points.size(), 1))
		draw_circle(points[i], 2.2, dot_color)


func _draw_arrowhead(points: PackedVector2Array, color: Color) -> void:
	if points.size() < 2:
		return

	var tip = points[points.size() - 1]
	var prev = points[points.size() - 2]
	var arrow_dir = (tip - prev).normalized()
	var arrow_perp = Vector2(-arrow_dir.y, arrow_dir.x)

	var p1 = tip
	var p2 = tip - arrow_dir * arrow_size + arrow_perp * arrow_size * 0.5
	var p3 = tip - arrow_dir * arrow_size - arrow_perp * arrow_size * 0.5
	var outline_points = PackedVector2Array(
		[
			tip + arrow_dir * 4.0,
			tip - arrow_dir * (arrow_size + 7.0) + arrow_perp * arrow_size * 0.68,
			tip - arrow_dir * (arrow_size + 7.0) - arrow_perp * arrow_size * 0.68,
		]
	)

	draw_polygon(outline_points, PackedColorArray([COLOR_OUTLINE, COLOR_OUTLINE, COLOR_OUTLINE]))
	draw_polygon(PackedVector2Array([p1, p2, p3]), PackedColorArray([color, color, color]))


func _draw_target_ring(end_pos: Vector2, color: Color) -> void:
	var pulse = (sin(_time * 7.0) + 1.0) * 0.5
	var radius = lerp(8.0, 14.0, pulse)
	var fill_color = Color(color.r, color.g, color.b, 0.22)

	draw_circle(end_pos, radius + 5.0, Color(0, 0, 0, 0.28))
	draw_circle(end_pos, radius, fill_color)
	draw_arc(end_pos, radius, 0, TAU, 36, COLOR_OUTLINE, 4.5)
	draw_arc(end_pos, radius, 0, TAU, 36, color, 2.8)


func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var q0 = p0.lerp(p1, t)
	var q1 = p1.lerp(p2, t)
	var q2 = p2.lerp(p3, t)
	var r0 = q0.lerp(q1, t)
	var r1 = q1.lerp(q2, t)
	return r0.lerp(r1, t)

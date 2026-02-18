## A visual targeting arrow drawn from a spell card to the mouse cursor.
## Used when casting unit-targeted spells (e.g., ZAP).
## Draws a curved line with an arrowhead from the origin to the current mouse position.
extends Node2D

var origin: Vector2 = Vector2.ZERO
var is_active: bool = false

# Visual settings
var line_color: Color = Color(1.0, 0.3, 0.3, 0.9)
var line_width: float = 4.0
var arrow_size: float = 16.0
var segments: int = 20
var curve_strength: float = 80.0


func _ready() -> void:
	z_index = 100 # Always render on top
	set_process(true)


func start(from_position: Vector2) -> void:
	origin = from_position
	is_active = true
	visible = true
	queue_redraw()


func stop() -> void:
	is_active = false
	visible = false
	queue_redraw()


func _process(_delta: float) -> void:
	if is_active:
		queue_redraw()


func _draw() -> void:
	if not is_active:
		return
	
	var mouse_pos = get_global_mouse_position()
	var start_pos = origin - global_position
	var end_pos = mouse_pos - global_position
	
	# Calculate a curved path using a quadratic bezier
	var mid = (start_pos + end_pos) / 2.0
	var direction = (end_pos - start_pos).normalized()
	var perpendicular = Vector2(-direction.y, direction.x)
	var control_point = mid + perpendicular * curve_strength
	
	# Build the bezier curve points
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var p = _quadratic_bezier(start_pos, control_point, end_pos, t)
		points.append(p)
	
	# Draw the line
	if points.size() >= 2:
		# Draw a glow/outline first
		draw_polyline(points, Color(0, 0, 0, 0.3), line_width + 4.0, true)
		# Draw the main line
		draw_polyline(points, line_color, line_width, true)
	
	# Draw arrowhead at the end
	if points.size() >= 2:
		var tip = points[points.size() - 1]
		var prev = points[points.size() - 2]
		var arrow_dir = (tip - prev).normalized()
		var arrow_perp = Vector2(-arrow_dir.y, arrow_dir.x)
		
		var p1 = tip
		var p2 = tip - arrow_dir * arrow_size + arrow_perp * arrow_size * 0.5
		var p3 = tip - arrow_dir * arrow_size - arrow_perp * arrow_size * 0.5
		
		draw_polygon(PackedVector2Array([p1, p2, p3]), PackedColorArray([line_color, line_color, line_color]))
	
	# Draw a pulsing circle at the cursor end
	var pulse = (sin(Time.get_ticks_msec() / 200.0) + 1.0) / 2.0
	var radius = lerp(8.0, 14.0, pulse)
	draw_circle(end_pos, radius, Color(line_color.r, line_color.g, line_color.b, 0.4))
	draw_arc(end_pos, radius, 0, TAU, 32, line_color, 2.0)


func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var q0 = p0.lerp(p1, t)
	var q1 = p1.lerp(p2, t)
	return q0.lerp(q1, t)

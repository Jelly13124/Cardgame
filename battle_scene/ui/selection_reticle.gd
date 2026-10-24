extends Node2D

## Target reticle after STS2's NSelectionReticle: four corner brackets around a
## creature's targeting rect. Shows with a quick fade and an expo-out settle
## from 0.9x; hides with a fade while easing out to 1.05x. Drawn in code (light
## line on a dark line) until dedicated art exists.

const LINE_COLOR := Color(1.0, 0.96, 0.86, 1.0)
const OUTLINE_COLOR := Color(0.06, 0.03, 0.02, 0.85)
## Bracket arm length as a share of the rect's shorter side.
const ARM_SHARE := 0.22

var _rect := Rect2()
var _shown := false
var _tween: Tween


func _init() -> void:
	name = "SelectionReticle"
	modulate.a = 0.0
	visible = false
	z_index = 30


## `local_rect` is in the parent creature's local space; the reticle scales
## about its centre.
func set_rect(local_rect: Rect2) -> void:
	_rect = Rect2(-local_rect.size * 0.5, local_rect.size)
	position = local_rect.get_center()
	queue_redraw()


func is_shown() -> bool:
	return _shown


func show_reticle() -> void:
	_shown = true
	visible = true
	if _tween:
		_tween.kill()
	if not is_inside_tree():
		modulate.a = 1.0
		scale = Vector2.ONE
		return
	scale = Vector2.ONE * 0.9
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.2)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(
		Tween.TRANS_EXPO
	)


func hide_reticle() -> void:
	if not _shown:
		return
	_shown = false
	if _tween:
		_tween.kill()
	if not is_inside_tree():
		modulate.a = 0.0
		visible = false
		return
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_OUT).set_trans(
		Tween.TRANS_SINE
	)
	_tween.tween_property(self, "scale", Vector2.ONE * 1.05, 0.2).set_ease(Tween.EASE_OUT).set_trans(
		Tween.TRANS_SINE
	)


func _draw() -> void:
	if _rect.size == Vector2.ZERO:
		return
	var arm := minf(_rect.size.x, _rect.size.y) * ARM_SHARE
	var corners := [
		[_rect.position, Vector2(1, 0), Vector2(0, 1)],
		[Vector2(_rect.end.x, _rect.position.y), Vector2(-1, 0), Vector2(0, 1)],
		[Vector2(_rect.position.x, _rect.end.y), Vector2(1, 0), Vector2(0, -1)],
		[_rect.end, Vector2(-1, 0), Vector2(0, -1)],
	]
	for width_color in [[7.0, OUTLINE_COLOR], [4.0, LINE_COLOR]]:
		for corner in corners:
			var at: Vector2 = corner[0]
			var bracket := PackedVector2Array([at + corner[1] * arm, at, at + corner[2] * arm])
			draw_polyline(bracket, width_color[1], width_color[0], true)

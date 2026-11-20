extends Control

## The merchant's trade rug (STS2 merchant_inventory SlotsContainer): one big
## flat canvas the goods lie on, drawn in the roster style instead of a dark
## slab: a faded olive tarp with a wobbly ink edge, a stitched hem, one sewn-on
## patch and sparse chevron marks. Pure drawing; it takes no input.

const FILL := Color("#6d7448")
const FILL_DARK := Color("#596038")
const HEM := Color("#c9bf8a")
const INK := Color("#1f1610")
const PATCH := Color("#8a6a45")
const EDGE_WIDTH := 5.0
const HEM_INSET := 22.0
const STITCH := 16.0
const STITCH_GAP := 10.0
const CHEVRON_STEP := Vector2(230.0, 190.0)


func _init() -> void:
	name = "ShopRug"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x < 80.0 or size.y < 80.0:
		return
	var edge := _wobbly_rect(Rect2(Vector2.ZERO, size).grow(-4.0), 5.0, 7)
	draw_colored_polygon(edge, FILL)
	_draw_chevrons()
	_draw_patch(Vector2(48.0, size.y - 96.0))
	_draw_stitches(Rect2(Vector2.ZERO, size).grow(-HEM_INSET))
	var closed := edge.duplicate()
	closed.append(edge[0])
	draw_polyline(closed, INK, EDGE_WIDTH, true)


## A rectangle with slightly bowed sides (hand-drawn edge), deterministic.
func _wobbly_rect(r: Rect2, amp: float, per_side: int) -> PackedVector2Array:
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var pts := PackedVector2Array()
	for side in 4:
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var normal := (b - a).orthogonal().normalized()
		for i in per_side:
			var t := float(i) / float(per_side)
			var bow := sin(t * PI) * amp * (1.0 if side % 2 == 0 else -0.6)
			pts.append(a.lerp(b, t) + normal * bow)
	return pts


func _draw_stitches(r: Rect2) -> void:
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for side in 4:
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var dir := (b - a).normalized()
		var length := a.distance_to(b)
		var t := 0.0
		while t < length:
			draw_line(a + dir * t, a + dir * minf(t + STITCH, length), HEM, 3.0, true)
			t += STITCH + STITCH_GAP


## Sparse woven chevrons, a few per row, faint so the goods stay the subject.
func _draw_chevrons() -> void:
	var mark := FILL_DARK
	var row := 0
	var y := 90.0
	while y < size.y - 60.0:
		var x := 120.0 + (CHEVRON_STEP.x * 0.5 if row % 2 == 1 else 0.0)
		while x < size.x - 80.0:
			var c := Vector2(x, y)
			draw_polyline(PackedVector2Array([c + Vector2(-26, 12), c, c + Vector2(26, 12)]), mark, 6.0, true)
			x += CHEVRON_STEP.x
		y += CHEVRON_STEP.y
		row += 1


## A sewn-on square patch with cross stitches in one corner.
func _draw_patch(at: Vector2) -> void:
	var quad := PackedVector2Array([at, at + Vector2(78, -6), at + Vector2(84, 62), at + Vector2(4, 66)])
	draw_colored_polygon(quad, PATCH)
	var closed := quad.duplicate()
	closed.append(quad[0])
	draw_polyline(closed, INK, 3.0, true)
	for i in 4:
		var a: Vector2 = quad[i]
		var b: Vector2 = quad[(i + 1) % 4]
		var mid := a.lerp(b, 0.5)
		var inward := ((quad[0] + quad[2]) * 0.5 - mid).normalized() * 9.0
		draw_line(mid - inward.orthogonal() * 0.5, mid + inward, HEM, 2.0, true)

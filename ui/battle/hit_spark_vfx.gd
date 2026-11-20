extends RefCounted

## A one-shot comic impact star at the point of contact, drawn in the roster
## style: a flat jagged star with a thick ink outline, a smaller accent star
## inside and a few ink speed marks. It pops in, holds for a beat and fades,
## all in about a quarter second. The kind of hit (a bullet, an area blast, an
## electric discharge or an enemy's blow) picks the spike count and colours.

const KIND_SHOT := "shot"
const KIND_BLAST := "blast"
const KIND_SHOCK := "shock"
const KIND_BLUNT := "blunt"

const INK := Color("#1f1610")
const OUTLINE_WIDTH := 4.0
## Outer radius of a plain shot at emphasis 1.
const BASE_RADIUS := 46.0
const POP_SECONDS := 0.06
const HOLD_SECONDS := 0.06
const FADE_SECONDS := 0.14

## Per kind: spike count, size multiplier, speed marks, star fill, accent fill.
const KINDS := {
	KIND_SHOT: {
		"spikes": 8, "size": 1.0, "marks": 3,
		"fill": Color("#ffe7a3"), "accent": Color("#f08a2c"),
	},
	KIND_BLAST: {
		"spikes": 11, "size": 1.3, "marks": 5,
		"fill": Color("#ffc163"), "accent": Color("#e2512a"),
	},
	KIND_SHOCK: {
		"spikes": 7, "size": 0.95, "marks": 4,
		"fill": Color("#c9f4ff"), "accent": Color("#3fa9f5"),
	},
	KIND_BLUNT: {
		"spikes": 6, "size": 1.15, "marks": 3,
		"fill": Color("#f6ead0"), "accent": Color("#d9a05b"),
	},
}


## Spawns the impact for `kind` at `world_pos`; `emphasis` scales it (heavy and
## lethal hits land bigger stars). Unknown kinds fall back to a shot. Returns
## the star node, whose parent layer is named CombatHitSpark_<kind>.
static func spawn(scene_root: Node, world_pos: Vector2, kind: String, emphasis := 1.0) -> Node2D:
	if not is_instance_valid(scene_root) or scene_root.get_tree() == null:
		return null
	var resolved := kind if KINDS.has(kind) else KIND_SHOT
	var settings: Dictionary = KINDS[resolved]
	var radius := BASE_RADIUS * float(settings["size"]) * sqrt(maxf(emphasis, 0.1))

	var layer := CanvasLayer.new()
	layer.name = "CombatHitSpark_%s" % resolved
	layer.layer = 50
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	scene_root.add_child(layer, true)  # readable names keep the kind when bursts overlap

	var star := Node2D.new()
	star.name = "Star"
	star.position = world_pos
	star.rotation = randf() * TAU
	star.set_meta("radius", radius)
	layer.add_child(star)
	var spikes := int(settings["spikes"])
	_add_star(star, "Fill", spikes, radius, settings["fill"])
	_add_star(star, "Accent", spikes, radius * 0.48, settings["accent"])
	_add_marks(star, int(settings["marks"]), radius)

	star.scale = Vector2.ONE * 0.4
	var tween := star.create_tween()
	tween.tween_property(star, "scale", Vector2.ONE, POP_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD_SECONDS)
	tween.set_parallel(true)
	tween.tween_property(star, "scale", Vector2.ONE * 1.12, FADE_SECONDS)
	tween.tween_property(star, "modulate:a", 0.0, FADE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Game time, so a hitstop holds the star frozen with everything else.
	scene_root.get_tree().create_timer(POP_SECONDS + HOLD_SECONDS + FADE_SECONDS + 0.05).timeout.connect(layer.queue_free)
	return star


## The star's points: outer tips of slightly uneven length between inner notches.
static func star_points(spikes: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in spikes * 2:
		var angle := TAU * float(i) / float(spikes * 2)
		var r := radius * 0.46
		if i % 2 == 0:
			r = radius * (0.86 + 0.14 * float((i * 7) % 5) / 4.0)
		points.append(Vector2.from_angle(angle) * r)
	return points


static func _add_star(parent: Node2D, part_name: String, spikes: int, radius: float, fill: Color) -> void:
	var points := star_points(spikes, radius)
	var poly := Polygon2D.new()
	poly.name = part_name
	poly.polygon = points
	poly.color = fill
	parent.add_child(poly)
	var outline := Line2D.new()
	outline.name = part_name + "Outline"
	outline.points = points
	outline.closed = true
	outline.width = OUTLINE_WIDTH if part_name == "Fill" else OUTLINE_WIDTH * 0.6
	outline.default_color = INK
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	outline.antialiased = true
	parent.add_child(outline)


## A few short ink dashes just outside the star, spaced around it.
static func _add_marks(parent: Node2D, count: int, radius: float) -> void:
	for i in count:
		var angle := TAU * (float(i) + 0.5) / float(count)
		var dir := Vector2.from_angle(angle)
		var mark := Line2D.new()
		mark.name = "Mark%d" % i
		mark.points = PackedVector2Array([dir * radius * 1.18, dir * radius * 1.5])
		mark.width = OUTLINE_WIDTH
		mark.default_color = INK
		mark.begin_cap_mode = Line2D.LINE_CAP_ROUND
		mark.end_cap_mode = Line2D.LINE_CAP_ROUND
		mark.antialiased = true
		parent.add_child(mark)

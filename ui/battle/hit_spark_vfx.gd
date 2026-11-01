extends RefCounted

## A one-shot spark burst at the point of contact (STS2 NHitSparkVfx), shaped
## by what landed the hit: a bullet, an area blast, an electric discharge or an
## enemy's blow. The comic impact frames still play on top of it.

const KIND_SHOT := "shot"
const KIND_BLAST := "blast"
const KIND_SHOCK := "shock"
const KIND_BLUNT := "blunt"

## Per kind: spark count, speed range (px/s), lifetime, size, colour at birth
## and the colour it fades through.
const KINDS := {
	KIND_SHOT: {
		"amount": 14, "speed": Vector2(320.0, 640.0), "lifetime": 0.32, "size": 5.0,
		"color": Color(1.0, 0.86, 0.42), "fade": Color(1.0, 0.45, 0.12, 0.0),
	},
	KIND_BLAST: {
		"amount": 30, "speed": Vector2(420.0, 920.0), "lifetime": 0.46, "size": 7.0,
		"color": Color(1.0, 0.62, 0.22), "fade": Color(0.75, 0.16, 0.06, 0.0),
	},
	KIND_SHOCK: {
		"amount": 22, "speed": Vector2(380.0, 820.0), "lifetime": 0.28, "size": 4.0,
		"color": Color(0.72, 0.96, 1.0), "fade": Color(0.25, 0.55, 1.0, 0.0),
	},
	KIND_BLUNT: {
		"amount": 16, "speed": Vector2(220.0, 480.0), "lifetime": 0.38, "size": 6.0,
		"color": Color(1.0, 0.93, 0.80), "fade": Color(0.62, 0.50, 0.38, 0.0),
	},
}


## Spawns the burst for `kind` at `world_pos`; `emphasis` scales the count and
## speed (heavy and lethal hits throw more). Unknown kinds fall back to a shot.
static func spawn(scene_root: Node, world_pos: Vector2, kind: String, emphasis := 1.0) -> CPUParticles2D:
	if not is_instance_valid(scene_root) or scene_root.get_tree() == null:
		return null
	var resolved := kind if KINDS.has(kind) else KIND_SHOT
	var settings: Dictionary = KINDS[resolved]
	var layer := CanvasLayer.new()
	layer.name = "CombatHitSpark_%s" % resolved
	layer.layer = 50
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	scene_root.add_child(layer, true)  # readable names keep the kind when bursts overlap

	var sparks := CPUParticles2D.new()
	sparks.process_mode = Node.PROCESS_MODE_ALWAYS
	sparks.position = world_pos
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = maxi(1, roundi(float(settings["amount"]) * emphasis))
	sparks.lifetime = float(settings["lifetime"])
	sparks.direction = Vector2.UP
	sparks.spread = 180.0
	sparks.gravity = Vector2(0.0, 900.0)
	var speed: Vector2 = settings["speed"] * sqrt(emphasis)
	sparks.initial_velocity_min = speed.x
	sparks.initial_velocity_max = speed.y
	sparks.damping_min = 300.0
	sparks.damping_max = 600.0
	sparks.scale_amount_min = float(settings["size"]) * 0.6
	sparks.scale_amount_max = float(settings["size"])
	var ramp := Gradient.new()
	ramp.set_color(0, settings["color"])
	ramp.set_color(1, settings["fade"])
	sparks.color_ramp = ramp
	layer.add_child(sparks)
	sparks.emitting = true
	sparks.finished.connect(layer.queue_free)
	return sparks

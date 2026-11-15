extends RefCounted

## A one-shot spark burst at the point of contact (STS2 NHitSparkVfx), shaped
## by what landed the hit: a bullet, an area blast, an electric discharge or an
## enemy's blow. The comic impact frames still play on top of it.

const KIND_SHOT := "shot"
const KIND_BLAST := "blast"
const KIND_SHOCK := "shock"
const KIND_BLUNT := "blunt"

## Per kind: streak-spark count, launch speed range (px/s), lifetime, layer size
## multiplier, colour at birth and the colour it fades through.
const KINDS := {
	KIND_SHOT: {
		"amount": 16, "speed": Vector2(1500.0, 2500.0), "lifetime": 0.4, "size": 1.0,
		"color": Color(1.0, 0.86, 0.42), "fade": Color(1.0, 0.45, 0.12, 0.0),
	},
	KIND_BLAST: {
		"amount": 26, "speed": Vector2(1700.0, 2800.0), "lifetime": 0.5, "size": 1.25,
		"color": Color(1.0, 0.62, 0.22), "fade": Color(0.75, 0.16, 0.06, 0.0),
	},
	KIND_SHOCK: {
		"amount": 20, "speed": Vector2(1600.0, 2600.0), "lifetime": 0.3, "size": 0.9,
		"color": Color(0.72, 0.96, 1.0), "fade": Color(0.25, 0.55, 1.0, 0.0),
	},
	KIND_BLUNT: {
		"amount": 14, "speed": Vector2(1200.0, 2000.0), "lifetime": 0.45, "size": 1.15,
		"color": Color(1.0, 0.93, 0.80), "fade": Color(0.62, 0.50, 0.38, 0.0),
	},
}

## Soft radial sprites drawn in code (glow, long and short streaks, speck). A
## non-square texture turns the radial falloff into an ellipse, which is what
## a streak needs. Built once and shared by every burst.
const _SHAPES := {
	"glow": Vector2i(128, 128),
	"rice_long": Vector2i(12, 72),
	"rice_short": Vector2i(10, 36),
	"speck": Vector2i(20, 20),
	"streak": Vector2i(18, 160),
}
static var _textures: Dictionary = {}


## Spawns the burst for `kind` at `world_pos`; `emphasis` scales the count,
## speed and size (heavy and lethal hits throw more). Unknown kinds fall back
## to a shot. Returns the main streak-spark layer.
##
## The layers follow STS2's hit_spark_vfx: a centre glow, fast velocity-aligned
## streak sparks with friction instead of gravity, slower small sparks, drifting
## specks and a couple of long outward streaks, all blended additively.
static func spawn(scene_root: Node, world_pos: Vector2, kind: String, emphasis := 1.0) -> CPUParticles2D:
	if not is_instance_valid(scene_root) or scene_root.get_tree() == null:
		return null
	var resolved := kind if KINDS.has(kind) else KIND_SHOT
	var settings: Dictionary = KINDS[resolved]
	var size: float = float(settings["size"]) * sqrt(emphasis)
	var speed: Vector2 = settings["speed"] * sqrt(emphasis)
	var lifetime: float = float(settings["lifetime"])
	var ramp := Gradient.new()
	ramp.set_color(0, settings["color"])
	ramp.set_color(1, settings["fade"])

	var layer := CanvasLayer.new()
	layer.name = "CombatHitSpark_%s" % resolved
	layer.layer = 50
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	scene_root.add_child(layer, true)  # readable names keep the kind when bursts overlap

	_add_glow(layer, world_pos, settings["color"], size)
	var sparks := _add_particles(layer, "Sparks", world_pos, "rice_long", ramp, {
		"amount": roundi(float(settings["amount"]) * emphasis), "lifetime": lifetime,
		"speed": speed, "damping": Vector2(10000.0, 14000.0), "scale": Vector2(0.8, 1.2) * size,
		"align": true,
	})
	_add_particles(layer, "SmallSparks", world_pos, "rice_short", ramp, {
		"amount": roundi(float(settings["amount"]) * 1.5 * emphasis), "lifetime": lifetime * 1.2,
		"speed": speed * 0.25, "damping": Vector2(1200.0, 1800.0), "scale": Vector2(0.7, 1.0) * size,
		"align": true,
	})
	_add_particles(layer, "Specks", world_pos, "speck", ramp, {
		"amount": roundi(10.0 * emphasis), "lifetime": 0.8,
		"speed": Vector2(150.0, 350.0), "damping": Vector2(250.0, 350.0), "scale": Vector2(0.4, 0.8) * size,
		"gravity": Vector2(0.0, 120.0),
	})
	_add_particles(layer, "Streaks", world_pos, "streak", ramp, {
		"amount": maxi(2, roundi(2.0 * emphasis)), "lifetime": 0.3,
		"speed": Vector2(900.0, 1600.0) * sqrt(emphasis), "damping": Vector2(6000.0, 8000.0),
		"scale": Vector2(0.9, 1.3) * size, "align": true,
	})
	# The specks live longest; free the whole burst after them. The timer runs on
	# game time, so a hitstop holds the burst frozen with everything else.
	scene_root.get_tree().create_timer(1.0).timeout.connect(layer.queue_free)
	return sparks


static func _add_glow(layer: Node, world_pos: Vector2, color: Color, size: float) -> void:
	var glow := Sprite2D.new()
	glow.name = "Glow"
	glow.texture = _texture("glow")
	glow.material = _additive()
	glow.position = world_pos
	glow.modulate = color
	glow.scale = Vector2.ONE * 0.6 * size
	layer.add_child(glow)
	var tween := glow.create_tween().set_parallel(true)
	tween.tween_property(glow, "scale", Vector2.ONE * 2.0 * size, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


static func _add_particles(layer: Node, part_name: String, world_pos: Vector2, shape: String, ramp: Gradient, p: Dictionary) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = part_name
	particles.process_mode = Node.PROCESS_MODE_ALWAYS
	particles.position = world_pos
	particles.texture = _texture(shape)
	particles.material = _additive()
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = maxi(1, int(p["amount"]))
	particles.lifetime = float(p["lifetime"])
	particles.lifetime_randomness = 0.5
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = p.get("gravity", Vector2.ZERO)
	var speed: Vector2 = p["speed"]
	particles.initial_velocity_min = speed.x
	particles.initial_velocity_max = speed.y
	var damping: Vector2 = p["damping"]
	particles.damping_min = damping.x
	particles.damping_max = damping.y
	var scale_range: Vector2 = p["scale"]
	particles.scale_amount_min = scale_range.x
	particles.scale_amount_max = scale_range.y
	particles.particle_flag_align_y = bool(p.get("align", false))
	particles.color_ramp = ramp
	layer.add_child(particles)
	particles.emitting = true
	return particles


static func _additive() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


static func _texture(shape: String) -> Texture2D:
	if _textures.has(shape):
		return _textures[shape]
	var falloff := Gradient.new()
	falloff.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	falloff.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = falloff
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var dims: Vector2i = _SHAPES[shape]
	tex.width = dims.x
	tex.height = dims.y
	_textures[shape] = tex
	return tex

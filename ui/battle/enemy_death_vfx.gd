extends Node2D

## An enemy's death (STS2 NMonsterDeathVfx): a snapshot of the enemy's sprite
## stays where it stood, burns away through a noise dissolve with a glowing
## rim, and sheds rust flakes that drift up and to the right. The enemy view
## itself leaves at once, so combat never sees a dying view; this node only
## looks, then frees itself.

const DELAY_SECONDS := 0.12
const DISSOLVE_SECONDS := 1.4
## The whole effect, flakes included; the node frees itself after it.
const LIFETIME_SECONDS := 2.4
const FLAKE_COUNT := 70

const DISSOLVE_SHADER := """
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.56, 0.2, 1.0);
uniform float edge_width = 0.07;
uniform float chunk_pixels = 38.0;
uniform vec2 seed = vec2(0.0);

varying vec2 local_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += a * value_noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	// fbm bunches around 0.47; stretch its middle so the burn spreads over
	// the whole dissolve instead of happening in one moment.
	float n = clamp((fbm(local_pos / chunk_pixels + seed) - 0.22) / 0.5, 0.0, 1.0);
	// progress 0 keeps every pixel, 1 removes them all.
	float t = progress * 1.1 - 0.05;
	if (n < t) {
		discard;
	}
	float rim = (1.0 - smoothstep(0.0, edge_width, n - t)) * step(0.001, progress);
	c.rgb *= mix(1.0, 0.55, progress);
	c.rgb = mix(c.rgb, edge_color.rgb * 1.6, rim);
	COLOR = c;
}
"""

static var _shader: Shader = null


## Leaves a dissolving copy of `sprite`'s current frame beside `view` in the
## battle. Returns null when there is nothing to show.
static func spawn(view: Node2D, sprite: AnimatedSprite2D) -> Node2D:
	if not is_instance_valid(view) or not view.is_inside_tree() or not is_instance_valid(sprite):
		return null
	if sprite.sprite_frames == null:
		return null
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null:
		return null
	var container := view.get_parent()
	var host := container.get_parent() if container else null
	if host == null:
		return null

	var vfx = load("uid://cayme2wbim86o").new()  # res://ui/battle/enemy_death_vfx.gd
	vfx.name = "EnemyDeathVfx"
	# Right above the enemies, below everything drawn after them (hand, HUD).
	host.add_child(vfx, true)
	host.move_child(vfx, container.get_index() + 1)
	vfx._build(sprite, texture)
	return vfx


func _build(sprite: AnimatedSprite2D, texture: Texture2D) -> void:
	var body := Sprite2D.new()
	body.name = "Body"
	body.texture = texture
	body.centered = sprite.centered
	body.offset = sprite.offset
	body.flip_h = sprite.flip_h
	body.flip_v = sprite.flip_v
	body.texture_filter = sprite.texture_filter
	var material := ShaderMaterial.new()
	material.shader = _dissolve_shader()
	material.set_shader_parameter("seed", Vector2(randf() * 50.0, randf() * 50.0))
	material.set_shader_parameter("progress", 0.0)
	body.material = material
	add_child(body)
	body.global_transform = sprite.global_transform

	var flakes := _make_flakes(texture.get_size() * sprite.global_scale.abs())
	add_child(flakes)
	flakes.global_position = body.global_position + sprite.offset * sprite.global_scale
	flakes.emitting = true

	body.modulate = Color(1.7, 1.35, 1.15)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(body, "modulate", Color.WHITE, 0.22)
	tween.tween_method(
		func(p: float): material.set_shader_parameter("progress", p), 0.0, 1.0, DISSOLVE_SECONDS
	).set_delay(DELAY_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(maxf(0.0, LIFETIME_SECONDS - DELAY_SECONDS - DISSOLVE_SECONDS))
	tween.chain().tween_callback(queue_free)


## Rust flakes and embers from the body's area, tumbling up and right.
func _make_flakes(body_size: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "Flakes"
	p.amount = FLAKE_COUNT
	p.one_shot = true
	p.explosiveness = 0.25
	p.lifetime = 1.5
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = body_size * 0.32
	p.direction = Vector2(0.55, -1.0)
	p.spread = 40.0
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 170.0
	p.gravity = Vector2(60.0, -70.0)
	p.damping_min = 20.0
	p.damping_max = 40.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -420.0
	p.angular_velocity_max = 420.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 8.0
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.7, 0.8))
	shrink.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = shrink
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.66, 0.28, 1.0))
	ramp.set_color(1, Color(0.22, 0.17, 0.14, 0.0))
	ramp.add_point(0.35, Color(0.78, 0.36, 0.16, 1.0))
	p.color_ramp = ramp
	return p


static func _dissolve_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = DISSOLVE_SHADER
	return _shader

// Grayscale-darken for LOCKED home-base building buttons (home_base_scene.gd).
// A plain modulate dim (0.75) read as "slightly dark", not "locked" — this
// desaturates to near-grey and drops brightness so locked tiles read at a
// glance. The brass lock overlay is a SIBLING node, so it keeps full color.
shader_type canvas_item;

uniform float saturation : hint_range(0.0, 1.0) = 0.25;
uniform float brightness : hint_range(0.0, 1.0) = 0.62;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(vec3(g), c.rgb, saturation) * brightness, c.a);
}

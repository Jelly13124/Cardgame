shader_type canvas_item;

uniform bool is_attack = false;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	float alpha = tex_color.a;

	if (is_attack) {
		float x = UV.x;
		float y = UV.y;

		// Downward spike at the bottom:
		// Center (x=0.5) reaches all the way to y=1.0 (bottom).
		// Edges (x=0 or x=1) are clipped at y=0.75.
		// This creates a V-shape pointing DOWN.
		float clip_y = 1.0 - (abs(x - 0.5) * 0.5);
		if (y > clip_y) {
			alpha = 0.0;
		}
	}

	COLOR = vec4(tex_color.rgb, alpha);
}

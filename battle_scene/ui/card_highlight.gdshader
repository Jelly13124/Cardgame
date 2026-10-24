shader_type canvas_item;

// Playable outline around a card silhouette (STS2 NCardHighlight). The rect is
// the card plus `margin` on every side; `source` is the card's shell texture.
// Pixels outside the silhouette but within `width_px` of it glow, fading out
// with distance.

uniform sampler2D source : filter_linear;
uniform vec2 card_size = vec2(208.0, 286.0);
uniform float margin = 12.0;
uniform float width_px = 0.0;
uniform vec4 glow_color : source_color = vec4(0.2, 0.92, 1.0, 0.98);

float alpha_at(vec2 px) {
	if (px.x < 0.0 || px.y < 0.0 || px.x > card_size.x || px.y > card_size.y) {
		return 0.0;
	}
	return texture(source, px / card_size).a;
}

void fragment() {
	vec2 px = UV * (card_size + vec2(margin * 2.0)) - vec2(margin);
	float strength = 0.0;
	if (width_px > 0.01 && alpha_at(px) < 0.5) {
		for (int i = 0; i < 16; i++) {
			float angle = float(i) * 0.3926991;
			vec2 dir = vec2(cos(angle), sin(angle));
			for (int r = 1; r <= 3; r++) {
				if (alpha_at(px + dir * width_px * float(r) / 3.0) >= 0.5) {
					strength = max(strength, 1.0 - float(r - 1) / 3.0);
				}
			}
		}
	}
	COLOR = vec4(glow_color.rgb, glow_color.a * strength);
}

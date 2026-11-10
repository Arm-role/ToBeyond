// Very subtle background life: two slow drifting soft glows and sparse twinkling
// stars. Put on the full-screen Background ColorRect; keeps the rect's colour.
shader_type canvas_item;

uniform float star_density = 0.018;
uniform float star_alpha = 0.35;
uniform float glow_alpha = 0.07;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 col = COLOR.rgb;
	// soft glows drifting slowly
	vec2 g1 = vec2(0.28 + 0.10 * sin(TIME * 0.11), 0.30 + 0.08 * cos(TIME * 0.09));
	vec2 g2 = vec2(0.74 + 0.09 * cos(TIME * 0.08), 0.68 + 0.10 * sin(TIME * 0.12));
	col += vec3(0.30, 0.18, 0.55) * glow_alpha * exp(-dot(UV - g1, UV - g1) * 7.0);
	col += vec3(0.55, 0.38, 0.12) * glow_alpha * 0.8 * exp(-dot(UV - g2, UV - g2) * 9.0);
	// stars on a 64x36 grid of square cells, drifting down very slowly
	vec2 uv = vec2(UV.x, UV.y + TIME * 0.004);
	vec2 cell = floor(uv * vec2(64.0, 36.0));
	vec2 f = fract(uv * vec2(64.0, 36.0));
	float h = hash(cell);
	if (h < star_density) {
		vec2 c = vec2(hash(cell + 3.7), hash(cell + 9.1)) * 0.6 + 0.2;
		float d = length(f - c);
		float tw = 0.55 + 0.45 * sin(TIME * (0.8 + h * 90.0) + h * 400.0);
		col += vec3(0.85, 0.82, 1.0) * star_alpha * tw * smoothstep(0.17, 0.0, d);
	}
	COLOR = vec4(col, COLOR.a);
}

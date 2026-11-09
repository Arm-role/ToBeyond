// Diagonal light band that sweeps across a card, clipped to the chamfered
// card shape of assets/frames/card_template.svg (360×504, corners cut at x+y=32).
// Put it on a full-rect ColorRect over the card; it only adds light.
shader_type canvas_item;
render_mode blend_add;

uniform float period = 2.4;    // seconds between sweeps
uniform float sweep = 0.7;     // seconds one sweep takes
uniform float band_width = 0.16;
uniform float strength = 0.5;
uniform float phase = 0.0;     // per-card offset in seconds

void fragment() {
	vec2 p = UV * vec2(360.0, 504.0);
	vec2 q = min(p, vec2(360.0, 504.0) - p);  // distance to the nearest edges
	float inside = step(5.0, q.x) * step(5.0, q.y) * step(32.0, q.x + q.y);

	float t = mod(TIME + phase, period) / sweep;  // 0..1 while sweeping
	float d = (UV.x + UV.y * 0.6) / 1.6;          // diagonal position 0..1
	float pos = mix(-band_width, 1.0 + band_width, t);
	float band = (1.0 - smoothstep(0.0, band_width, abs(d - pos))) * step(t, 1.0);

	COLOR = vec4(1.0, 0.97, 0.85, band * strength * inside);
}

// Pulsing rim glow (+ optional slow light sweep) over a chamfered card slot, for
// uncommon / rare artifacts. Full-rect ColorRect over the slot; only adds light.
// Same card shape as card_shine.gdshader (360x504, corners cut at x+y=32).
shader_type canvas_item;
render_mode blend_add;

uniform vec3 tint : source_color = vec3(1.0, 0.81, 0.35);
uniform float rim = 0.5;          // rim glow strength
uniform float pulse_speed = 2.2;
uniform float sweep_strength = 0.0; // > 0 adds a sweeping band (rare)
uniform float phase = 0.0;

void fragment() {
	vec2 size = vec2(360.0, 504.0);
	vec2 p = UV * size;
	vec2 q = min(p, size - p);
	float edge = min(min(q.x, q.y), (q.x + q.y - 32.0) * 0.7071);  // distance to the border
	float inside = step(0.0, edge);
	float glow = exp(-max(edge, 0.0) / 26.0);                       // bright at the border, fading inward
	float pulse = 0.65 + 0.35 * sin((TIME + phase) * pulse_speed);

	float t = fract((TIME + phase) / 3.2) * 1.6 - 0.3;               // band position
	float d = (UV.x + UV.y * 0.6) / 1.6;
	float band = (1.0 - smoothstep(0.0, 0.14, abs(d - t))) * sweep_strength;

	float a = (glow * rim * pulse + band) * inside;
	COLOR = vec4(tint * a, a);
}

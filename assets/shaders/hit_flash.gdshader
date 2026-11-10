// Tints a sprite or label towards flash_color while keeping its shape (alpha).
// Animate `flash` from 1 to 0 for a hit flash.
shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, flash_color.rgb, flash);
}

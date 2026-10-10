shader_type canvas_item;
// Dims and softly blurs whatever is behind a battle overlay (Mulligan, Result).
// 5x5 box blur on the screen texture; no mipmaps, so it works in Compatibility.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float radius = 2.5;
uniform vec4 tint : source_color = vec4(0.11, 0.13, 0.14, 0.58);

void fragment() {
	vec2 step_px = SCREEN_PIXEL_SIZE * radius;
	vec3 sum = vec3(0.0);
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			sum += texture(screen_texture, SCREEN_UV + vec2(float(x), float(y)) * step_px).rgb;
		}
	}
	vec3 blurred = sum / 25.0;
	COLOR = vec4(mix(blurred, tint.rgb, tint.a), 1.0);
}

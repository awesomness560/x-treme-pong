shader_type canvas_item;

group_uniforms Colors;
uniform vec4 background_color : source_color = vec4(0.02, 0.01, 0.05, 1.0);
uniform vec4 line_color : source_color = vec4(0.85, 0.25, 1.0, 1.0);
uniform float line_intensity : hint_range(0.0, 8.0) = 0.6;

group_uniforms Grid;
uniform float cell_size : hint_range(8.0, 256.0) = 64.0;
uniform float line_width : hint_range(0.5, 6.0) = 1.0;
uniform float glow_width : hint_range(0.0, 20.0) = 5.0;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.2;
uniform int major_every : hint_range(0, 16) = 4;
uniform float major_boost : hint_range(1.0, 4.0) = 1.8;

group_uniforms Perspective;
uniform float perspective : hint_range(0.0, 0.95) = 0.35;
uniform bool vanish_right = true;
uniform float depth_fade : hint_range(0.0, 1.0) = 0.6;
uniform float scroll_speed = 0.0;
group_uniforms;

float grid_lines(vec2 coord) {
	vec2 fw = max(fwidth(coord), vec2(1e-5));
	vec2 dist = abs(fract(coord - 0.5) - 0.5) / fw; // pixels to nearest line
	float d = min(dist.x, dist.y);

	float core = 1.0 - smoothstep(line_width * 0.5 - 0.5, line_width * 0.5 + 0.5, d);
	float glow = glow_strength * exp(-d / max(glow_width, 0.001));

	// Fade lines out where they get too dense to draw cleanly (near the horizon).
	float density = 1.0 - smoothstep(0.15, 0.5, max(fw.x, fw.y));
	return max(core, glow) * density;
}

void fragment() {
	// Size of the ColorRect in pixels, taken from how fast UV changes per pixel.
	vec2 rect_px = 1.0 / max(abs(vec2(dFdx(UV.x), dFdy(UV.y))), vec2(1e-6));

	// s = 0 on the player side, 1 on the boss side.
	float s = vanish_right ? UV.x : 1.0 - UV.x;
	float denom = 1.0 - perspective * s;

	vec2 px = vec2(s * rect_px.x, (UV.y - 0.5) * rect_px.y) / denom;
	px.x += TIME * scroll_speed;
	vec2 coord = px / cell_size;

	float lines = grid_lines(coord);
	if (major_every > 0) {
		lines = max(lines, grid_lines(coord / float(major_every)) * major_boost);
	}

	float fade = 1.0 - depth_fade * s;
	vec3 col = background_color.rgb + line_color.rgb * line_intensity * lines * fade;
	COLOR = vec4(col, 1.0);
}
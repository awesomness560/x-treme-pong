shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

group_uniforms Curvature;
uniform float curvature : hint_range(0.0, 0.5) = 0.1;
uniform float border_softness : hint_range(0.0005, 0.02) = 0.003;

group_uniforms Scanlines;
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.15;
uniform float scanline_spacing : hint_range(1.0, 8.0) = 3.0;

group_uniforms ChromaticAberration;
uniform float aberration_px : hint_range(0.0, 3.0) = 0.75;
uniform float aberration_start : hint_range(0.0, 1.0) = 0.5;

group_uniforms Vignette;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform float vignette_radius : hint_range(0.0, 2.0) = 1.4;
uniform float vignette_softness : hint_range(0.01, 1.5) = 0.8;
group_uniforms;

vec2 barrel(vec2 uv) {
	vec2 cc = uv - 0.5;
	return uv + cc * dot(cc, cc) * curvature;
}

void fragment() {
	vec2 uv = barrel(SCREEN_UV);
	vec2 cc = uv - 0.5;
	float dist = length(cc) * 2.0; // 0 at center, 1 at edge midpoints

	// Chromatic aberration: zero in the center, ramps up toward the edges.
	float edge = smoothstep(aberration_start, 1.0, dist);
	vec2 ca = normalize(cc + 1e-5) * aberration_px * edge * SCREEN_PIXEL_SIZE;

	vec3 col;
	col.r = texture(screen_texture, uv + ca).r;
	col.g = texture(screen_texture, uv).g;
	col.b = texture(screen_texture, uv - ca).b;

	// Scanlines: static, and they follow the curve.
	float line = 0.5 + 0.5 * cos(uv.y / SCREEN_PIXEL_SIZE.y * TAU / scanline_spacing);
	col *= 1.0 - scanline_opacity * line;

	// Vignette: strongest in the corners.
	col *= 1.0 - vignette_strength * smoothstep(vignette_radius - vignette_softness, vignette_radius, dist);

	// Black outside the curved screen.
	vec2 inside = smoothstep(vec2(0.0), vec2(border_softness), uv)
		* smoothstep(vec2(0.0), vec2(border_softness), 1.0 - uv);
	col *= inside.x * inside.y;

	COLOR = vec4(col, 1.0);
}
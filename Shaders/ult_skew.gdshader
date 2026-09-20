shader_type canvas_item;

group_uniforms Shape;
/// Shears the band. Negative leans the top left, for a top-left to bottom-right cut.
uniform float slant : hint_range(-4.0, 4.0) = -1.6;
/// Band height as a fraction of the rect. 1 = fills it.
uniform float thickness : hint_range(0.05, 1.0) = 0.55;
/// Band length as a fraction of the rect's usable width.
uniform float band_length : hint_range(0.05, 1.0) = 0.9;
/// Slides the band across its short axis.
uniform float band_offset : hint_range(-1.0, 1.0) = 0.0;
/// Slides the band along its long axis.
uniform float length_offset : hint_range(-1.0, 1.0) = 0.0;
uniform float edge_softness : hint_range(0.0, 4.0) = 1.0;

group_uniforms Colors;
uniform vec4 border_color : source_color = vec4(1.0, 0.3, 0.8, 1.0);
/// Brightness of the border. Above 1 blooms.
uniform float border_brightness : hint_range(0.5, 6.0) = 2.6;
uniform vec4 inner_color : source_color = vec4(0.04, 0.02, 0.06, 1.0);
/// Inner darkens toward the middle of the band.
uniform float inner_darkening : hint_range(0.0, 1.0) = 0.5;

group_uniforms Border;
/// Solid border thickness, in pixels.
uniform float border_width : hint_range(0.0, 40.0) = 6.0;
/// How far the glow bleeds inward from the border.
uniform float border_glow : hint_range(0.0, 200.0) = 55.0;
/// Strength of that inward bleed.
uniform float border_glow_strength : hint_range(0.0, 2.0) = 0.55;

group_uniforms SpeedLines;
/// 0 hides them.
uniform float lines_opacity : hint_range(0.0, 2.0) = 0.7;
/// Spacing between lines, in pixels along the band.
uniform float line_spacing : hint_range(4.0, 120.0) = 26.0;
uniform float line_width : hint_range(0.5, 20.0) = 2.5;
/// How far lines reach in from the long edges, 0 to 0.5.
uniform float line_reach : hint_range(0.0, 0.5) = 0.32;
/// Randomises line length and brightness.
uniform float line_variation : hint_range(0.0, 1.0) = 0.7;
uniform float line_scroll = 0.0;

float hash(float n) {
	return fract(sin(n * 78.233) * 43758.5453);
}

void fragment() {
	vec2 size = 1.0 / max(abs(vec2(dFdx(UV.x), dFdy(UV.y))), vec2(1e-6));
	vec2 raw = UV * size;

	// Shear into band space. x runs along the band, y across it.
	float cx = raw.x - slant * (raw.y - size.y * 0.5);
	float cy = raw.y - size.y * (0.5 + band_offset * 0.5);

	// Inset so the sheared ends never clip against the rect.
	float margin = abs(slant) * size.y * 0.5;
	float usable = max(size.x - margin * 2.0, 1.0);
	float half_len = usable * band_length * 0.5;
	float half_band = size.y * thickness * 0.5;

	// Distance inside each axis: positive inside, 0 at the edge.
	float dist_y = half_band - abs(cy);
	float dist_x = half_len - abs(cx - size.x * 0.5 - length_offset * half_len);

	float dist = min(dist_x, dist_y);
	float shape = smoothstep(-edge_softness, edge_softness, dist);
	if (shape <= 0.0) {
		discard;
	}

	// 0 at a long edge, 1 at the centre line.
	float depth = clamp(dist_y / max(half_band, 0.001), 0.0, 1.0);

	// --- Interior: darkest in the middle ---
	vec3 col = inner_color.rgb * (1.0 - inner_darkening * depth);

	// --- Border glow, bleeding inward from every edge ---
	float glow = exp(-max(dist - border_width, 0.0) / max(border_glow, 0.001));
	col += border_color.rgb * border_brightness * glow * border_glow_strength;

	// --- Speed lines, hugging the long edges and cutting inward ---
	if (lines_opacity > 0.0) {
		float along = cx + line_scroll;
		float cell = floor(along / line_spacing);
		float rnd = hash(cell);
		float rnd2 = hash(cell + 41.0);

		// Distance to this line's centre, in pixels.
		float d = abs(fract(along / line_spacing) - 0.5) * line_spacing;
		float w = line_width * (1.0 + rnd * line_variation);
		float stroke = 1.0 - smoothstep(w * 0.5 - 0.5, w * 0.5 + 0.5, d);

		// Each line reaches a random distance in from its edge.
		float reach = line_reach * (1.0 - line_variation * rnd2);
		float fade = 1.0 - smoothstep(0.0, reach, depth);
		// Each line hangs off one edge, picked at random.
		float from_top = step(0.5, rnd2);
		float side = mix(step(cy, 0.0), step(0.0, cy), from_top);
		// Fade out before the slanted ends rather than being sliced by them.
		float end_fade = smoothstep(0.0, half_len * 0.15, dist_x);

		col += border_color.rgb * border_brightness * stroke * fade * side
			* end_fade * lines_opacity * (0.4 + 0.6 * rnd);
	}

	// --- Solid border, drawn last so it sits on top ---
	float edge = 1.0 - smoothstep(border_width - edge_softness,
		border_width + edge_softness, dist);
	col = mix(col, border_color.rgb * border_brightness, edge);

	COLOR = vec4(col, shape);
}
shader_type canvas_item;

group_uniforms Health;
/// 0 = empty, 1 = full. Drains from the high end.
uniform float health : hint_range(0.0, 1.0) = 1.0;
uniform int segment_count : hint_range(1, 16) = 10;


group_uniforms Break;
/// Range of segments currently shattering. -1 for none.
uniform int break_low = -1;
uniform int break_high = -1;
/// 0 = intact, 1 = fully shattered.
uniform float break_progress : hint_range(0.0, 1.0) = 0.0;

group_uniforms Look;
uniform vec4 base_color : source_color = vec4(0.9, 0.2, 0.95, 1.0);
uniform float empty_dim : hint_range(0.0, 0.5) = 0.12;
uniform float shard_boost : hint_range(1.0, 4.0) = 2.0;
/// Shears the whole bar. Positive leans right at the top.
uniform float slant : hint_range(-2.0, 2.0) = 0.4;
/// Flips which end is full, so the bar drains from the other side.
uniform bool reverse = false;
uniform float gap : hint_range(0.0, 40.0) = 6.0;
uniform float edge_softness : hint_range(0.0, 4.0) = 1.0;

group_uniforms Damage;
uniform float shard_size : hint_range(4.0, 60.0) = 14.0;
uniform float crack_width : hint_range(0.0, 6.0) = 1.5;
uniform float burst_distance : hint_range(0.0, 120.0) = 25.0;
uniform float fall : hint_range(-200.0, 200.0) = 35.0;
uniform float spin : hint_range(0.0, 3.0) = 0.8;

vec2 hash2(vec2 p) {
	float n = sin(dot(p, vec2(41.3, 289.1))) * 43758.5453;
	return vec2(fract(n), fract(n * 1.618)) * 2.0 - 1.0;
}

/// Coverage of segment `index`, positive inside. A band in sheared space.
/// `fill` trims it from the draining edge: 1 = whole, 0 = nothing.
float segment_mask(vec2 p, vec2 lay, int index, float fill) {
	float slot = lay.x / float(segment_count);
	float left = float(index) * slot + gap * 0.5;
	float right = left + slot - gap;
	right = mix(left, right, clamp(fill, 0.0, 1.0));
	float x_in = min(p.x - left, right - p.x);
	return min(x_in, min(p.y, lay.y - p.y));
}

float crack_distance(vec2 p) {
	vec2 cell = floor(p / shard_size);
	float best = 1e9;
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			vec2 c = cell + vec2(float(dx), float(dy));
			vec2 site = (c + 0.5 + hash2(c) * 0.35) * shard_size;
			best = min(best, length(p - site));
		}
	}
	return best;
}

void fragment() {
	vec2 size = 1.0 / max(abs(vec2(dFdx(UV.x), dFdy(UV.y))), vec2(1e-6));
	vec2 raw = UV * size;

	// Inset by exactly how far the shear displaces the top and bottom edges.
	float margin = abs(slant) * size.y * 0.5;
	vec2 lay = vec2(max(size.x - margin * 2.0, 1.0), size.y);

	// Shear the whole bar, then optionally flip which end is full.
	vec2 px = vec2(raw.x - slant * (raw.y - size.y * 0.5) - margin, raw.y);
	if (reverse) {
		px.x = lay.x - px.x;
	}

	vec3 fill_rgb = base_color.rgb;
	vec3 empty_rgb = base_color.rgb * empty_dim;
	vec3 shard_rgb = base_color.rgb * shard_boost;

	vec4 col = vec4(0.0);
	float scaled = health * float(segment_count);

	for (int i = 0; i < segment_count; i++) {
		float fill = clamp(scaled - float(i), 0.0, 1.0);

		// Dim socket, always the full segment shape.
		float socket = smoothstep(-edge_softness, edge_softness,
			segment_mask(px, lay, i, 1.0));
		col = mix(col, vec4(empty_rgb, base_color.a), socket);

		bool breaking = (i >= break_low) && (i <= break_high) && (break_progress > 0.0);
		
		if (!breaking) {
			// Solid fill, trimmed to how much of this segment is left.
			if (fill > 0.0) {
				float m = smoothstep(-edge_softness, edge_softness,
					segment_mask(px, lay, i, fill));
				col = mix(col, vec4(fill_rgb, base_color.a), m);
			}
			continue;
		}

		// --- Shattering: the whole segment breaks apart ---
		float p = clamp(break_progress, 0.0, 1.0);
		if (p >= 1.0) {
			continue;
		}

		vec2 cell = floor(px / shard_size);
		vec2 rnd = hash2(cell + vec2(float(i) * 7.0));
		vec2 drift = normalize(rnd + vec2(0.001)) * burst_distance * p;
		drift.y += fall * p * p;
		drift += rnd.yx * spin * shard_size * p;

		vec2 src = px - drift;
		if (floor(src / shard_size) != cell) {
			continue;
		}

		float sm = smoothstep(-edge_softness, edge_softness,
			segment_mask(src, lay, i, 1.0));
		if (sm <= 0.0) {
			continue;
		}

		float cd = crack_distance(src);
		float cracked = smoothstep(0.0, crack_width, cd - shard_size * 0.5 * p);

		vec3 shard = mix(fill_rgb, shard_rgb, p);
		col = mix(col, vec4(shard, base_color.a), sm * cracked * (1.0 - p * p));
	}

	COLOR = col;
}
shader_type canvas_item;

group_uniforms State;
/// 0 = pristine, 1 = about to break. How many fractures have appeared.
uniform float damage : hint_range(0.0, 1.0) = 0.0;
/// 0 = intact, 1 = fully shattered.
uniform float shatter : hint_range(0.0, 1.0) = 0.0;
/// Pulsed to 1 on a hit, tweened back down.
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
/// Where the last hit landed, in UV space.
uniform vec2 hit_point = vec2(0.5, 0.5);
/// How far the hit flash reaches, in pixels.
uniform float flash_radius : hint_range(20.0, 600.0) = 220.0;

group_uniforms Colors;
uniform vec4 body_color : source_color = vec4(0.10, 0.06, 0.16, 1.0);
uniform vec4 crack_color : source_color = vec4(1.0, 0.35, 0.85, 1.0);
uniform float crack_brightness : hint_range(0.5, 8.0) = 3.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.4, 0.9, 1.0);
uniform float outline_width : hint_range(0.0, 20.0) = 3.0;

group_uniforms Fractures;
/// How many fracture lines exist in total. They appear as damage rises.
uniform int line_count : hint_range(1, 40) = 18;
/// Line thickness in pixels.
uniform float line_width : hint_range(0.5, 8.0) = 1.8;
/// Glow bleed from a line, in pixels.
uniform float line_glow : hint_range(0.0, 40.0) = 9.0;
uniform float line_glow_strength : hint_range(0.0, 1.0) = 0.22;
/// Damage range a single line takes to draw itself across the slab.
uniform float line_fade : hint_range(0.02, 0.5) = 0.12;
/// Shortest a fracture can be, as a fraction of the slab's long axis.
uniform float min_length : hint_range(0.05, 1.0) = 0.25;
/// Longest a fracture can be.
uniform float max_length : hint_range(0.05, 2.0) = 0.9;
/// How far lines tilt off the short axis, in degrees. 90 = any angle.
uniform float angle_spread : hint_range(0.0, 90.0) = 55.0;
/// How crooked a line is. 0 = dead straight.
uniform float crookedness : hint_range(0.0, 30.0) = 7.0;
/// Number of kinks along a line.
uniform float kink_frequency : hint_range(0.5, 8.0) = 2.5;
uniform float seed : hint_range(0.0, 100.0) = 7.0;

group_uniforms ShatterFx;
uniform float cell_size : hint_range(8.0, 200.0) = 48.0;
uniform float burst_distance : hint_range(0.0, 400.0) = 120.0;
/// Sideways bias, so debris flies into the court.
uniform float burst_push : hint_range(-300.0, 300.0) = 90.0;
uniform float burst_fall : hint_range(-300.0, 300.0) = 60.0;
uniform float burst_spin : hint_range(0.0, 3.0) = 0.8;

vec2 hash2(vec2 p) {
	float n = sin(dot(p, vec2(41.3, 289.1)) + seed) * 43758.5453;
	return vec2(fract(n), fract(n * 1.618)) * 2.0 - 1.0;
}

float hash1(float n) {
	return fract(sin(n * 127.1 + seed * 13.7) * 43758.5453);
}

/// Distance in pixels to fracture line `i`, or a big number if it's not
/// there yet or the pixel is past the line's ends.
float fracture_distance(vec2 p, vec2 size, int i, float shattered) {
	float fi = float(i);

	// Stable per-line properties.
	float r_thresh = hash1(fi * 1.7);
	float r_angle  = hash1(fi * 3.3 + 11.0);
	float r_len    = hash1(fi * 5.1 + 23.0);
	float r_pos_x  = hash1(fi * 7.9 + 31.0);
	float r_pos_y  = hash1(fi * 9.4 + 47.0);
	float r_phase  = hash1(fi * 11.2 + 59.0);

	// Lines appear in order of their threshold, and draw outward from
	// their midpoint as `grown` rises.
	float grown = smoothstep(r_thresh, r_thresh + line_fade, damage);
	grown = max(grown, shattered);
	if (grown <= 0.0) {
		return 1e6;
	}

	// Mostly across the slab's short axis, tilted by up to angle_spread.
	float a = radians(90.0 + (r_angle * 2.0 - 1.0) * angle_spread);
	vec2 dir = vec2(cos(a), sin(a));
	vec2 nrm = vec2(-dir.y, dir.x);

	vec2 centre = vec2(r_pos_x * size.x, r_pos_y * size.y);
	float span = max(size.x, size.y);
	float half_len = span * mix(min_length, max_length, r_len) * 0.5 * grown;

	vec2 d = p - centre;
	float along = dot(d, dir);
	if (abs(along) > half_len) {
		return 1e6;
	}

	// Crooked: the line wanders sideways along its length.
	float wobble = sin(along / span * kink_frequency * TAU + r_phase * TAU)
		* crookedness;
	wobble += sin(along / span * kink_frequency * 2.7 * TAU + r_phase * 9.0)
		* crookedness * 0.4;

	float across = abs(dot(d, nrm) - wobble);

	// Taper to nothing at the two ends, so fractures thin out.
	float taper = smoothstep(half_len, half_len * 0.55, abs(along));
	return mix(1e6, across, taper);
}

void fragment() {
	vec2 size = 1.0 / max(abs(vec2(dFdx(UV.x), dFdy(UV.y))), vec2(1e-6));
	vec2 px = UV * size;

	float s = clamp(shatter, 0.0, 1.0);
	vec2 src = px;
	float shard_fade = 1.0;

	// --- Shatter: undo each shard's motion and sample where it came from ---
	if (s > 0.0) {
		vec2 cell = floor(px / cell_size);
		vec2 rnd = hash2(cell + vec2(13.0, 71.0));

		vec2 drift = normalize(rnd + vec2(0.001)) * burst_distance * s;
		drift.x += burst_push * s * s;
		drift.y += burst_fall * s * s;
		drift += rnd.yx * burst_spin * cell_size * s;

		src = px - drift;
		if (floor(src / cell_size) != cell) {
			discard;
		}
		shard_fade = 1.0 - s * s;
	}

	if (src.x < 0.0 || src.y < 0.0 || src.x > size.x || src.y > size.y) {
		discard;
	}

	// --- Nearest fracture line ---
	float best = 1e6;
	for (int i = 0; i < line_count; i++) {
		best = min(best, fracture_distance(src, size, i, s > 0.0 ? 1.0 : 0.0));
	}

	vec3 col = body_color.rgb;

	if (best < 1e5) {
		float core = 1.0 - smoothstep(line_width * 0.5 - 0.5,
			line_width * 0.5 + 0.5, best);
		float glow = exp(-best / max(line_glow, 0.001)) * line_glow_strength;

		float hit_d = distance(src, hit_point * size);
		float flash = hit_flash * exp(-hit_d / max(flash_radius, 1.0));

		col += crack_color.rgb * crack_brightness * (core + glow) * (1.0 + flash * 2.5);
	}

	// Damage warms the whole slab slightly, so it reads as stressed.
	col += crack_color.rgb * 0.12 * damage * damage;

	if (outline_width > 0.0) {
		float edge_d = min(min(src.x, size.x - src.x), min(src.y, size.y - src.y));
		float on_edge = 1.0 - smoothstep(outline_width - 1.0, outline_width + 1.0, edge_d);
		col = mix(col, edge_color.rgb * crack_brightness, on_edge);
	}

	COLOR = vec4(col, shard_fade);
}
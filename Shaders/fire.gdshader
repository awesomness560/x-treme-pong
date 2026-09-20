shader_type canvas_item;
render_mode blend_add;

group_uniforms Motion;
/// Unit vector the ball is travelling. The flame trails opposite this.
uniform vec2 flame_dir = vec2(1.0, 0.0);
/// 0 = round, 1 = long streak. Drive from ball speed.
uniform float stretch : hint_range(0.0, 1.0) = 0.0;
/// Tail length multiplier at full stretch.
uniform float stretch_amount : hint_range(1.0, 8.0) = 3.5;
/// How much it narrows as it stretches.
uniform float stretch_narrow : hint_range(0.0, 1.0) = 0.4;

group_uniforms Flame;
/// 0 = out, 1 = full. Drives size and brightness.
uniform float heat : hint_range(0.0, 1.0) = 1.0;
/// The one colour. The bands are brightness steps of it.
uniform vec4 flame_color : source_color = vec4(1.0, 0.45, 0.12, 1.0);
uniform float outer_brightness : hint_range(0.1, 6.0) = 1.1;
uniform float mid_brightness : hint_range(0.1, 8.0) = 2.4;
uniform float core_brightness : hint_range(0.1, 10.0) = 5.0;
/// How white the innermost band goes. 0 keeps it pure colour.
uniform float core_whiteness : hint_range(0.0, 1.0) = 0.55;
/// Inner band size, as a fraction of the outer edge. 1.0 hides it.
uniform float mid_size : hint_range(0.1, 1.0) = 0.68;
uniform float core_size : hint_range(0.05, 1.0) = 0.38;
/// Radius at full heat, in UV units. 0.5 fills the sprite.
uniform float radius : hint_range(0.05, 0.5) = 0.4;

group_uniforms Tongues;
/// How far the tongues push the edge in and out.
uniform float tongue_depth : hint_range(0.0, 1.0) = 0.6;
/// Number of tongues around the flame. Higher = finer.
uniform float tongue_scale : hint_range(1.0, 14.0) = 5.0;
/// How fast they flicker and flow.
uniform float flow_speed : hint_range(0.0, 8.0) = 2.6;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453) * 2.0 - 1.0;
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(dot(hash2(i), f), dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
		mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
			dot(hash2(i + vec2(1.0)), f - vec2(1.0)), u.x),
		u.y) * 0.5 + 0.5;
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 3; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	if (heat <= 0.001) {
		discard;
	}

	// Rotate into flame space: +x is the direction of travel.
	vec2 d = normalize(flame_dir + vec2(1e-5));
	vec2 p = UV - vec2(0.5);
	vec2 fp = vec2(dot(p, d), dot(p, vec2(-d.y, d.x)));

	// Stretch: the half behind the ball lengthens, the front stays tight.
	float tail_len = 1.0 + (stretch_amount - 1.0) * stretch;
	float across = 1.0 + stretch_narrow * stretch * 2.0;
	vec2 sp = vec2(fp.x < 0.0 ? fp.x / tail_len : fp.x * 1.3, fp.y * across);

	float r = radius * (0.4 + 0.6 * heat);

	// Teardrop: centre sits forward, so the mass hangs behind.
	sp.x -= r * 0.25;
	float dist = length(sp);

	// Tongues push the boundary in and out, more behind the ball.
	float ang = atan(sp.y, sp.x);
	vec2 np = vec2(ang * tongue_scale, sp.x * tongue_scale * 1.5 + TIME * flow_speed);	float lick = fbm(np) - 0.5;

	float behind = clamp(-sp.x / max(r, 0.001) * 0.5 + 0.5, 0.0, 1.0);
	float reach = tongue_depth * (0.35 + 1.3 * behind);

	// One wobbling boundary, not a gradient.
	float edge = r * (1.0 + reach * lick * 2.0);

	// Hard cut, anti-aliased to a single pixel.
	float aa = fwidth(dist) * 1.2;
	float outer = 1.0 - smoothstep(edge - aa, edge + aa, dist);
	if (outer <= 0.0) {
		discard;
	}

	float mid = 1.0 - smoothstep(edge * mid_size - aa, edge * mid_size + aa, dist);
	float core = 1.0 - smoothstep(edge * core_size - aa, edge * core_size + aa, dist);

	// Flat fills, no gradient between the bands.
	vec3 col = flame_color.rgb * outer_brightness;
	col = mix(col, flame_color.rgb * mid_brightness, mid);
	col = mix(col, mix(flame_color.rgb, vec3(1.0), core_whiteness) * core_brightness, core);

	COLOR = vec4(col * heat, outer * flame_color.a);
}
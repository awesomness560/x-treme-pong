shader_type canvas_item;

group_uniforms Progress;
/// 0 to 1. The script eases this toward the real charge.
uniform float fill : hint_range(0.0, 1.0) = 0.0;
/// Bar fractions per second, smoothed. Drives the spark's energy.
uniform float rate : hint_range(0.0, 3.0) = 0.0;
/// 0 to 1, pulsed by the script on a gain. A flash at the leading edge.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
/// 0 to 1, the firing wipe. 1 = fully emptied.
uniform float sweep : hint_range(0.0, 1.0) = 0.0;
/// 0 = charging, 1 = armed. The script pulses this for the gold beat.
uniform float armed : hint_range(0.0, 1.0) = 0.0;

group_uniforms Look;
uniform vec4 fill_color : source_color = vec4(1.0, 0.25, 0.75, 1.0);
uniform vec4 armed_color : source_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform vec4 empty_color : source_color = vec4(0.08, 0.04, 0.09, 1.0);
/// Brightness of the filled bar at rest. Above 1 blooms.
uniform float base_brightness : hint_range(0.2, 4.0) = 0.9;
/// Extra brightness as the bar approaches full.
uniform float anticipation_boost : hint_range(0.0, 3.0) = 1.2;
/// Where anticipation starts.
uniform float anticipation_from : hint_range(0.0, 1.0) = 0.75;
/// Shears the whole bar. 0 = straight.
uniform float slant : hint_range(-2.0, 2.0) = 0.0;
uniform float edge_softness : hint_range(0.0, 4.0) = 1.0;
/// Outline thickness in pixels. 0 = no border.
uniform float border_thickness : hint_range(0.0, 10.0) = 1.5;
uniform vec4 border_color : source_color = vec4(0.6, 0.3, 0.55, 1.0);
/// How much the border brightens when armed.
uniform float border_armed_boost : hint_range(0.0, 4.0) = 1.6;
/// Inset the fill so it sits inside the border rather than under it.
uniform float border_padding : hint_range(0.0, 8.0) = 1.0;

group_uniforms Spark;
/// Width of the spark at the fill edge, in pixels.
uniform float spark_width : hint_range(2.0, 60.0) = 14.0;
/// Extra width when climbing fast.
uniform float spark_rate_width : hint_range(0.0, 60.0) = 26.0;
/// How hard the spark flickers. Scales with rate.
uniform float spark_jitter : hint_range(0.0, 1.0) = 0.6;
uniform float spark_speed : hint_range(0.0, 60.0) = 22.0;

float hash(float n) {
	return fract(sin(n * 91.3458) * 47453.5453);
}

void fragment() {
	vec2 size = 1.0 / max(abs(vec2(dFdx(UV.x), dFdy(UV.y))), vec2(1e-6));
	vec2 raw = UV * size;

	// Inset so the shear never clips the ends.
	float margin = abs(slant) * size.y * 0.5;
	vec2 lay = vec2(max(size.x - margin * 2.0, 1.0), size.y);

	// Shear, then flip x so the bar fills right to left.
	vec2 px = vec2(raw.x - slant * (raw.y - size.y * 0.5) - margin, raw.y);
	px.x = lay.x - px.x;

		// Distance to the nearest edge of the parallelogram, in pixels.
	float inside = min(min(px.x, lay.x - px.x), min(px.y, lay.y - px.y));
	float shape = smoothstep(-edge_softness, edge_softness, inside);
	if (shape <= 0.0) {
		discard;
	}

	// The fill area sits inside the border plus its padding.
	float inset = border_thickness + border_padding;
	vec2 inner = vec2(max(lay.x - inset * 2.0, 1.0), max(lay.y - inset * 2.0, 1.0));
	vec2 ipx = px - vec2(inset);
	float in_inner = min(min(ipx.x, inner.x - ipx.x), min(ipx.y, inner.y - ipx.y));
	float inner_mask = smoothstep(-edge_softness, edge_softness, in_inner);

	float t = ipx.x / inner.x;         // 0 at the right end, 1 at the left
	float edge = fill * (1.0 - sweep); // the sweep wipes the fill away

	vec3 body = mix(fill_color.rgb, armed_color.rgb, armed);

	float anticip = smoothstep(anticipation_from, 1.0, fill);
	float bright = base_brightness + anticipation_boost * anticip + armed * 0.8;

	// --- The bar itself, inside the border ---
	float filled = 1.0 - smoothstep(-edge_softness, edge_softness, (t - edge) * inner.x);
	vec3 col = mix(empty_color.rgb, body * bright, filled) * inner_mask;

	// --- Spark at the leading edge ---
	float energy = clamp(rate * 2.0, 0.0, 1.0);
	float width = spark_width + spark_rate_width * energy;
	float d = abs(t - edge) * inner.x;

	float flick = 1.0 - spark_jitter * energy * hash(floor(TIME * spark_speed) + px.y * 0.05);
	float spark = exp(-d / max(width, 0.001)) * flick;
	spark *= 0.35 + 1.4 * energy + armed * 0.6;
	spark += flash * exp(-d / (width * 3.0)) * 2.0;

	if (edge > 0.001 && edge < 0.999) {
		col += mix(body, vec3(1.0), 0.6 * energy + flash) * spark * inner_mask;
	}

	if (sweep > 0.0 && sweep < 1.0) {
		col += vec3(1.0) * exp(-d / 18.0) * 2.5 * inner_mask;
	}

	// --- Border: the ring between the outer shape and the inner area ---
	if (border_thickness > 0.0) {
		float band = 1.0 - smoothstep(-edge_softness, edge_softness,
			inside - border_thickness);
		vec3 bc = mix(border_color.rgb, armed_color.rgb * border_armed_boost, armed);
		// A little of the gain flash bleeds into the border.
		bc += vec3(1.0) * flash * 0.5;
		col = mix(col, bc, band * shape);
	}

	COLOR = vec4(col, shape);
}
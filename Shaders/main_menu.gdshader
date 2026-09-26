shader_type canvas_item;
render_mode blend_mix;

uniform vec2 rect_size = vec2(420.0, 190.0);

uniform vec4 frame_color : source_color = vec4(0.27, 0.25, 0.48, 1.0);
uniform vec4 shard_color : source_color = vec4(1.0, 0.24, 0.78, 1.0);
uniform float thickness : hint_range(1.0, 16.0) = 3.0;

uniform float damage : hint_range(0.0, 1.0) = 0.6;
uniform float creep_speed : hint_range(0.0, 0.1) = 0.0;

uniform float glow_strength : hint_range(1.0, 6.0) = 2.4;
uniform float drift_amount : hint_range(0.0, 20.0) = 6.0;   // how far shards float out
uniform float drift_speed  : hint_range(0.0, 3.0) = 0.6;
uniform float jitter_amount: hint_range(0.0, 4.0) = 1.0;    // per-shard shake

// Bites taken out of the frame: xy = offset from top-right corner, zw = size.
// x grows left (negative), y grows down (positive).
const vec4 BITES[6] = vec4[6](
    vec4(  -4.0,  34.0,  8.0, 26.0),
    vec4(  -4.0,  74.0,  8.0, 14.0),
    vec4( -30.0,  -4.0, 22.0,  8.0),
    vec4( -66.0,  -4.0, 14.0,  8.0),
    vec4(  -4.0, 104.0,  8.0, 20.0),
    vec4( -94.0,  -4.0,  9.0,  8.0)
);

// Detached shards: xy = base offset from top-right, zw = size.
const vec4 SHARDS[7] = vec4[7](
    vec4( -16.0,  30.0,  7.0,  7.0),
    vec4( -28.0,  48.0,  5.0, 10.0),
    vec4( -14.0,  70.0,  9.0,  5.0),
    vec4( -40.0,  16.0,  4.0,  4.0),
    vec4( -34.0,  92.0,  6.0,  6.0),
    vec4( -56.0,  60.0,  3.0,  8.0),
    vec4( -50.0, 118.0,  5.0,  5.0)
);

float hash(float n) {
    return fract(sin(n * 78.233) * 43758.5453);
}

// 1 inside the rect, 0 outside, antialiased
float rect_mask(vec2 p, vec2 pos, vec2 size) {
    vec2 d = abs(p - (pos + size * 0.5)) - size * 0.5;
    float outside = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
    return 1.0 - smoothstep(-0.8, 0.8, outside);
}

void fragment() {
    vec2 px = UV * rect_size;
    float dmg = clamp(damage + TIME * creep_speed, 0.0, 1.0);
    vec2 corner = vec2(rect_size.x, 0.0);

    // --- frame outline as a rectangular ring ---
    vec2 inner_lo = vec2(thickness);
    vec2 inner_hi = rect_size - thickness;
    float inside_outer = rect_mask(px, vec2(0.0), rect_size);
    float inside_inner = rect_mask(px, inner_lo, inner_hi - inner_lo);
    float frame = inside_outer * (1.0 - inside_inner);

    // --- chew rectangular bites out of it ---
    for (int i = 0; i < 6; i++) {
        float t = float(i) / 6.0;
        float on = step(t * 0.8, dmg);
        vec2 pos = corner + BITES[i].xy;
        frame *= 1.0 - rect_mask(px, pos, BITES[i].zw) * on;
    }

    // --- detached shards drifting outward ---
    float shards = 0.0;
    for (int i = 0; i < 7; i++) {
        float t = float(i) / 7.0;
        float reveal = smoothstep(t * 0.85, t * 0.85 + 0.15, dmg);
        if (reveal <= 0.001) { continue; }

        float seed = float(i) * 3.77;
        // slow outward float, away from the corner
        vec2 dir = normalize(vec2(1.0, -0.35) + vec2(hash(seed) - 0.5, hash(seed + 1.0) - 0.5));
        float phase = TIME * drift_speed + hash(seed + 2.0) * 6.28;
        vec2 drift = dir * (sin(phase) * 0.5 + 0.5) * drift_amount * reveal;

        // fast small jitter so it never sits still
        vec2 jitter = vec2(
            sin(TIME * 17.0 + seed * 5.1),
            cos(TIME * 21.0 + seed * 3.3)
        ) * jitter_amount;

        vec2 pos = corner + SHARDS[i].xy + drift + jitter;
        shards = max(shards, rect_mask(px, pos, SHARDS[i].zw) * reveal);
    }

    vec3 col = frame_color.rgb * frame;
    col = mix(col, shard_color.rgb * glow_strength, shards);
    float alpha = max(frame * frame_color.a, shards * shard_color.a);

    COLOR = vec4(col, alpha);
}
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 1.0;

uniform vec4 fill_color : source_color = vec4(0.8, 0.2, 0.2, 1.0);
uniform vec4 background_color : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float border_thickness : hint_range(0.0, 0.2) = 0.05;
uniform float edge_softness : hint_range(0.001, 0.05) = 0.01;

float heart(vec2 uv) {
	// Normalize UV to [-1,1]
	uv = uv * 2.0 - vec2(1.0);
	uv.y *= -1.0;

	// Slight vertical nudge (less aggressive than before)
	uv.y -= 0.01;

	float x = uv.x;
	float y = uv.y;
	float a = x * x + y * y - 0.23;
	return a * a * a - x * x * y * y * y;
}

void fragment() {
	vec2 uv = UV;
	float h = heart(uv);
	if (h > 0.0)
		discard;

	vec4 color = background_color;

	// Fill from top to bottom
	if (uv.y >= (1.0 - progress)) {
		color = fill_color;
	}

	// Border smoothing
	float edge = smoothstep(-edge_softness, edge_softness, h + border_thickness);
	color = mix(border_color, color, edge);

	COLOR = color;
}

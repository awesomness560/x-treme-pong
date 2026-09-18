shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float thickness : hint_range(0.5, 40.0) = 3.0;
uniform float dash_length : hint_range(1.0, 200.0) = 16.0;
uniform float gap_length : hint_range(0.0, 200.0) = 14.0;
uniform float softness : hint_range(0.0, 4.0) = 1.0;

void fragment() {
	// Work in pixels so the dashes don't stretch with the rect's size.
	vec2 size = 1.0 / max(abs(vec2(dFdx(UV.x), dFdy(UV.y))), vec2(1e-6));
	vec2 px = UV * size;

	// Horizontal distance from the center line.
	float d = abs(px.x - size.x * 0.5);
	float line = 1.0 - smoothstep(thickness * 0.5 - softness, thickness * 0.5 + softness, d);

	// Dash pattern down the line, centered so it's symmetrical top to bottom.
	float period = dash_length + gap_length;
	float phase = mod(px.y - size.y * 0.5 + dash_length * 0.5, period);
	float dash = 1.0 - smoothstep(dash_length - softness, dash_length + softness, phase);

	COLOR = vec4(line_color.rgb, line_color.a * line * dash);
}
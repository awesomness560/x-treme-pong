shader_type canvas_item;

uniform vec4 left_color : source_color = vec4(0.10, 0.06, 0.14, 1.0);
uniform vec4 right_color : source_color = vec4(0.02, 0.10, 0.16, 1.0);
uniform vec4 line_color : source_color = vec4(1.0, 0.24, 0.78, 0.6);
uniform float top_x = 0.62;      // where the split meets the top edge
uniform float bottom_x = 0.48;   // where it meets the bottom edge
uniform float line_width = 0.003;

void fragment() {
    float split = mix(top_x, bottom_x, UV.y);
    float d = UV.x - split;
    float edge = fwidth(d);

    vec4 col = mix(left_color, right_color, smoothstep(-edge, edge, d));
    float line = 1.0 - smoothstep(line_width - edge, line_width + edge, abs(d));
    COLOR = mix(col, line_color, line * line_color.a);
}
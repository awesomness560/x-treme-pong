shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 fill_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float border_width : hint_range(0.0, 0.5) = 0.02;

void fragment() {
    // Check if the current pixel is within the border boundaries
    bool is_horizontal_border = (UV.x < border_width || UV.x > (1.0 - border_width));
    bool is_vertical_border = (UV.y < border_width || UV.y > (1.0 - border_width));
    
    if (is_horizontal_border || is_vertical_border) {
        COLOR = border_color;
    } else {
        COLOR = fill_color;
    }
}

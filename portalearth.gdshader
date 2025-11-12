shader_type canvas_item;

uniform float time_speed = 2.0;

void fragment() {
    COLOR = texture(TEXTURE, UV);
    COLOR.rgb += vec3(0.1 * sin(TIME * time_speed + UV.x * 6.0));
}

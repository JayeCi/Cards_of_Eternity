shader_type spatial;

render_mode blend_add, cull_disabled, unshaded;

uniform float speed : hint_range(0.1, 5.0) = 1.8;
uniform float swirl_strength : hint_range(0.0, 10.0) = 5.0;
uniform float distortion_amount : hint_range(0.0, 1.0) = 0.3;
uniform vec4 inner_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform vec4 outer_color : source_color = vec4(0.0, 0.1, 0.2, 1.0);
uniform float ring_glow_strength : hint_range(0.0, 3.0) = 1.5;
uniform float pulse_speed : hint_range(0.1, 10.0) = 2.5;

void fragment() {
    vec2 uv = UV * 2.0 - 1.0;
    float r = length(uv);
    float angle = atan(uv.y, uv.x);
    float t = TIME * speed;

    // swirl + radial distortion
    angle += sin(t + r * swirl_strength) * distortion_amount;
    uv = vec2(cos(angle), sin(angle)) * r;

    // color glow and swirl pulse
    float wave = sin(r * 10.0 - t * 3.0) * 0.5 + 0.5;
    float glow = smoothstep(0.9, 0.3, r) * wave;

    vec3 core_color = mix(outer_color.rgb, inner_color.rgb, glow);
    float pulse = 0.6 + 0.4 * sin(t * pulse_speed);

    // outer ring highlight
    float ring = pow(1.0 - smoothstep(0.7, 0.9, r), 3.0) * ring_glow_strength;

    // combine color layers
    vec3 final_color = core_color * pulse + ring * inner_color.rgb;

    ALBEDO = final_color;
    ALPHA = smoothstep(0.9, 0.4, 1.0 - r) * pulse;
}

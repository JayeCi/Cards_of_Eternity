shader_type sky;

uniform float speed = 0.05;
uniform sampler2D noise_tex;

void fragment() {
    // Use the ray direction provided by the sky shader
    vec3 dir = normalize(RAY_DIRECTION);
    vec2 uv = dir.xz * 0.5 + 0.5; // map XZ to UV space

    // Scroll horizontally over time
    uv.x += TIME * speed;

    // Sample the noise texture
    vec3 noise = texture(noise_tex, uv).rgb;

    // Blend between base and highlight colors
    vec3 base_color = vec3(0.1, 0.2, 0.4);
    vec3 highlight = vec3(0.6, 0.8, 1.0);
    vec3 color = mix(base_color, highlight, noise.r);

    COLOR = vec4(color, 1.0);
}

shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, unshaded;


//Noise and color uniforms
uniform sampler2D noise_tex : repeat_enable;
uniform vec4 root_color : source_color = vec4(1.0, 0.75, 0.3, 1.0);
uniform vec4 tip_color  : source_color = vec4(1.0, 0.03, 0.001, 1.0);
uniform float poster_color : hint_range(0.0, 16.0) = 6.0;

//Fire
uniform float fire_alpha : hint_range(0.0, 1.0) = 1.0;
uniform vec2  fire_speed = vec2(0.015, 0.5);
uniform float fire_aperture : hint_range(0.0, 5.0) = 0.22;

//Vignette
uniform float vignette_radius : hint_range(0.0, 1.0) = 0.25;
uniform float vignette_falloff : hint_range(0.0, 0.5) = 0.25;
uniform float noise_influence : hint_range(0.0, 1.0) = 1.0;

vec2 polar_coordinates(vec2 uv, vec2 center, float zoom, float repeat) {
    vec2 d = uv - center;
    float r = length(d) * 2.0;
    float theta = atan(d.y, d.x) * (1.0 / (2.0 * 3.1416));
    return mod(vec2(r * zoom, theta * repeat), 1.0);
}

void fragment() {
    vec2 uv = UV;
    vec2 center = vec2(0.5);

    vec2 p = polar_coordinates(uv, center, 1.0, 1.0);

    // Movement
    p.x += TIME * fire_speed.y;
    p.y += sin(TIME) * fire_speed.x;

    float n = texture(noise_tex, p).r;

    float dist = distance(uv, center);
    float edge = clamp(1.0 - dist, 0.0, 1.0);
    float noise_val = edge * (((edge + fire_aperture) * n - fire_aperture) * 75.0);
    noise_val = clamp(noise_val, 0.0, 1.0);

    float effective_radius = vignette_radius + n * noise_influence * vignette_falloff;
    float mask = smoothstep(effective_radius + vignette_falloff, effective_radius, 1.0 - dist);

    float alpha = noise_val * fire_alpha * mask;

    vec3 fire_rgb;
    if (poster_color >= 1.0) {
        float q = floor(n * poster_color) / poster_color;
        fire_rgb = mix(tip_color.rgb, root_color.rgb, q);
        alpha = floor(alpha * poster_color) / poster_color;
    } else {
        fire_rgb = mix(tip_color.rgb, root_color.rgb, n);
    }

    EMISSION = fire_rgb * alpha * 1.5; // extra glow looks better in 3D
    ALBEDO = fire_rgb;
    ALPHA = alpha;
}

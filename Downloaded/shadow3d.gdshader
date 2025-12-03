shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// --------------------
// ENABLE / DISABLE
// --------------------
uniform bool shadow_enabled = true; // Turn OFF in inspector to disable
uniform vec3 disabled_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float disabled_emission : hint_range(0.0, 5.0) = 0.0;

// --------------------
// STYLE CONTROLS
// --------------------
uniform vec3 core_color : source_color = vec3(0.0, 0.0, 0.0);     // True shadow color
uniform float core_darkness : hint_range(0.0, 2.0) = 1.5;

uniform vec3 aura_color : source_color = vec3(0.15, 0.05, 0.25);  // Purple-dark aura
uniform float aura_strength : hint_range(0.0, 5.0) = 2.5;
uniform float aura_power : hint_range(0.5, 8.0) = 2.5;

uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;
uniform float pulse_amount : hint_range(0.0, 2.0) = 0.8;

uniform float distortion_speed : hint_range(0.0, 10.0) = 2.5;
uniform float distortion_scale : hint_range(0.1, 10.0) = 2.5;
uniform float distortion_strength : hint_range(0.0, 2.0) = 0.7;

// WORLD POS PASS
varying vec3 world_pos;

// --------------------
// NOISE FUNCTION
// --------------------
float noise(vec3 p) {
    p = fract(p * 0.3183099 + .1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec3 final_albedo;
    vec3 final_emission;

    if (!shadow_enabled) {
        // Simple flat look when disabled
        final_albedo = disabled_color;
        final_emission = disabled_color * disabled_emission;
    } else {
        vec3 N = normalize(NORMAL);
        vec3 V = normalize(-VIEW);

        // 1. ULTRA DARK CORE
        vec3 color = core_color * core_darkness;

        // 2. AURA (Shadow Rim Light)
        float fres = 1.0 - max(dot(N, V), 0.0);
        fres = pow(fres, aura_power);
        vec3 aura = aura_color * fres * aura_strength;

        // 3. DARKNESS PULSE (breathing effect)
        float pulse = (sin(TIME * pulse_speed + world_pos.y * 0.5) * 0.5 + 0.5);
        pulse = mix(1.0, pulse, pulse_amount);

        // 4. DISTORTION / LIVING SHADOW
        float dist_noise = noise(world_pos * distortion_scale + TIME * distortion_speed);
        float dark_warp = 1.0 - dist_noise * distortion_strength;

        // FINAL EMISSION = Aura + pulsing movement
        vec3 shadow_emission = (aura * pulse) * dark_warp;

        final_albedo = color * dark_warp;
        final_emission = shadow_emission;
    }

    ALBEDO = final_albedo;
    EMISSION = final_emission;
}

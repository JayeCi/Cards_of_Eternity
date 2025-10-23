shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.8, 0.4, 1.0); // glow tint
uniform float glow_strength : hint_range(0.0, 5.0, 0.1) = 1.5;
uniform float glow_size : hint_range(0.0, 2.0, 0.1) = 0.4;

uniform float shimmer_speed : hint_range(0.1, 10.0, 0.1) = 2.0;
uniform float shimmer_intensity : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform vec2 shimmer_direction = vec2(1.0, 0.0); // direction of shimmer flow

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // 🔆 Soft glow based on alpha falloff
    float dist = length(UV - vec2(0.5));
    float glow = smoothstep(0.7 + glow_size, 0.4 + glow_size, dist);
    vec4 glow_col = glow_color * glow_strength * glow * tex.a;

    // ✨ Animated shimmer overlay (sinusoidal brightness wave)
    float shimmer_wave = sin((UV.x * shimmer_direction.x + UV.y * shimmer_direction.y) * 15.0 + TIME * shimmer_speed);
    shimmer_wave = (shimmer_wave * 0.5 + 0.5) * shimmer_intensity;

    // 🌀 Combine everything
    vec4 color = tex;
    color.rgb += glow_col.rgb;
    color.rgb += shimmer_wave * glow_color.rgb;

    COLOR = vec4(color.rgb, tex.a);
}

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 fog_color : source_color = vec4(0.1, 0.1, 0.15, 0.8);
uniform vec4 edge_color : source_color = vec4(0.3, 0.3, 0.4, 1.0);
uniform float fog_density : hint_range(0.0, 1.0) = 0.7;
uniform float edge_glow : hint_range(0.0, 2.0) = 0.5;
uniform float animation_speed : hint_range(0.0, 2.0) = 0.3;
uniform sampler2D noise_texture;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Create animated fog effect
	vec2 uv = UV * 2.0 + vec2(TIME * animation_speed * 0.1, TIME * animation_speed * 0.05);
	float noise1 = texture(noise_texture, uv).r;
	float noise2 = texture(noise_texture, uv * 1.5 + vec2(TIME * animation_speed * 0.15, 0.0)).r;
	float combined_noise = (noise1 + noise2) * 0.5;

	// Edge detection for rim lighting
	float fresnel = pow(1.0 - dot(NORMAL, VIEW), 3.0);

	// Mix fog color with edge glow
	vec3 final_color = mix(fog_color.rgb, edge_color.rgb, fresnel * edge_glow);
	final_color += combined_noise * 0.1; // Add noise variation

	ALBEDO = final_color;
	ALPHA = fog_color.a * (0.7 + combined_noise * 0.3);
	EMISSION = edge_color.rgb * fresnel * edge_glow * 0.3;
	ROUGHNESS = 0.9;
}

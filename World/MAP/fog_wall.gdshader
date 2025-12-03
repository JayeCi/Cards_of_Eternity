shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// Fog appearance
uniform vec4 fog_color : source_color = vec4(0.7, 0.7, 0.8, 0.9);
uniform float fog_density : hint_range(0.0, 1.0) = 0.85;
uniform float edge_softness : hint_range(0.0, 1.0) = 0.3;

// Animation
uniform float flow_speed : hint_range(0.0, 5.0) = 0.5;
uniform float swirl_speed : hint_range(0.0, 5.0) = 0.3;
uniform float noise_scale : hint_range(0.1, 10.0) = 2.0;
uniform float distortion_strength : hint_range(0.0, 1.0) = 0.2;

// Glow effect
uniform vec4 glow_color : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform float glow_strength : hint_range(0.0, 2.0) = 0.3;

// Hash function for noise
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.13);
	p3 += dot(p3, p3.yzx + 3.333);
	return fract((p3.x + p3.y) * p3.z);
}

// 2D noise
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);

	f = f * f * (3.0 - 2.0 * f);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal Brownian Motion for layered noise
float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;

	for (int i = 0; i < 4; i++) {
		value += amplitude * noise(p * frequency);
		frequency *= 2.0;
		amplitude *= 0.5;
	}

	return value;
}

void fragment() {
	// Get UV coordinates
	vec2 uv = UV;

	// Create flowing fog effect
	vec2 flow_offset = vec2(TIME * flow_speed * 0.1, TIME * flow_speed * 0.05);
	vec2 swirl_offset = vec2(
		sin(TIME * swirl_speed + uv.y * 3.14159) * 0.1,
		cos(TIME * swirl_speed * 0.8 + uv.x * 3.14159) * 0.1
	);

	// Sample noise at different scales
	vec2 noise_uv = (uv + flow_offset + swirl_offset) * noise_scale;
	float fog_noise1 = fbm(noise_uv);
	float fog_noise2 = fbm(noise_uv * 1.5 + vec2(100.0, 100.0));

	// Combine noise layers
	float fog_pattern = (fog_noise1 * 0.6 + fog_noise2 * 0.4);

	// Add some distortion based on noise
	float distortion = (fog_pattern - 0.5) * distortion_strength;
	uv.x += distortion;

	// Soften edges (top and bottom)
	float edge_mask = 1.0 - abs(uv.y - 0.5) * 2.0;
	edge_mask = pow(edge_mask, 1.0 - edge_softness);

	// Calculate final fog alpha
	float fog_alpha = fog_pattern * fog_density * edge_mask;
	fog_alpha = clamp(fog_alpha, 0.0, 1.0);

	// Add subtle glow to the fog
	vec3 final_color = mix(fog_color.rgb, glow_color.rgb, fog_pattern * glow_strength);

	// Output
	ALBEDO = final_color;
	ALPHA = fog_alpha * fog_color.a;

	// Add emission for ethereal glow
	EMISSION = glow_color.rgb * glow_strength * fog_pattern * 0.5;
}

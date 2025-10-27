shader_type spatial;

// ======================================================
// 🎨 Rendering setup
// ======================================================
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// ======================================================
// 🌊 Wave Controls
// ======================================================
uniform float wave_speed : hint_range(0.1, 5.0) = 1.5;
uniform float wave_strength : hint_range(0.01, 0.5) = 0.08;
uniform float wave_scale : hint_range(0.1, 5.0) = 1.2;

// ======================================================
// 💧 Color and Depth
// ======================================================
uniform vec3 shallow_color : source_color = vec3(0.1, 0.5, 0.7);
uniform vec3 deep_color : source_color = vec3(0.0, 0.1, 0.25);
uniform float depth_fade : hint_range(0.1, 5.0) = 1.5;

// ======================================================
// ✨ Reflection / Fresnel
// ======================================================
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.45;
uniform float fresnel_strength : hint_range(0.0, 3.0) = 1.5;

// ======================================================
// 🫧 Foam
// ======================================================
uniform float foam_intensity : hint_range(0.0, 1.0) = 0.25;
uniform float foam_scale : hint_range(0.5, 10.0) = 3.0;
uniform float foam_speed : hint_range(0.1, 3.0) = 1.0;

// ======================================================
// Internal variables
// ======================================================
varying vec3 world_pos;

// ======================================================
// 🏔️ Vertex: wave motion
// ======================================================
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wave =
		sin(world_pos.x * wave_scale + TIME * wave_speed) +
		cos(world_pos.z * wave_scale * 1.2 + TIME * wave_speed * 0.8);
	VERTEX.y += wave * wave_strength;
}

// ======================================================
// 🔹 Simple pseudo-noise
// ======================================================
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x)
	     + (c - a) * u.y * (1.0 - u.x)
	     + (d - b) * u.x * u.y;
}

// ======================================================
// 💧 Fragment
// ======================================================
void fragment() {
	vec3 view_dir = normalize(-VERTEX);
	float fresnel = pow(1.0 - dot(view_dir, NORMAL), 3.0) * fresnel_strength;

	// Depth-based tint
	float depth = clamp(1.0 - (VERTEX.y / depth_fade), 0.0, 1.0);
	vec3 water_col = mix(shallow_color, deep_color, depth);

	// Procedural foam
	vec2 foam_uv = world_pos.xz * foam_scale + TIME * foam_speed;
	float foam = smoothstep(0.6, 0.9, noise(foam_uv));
	vec3 foam_col = mix(water_col, vec3(1.0), foam * foam_intensity);

	// Fresnel reflection blend
	ALBEDO = mix(foam_col, vec3(1.0), fresnel * reflection_strength);

	// Material look
	ROUGHNESS = 0.05;
	METALLIC = 0.4;
	SPECULAR = 0.9;
	EMISSION = ALBEDO * 0.05 * fresnel;

	// 💧 Transparency — fade based on depth
	ALPHA = mix(0.9, 0.4, depth);
}

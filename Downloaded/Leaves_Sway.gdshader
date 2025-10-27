shader_type spatial;

// ======================================================
// 🌬️ Wind Sway Controls
// ======================================================
uniform float sway_strength : hint_range(0.0, 1.0) = 0.25;
uniform float sway_speed : hint_range(0.1, 5.0) = 1.2;
uniform float sway_scale : hint_range(0.1, 5.0) = 0.8;
uniform vec3 wind_direction = vec3(1.0, 0.0, 0.3);

// ======================================================
// 🌿 Texturing
// ======================================================
uniform sampler2D albedo_texture : source_color;   // your leaf/bush texture
uniform float texture_brightness : hint_range(0.0, 2.0) = 1.0;
uniform bool use_vertex_color = true;

// ======================================================
// 💡 Material properties
// ======================================================
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float specular : hint_range(0.0, 1.0) = 0.2;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.3;

// ======================================================
// Internal
// ======================================================
varying vec3 world_pos;
varying vec2 uv_interp;

// ======================================================
// 🏔️ Vertex: apply sway motion
// ======================================================
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	uv_interp = UV;

	float wave = sin((world_pos.x + world_pos.z) * sway_scale + TIME * sway_speed);
	float height_factor = clamp(VERTEX.y, 0.0, 1.0);

	VERTEX.xyz += wind_direction * wave * sway_strength * height_factor;
}

// ======================================================
// 🌿 Fragment: keep texture, add lighting
// ======================================================
void fragment() {
	vec4 tex = texture(albedo_texture, uv_interp);

	if (use_vertex_color) {
		ALBEDO = tex.rgb * COLOR.rgb * texture_brightness;
	} else {
		ALBEDO = tex.rgb * texture_brightness;
	}

	// Transparency cutoff for leaf shapes
	if (tex.a < alpha_cutoff) {
		discard;
	}

	ALPHA = tex.a;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}

shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, blend_add;

uniform vec4 line_color : source_color = vec4(0.5, 0.7, 1.0, 0.8);
uniform vec4 glow_color : source_color = vec4(0.7, 0.9, 1.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 3.0) = 1.5;
uniform float flow_speed : hint_range(0.0, 5.0) = 2.0;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.0;
uniform float line_width : hint_range(0.01, 1.0) = 0.1;

varying vec2 uv_coords;
varying float distance_along_line;

void vertex() {
	uv_coords = UV;
	distance_along_line = UV.x;
}

void fragment() {
	// Animated flow effect - moves along the line
	float flow = fract(distance_along_line - TIME * flow_speed * 0.2);

	// Pulse effect - entire line pulses
	float pulse = sin(TIME * pulse_speed) * 0.3 + 0.7;

	// Create bright spots that flow along the line
	float flow_spots = smoothstep(0.7, 0.9, flow) * smoothstep(1.0, 0.9, flow);

	// Edge fade for smooth line appearance
	float edge_fade = 1.0 - abs(uv_coords.y * 2.0 - 1.0);
	edge_fade = pow(edge_fade, 2.0);

	// Combine effects
	vec3 final_color = line_color.rgb;
	final_color += glow_color.rgb * flow_spots * glow_intensity;
	final_color *= pulse;

	float alpha = line_color.a * edge_fade * pulse;
	alpha += flow_spots * 0.5;

	ALBEDO = final_color;
	ALPHA = clamp(alpha, 0.0, 1.0);
	EMISSION = final_color * glow_intensity * 0.5;
}

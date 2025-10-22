shader_type canvas_item;

uniform float time_speed = 2.5;
uniform float ripple_strength = 0.15;
uniform vec4 base_color : source_color = vec4(0.2, 0.2, 0.8, 0.5);

void fragment() {
	vec2 uv = UV;
	float wave = sin(uv.x * 15.0 + TIME * time_speed) * cos(uv.y * 15.0 + TIME * time_speed);
	vec2 ripple_uv = uv + vec2(wave * ripple_strength, wave * ripple_strength);
	float mask = smoothstep(0.0, 1.0, 1.0 - length(ripple_uv - 0.5) * 1.2);

	COLOR = base_color;
	COLOR.rgb += wave * 0.1;
	COLOR.a *= mask;
}

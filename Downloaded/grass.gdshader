shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled;

// -----------------------------------
const int TOTAL_GRASS_VARIANTS = 4;

uniform bool enable_details = true;
uniform bool billboard_y = false;
uniform vec3 detail_color:source_color = vec3(0.2);

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;

uniform sampler2D variants[TOTAL_GRASS_VARIANTS];

instance uniform int variant_index;
// -----------------------------------

void vertex(){
	// Wind sway
	float root = (1.0 - UV.y);
	vec3 sway;
	sway.x = sin(NODE_POSITION_WORLD.x + TIME * 1.25 + UV.y) * root * 0.10;
	sway.y = sin(NODE_POSITION_WORLD.x + TIME * 0.6 + UV.y) * root * 0.08;
	sway.z = cos(NODE_POSITION_WORLD.z + TIME * 0.45 + UV.y) * root * 0.15;

	if(billboard_y){
		VERTEX += sway;
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
			vec4(0.0, 1.0, 0.0, 0.0),
			vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
			MODEL_MATRIX[3]
		);
	} else {
		VERTEX += (vec4(sway, 1.0) * MODEL_MATRIX).xyz;
	}
}

void fragment() {
	// Base blade texture
	ALBEDO = texture(albedo_tex, UV).rgb;

	vec4 detail_mask = texture(variants[variant_index], UV);

	if(enable_details){
		ALBEDO = mix(detail_color, ALBEDO, detail_mask.r);
	}

	ALPHA = detail_mask.a;
	ALPHA_SCISSOR_THRESHOLD = 0.8;
}

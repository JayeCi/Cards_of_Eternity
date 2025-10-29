shader_type canvas_item; // use 'spatial' if it's a 3D mesh

// 🔧 Adjustable parameters
uniform float speed : hint_range(0.1, 5.0) = 1.5;
uniform float width : hint_range(0.05, 1.0) = 0.25;
uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 1.0, 0.8);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // ✨ Shimmer sweep effect
    float angle = 0.6; // tilt of the sweep
    float offset = TIME * speed;
    float shine = sin((UV.x + UV.y * angle + offset) * 10.0);
    shine = smoothstep(0.5 - width, 0.5 + width, shine);
    
    vec4 shimmer = shine_color * shine * intensity;
    COLOR = tex_color + shimmer * tex_color.a;
}

shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back;

varying vec3 world_pos;
uniform vec3 deep_color : source_color = vec3(0.018, 0.12, 0.22);
uniform vec3 shallow_color : source_color = vec3(0.06, 0.42, 0.48);

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(VERTEX.x * 0.16 + TIME * 0.9) * 0.035;
	VERTEX.y += cos(VERTEX.z * 0.13 + TIME * 0.7) * 0.025;
}

void fragment() {
	float broad_wave = 0.5 + 0.5 * sin(world_pos.x * 0.07 + world_pos.z * 0.05 + TIME * 0.45);
	float ripples = 0.5 + 0.5 * sin(world_pos.x * 0.20 + world_pos.z * 0.11 + TIME * 0.8);
	ALBEDO = mix(deep_color, shallow_color, 0.20 + broad_wave * 0.22 + ripples * 0.11);
	METALLIC = 0.05;
	ROUGHNESS = 0.12;
	ALPHA = 0.64;
}

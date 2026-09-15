shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(VERTEX.x * 0.16 + TIME * 0.9) * 0.035;
	VERTEX.y += cos(VERTEX.z * 0.13 + TIME * 0.7) * 0.025;
}

void fragment() {
	float ripples = 0.5 + 0.5 * sin(world_pos.x * 0.20 + world_pos.z * 0.11 + TIME * 0.8);
	vec3 deep = vec3(0.025, 0.16, 0.28);
	vec3 shallow = vec3(0.08, 0.42, 0.50);
	ALBEDO = mix(deep, shallow, 0.25 + ripples * 0.18);
	METALLIC = 0.05;
	ROUGHNESS = 0.12;
	ALPHA = 0.78;
}

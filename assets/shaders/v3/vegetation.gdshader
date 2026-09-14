shader_type spatial;
render_mode cull_disabled, diffuse_burley;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float variation = 0.5 + 0.5 * sin(world_pos.x * 4.7 + world_pos.z * 2.1);
	ALBEDO = mix(vec3(0.08, 0.24, 0.07), vec3(0.24, 0.48, 0.12), variation);
	ROUGHNESS = 0.95;
}

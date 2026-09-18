shader_type spatial;
render_mode diffuse_burley, cull_back;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float crown = smoothstep(0.0, 1.0, world_pos.y * 0.12);
	ALBEDO = mix(vec3(0.20, 0.10, 0.035), vec3(0.08, 0.31, 0.10), crown);
	ROUGHNESS = 0.9;
}

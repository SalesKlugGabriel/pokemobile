shader_type spatial;
render_mode cull_disabled, diffuse_burley;

varying vec3 world_pos;

uniform float wind_strength : hint_range(0.0, 0.2) = 0.065;
uniform float wind_speed : hint_range(0.1, 4.0) = 1.35;

void vertex() {
	vec3 instance_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float blade_mask = clamp(VERTEX.y / 0.9, 0.0, 1.0);
	float gust = sin(TIME * wind_speed + instance_origin.x * 0.31 + instance_origin.z * 0.27);
	VERTEX.x += gust * wind_strength * blade_mask;
	VERTEX.z += cos(TIME * wind_speed * 0.73 + instance_origin.z * 0.22) * wind_strength * 0.45 * blade_mask;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float variation = 0.5 + 0.5 * sin(world_pos.x * 4.7 + world_pos.z * 2.1);
	ALBEDO = mix(vec3(0.10, 0.30, 0.08), vec3(0.34, 0.56, 0.16), variation);
	ROUGHNESS = 0.95;
}

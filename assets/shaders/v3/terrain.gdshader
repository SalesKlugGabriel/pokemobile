shader_type spatial;
render_mode diffuse_burley, cull_back;

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i); float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0)); float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float h = world_pos.y;
	vec3 sand = vec3(0.78, 0.64, 0.38);
	vec3 grass = vec3(0.16, 0.34, 0.13);
	vec3 grass_light = vec3(0.28, 0.46, 0.16);
	vec3 rock = vec3(0.29, 0.30, 0.28);
	float n = noise(world_pos.xz * 0.11) * 0.16 + noise(world_pos.xz * 0.35) * 0.06;
	vec3 col = mix(sand, grass, smoothstep(0.7, 2.4, h));
	col = mix(col, rock, smoothstep(11.0, 15.0, h));
	col = mix(col, grass_light, smoothstep(0.20, 0.75, noise(world_pos.xz * 0.17)) * 0.18);
	ALBEDO = clamp(col + n - 0.08, 0.0, 1.0);
	ROUGHNESS = 0.92;
}

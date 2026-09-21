shader_type spatial;
render_mode diffuse_burley, cull_back;

varying vec3 world_pos;
uniform float sea_level = 0.0;
uniform float shoreline_height = 0.36;
uniform float beach_height = 2.08;
uniform float rock_height = 10.0;
uniform float rock_slope = 0.42;

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
	vec3 deep_bed = vec3(0.025, 0.13, 0.17);
	vec3 shallow_bed = vec3(0.10, 0.32, 0.30);
	vec3 wet_sand = vec3(0.62, 0.55, 0.38);
	vec3 sand = vec3(0.78, 0.67, 0.45);
	vec3 grass = vec3(0.17, 0.34, 0.14);
	vec3 grass_light = vec3(0.29, 0.45, 0.17);
	vec3 rock = vec3(0.31, 0.32, 0.30);
	float n = noise(world_pos.xz * 0.11) * 0.12 + noise(world_pos.xz * 0.35) * 0.045;
	float slope = 1.0 - clamp(NORMAL.y, 0.0, 1.0);
	vec3 col = mix(deep_bed, shallow_bed, smoothstep(sea_level - 2.4, sea_level, h));
	col = mix(col, wet_sand, smoothstep(sea_level - 0.10, sea_level + shoreline_height, h));
	col = mix(col, sand, smoothstep(sea_level + shoreline_height * 0.7, sea_level + beach_height, h));
	col = mix(col, grass, smoothstep(sea_level + beach_height * 0.75, sea_level + beach_height + 1.25, h));
	col = mix(col, rock, smoothstep(rock_height, rock_height + 3.5, h));
	col = mix(col, rock, smoothstep(rock_slope, rock_slope + 0.25, slope));
	col = mix(col, grass_light, smoothstep(0.20, 0.75, noise(world_pos.xz * 0.17)) * 0.18);
	float shore = 1.0 - smoothstep(0.0, shoreline_height, abs(h - sea_level));
	col = mix(col, vec3(0.83, 0.75, 0.52), shore * 0.22);
	ALBEDO = clamp(col + n - 0.08, 0.0, 1.0);
	ROUGHNESS = 0.92;
}

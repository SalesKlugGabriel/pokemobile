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
	float macro = noise(world_pos.xz * 0.055);
	float medium = noise(world_pos.xz * 0.16);
	float grain = noise(world_pos.xz * 0.72);
	float n = (macro - 0.5) * 0.10 + (medium - 0.5) * 0.055;
	vec3 deep_bed = mix(vec3(0.018, 0.095, 0.13), vec3(0.035, 0.16, 0.18), macro);
	vec3 shallow_bed = mix(vec3(0.07, 0.25, 0.25), vec3(0.13, 0.37, 0.32), medium);
	vec3 wet_sand = mix(vec3(0.48, 0.43, 0.31), vec3(0.64, 0.57, 0.39), medium);
	vec3 sand = mix(vec3(0.62, 0.52, 0.33), vec3(0.82, 0.71, 0.48), grain);
	vec3 grass_dark = vec3(0.095, 0.24, 0.10);
	vec3 grass_light = vec3(0.27, 0.44, 0.15);
	vec3 grass = mix(grass_dark, grass_light, macro * 0.72 + medium * 0.28);
	vec3 rock = mix(vec3(0.20, 0.22, 0.22), vec3(0.38, 0.36, 0.31), medium);
	float slope = 1.0 - clamp(NORMAL.y, 0.0, 1.0);
	vec3 col = mix(deep_bed, shallow_bed, smoothstep(sea_level - 2.4, sea_level, h));
	col = mix(col, wet_sand, smoothstep(sea_level - 0.10, sea_level + shoreline_height, h));
	col = mix(col, sand, smoothstep(sea_level + shoreline_height * 0.7, sea_level + beach_height, h));
	col = mix(col, grass, smoothstep(sea_level + beach_height * 0.75, sea_level + beach_height + 1.25, h));
	// Manchas de solo quebram a leitura de um tapete verde sem criar textura repetida.
	float soil_patch = smoothstep(0.72, 0.90, noise(world_pos.xz * 0.095 + vec2(13.0, 7.0)));
	float above_beach = smoothstep(sea_level + beach_height, sea_level + beach_height + 1.8, h);
	col = mix(col, vec3(0.25, 0.20, 0.11), soil_patch * above_beach * 0.16);
	col = mix(col, rock, smoothstep(rock_height, rock_height + 3.5, h));
	col = mix(col, rock, smoothstep(rock_slope, rock_slope + 0.25, slope));
	float shore = 1.0 - smoothstep(0.0, shoreline_height, abs(h - sea_level));
	col = mix(col, vec3(0.83, 0.75, 0.52), shore * 0.22);
	ALBEDO = clamp(col + n, 0.0, 1.0);
	ROUGHNESS = mix(0.96, 0.73, smoothstep(sea_level - 0.1, sea_level + shoreline_height, h));
	ROUGHNESS = mix(ROUGHNESS, 0.88, smoothstep(rock_slope, rock_slope + 0.25, slope));
}

shader_type canvas_item;

// Anima somente a água azul do atlas. Coordenadas mundiais evitam que cada
// quadrado repita a mesma onda; quantização mantém os reflexos em pixels.
varying vec2 mundo;
varying vec4 tinta;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	tinta = COLOR;
}

void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	vec2 slot = floor(UV * vec2(textureSize(TEXTURE, 0)) / 128.0);
	bool mar = (slot == vec2(1.0, 1.0)) || (slot == vec2(0.0, 3.0)) ||
		(slot == vec2(5.0, 3.0)) || (slot.y == 10.0);
	bool azul = texel.b > texel.r * 1.25 && texel.g > texel.r * 1.15;
	if (mar && azul) {
		vec2 p = floor(mundo / 4.0);
		float tempo = floor(TIME * 6.0) / 6.0;
		float onda = sin(p.y * 0.23 + sin(p.x * 0.041) * 2.0 - tempo * 0.7);
		float detalhe = sin(p.x * 0.19 + p.y * 0.073 + tempo * 0.3);
		float manchas = sin(p.x * 0.025 + sin(p.y * 0.019) * 2.0) + sin(p.y * 0.032 - p.x * 0.014);
		// Substitui a repetição em escamas do tile por massas de cor em
		// coordenadas do mundo. Nenhuma deformação de UV ou leitura de tela.
		vec3 fundo = vec3(0.051, 0.239, 0.427);
		vec3 medio = vec3(0.078, 0.329, 0.478);
		vec3 claro = vec3(0.118, 0.435, 0.604);
		vec3 agua = mix(fundo, medio, step(-0.55, manchas));
		agua = mix(agua, claro, step(0.8, manchas) * 0.55);
		float brilho = step(0.975, onda) * step(0.35, detalhe);
		agua = mix(agua, vec3(0.56, 0.83, 0.91), brilho * 0.38);
		texel.rgb = agua;
	}
	COLOR = texel * tinta;
}

## Auditoria CPU da geometria atual. Não mede FPS/GPU e não altera cenas do jogo.
## Uso: godot4 --headless --path . --script res://tools/world_factory/benchmark_chunks.gd
extends SceneTree

const Terreno = preload("res://scripts/gameplay_v3/mundo/Terreno3D.gd")
const AREA_M: int = 256
const PASSO_M: int = 2
const TAMANHOS: Array[int] = [32, 64, 128, 256]
const REPETICOES: int = 3

func _initialize() -> void:
	_medir_consistencia_altura_e_malha()
	for tamanho in TAMANHOS:
		var gerar_ms: Array[float] = []
		var colisao_ms: Array[float] = []
		var contagem: int = 0
		var triangulos: int = 0
		for repeticao in REPETICOES:
			var t_gerar: int = Time.get_ticks_usec()
			var malhas: Array[ArrayMesh] = []
			for cx in AREA_M / tamanho:
				for cz in AREA_M / tamanho:
					malhas.append(_malha(cx, cz, tamanho))
			gerar_ms.append(float(Time.get_ticks_usec() - t_gerar) / 1000.0)
			var t_colisao: int = Time.get_ticks_usec()
			for malha in malhas:
				var forma: Shape3D = malha.create_trimesh_shape()
				if forma == null:
					push_error("Falha ao criar colisão")
			colisao_ms.append(float(Time.get_ticks_usec() - t_colisao) / 1000.0)
			contagem = malhas.size()
			triangulos = AREA_M * AREA_M / (PASSO_M * PASSO_M) * 2
		gerar_ms.sort()
		colisao_ms.sort()
		print("CHUNK_BENCH tamanho=%dm area=%dm passo=%dm chunks=%d triangulos=%d gerar_mediana_ms=%.3f colisao_mediana_ms=%.3f" % [
			tamanho, AREA_M, PASSO_M, contagem, triangulos, gerar_ms[1], colisao_ms[1]
		])
	quit()

func _medir_consistencia_altura_e_malha() -> void:
	# A API pública deve descrever o mesmo plano dos triângulos de colisão. Duas
	# amostras por célula exercem ambos os lados da diagonal A-C, não só o centro.
	var maximo: float = 0.0
	var acima_10cm: int = 0
	var acima_25cm: int = 0
	var onde := Vector2.ZERO
	for ix in 80:
		for iz in 80:
			var xa: float = -80.0 + ix * 2.0
			var za: float = -80.0 + iz * 2.0
			for uv in [Vector2(0.72, 0.21), Vector2(0.27, 0.74)]:
				var publico: float = Terreno.altura_em(xa + uv.x * PASSO_M, za + uv.y * PASSO_M)
				var triangulado: float = _altura_do_triangulo(xa, za, uv.x, uv.y)
				var delta: float = absf(publico - triangulado)
				if delta > maximo:
					maximo = delta
					onde = Vector2(xa + uv.x * PASSO_M, za + uv.y * PASSO_M)
				if delta > 0.10:
					acima_10cm += 1
				if delta > 0.25:
					acima_25cm += 1
	print("HEIGHT_CONSISTENCY amostras=12800 max_m=%.6f onde=%s acima_10cm=%d acima_25cm=%d" % [maximo, onde, acima_10cm, acima_25cm])

func _altura_do_triangulo(xa: float, za: float, u: float, v: float) -> float:
	var a: float = Terreno.altura_em(xa, za)
	var b: float = Terreno.altura_em(xa + PASSO_M, za)
	var c: float = Terreno.altura_em(xa + PASSO_M, za + PASSO_M)
	var d: float = Terreno.altura_em(xa, za + PASSO_M)
	if v <= u:
		return a * (1.0 - u) + b * (u - v) + c * v
	return a * (1.0 - v) + c * u + d * (v - u)

func _malha(cx: int, cz: int, tamanho: int) -> ArrayMesh:
	var ferramenta := SurfaceTool.new()
	ferramenta.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inicio_x: float = -AREA_M * 0.5 + cx * tamanho
	var inicio_z: float = -AREA_M * 0.5 + cz * tamanho
	for ix in tamanho / PASSO_M:
		for iz in tamanho / PASSO_M:
			var x: float = inicio_x + ix * PASSO_M
			var z: float = inicio_z + iz * PASSO_M
			var a := Vector3(x, Terreno.altura_em(x, z), z)
			var b := Vector3(x + PASSO_M, Terreno.altura_em(x + PASSO_M, z), z)
			var c := Vector3(x + PASSO_M, Terreno.altura_em(x + PASSO_M, z + PASSO_M), z + PASSO_M)
			var d := Vector3(x, Terreno.altura_em(x, z + PASSO_M), z + PASSO_M)
			for ponto in [a, b, c, a, c, d]:
				ferramenta.set_color(Color(0.3, 0.4, 0.2))
				ferramenta.add_vertex(ponto)
	ferramenta.generate_normals()
	return ferramenta.commit()

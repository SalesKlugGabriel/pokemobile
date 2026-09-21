## WorldTerrainFactory — terreno por seed, amostrado em coordenadas globais.
##
## A classe é isolada da cena: recebe a spec explicitamente, não consulta
## RNGManager e não usa randf(). A geometria vem de vértices globais, por isso
## chunks adjacentes compartilham exatamente a mesma altura na borda.
class_name WorldTerrainFactory
extends RefCounted

var _spec: Dictionary
var _bounds: Dictionary
var _terrain: Dictionary
var _seed: int
var _passo: float
var _chunk: float
var _mar: float
var _largura_praia: float
var _largura_linha_dagua: float
var _profundidade_rasa: float
var _inicio_rocha_por_inclinacao: float
var _inicio_rocha_por_altura: float

func _init(spec: Dictionary) -> void:
	_spec = spec.duplicate(true)
	_bounds = _spec.get("bounds_m", {})
	_terrain = _spec.get("terrain", {})
	_seed = int(_spec.get("world_seed", 0))
	_passo = float(_terrain.get("sample_step_m", 2.0))
	_chunk = float(_terrain.get("chunk_size_m", 64.0))
	_mar = float(_terrain.get("sea_level_m", 0.0))
	_largura_praia = float(_terrain.get("beach_width_m", 8.0))
	_largura_linha_dagua = float(_terrain.get("shoreline_width_m", 2.0))
	_profundidade_rasa = float(_terrain.get("shallow_depth_m", 2.4))
	_inicio_rocha_por_inclinacao = float(_terrain.get("rock_slope_start", 0.42))
	_inicio_rocha_por_altura = float(_terrain.get("rock_height_start_m", 10.0))

func passo_m() -> float:
	return _passo

func chunk_m() -> float:
	return _chunk

func seed() -> int:
	return _seed

func nivel_do_mar() -> float:
	return _mar

func largura_praia_m() -> float:
	return _largura_praia

func largura_linha_dagua_m() -> float:
	return _largura_linha_dagua

func profundidade_rasa_m() -> float:
	return _profundidade_rasa

func origem_do_chunk(cx: int, cz: int) -> Vector2:
	return Vector2(float(_bounds.get("min_x", 0.0)) + cx * _chunk,
		float(_bounds.get("min_z", 0.0)) + cz * _chunk)

func coordenada_do_chunk(x: float, z: float) -> Vector2i:
	return Vector2i(floori((x - float(_bounds.get("min_x", 0.0))) / _chunk),
		floori((z - float(_bounds.get("min_z", 0.0))) / _chunk))

## Altura de um vértice que pertence a um chunk. Exposta para validação de
## costura; a malha chama a mesma fonte analítica nesses pontos globais.
func altura_do_vertice_chunk(cx: int, cz: int, ix: int, iz: int) -> float:
	var origem := origem_do_chunk(cx, cz)
	return altura_analitica_em(origem.x + ix * _passo, origem.y + iz * _passo)

## Camadas geográficas: costa dominante → relevo macro → colinas → penhasco.
## A fonte é contínua somente para criar vértices; `altura_em` devolve a mesma
## triangulação física, igual ao contrato corrigido na RFC-006.
func altura_analitica_em(x: float, z: float) -> float:
	var sul_norte := (z - float(_bounds.get("min_z", -128.0))) / float(_bounds.get("depth", 256.0))
	var altura := sul_norte * 11.0 - 4.6

	# Três escalas de detalhe, todas em coordenadas globais. O ruído de valor
	# interpolado evita a leitura de ondas senoidais sem criar degraus de malha.
	altura += (_ruido_suave(x, z, 96.0) - 0.5) * 4.4 # forma primária
	altura += (_ruido_suave(x + 191.0, z - 73.0, 34.0) - 0.5) * 2.1 # vales e colinas
	altura += (_ruido_suave(x - 47.0, z + 129.0, 10.0) - 0.5) * 0.38 # irregularidade discreta

	# Colina baixa e larga: forma primária, não ruído puro.
	var colina := Vector2(x + 34.0, z - 20.0).length()
	if colina < 42.0:
		altura += 6.0 * (1.0 - smoothstep(0.0, 42.0, colina))

	# Penhasco compacto junto à futura entrada de caverna; o platô e a borda
	# curta tornam a silhueta legível sem transformar o mapa inteiro em rampa.
	var penhasco := Vector2(x - 72.0, z + 52.0).length()
	if penhasco < 17.0:
		altura += 9.0
	elif penhasco < 24.0:
		var t := (penhasco - 17.0) / 7.0
		altura += 9.0 * (1.0 - smoothstep(0.0, 1.0, t))

	# Costa contínua: reduz só o relevo onde a geografia já encontra o nível do
	# mar. A largura vem da spec; não há coordenada de praia escondida no código.
	var distancia_mar := absf(altura - _mar)
	var faixa_de_modelagem := _largura_praia * 0.42
	var peso_praia := 1.0 - smoothstep(0.0, faixa_de_modelagem, distancia_mar)
	if peso_praia > 0.0:
		altura = lerpf(altura, _mar - _profundidade_rasa * 0.12, 0.42 * peso_praia)
	return altura

func _ruido_suave(x: float, z: float, escala: float) -> float:
	var px := x / escala
	var pz := z / escala
	var ix := floori(px)
	var iz := floori(pz)
	var fx := px - float(ix)
	var fz := pz - float(iz)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var a := _hash_de_grade(ix, iz)
	var b := _hash_de_grade(ix + 1, iz)
	var c := _hash_de_grade(ix, iz + 1)
	var d := _hash_de_grade(ix + 1, iz + 1)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)

func _hash_de_grade(ix: int, iz: int) -> float:
	var valor := sin(float(ix * 15731 + iz * 789221 + _seed * 1376312589)) * 43758.5453
	return valor - floorf(valor)

func altura_em(x: float, z: float) -> float:
	var min_x := float(_bounds.get("min_x", 0.0))
	var min_z := float(_bounds.get("min_z", 0.0))
	var max_x := min_x + float(_bounds.get("width", 0.0))
	var max_z := min_z + float(_bounds.get("depth", 0.0))
	if x < min_x or x > max_x or z < min_z or z > max_z:
		return altura_analitica_em(x, z)
	var colunas := int(float(_bounds.get("width", 0.0)) / _passo) - 1
	var linhas := int(float(_bounds.get("depth", 0.0)) / _passo) - 1
	var ix := clampi(floori((x - min_x) / _passo), 0, colunas)
	var iz := clampi(floori((z - min_z) / _passo), 0, linhas)
	var xa := min_x + ix * _passo
	var za := min_z + iz * _passo
	var u := clampf((x - xa) / _passo, 0.0, 1.0)
	var v := clampf((z - za) / _passo, 0.0, 1.0)
	var a := altura_analitica_em(xa, za)
	var b := altura_analitica_em(xa + _passo, za)
	var c := altura_analitica_em(xa + _passo, za + _passo)
	var d := altura_analitica_em(xa, za + _passo)
	return a * (1.0 - u) + b * (u - v) + c * v if v <= u else a * (1.0 - v) + c * u + d * (v - u)

func normal_em(x: float, z: float) -> Vector3:
	var dx := altura_em(x + _passo, z) - altura_em(x - _passo, z)
	var dz := altura_em(x, z + _passo) - altura_em(x, z - _passo)
	return Vector3(-dx, 2.0 * _passo, -dz).normalized()

func tipo_de_superficie_em(x: float, z: float) -> String:
	var altura := altura_em(x, z)
	var inclinacao := 1.0 - normal_em(x, z).y
	if altura < _mar - _profundidade_rasa:
		return "deep_waterbed"
	if altura < _mar:
		return "shallow_waterbed"
	var faixa_shore := _largura_linha_dagua * 0.18
	if altura < _mar + faixa_shore:
		return "shoreline"
	var faixa_areia := maxf(faixa_shore + 0.35, _largura_praia * 0.26)
	if altura < _mar + faixa_areia:
		return "sand"
	if inclinacao >= _inicio_rocha_por_inclinacao or altura >= _inicio_rocha_por_altura:
		return "rock"
	return "grass"

func gerar_malha_chunk(cx: int, cz: int) -> ArrayMesh:
	var origem := origem_do_chunk(cx, cz)
	var ferramenta := SurfaceTool.new()
	ferramenta.begin(Mesh.PRIMITIVE_TRIANGLES)
	var por_lado := int(_chunk / _passo)
	for ix in por_lado:
		for iz in por_lado:
			var xa := origem.x + ix * _passo
			var za := origem.y + iz * _passo
			var a := Vector3(xa, altura_do_vertice_chunk(cx, cz, ix, iz), za)
			var b := Vector3(xa + _passo, altura_do_vertice_chunk(cx, cz, ix + 1, iz), za)
			var c := Vector3(xa + _passo, altura_do_vertice_chunk(cx, cz, ix + 1, iz + 1), za + _passo)
			var d := Vector3(xa, altura_do_vertice_chunk(cx, cz, ix, iz + 1), za + _passo)
			for ponto in [a, b, c, a, c, d]:
				ferramenta.set_color(_cor_da_superficie(ponto.x, ponto.z))
				ferramenta.add_vertex(ponto)
	ferramenta.generate_normals()
	return ferramenta.commit()

func _cor_da_superficie(x: float, z: float) -> Color:
	match tipo_de_superficie_em(x, z):
		"deep_waterbed":
			return Color(0.045, 0.14, 0.18)
		"shallow_waterbed":
			return Color(0.12, 0.35, 0.34)
		"shoreline":
			return Color(0.67, 0.61, 0.43)
		"sand":
			return Color(0.78, 0.68, 0.45)
		"rock":
			return Color(0.34, 0.34, 0.31)
		_:
			return Color(0.21, 0.39, 0.20)

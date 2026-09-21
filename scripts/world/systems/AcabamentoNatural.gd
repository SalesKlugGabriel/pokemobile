## Camada exclusivamente visual. Lê o terreno já pintado, incluindo overrides,
## sem alterar células, colisões, fauna, RNG do jogo ou coordenadas do mundo.
## Só percorre o retângulo visível; rotas de 12 mil tiles não aumentam o custo.
extends Node2D

const PASSO := 8
const LIMITE_CELULAS := 1600
const VIZINHOS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const SOMBRA := Color(0.07, 0.12, 0.04, 0.24)
const SHADER_AGUA = preload("res://assets/shaders/ambiente_pixel.gdshader")

var mapa: TileMap
var _atlas: Texture2D
var _restante := 0.0
var _tamanho := 128
var _gramas := {}
var _solos := {}
var _material_anterior: Material
var celulas_avaliadas := 0

func configurar(terreno: TileMap) -> void:
	mapa = terreno
	_tamanho = mapa.tile_set.tile_size.x
	var fonte := mapa.tile_set.get_source(0) as TileSetAtlasSource
	_atlas = fonte.texture
	for ch in [".", "G", "9"]:
		_gramas[MapLayouts.CHAR_MAP[ch]] = true
		for coordenada in MapLayouts.VARIANTES_TERRENO.get(ch, []):
			_gramas[coordenada] = true
	for ch in ["P", "D", "S", "_", "^", ":", "z"]:
		_solos[MapLayouts.CHAR_MAP[ch]] = true
		for coordenada in MapLayouts.VARIANTES_TERRENO.get(ch, []):
			_solos[coordenada] = true
	# Filho do TileMap: acompanha sua transformação e fica acima do chão,
	# abaixo das entidades e dos telhados, que usam z_index maior.
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_material_anterior = mapa.material
	if mapa.material == null:
		var material_agua := ShaderMaterial.new()
		material_agua.shader = SHADER_AGUA
		mapa.material = material_agua
	queue_redraw()

func _process(delta: float) -> void:
	_restante -= delta
	if _restante <= 0.0:
		_restante = 0.12
		queue_redraw()

func _draw() -> void:
	if not is_instance_valid(mapa) or not _atlas:
		return
	var inversa := get_global_transform_with_canvas().affine_inverse()
	var tela := get_viewport_rect()
	var inicio := mapa.local_to_map(inversa * tela.position) - Vector2i.ONE
	var fim := mapa.local_to_map(inversa * tela.end) + Vector2i.ONE
	celulas_avaliadas = 0
	# Em zoom extremo, não desenhar uma parte arbitrária da tela: a camada
	# fina some inteira e o atlas original continua correto.
	if (fim.x - inicio.x + 1) * (fim.y - inicio.y + 1) > LIMITE_CELULAS:
		return
	for y in range(inicio.y, fim.y + 1):
		for x in range(inicio.x, fim.x + 1):
			celulas_avaliadas += 1
			var celula := Vector2i(x, y)
			var co := mapa.get_cell_atlas_coords(0, celula)
			var solo: bool = _solos.has(co)
			var agua := co == MapLayouts.CHAR_MAP["~"]
			var grama: bool = _gramas.has(co)
			if not solo and not agua and not grama:
				continue
			var origem := mapa.map_to_local(celula) - Vector2.ONE * _tamanho * 0.5
			for lado in range(4):
				var vizinho := mapa.get_cell_atlas_coords(0, celula + VIZINHOS[lado])
				if (solo or agua) and _gramas.has(vizinho):
					_borda(celula, origem, lado, vizinho, agua)
				elif grama and _e_mata(vizinho):
					_sombra_da_mata(celula, origem, lado)

func _e_mata(co: Vector2i) -> bool:
	return co == MapLayouts.CHAR_MAP["T"] or co == MapLayouts.CHAR_MAP["N"] or co == MapLayouts.CHAR_MAP["O"] or (co.y >= 11 and co.y <= 13)

static func irregular(celula: Vector2i, segmento: int, lado: int) -> int:
	# Hash local: nunca consome RNGManager nem muda ao revisitar a área.
	var h: int = (celula.x * 374761393 + celula.y * 668265263 + segmento * 1274126177 + lado * 1442695041) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return (h ^ (h >> 16)) & 0x7fffffff

func _faixa(origem: Vector2, lado: int, passo: int, profundidade: float, largura: float = PASSO) -> Rect2:
	match lado:
		0: return Rect2(origem + Vector2(passo, 0), Vector2(largura, profundidade))
		1: return Rect2(origem + Vector2(passo, _tamanho - profundidade), Vector2(largura, profundidade))
		2: return Rect2(origem + Vector2(0, passo), Vector2(profundidade, largura))
		_: return Rect2(origem + Vector2(_tamanho - profundidade, passo), Vector2(profundidade, largura))

func _borda(celula: Vector2i, origem: Vector2, lado: int, textura: Vector2i, agua: bool) -> void:
	for passo in range(0, _tamanho, PASSO):
		var n := irregular(celula, passo / PASSO, lado)
		var profundidade := float(4 + (n % 4) * 4)
		# O barranco mergulha na água em três degraus de cor, sem blur.
		if agua:
			draw_rect(_faixa(origem, lado, passo, profundidade + 16), Color(0.12, 0.44, 0.53, 0.50))
			draw_rect(_faixa(origem, lado, passo, profundidade + 8), Color(0.20, 0.22, 0.12, 0.75))
		else:
			draw_rect(_faixa(origem, lado, passo, profundidade + 4), Color(0.22, 0.26, 0.10, 0.28))
		var destino := _faixa(origem, lado, passo, profundidade)
		var recorte := Rect2(Vector2(textura * _tamanho) + destino.position - origem, destino.size)
		draw_texture_rect_region(_atlas, destino, recorte)

func _sombra_da_mata(celula: Vector2i, origem: Vector2, lado: int) -> void:
	# Sol a noroeste: só projeta para sul/leste (vizinho ao norte/oeste).
	if lado != 0 and lado != 2:
		return
	for passo in range(0, _tamanho, PASSO * 2):
		var profundidade := float(8 + (irregular(celula, passo, lado) % 4) * 4)
		draw_rect(_faixa(origem, lado, passo, profundidade, PASSO * 2), SOMBRA)

func _exit_tree() -> void:
	if is_instance_valid(mapa) and mapa.material is ShaderMaterial and mapa.material.shader == SHADER_AGUA:
		mapa.material = _material_anterior

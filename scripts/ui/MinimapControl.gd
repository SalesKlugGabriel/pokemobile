## MinimapControl.gd — Minimapa local: o pedaço de mundo em volta do jogador.
##
## Reescrito em 04/09. O antigo tinha `MAP_W = 100` / `MAP_H = 120` cravados,
## de quando o mundo inteiro tinha esse tamanho. Hoje o mapa tem ~940 x 465
## tiles: o ponto do jogador caía sempre fora do quadro e o widget virava um
## retângulo verde liso — foi assim que apareceu no teste de gameplay.
##
## Em vez de tentar caber o mundo inteiro num quadrado de 60px (onde nada seria
## legível), ele mostra um RAIO em volta do jogador, lendo os tiles de verdade
## do TileMap e pintando por tipo de terreno. Assim a criança vê onde tem mato,
## água, estrada e prédio à sua volta — que é a pergunta que um minimapa
## responde.
extends Control

## Quantos tiles de cada lado do jogador aparecem.
const RAIO : int = 14

## Cor por tipo de terreno. Chave = char do MapLayouts; o resto cai no padrão.
const COR_POR_CHAR := {
	"~": Color(0.16, 0.36, 0.62),   # mar
	"S": Color(0.80, 0.70, 0.44),   # areia
	"P": Color(0.62, 0.48, 0.32),   # estrada de terra
	"A": Color(0.16, 0.42, 0.16),   # mato alto (onde aparece Pokémon)
	"T": Color(0.11, 0.26, 0.13),   # árvores
	"N": Color(0.11, 0.26, 0.13),
	"O": Color(0.20, 0.28, 0.12),
	"K": Color(0.24, 0.20, 0.13),
	"W": Color(0.55, 0.55, 0.58),   # parede
	"w": Color(0.55, 0.55, 0.58),
	"H": Color(0.62, 0.26, 0.18),   # telhado
	"I": Color(0.45, 0.36, 0.26),   # piso interno
	"d": Color(0.92, 0.78, 0.30),   # porta — o que a criança está procurando
	"R": Color(0.45, 0.45, 0.48),   # rocha
}
const COR_GRAMA := Color(0.26, 0.52, 0.24)
const COR_FORA  := Color(0.06, 0.07, 0.06)

var _por_atlas : Dictionary = {}   # Vector2i -> Color, montado uma vez

func _ready() -> void:
	_montar_tabela()
	# Clicar no minimapa abre o mapa da região. É o gesto natural — e o terceiro
	# caminho até ele, junto da tecla M e do botão no menu de Pausa. Recurso com
	# um caminho só é recurso que a maioria não acha.
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Abrir o mapa de Kanto (M)"
	gui_input.connect(_ao_clicar)

func _ao_clicar(evento: InputEvent) -> void:
	if not (evento is InputEventMouseButton) or not evento.pressed:
		return
	var mapa := get_tree().root.get_node_or_null("GlobalUI/MapaMundi")
	if mapa and mapa.has_method("abrir"):
		accept_event()
		mapa.abrir()

## Traduz o CHAR_MAP (e as variantes de terreno) numa tabela coordenada→cor,
## resolvida UMA vez. Sem isto seria uma busca linear no CHAR_MAP por tile
## desenhado, a cada quadro, pra ~840 tiles.
func _montar_tabela() -> void:
	for ch in MapLayouts.CHAR_MAP:
		var cor : Color = COR_POR_CHAR.get(ch, COR_GRAMA)
		_por_atlas[MapLayouts.CHAR_MAP[ch]] = cor
	for ch in MapLayouts.VARIANTES_TERRENO:
		var cor : Color = COR_POR_CHAR.get(ch, COR_GRAMA)
		for co in MapLayouts.VARIANTES_TERRENO[ch]:
			_por_atlas[co] = cor
	# Beira da praia: água com areia de um lado — no minimapa vale como praia.
	for co in MapLayouts.COSTA_ATLAS:
		_por_atlas[co] = COR_POR_CHAR["S"]

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var sz : Vector2 = size
	draw_rect(Rect2(Vector2.ZERO, sz), COR_FORA)

	var jogador = WorldManager.player
	var tm = WorldManager.tilemap
	if jogador == null or not is_instance_valid(jogador) or tm == null:
		return

	var centro : Vector2i = jogador.grid_pos
	var lado : int = RAIO * 2 + 1
	var passo : Vector2 = sz / float(lado)

	for dy in range(-RAIO, RAIO + 1):
		for dx in range(-RAIO, RAIO + 1):
			var t := Vector2i(centro.x + dx, centro.y + dy)
			if tm.get_cell_source_id(0, t) == -1:
				continue
			var cor : Color = _por_atlas.get(tm.get_cell_atlas_coords(0, t), COR_GRAMA)
			draw_rect(Rect2(Vector2(dx + RAIO, dy + RAIO) * passo, passo + Vector2(1, 1)), cor)

	# Jogador: sempre no centro, com contorno claro pra destacar de qualquer cor
	var meio : Vector2 = sz / 2.0
	draw_circle(meio, 3.5, Color(0, 0, 0, 0.8))
	draw_circle(meio, 2.5, Color(1.0, 0.35, 0.15))

	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.35, 0.35, 0.35, 0.7), false, 1.0)

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
	# ── Biomas da Fase 2 (05/09) ────────────────────────────────────────────
	"z": Color(0.34, 0.38, 0.22), "!": Color(0.50, 0.74, 0.24),
	"0": Color(0.29, 0.38, 0.31), "(": Color(0.38, 0.46, 0.20),
	")": Color(0.33, 0.27, 0.20),
	"^": Color(0.50, 0.46, 0.41), "/": Color(0.34, 0.31, 0.27),
	"<": Color(0.66, 0.64, 0.60), ">": Color(0.45, 0.41, 0.37),
	":": Color(0.63, 0.54, 0.41),
	"_": Color(0.84, 0.72, 0.48), "'": Color(0.88, 0.78, 0.56),
	"*": Color(0.29, 0.52, 0.27), ";": Color(0.93, 0.91, 0.84),
	"+": Color(0.78, 0.66, 0.42),
	"%": Color(0.73, 0.66, 0.54), "[": Color(0.55, 0.48, 0.38),
	"|": Color(0.67, 0.62, 0.52), "]": Color(0.60, 0.55, 0.45),
	"=": Color(0.68, 0.62, 0.50),
	"&": Color(0.36, 0.28, 0.22), "{": Color(0.34, 0.31, 0.30),
	"}": Color(0.20, 0.22, 0.30), "$": Color(0.46, 0.38, 0.29),
	"@": Color(0.55, 0.55, 0.56),
	"9": Color(0.14, 0.23, 0.13), "?": Color(0.47, 0.88, 0.77),
	"`": Color(0.23, 0.17, 0.12),
	"#": Color(0.57, 0.42, 0.24), "-": Color(0.57, 0.42, 0.24),
	# Cores derivadas da COR MÉDIA do próprio tile no atlas, com a saturação
	# puxada — a média de um tile sai sempre mais apagada que ele. Geradas
	# assim, e não escolhidas a olho, porque 27 terrenos estavam caindo no
	# verde genérico do fallback e o mapa mentia sobre eles.
	".": Color(0.36, 0.63, 0.05),
	"D": Color(0.56, 0.38, 0.15),
	"M": Color(0.65, 0.13, 0.03),
	"E": Color(0.38, 0.55, 0.05),
	"X": Color(0.25, 0.50, 0.05),
	"B": Color(0.03, 0.37, 0.59),
	"C": Color(0.33, 0.72, 0.94),
	"J": Color(0.22, 0.64, 0.90),
	"L": Color(0.36, 0.32, 0.25),
	"Q": Color(0.21, 0.19, 0.14),
	"U": Color(0.08, 0.53, 0.73),
	"V": Color(0.27, 0.03, 0.30),
	"Y": Color(0.37, 0.22, 0.09),
	"Z": Color(0.29, 0.17, 0.07),
	"b": Color(0.33, 0.29, 0.27),
	"c": Color(0.24, 0.14, 0.10),
	"e": Color(0.35, 0.24, 0.14),
	"f": Color(0.40, 0.37, 0.33),
	"g": Color(0.49, 0.45, 0.38),
	"h": Color(0.37, 0.35, 0.24),
	"i": Color(0.34, 0.54, 0.04),
	"j": Color(0.36, 0.41, 0.00),
	"k": Color(0.07, 0.31, 0.33),
	"l": Color(0.41, 0.33, 0.26),
	"m": Color(0.60, 0.22, 0.10),
	"n": Color(0.40, 0.52, 0.05),
	"o": Color(0.07, 0.03, 0.01),
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

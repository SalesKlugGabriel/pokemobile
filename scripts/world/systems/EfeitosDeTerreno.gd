## EfeitosDeTerreno.gd — O terreno que muda como se joga (05/09).
##
## Pedido do Gabriel: cada lendário atrás de um minigame próprio, "incrivelmente
## difíceis de alcançar". Os três minigames são, no fundo, três terrenos que
## quebram uma regra de movimento:
##
##   GELO       — pisar não anda um tile: desliza até bater em alguma coisa.
##                É o covil do Articuno, na Ilha Gélida.
##   QUEBRADIÇO — a pedra pisada vira LAVA depois que você sai dela. Não existe
##                voltar. É a Cratera do Moltres.
##   PORTÃO     — bloqueia até a alavanca do grupo ser puxada; puxar uma inverte
##                o grupo inteiro, então abrir um caminho fecha outro. É o
##                labirinto do Zapdos, na Usina.
##
## Tudo aqui é consultado a partir do TILE em que o jogador está — não há estado
## escondido em cada mapa. Quem pinta o mapa decide o efeito; este arquivo só
## responde "o que este tile faz".
class_name EfeitosDeTerreno
extends RefCounted

## Chars com efeito. Ficam aqui, num lugar só, porque três sistemas diferentes
## precisam da mesma resposta (movimento, colisão e o teste que prova que os
## covis têm solução) — e três cópias divergem no primeiro tile novo.
const CHAR_GELO       := ","
const CHAR_QUEBRADICO := "="
const CHAR_LAVA       := "c"
const CHAR_PORTAO     := "["
const CHAR_ALAVANCA   := "|"

static func _atlas(ch: String) -> Vector2i:
	return MapLayouts.CHAR_MAP.get(ch, Vector2i(-1, -1))

## O jogador desliza neste tile?
static func e_gelo(tm: TileMap, tile: Vector2i) -> bool:
	if tm == null:
		return false
	return MapLayouts.atlas_e_do_char(tm.get_cell_atlas_coords(0, tile), CHAR_GELO)

## Este tile desmorona depois de pisado?
static func e_quebradico(tm: TileMap, tile: Vector2i) -> bool:
	if tm == null:
		return false
	return tm.get_cell_atlas_coords(0, tile) == _atlas(CHAR_QUEBRADICO)

static func e_alavanca(tm: TileMap, tile: Vector2i) -> bool:
	if tm == null:
		return false
	return tm.get_cell_atlas_coords(0, tile) == _atlas(CHAR_ALAVANCA)

## Transforma o piso rachado em lava. Chamado quando o jogador SAI do tile —
## nunca quando entra, senão ele cairia no próprio passo.
static func desmoronar(tm: TileMap, tile: Vector2i) -> void:
	if tm == null or not e_quebradico(tm, tile):
		return
	tm.set_cell(0, tile, 0, _atlas(CHAR_LAVA))

## Inverte todos os portões do mapa: os fechados abrem, os abertos fecham.
##
## Um só grupo de propósito. A ideia do quebra-cabeça é "abrir um caminho fecha
## outro" — com vários grupos independentes o jogador resolveria cada um
## isolado, e o labirinto viraria uma sequência de portas, não uma escolha.
static func inverter_portoes(tm: TileMap) -> int:
	if tm == null:
		return 0
	var fechado := _atlas(CHAR_PORTAO)
	var aberto := _atlas("=")     # piso de degrau = portão recolhido
	var trocas := {}
	for celula in tm.get_used_cells(0):
		var co := tm.get_cell_atlas_coords(0, celula)
		if co == fechado:
			trocas[celula] = aberto
		elif co == aberto:
			trocas[celula] = fechado
	for celula in trocas:
		tm.set_cell(0, celula, 0, trocas[celula])
	return trocas.size()

# ──────────────────────────────────────────────────────────────────────────────
# Deslize
# ──────────────────────────────────────────────────────────────────────────────

## Até onde o jogador escorrega saindo de `de` na direção `d`.
##
## Espelha exatamente `CovisLendarios._deslizar`, que é o que o gerador usa pra
## PROVAR que cada andar tem solução. As duas precisam concordar: se o jogo
## deslizar diferente do que o gerador supôs, o andar provado como solucionável
## deixa de ser — e o jogador fica preso num quebra-cabeça sem saída.
## `teste_covis_lendarios.gd` compara as duas função a função.
static func destino_do_deslize(tm: TileMap, de: Vector2i, d: Vector2i,
		limite: int = 40) -> Vector2i:
	var atual := de
	for _i in limite:
		var proximo := atual + d
		if not _pisavel(tm, proximo):
			return atual
		atual = proximo
		if not e_gelo(tm, atual):
			return atual      # saiu do gelo: para aqui (escada, piso, saída)
	return atual

static func _pisavel(tm: TileMap, tile: Vector2i) -> bool:
	if tm.get_cell_source_id(0, tile) == -1:
		return false
	var td : TileData = tm.get_cell_tile_data(0, tile)
	return td != null and not td.get_custom_data("blocked")

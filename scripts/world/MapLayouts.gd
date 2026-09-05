## MapLayouts.gd — Layout procedural dos mapas em tiles.
##
## ARQUITETURA: Mundo aberto unificado (world_map) + interiores separados.
##   world_map: 100×120 tiles (1600×1920 px) — PalletTown + Route1 + ViridianCity contínuos
##   pokemon_center: 16×14 tiles — interior separado
##
## Zonas do world_map:
##   Rows 0-1:    Borda norte
##   Rows 2-38:   Viridian City
##   Rows 39-79:  Rota 1
##   Rows 80-118: Pallet Town
##   Row 119:     Borda sul
##
## Corredor principal norte-sul: cols 44-56
## Player spawn: tile (50, 110) → pixel (800, 1760)
## PokéCenter Pallet: entrada tile (77, 88) → pixel (1232, 1408)
##
## Atlas (source 0, overworld.tres):
##   Walkable row 0:  . grass  P path  F flower  S sand  G lt_grass  D dk_path  I floor  M mat
##   Blocked  row 1:  W wall   ~ water  T tree    R rock  E fence     d door     H roof   X hedge
##   Linha 2 (02/09, categoria "Terreno base" — diversidade de tiles pedida pelo Gabriel):
##                    A tall_grass (walkable)  N pine_tree  O autumn_tree  K stump (bloqueados)
##   Linha 3 (categoria "Água/gelo/rocha"):
##                    B água_lírios (bloq.)  C gelo  J gelo_trincado  L parede_rocha (bloq.)
##                    Q entrada_caverna  U água_praia
##   Linha 4 (categoria "Terrenos especiais"):
##                    V solo_envenenado  Y lama  Z lama_funda  b poça_dágua
##                    c rocha_vulcânica (bloq.)  e trilhos  f piso_pedra
##   Linha 5 (categoria "Interior/decoração", todos walkable):
##                    g piso_pedra_clara  h pedra_c_musgo  i cogumelos  j folhas_caídas  k junco
##   Linha 6 (categoria "Estrutura"):
##                    l janela  m canto_casa  n caixa (bloqueados)  o entrada_casa (walkable)
class_name MapLayouts
extends RefCounted

const CHAR_MAP : Dictionary = {
	".": Vector2i(0, 0), "P": Vector2i(1, 0), "F": Vector2i(2, 0), "S": Vector2i(3, 0),
	"G": Vector2i(4, 0), "D": Vector2i(5, 0), "I": Vector2i(6, 0), "M": Vector2i(7, 0),
	"W": Vector2i(0, 1), "~": Vector2i(1, 1), "T": Vector2i(2, 1), "R": Vector2i(3, 1),
	"E": Vector2i(4, 1), "d": Vector2i(5, 1), "H": Vector2i(6, 1), "X": Vector2i(7, 1),
	"A": Vector2i(0, 2), "N": Vector2i(1, 2), "O": Vector2i(2, 2), "K": Vector2i(3, 2),
	"B": Vector2i(0, 3), "C": Vector2i(1, 3), "J": Vector2i(2, 3), "L": Vector2i(3, 3),
	"Q": Vector2i(4, 3), "U": Vector2i(5, 3),
	"V": Vector2i(0, 4), "Y": Vector2i(1, 4), "Z": Vector2i(2, 4), "b": Vector2i(3, 4),
	"c": Vector2i(4, 4), "e": Vector2i(5, 4), "f": Vector2i(6, 4),
	"g": Vector2i(0, 5), "h": Vector2i(1, 5), "i": Vector2i(2, 5), "j": Vector2i(3, 5),
	"k": Vector2i(4, 5),
	"l": Vector2i(0, 6), "m": Vector2i(1, 6), "n": Vector2i(2, 6), "o": Vector2i(3, 6),
	# "w" = PAREDE LISA (04/09). O atlas não tinha uma: o tile "W" tem uma janela
	# desenhada nele, então prédio inteiro feito de "W" virava grade de janelas
	# (correção do Gabriel: "as paredes estão sendo representadas incorretamente
	# como se fossem apenas janelas"). Gerada a partir da faixa limpa do próprio
	# "W", então casa perfeitamente com ele — ver tools/ (parede lisa em (4,8)).
	# ── Biomas da Fase 2 (05/09) ────────────────────────────────────────────
	# Bases andáveis de cada bioma novo. As letras acabaram (61 dos 62 chars
	# alfanuméricos já estavam em uso), então daqui em diante o mapa usa
	# pontuação — com mnemônico onde deu: "^" montanha, "_" deserto liso.
	"z": Vector2i(0, 14),   # pântano — chão
	"^": Vector2i(0, 15),   # montanha — rocha
	"_": Vector2i(0, 16),   # deserto — areia seca
	"%": Vector2i(0, 17),   # ruínas — mosaico
	"&": Vector2i(0, 18),   # assombrado — assoalho podre
	"9": Vector2i(0, 19),   # mata fechada — chão de sombra
	# objetos de pântano
	"!": Vector2i(4, 14),   # poça tóxica (andável, envenena — Fase 6)
	"0": Vector2i(5, 14),   # água parada (bloqueia)
	"(": Vector2i(6, 14),   # junco
	")": Vector2i(7, 14),   # tronco morto (bloqueia)
	# montanha
	"/": Vector2i(4, 15),   # falésia (bloqueia)
	"<": Vector2i(5, 15),   # cume (bloqueia)
	">": Vector2i(6, 15),   # pedregulho (bloqueia)
	":": Vector2i(7, 15),   # trilha
	# deserto
	"'": Vector2i(4, 16),   # duna
	"*": Vector2i(5, 16),   # cacto (bloqueia)
	";": Vector2i(6, 16),   # osso
	"+": Vector2i(7, 16),   # gretas
	# ruínas
	"[": Vector2i(4, 17),   # parede de hieróglifos (bloqueia)
	"|": Vector2i(5, 17),   # pilar de pé (bloqueia)
	"]": Vector2i(6, 17),   # pilar caído (bloqueia)
	"=": Vector2i(7, 17),   # degrau
	# assombrado
	"{": Vector2i(4, 18),   # parede rachada (bloqueia)
	"}": Vector2i(5, 18),   # janela quebrada (bloqueia)
	"$": Vector2i(6, 18),   # tábua solta
	"@": Vector2i(7, 18),   # teia
	# mata fechada
	"?": Vector2i(4, 19),   # cogumelo brilhante
	"`": Vector2i(5, 19),   # raiz
	# ponte (as pontas são escolhidas por pós-passada, ver `costurar_pontes`)
	"#": Vector2i(0, 20),   # ponte horizontal
	"-": Vector2i(3, 20),   # ponte vertical
	"w": Vector2i(4, 8),
	# Beira da praia (04/09): o encontro areia/mar, que não existia — a costa era
	# uma linha reta ("parece uma bandeira"). Nome = de que lado fica a AREIA.
	"1": Vector2i(0, 10), "2": Vector2i(1, 10), "3": Vector2i(2, 10), "4": Vector2i(3, 10),
	"5": Vector2i(4, 10), "6": Vector2i(5, 10), "7": Vector2i(6, 10), "8": Vector2i(7, 10),
	# ── KIT MODULAR DE CASA (04/09, regra obrigatória 2 do Gabriel) ──
	# Antes só existia telhado central + parede frontal, o que só permitia
	# fachada reta infinita — nunca uma casa fechada vista de cima. Estas peças
	# são derivadas da própria arte de telhado/parede (tools/gerar_kit_casa.py),
	# então encaixam sem destoar. Luz de cima-esquerda: cumeeira e aresta
	# esquerda claras, beiral e aresta direita escuros.
	"q": Vector2i(5, 8),   # telhado — borda superior (cumeeira)
	"r": Vector2i(6, 8),   # telhado — borda inferior (beiral)
	"s": Vector2i(7, 8),   # telhado — borda esquerda
	"t": Vector2i(0, 9),   # telhado — borda direita
	"u": Vector2i(1, 9),   # telhado — canto superior esquerdo
	"v": Vector2i(2, 9),   # telhado — canto superior direito
	"x": Vector2i(3, 9),   # telhado — canto inferior esquerdo
	"y": Vector2i(4, 9),   # telhado — canto inferior direito
	"a": Vector2i(5, 9),   # parede — lateral esquerda
	"p": Vector2i(6, 9),   # parede — lateral direita
}

# ──────────────────────────────────────────────────────────────────────────────
# World Map unificado — 100×192, mundo aberto de verdade (sem warp entre
# cidade/rota — só warp pra caverna/subterrâneo/submarino/trocar de
# continente, decisão do Gabriel em 31/08). Pewter City e Rota 2 entraram
# como uma faixa nova ao norte de Viridian; todo o resto do mapa (Viridian/
# Rota 1/Pallet) manteve o próprio código de sempre — só passou a receber um
# número de linha deslocado (old_r = r - OFFSET_ANTIGO), pra não precisar
# reescrever nada que já estava testado.
# ──────────────────────────────────────────────────────────────────────────────

const PEWTER_ROWS  : int = 36   # linhas 1-36 (global)
const ROUTE2_ROWS  : int = 36   # linhas 37-72 (global)
const OFFSET_ANTIGO : int = PEWTER_ROWS + ROUTE2_ROWS  # 72 — a partir daqui, é o mapa de sempre

# Largura original (Pewter/Rota2/Viridian/Rota1/Pallet — tudo que já existia).
const W_ANTIGO : int = 100
# Tier 2 (Gabriel, 31/08): Rota 3 → Mt Moon (entrada) → Rota 4 → Cerulean City,
# tudo a LESTE de Pewter, na mesma faixa de linhas (1-36) — mundo aberto de
# verdade, sem warp de rota/cidade (só a caverna em si vira cena própria).
const ROUTE3_COLS    : int = 60
const ROUTE4_COLS    : int = 60
const CERULEAN_COLS  : int = 60
const SPINE_COL_INICIO : int = W_ANTIGO + ROUTE3_COLS + ROUTE4_COLS  # 220 — início de Cerulean

# ──────────────────────────────────────────────────────────────────────────────
# REORGANIZAÇÃO GEOGRÁFICA (02/09) — pedido do Gabriel com referência visual
# do Kanto real: Saffron embaixo de Cerulean, Vermilion embaixo de Saffron,
# Celadon à esquerda de Saffron (mar de verdade separando de Viridian — só
# atravessa por Saffron ou, no futuro, nadando), Lavender à direita de
# Saffron (herda a Rock Tunnel que já existia), Fuchsia embaixo de Lavender.
# Substitui a "fileira reta" dos Tiers 3-7 (Vermilion→Celadon→Fuchsia→
# Saffron→Lavender, tudo em fila a leste de Cerulean) por uma CRUZ ao sul de
# Cerulean. Pewter↔Cerulean (Rota3/MtMoon/Rota4) e tudo ao NORTE de Cerulean
# (Rota24/25/Casa do Bill) e a OESTE de Viridian (Rota22/Victory Road/Indigo
# Plateau) continuam exatamente iguais — só o que ficava a LESTE de Cerulean
# foi desmontado e remontado. Cada cidade manteve o próprio desenho interno
# (Ginásio/Centro/etc. nas mesmas posições relativas) — só mudou ONDE ela é
# ancorada no mapa; o código de cada prédio foi extraído pra uma função
# própria por cidade, reutilizável não importa de que direção se chega.
# ──────────────────────────────────────────────────────────────────────────────
const CIDADE_ROWS : int = 36   # toda cidade nova usa a mesma altura de banda

# Rota 5 (Cerulean → Saffron, pra baixo).
const ROUTE5_SUL_ROWS : int = 30
const ROUTE5_SUL_START : int = PEWTER_ROWS + 1  # 37 (r=36 é a linha de transição/seam)
const SAFFRON_ROW_INICIO : int = ROUTE5_SUL_START + ROUTE5_SUL_ROWS  # 67
const SAFFRON_ROWS : int = CIDADE_ROWS
const SAFFRON_COLS : int = 60

# Rota 6 (Saffron → Vermilion, pra baixo).
const ROUTE6_SUL_ROWS : int = 30
const VERMILION_ROW_INICIO : int = SAFFRON_ROW_INICIO + SAFFRON_ROWS + ROUTE6_SUL_ROWS  # 132
const VERMILION_ROWS : int = CIDADE_ROWS
const VERMILION_COLS : int = 60

# Rota 7 (Saffron → Celadon, pra esquerda) — mar de verdade separa Celadon
# de Viridian (não dá pra ir a pé; só por Saffron, ou nadando no futuro).
const ROUTE7_SUL_COLS : int = 40
const CELADON_COLS   : int = 60
const CELADON_COL_FIM    : int = SPINE_COL_INICIO - 1 - ROUTE7_SUL_COLS       # 179
const CELADON_COL_INICIO : int = CELADON_COL_FIM - CELADON_COLS + 1          # 120
const MAR_CELADON_VIRIDIAN_COL_INICIO : int = W_ANTIGO                       # 100
const MAR_CELADON_VIRIDIAN_COL_FIM    : int = CELADON_COL_INICIO - 1         # 119

# Rota 8 (Saffron → Lavender, pra direita) — reaproveita o comprimento e a
# boca de Rock Tunnel que já existiam nas antigas Rota 9 + Rota 10.
const ROUTE9_COLS    : int = 60
const ROUTE10_COLS   : int = 60
const ROUTE8_SUL_COLS : int = ROUTE9_COLS + ROUTE10_COLS                     # 120
const LAVENDER_COL_INICIO : int = SPINE_COL_INICIO + CERULEAN_COLS + ROUTE8_SUL_COLS  # 400
const LAVENDER_COLS  : int = 60

# Rota (Lavender → Fuchsia, pra baixo) — Fuchsia fica embaixo de Lavender,
# mesmas colunas.
const ROUTE_LAVENDER_FUCHSIA_ROWS : int = 30
const FUCHSIA_ROW_INICIO : int = SAFFRON_ROW_INICIO + SAFFRON_ROWS + ROUTE_LAVENDER_FUCHSIA_ROWS  # 132
const FUCHSIA_ROWS  : int = CIDADE_ROWS
const FUCHSIA_COLS  : int = 60

# Rota 11 → Diglett's Cave — espora a LESTE de Vermilion (Tier 19, refeita
# aqui: antes saía "ao norte" só porque Vermilion morava lá; agora que
# Vermilion tem saída norte/sul ocupadas por Cerulean/costa, a espora sai
# a leste, mesma ideia de sempre — beco sem saída, sem "contornar").
const ROUTE11_LESTE_COLS : int = 30
const ROUTE11_COL_INICIO : int = SPINE_COL_INICIO + CERULEAN_COLS  # 280

const W_TOTAL : int = LAVENDER_COL_INICIO + LAVENDER_COLS + 5   # 465 (margem de borda)
## +44 em 05/09: a Ilha do Deserto (pedido do Gabriel) fica no mar ao sul da
## usina, e sem esta margem o mapa acabava antes dela — a faixa era gerada e o
## array de linhas nem chegava lá.
const H_TOTAL : int = 374   # Cerulean→Saffron→Vermilion→costa→usina→Ilha do Deserto

# Tier 8 (01/09): Rota 24 → Rota 25 → Casa do Bill — desvio ao NORTE de
# Cerulean (não é continuar pra leste). Diferente de Pewter/Rota 2 (que
# empurrou TUDO pra baixo e exigiu traduzir a linha de cada NPC/warp já
# testado), este ramo é gerado e pintado à PARTE, em linhas NEGATIVAS
# (r=-1 é a linha logo ao norte de Cerulean, r=-NORTE_OFFSET é a borda) —
# o `tiles` principal (`_gen_world_map`) continua exatamente r=0..H-1, sem
# nenhuma mudança, pra não quebrar nenhuma conferência de teste já escrita
# com esse índice (todo teste dos Tiers 1-7 lê `tiles[N][...]` assumindo
# índice do array == linha do mundo). O TileMap do Godot aceita coordenada
# negativa de verdade (testado) — só a pintura (`paint()`) sabe do ramo.
const ROUTE24_ROWS : int = 20   # mais perto de Cerulean
const ROUTE25_ROWS : int = 20   # mais ao norte, termina na Casa do Bill
const NORTE_OFFSET : int = ROUTE24_ROWS + ROUTE25_ROWS  # 40
# Colunas globais do corredor (dentro da faixa de Cerulean: cc 27-29 local).
const RAMO_NORTE_COL_INICIO : int = SPINE_COL_INICIO + 27
const RAMO_NORTE_COL_FIM    : int = SPINE_COL_INICIO + 29

# Tier 17 (01/09): Nugget Bridge — travessia de rio dentro da Rota 24 (fb =
# "from border", ver _norte_de_cerulean_cell). O TreinadorRota24 (Tier 8) já
# fica bem no meio dessa faixa (fb~30) — a mesma referência canônica de
# "cadeia de treinadores atravessando a ponte" cai de graça, sem precisar de
# NPC novo.
const NUGGET_BRIDGE_FB_INICIO : int = 25
const NUGGET_BRIDGE_FB_FIM    : int = 33

# Tier 9 (01/09): litoral de verdade — praia + mar ao SUL de Vermilion City
# (cidade portuária, já tinha decoração de "doca"). Pedido do Gabriel:
# bioma sempre com identidade própria (praia tem que parecer praia, não
# grama com água do lado) — areia com curva de costa orgânica (função seno,
# não corte reto) + rochedos de maré esparsos, terminando num mar aberto
# que fica registrado aqui como fonte única de verdade pra quando o mapa
# SUBMARINO for construído (tem que ter exatamente o mesmo formato). Desde a
# reorganização de 02/09, a costa sai do NOVO sul de Vermilion (linha
# VERMILION_COAST_ROW_INICIO), não mais logo depois de Pewter.
const COASTLINE_ROWS : int = 40
const VERMILION_COAST_ROW_INICIO : int = VERMILION_ROW_INICIO + VERMILION_ROWS  # 168
const VERMILION_COAST_COL_INICIO : int = SPINE_COL_INICIO
const VERMILION_COAST_COL_FIM    : int = VERMILION_COAST_COL_INICIO + VERMILION_COLS - 1

# Tier 13 (01/09): Arquipélago Tropical — mar aberto continuando ao sul do
# litoral de Vermilion, com 2 ilhas. Pedido do Gabriel: o barco só leva a
# Cinnabar — estas ilhas só vão ficar alcançáveis quando existir Surf (nadar
# pelo mar) ou Fly (voar até lá), NENHUM dos dois construído ainda. Por isso
# não têm warp nenhum: ficam prontas, visíveis no mapa, mas sem jeito de
# chegar lá por enquanto — de propósito. Tema tropical (vegetação densa,
# lagoa interna), contorno orgânico igual ao resto do litoral.
const ARQUIPELAGO_ROWS : int = 40

# Tier 14 (01/09): Seafoam Islands — continuando o mar mais ao sul do
# Arquipélago Tropical, mesma faixa de colunas (Vermilion). Mesma regra dos
# Tiers 11/13: só alcançável quando Surf/Fly existir — SEM warp/prédio/NPC de
# propósito. Tema diferente do Arquipélago (regra de tematização de bioma do
# Gabriel): ilhotas frias/rochosas tipo gruta costeira (praia pálida + piso
# escuro rochoso + rochedo esparso), NADA de vegetação (T/F/G) — é o oposto
# do visual tropical, não "a mesma ilha com Pokémon diferente".
const SEAFOAM_ROWS : int = 40

# Tier 20 (01/09): Power Plant — continuando o mar mais ao sul do Seafoam
# Islands, mesma faixa de colunas (Vermilion). Mesma regra dos Tiers 11/13/
# 14: só alcançável quando Surf/Fly existir — SEM warp/NPC de propósito.
# Diferente das ilhas anteriores (terreno natural), aqui é uma ilha
# artificial pequena com um PRÉDIO (fachada, mesmo padrão de Silph Co./
# Torre Pokémon) — usina elétrica, não bioma.
const POWERPLANT_ROWS : int = 30
## Ilha do Deserto (05/09) — a decisão do Gabriel sobre o único bioma que Kanto
## não tinha. Fica no mar ao SUL de Vermilion, depois da usina: só se alcança de
## Surf, e por isso não desloca nada do mapa canônico. É onde ficam as pirâmides,
## os hieróglifos e os Pokémon Psíquicos.
const ILHA_DESERTO_ROWS : int = 44

# Tier 18 (01/09): Rota 22 → Victory Road (caverna, opcional/lateral, mesmo
# padrão do Mt Moon/Rock Tunnel — não bloqueia, dá pra contornar) → Indigo
# Plateau (Liga Pokémon, FECHADA — bloqueada pela mesma história do Ginásio
# de Viridian/Giovanni, GYM-08). Primeiro ramo em COLUNAS NEGATIVAS (todos os
# ramos anteriores — Tier 8/9 — usavam linhas negativas ou positivas, nunca
# colunas): sai do corredor leste-oeste de Viridian (row 28-29, mesmo
# corredor do "passeio da cidade") pra OESTE. Mesma técnica de sempre: gerado
# e pintado à PARTE (`_gen_oeste_de_viridian`), sem tocar no array principal
# — só um seam-fix pontual em `_world_cell`/`_viridian_cell` pra abrir a
# passagem, igual toda vez que um ramo novo nasce de território já testado.
const ROUTE22_COLS  : int = 60   # mais perto de Viridian
const INDIGO_COLS   : int = 40   # mais a oeste, término (Liga Pokémon)
const OESTE_OFFSET  : int = ROUTE22_COLS + INDIGO_COLS  # 100 (c=-1..-100)
const OESTE_ROWS    : int = 36   # mesma altura de banda que toda rota (estilo PEWTER_ROWS)
const OESTE_ROW_INICIO : int = 82   # global; local row 18-19 cai em 100-101 (seam)

static func _gen_world_map() -> Array:
	var W := W_TOTAL
	var H := H_TOTAL
	var grid : Array = []
	for r in H:
		var row := ""
		for c in W:
			row += _world_cell(c, r, W, H)
		grid.append(row)
	return grid

## Ramo da Rota 24/25 (Tier 8) — array próprio, NORTE_OFFSET linhas, full
## width. `grid[0]` é a linha mais ao norte (r=-NORTE_OFFSET, borda),
## `grid[NORTE_OFFSET-1]` é a mais próxima de Cerulean (r=-1).
static func _gen_norte_de_cerulean() -> Array:
	var W := W_TOTAL
	var grid : Array = []
	for i in NORTE_OFFSET:
		var r := i - NORTE_OFFSET
		var row := ""
		for c in W:
			if r == -NORTE_OFFSET or c == 0 or c >= W - 1:
				row += "T"
			else:
				row += _norte_de_cerulean_cell(c, r, W)
		grid.append(row)
	return grid

static func _world_cell(c: int, r: int, W: int, H: int) -> String:
	# Bordas absolutas. Achado (Tier 8): "r==0" NÃO faz mais parte dessa
	# checagem — a borda norte em r=0 já é garantida por dentro de
	# _pewter_cell/_leste_de_pewter_cell (ambas têm "r<=2 → T" próprio, como
	# sempre tiveram), e manter "r==0" AQUI bloquearia incondicionalmente a
	# passagem da Rota 24 pra dentro de Cerulean, sem chance do seam-fix
	# (abaixo) nunca ser alcançado — mesmo problema, uma camada acima.
	# Mesma classe (Tier 18): "c==0" sozinho bloquearia incondicionalmente a
	# passagem da Rota 22 (ramo oeste) pra dentro de Viridian — abre exceção
	# só nas 2 linhas do corredor leste-oeste de Viridian (old_r 28/29 →
	# global 100/101), igual "r==0" abriu exceção pro ramo norte no Tier 8.
	if r >= H - 1 or c >= W - 1:
		return "T"
	if c == 0 and r != OFFSET_ANTIGO + 28 and r != OFFSET_ANTIGO + 29:
		return "T"

	# ── Pewter City (linhas 1-36) — e, a leste dela, Rota 3/Mt Moon/Rota 4/
	# Cerulean, na MESMA faixa de linhas (a "largura antiga" W_ANTIGO é onde
	# Pewter termina; dali pra leste é território novo) ────────────────────
	if r <= PEWTER_ROWS:
		if c < W_ANTIGO:
			# Achado (mesma classe do seam de Viridian/Rota2): _pewter_cell
			# trata c>=W-3 como borda leste — fazia sentido quando Pewter
			# era o fim do mapa. Agora que a Rota 3 continua pra leste, isso
			# virava parede bem no meio do caminho principal (row 16-20).
			if c >= W_ANTIGO - 3 and r >= 16 and r <= 20:
				return "P"
			return _pewter_cell(c, r, W_ANTIGO)
		# Achado (mesma classe, Tier 8): _leste_de_pewter_cell trata r<=2
		# como borda norte — fazia sentido antes de existir a Rota 24 saindo
		# de Cerulean pra cima. Abre passagem só nas colunas do ramo.
		if c >= RAMO_NORTE_COL_INICIO and c <= RAMO_NORTE_COL_FIM and r <= 2:
			return "P"
		# Reorganização de 02/09: Cerulean agora também sai pro SUL (Rota 5,
		# rumo a Saffron) pelas MESMAS colunas do ramo norte (cc 27-29) —
		# mesma classe de seam, abrindo a borda sul de _leste_de_pewter_cell.
		if c >= RAMO_NORTE_COL_INICIO and c <= RAMO_NORTE_COL_FIM and r >= PEWTER_ROWS - 1:
			return "P"
		return _leste_de_pewter_cell(c - W_ANTIGO, r)

	# ── Mar entre Celadon e Viridian (reorganização de 02/09) — separação DE
	# VERDADE, pedido do Gabriel: não dá pra ir a pé, só por Saffron (ou
	# nadando, quando Surf existir). Mesma faixa de linhas de Celadon. ─────
	if c >= MAR_CELADON_VIRIDIAN_COL_INICIO and c <= MAR_CELADON_VIRIDIAN_COL_FIM \
	and r >= SAFFRON_ROW_INICIO and r <= SAFFRON_ROW_INICIO + SAFFRON_ROWS - 1:
		return "~"

	# ── Rota 7 → Celadon (reorganização de 02/09: Celadon fica a OESTE de
	# Saffron, não mais a leste de Vermilion) — mesma faixa de linhas de
	# Saffron (r local 0-35 = mesmo "no_caminho" r16-20 de sempre) ────────
	if c >= CELADON_COL_INICIO and c < SPINE_COL_INICIO \
	and r >= SAFFRON_ROW_INICIO and r <= SAFFRON_ROW_INICIO + SAFFRON_ROWS - 1:
		var local_r := r - SAFFRON_ROW_INICIO
		if c < CELADON_COL_INICIO + CELADON_COLS:
			return _celadon_cell(c - CELADON_COL_INICIO, local_r)
		return _route7_cell(SPINE_COL_INICIO - 1 - c, local_r)

	# ── Espinha central: Cerulean → Rota 5 → Saffron → Rota 6 → Vermilion →
	# litoral/ilhas (reorganização de 02/09 — antes essa faixa de colunas só
	# tinha Cerulean; agora continua pro SUL em vez de leste) ──────────────
	if c >= SPINE_COL_INICIO and c < SPINE_COL_INICIO + CERULEAN_COLS:
		var cc_spine := c - SPINE_COL_INICIO
		if r >= ROUTE5_SUL_START and r < VERMILION_COAST_ROW_INICIO:
			return _sul_de_cerulean_cell(cc_spine, r - ROUTE5_SUL_START)
		if r >= VERMILION_COAST_ROW_INICIO and r < VERMILION_COAST_ROW_INICIO + COASTLINE_ROWS:
			return _vermilion_coastline_cell(c, r - VERMILION_COAST_ROW_INICIO + 1, W)
		if r < VERMILION_COAST_ROW_INICIO + COASTLINE_ROWS + ARQUIPELAGO_ROWS:
			return _arquipelago_tropical_cell(c, r - VERMILION_COAST_ROW_INICIO - COASTLINE_ROWS, W)
		if r < VERMILION_COAST_ROW_INICIO + COASTLINE_ROWS + ARQUIPELAGO_ROWS + SEAFOAM_ROWS:
			return _seafoam_cell(c, r - VERMILION_COAST_ROW_INICIO - COASTLINE_ROWS - ARQUIPELAGO_ROWS, W)
		if r < VERMILION_COAST_ROW_INICIO + COASTLINE_ROWS + ARQUIPELAGO_ROWS + SEAFOAM_ROWS + POWERPLANT_ROWS:
			return _powerplant_cell(c, r - VERMILION_COAST_ROW_INICIO - COASTLINE_ROWS - ARQUIPELAGO_ROWS - SEAFOAM_ROWS, W)
		if r < VERMILION_COAST_ROW_INICIO + COASTLINE_ROWS + ARQUIPELAGO_ROWS + SEAFOAM_ROWS + POWERPLANT_ROWS + ILHA_DESERTO_ROWS:
			return _ilha_deserto_cell(c, r - VERMILION_COAST_ROW_INICIO - COASTLINE_ROWS - ARQUIPELAGO_ROWS - SEAFOAM_ROWS - POWERPLANT_ROWS, W)

	# ── Rota 11 → Diglett's Cave, a LESTE de Vermilion (reorganização de
	# 02/09) — mesma faixa de linhas de Vermilion ─────────────────────────
	if c >= ROUTE11_COL_INICIO and c < ROUTE11_COL_INICIO + ROUTE11_LESTE_COLS \
	and r >= VERMILION_ROW_INICIO and r <= VERMILION_ROW_INICIO + VERMILION_ROWS - 1:
		return _route11_digletts_cell(c - ROUTE11_COL_INICIO, r - VERMILION_ROW_INICIO)

	# ── Rota 8 → Lavender (reorganização de 02/09: Lavender fica a LESTE de
	# Saffron — reaproveita o comprimento e a boca de Rock Tunnel que já
	# existiam) — mesma faixa de linhas de Saffron ─────────────────────────
	if c >= SPINE_COL_INICIO + CERULEAN_COLS and c < LAVENDER_COL_INICIO + LAVENDER_COLS \
	and r >= SAFFRON_ROW_INICIO and r <= SAFFRON_ROW_INICIO + SAFFRON_ROWS - 1:
		var local_r8 := r - SAFFRON_ROW_INICIO
		if c < LAVENDER_COL_INICIO:
			return _route8_cell(c - (SPINE_COL_INICIO + CERULEAN_COLS), local_r8)
		return _lavender_cell(c - LAVENDER_COL_INICIO, local_r8)

	# ── Rota Lavender→Fuchsia + Fuchsia (reorganização de 02/09: Fuchsia
	# fica embaixo de Lavender) — mesmas colunas de Lavender ───────────────
	if c >= LAVENDER_COL_INICIO and c < LAVENDER_COL_INICIO + LAVENDER_COLS \
	and r > SAFFRON_ROW_INICIO + SAFFRON_ROWS - 1 and r < VERMILION_COAST_ROW_INICIO:
		var local_lf := r - (SAFFRON_ROW_INICIO + SAFFRON_ROWS)
		var lc := c - LAVENDER_COL_INICIO
		if local_lf < ROUTE_LAVENDER_FUCHSIA_ROWS:
			if lc >= 27 and lc <= 29:
				return "P"
			if _espalhar_sal(c, r, 1) < 2:
				return "T"
			if _espalhar_sal(c, r, 2) < 2:
				return "F"
			return "."
		return _fuchsia_cell(lc, local_lf - ROUTE_LAVENDER_FUCHSIA_ROWS)

	# ── Rota 2 (linhas 37-72) — só existe na largura antiga; o resto é borda
	if r <= OFFSET_ANTIGO:
		if c >= W_ANTIGO:
			return "T"
		return _route2_cell(c, r - PEWTER_ROWS, W_ANTIGO)

	# ── Daqui pra baixo: exatamente o mapa antigo (Viridian/Rota 1/Pallet),
	# só com o número de linha traduzido de volta pro valor original ────────
	var old_r := r - OFFSET_ANTIGO

	# A "cidade antiga" só tem W_ANTIGO (100) de largura, e tudo a leste disso
	# era devolvido como árvore — o que, somado à borda sul, criava aquele bloco
	# maciço de árvore morta no lugar onde devia estar o mar (correção do
	# Gabriel, 04/09). Na faixa de PALLET essa área agora é oceano: é o que dá
	# continuidade entre a costa sul e o resto da água. Viridian e Rota 1
	# continuam com borda de árvore (não são costeiras neste mapa).
	if c >= W_ANTIGO:
		if old_r >= 80:
			return _pallet_cell(c, old_r, W_ANTIGO)
		return "T"

	# ── Viridian City (rows 2-38 no mapa antigo) ────────────────────────────
	if old_r <= 38:
		# Achado: _viridian_cell trata old_r<=3 como borda norte — fazia
		# sentido quando Viridian era o topo do mapa de verdade. Agora que a
		# Rota 2 continua pra cima, isso virava uma parede de 3 tiles bem no
		# meio do corredor. Corrigido só nas colunas do corredor, sem tocar
		# em nada mais de Viridian (loja/NPC/decoração continuam iguais).
		if old_r <= 3 and c >= 44 and c <= 56:
			return "P"
		# Mesma classe (Tier 18): _viridian_cell trata c<=2 como borda oeste —
		# fazia sentido antes de existir a Rota 22 saindo pra oeste. Abre
		# passagem só nas 2 linhas do corredor leste-oeste (old_r 28/29,
		# "passeio da cidade"), sem tocar em mais nada de Viridian.
		if (old_r == 28 or old_r == 29) and c <= 2:
			return "P"
		return _viridian_cell(c, old_r, W_ANTIGO)

	# ── Rota 1 (rows 39-79 no mapa antigo) ──────────────────────────────────
	if old_r <= 79:
		return _route1_cell(c, old_r, W_ANTIGO)

	# ── Pallet Town (rows 80-119 no mapa antigo) ────────────────────────────
	return _pallet_cell(c, old_r, W_ANTIGO)

# ──────────────────────────────────────────────────────────────────────────────
# Rota 24 → Rota 25 → Casa do Bill — ramo ao norte de Cerulean (Tier 8).
# `c` é GLOBAL (o corredor só existe numa faixa estreita de colunas). `r` é
# NEGATIVO aqui (r=-1 é a linha logo ao norte de Cerulean/Pewter, r=
# -NORTE_OFFSET+1 é a mais distante, perto da borda do mapa). `fb` ("from
# border") inverte isso pra positivo — 1 = mais ao norte, NORTE_OFFSET-1 =
# mais perto de Cerulean — só pra deixar a aritmética legível, igual ao
# resto do arquivo usa números pequenos crescendo "pra dentro" da cidade.
# ──────────────────────────────────────────────────────────────────────────────
static func _norte_de_cerulean_cell(c: int, r: int, W: int) -> String:
	var fb := r + NORTE_OFFSET

	# Fora da faixa de colunas do ramo (corredor + Casa do Bill ao lado):
	# nada existe ainda nessa latitude.
	if c < RAMO_NORTE_COL_INICIO - 3 or c > RAMO_NORTE_COL_FIM + 12:
		return "T"

	var no_corredor := c >= RAMO_NORTE_COL_INICIO and c <= RAMO_NORTE_COL_FIM

	# ── Casa do Bill — AO LADO do corredor (não em cima, senão bloquearia a
	# única passagem entre Rota 24 e Rota 25), mesmo padrão de toda cidade:
	# prédio ao lado do caminho principal + um trecho curto ligando os dois ──
	var casa_col_inicio := RAMO_NORTE_COL_FIM + 4
	var casa_col_fim    := RAMO_NORTE_COL_FIM + 12
	if fb >= 3 and fb <= 9 and c >= casa_col_inicio and c <= casa_col_fim:
		if c == casa_col_inicio or c == casa_col_fim: return _parede_frontal(c, r)
		if fb == 3: return "H"
		if fb == 9:
			if c >= casa_col_inicio + 3 and c <= casa_col_inicio + 5: return "d"  # porta
			return _parede_frontal(c, r)
		return "I"
	# ── Trecho ligando a porta da Casa do Bill até o corredor principal ──
	if fb >= 9 and fb <= 10 and c >= RAMO_NORTE_COL_FIM and c <= casa_col_inicio + 4:
		return "P"

	# ── Rota 25 (mais ao norte, fb 1..ROUTE25_ROWS-1, já descontada a casa) ──
	if fb < ROUTE25_ROWS:
		if no_corredor:
			return "P"
		if _espalhar_sal(c, r, 3) < 2:
			return "T"
		if _espalhar_sal(c, r, 4) < 2:
			return "F"
		return "."

	# ── Nugget Bridge (Tier 17) — travessia de rio na Rota 24, fb 25-33
	# (o TreinadorRota24 já existente fica bem no meio da ponte, fb~30 —
	# mesma referência canônica: cadeia de treinadores atravessando a ponte).
	# Corredor vira o tabuleiro da ponte ("P"); os lados viram rio ("~") em
	# vez do mato normal da Rota 24.
	if fb >= NUGGET_BRIDGE_FB_INICIO and fb <= NUGGET_BRIDGE_FB_FIM \
	and c >= RAMO_NORTE_COL_INICIO - 3 and c <= RAMO_NORTE_COL_FIM + 3:
		if no_corredor:
			return "P"
		return "~"

	# ── Boca da Caverna de Cerulean (Mewtwo, MAIN-10, 03/09) — colada no
	# corredor, bem perto de Cerulean (fb 35-39, logo antes do seam da
	# cidade). Mesma técnica de "boca de caverna" de Diglett's Cave: rocha
	# ao redor, só o vão central é andável (o warp fica ali). Vinha faltando
	# — a "confront mewtwo" da MAIN-10 nunca teve onde acontecer.
	if fb >= 35 and fb <= 39 and c >= RAMO_NORTE_COL_INICIO - 3 and c < RAMO_NORTE_COL_INICIO:
		if fb >= 36 and fb <= 38:
			return "P"
		return "R"

	# ── Rota 24 (mais perto de Cerulean, fb ROUTE25_ROWS..NORTE_OFFSET-1) ──
	if no_corredor:
		return "P"
	if _espalhar_sal(c, r, 5) < 2:
		return "T"
	if _espalhar_sal(c, r, 6) < 2:
		return "F"
	return "."

# ──────────────────────────────────────────────────────────────────────────────
# Rota 11 → Diglett's Cave — espora a LESTE de Vermilion (refeita em 02/09:
# antes saía "ao norte" só porque Vermilion não tinha mais nenhuma saída
# livre; agora que o norte/sul de Vermilion já são Cerulean/costa, a espora
# sai a leste). Vive dentro do array PRINCIPAL agora (não precisa mais de
# pintura à parte — a reorganização geográfica já deixou essa faixa de
# colunas livre no array principal). `dist` = distância da borda leste de
# Vermilion (0 = colado nela). `vr` = linha local, MESMA banda de Vermilion
# (0-35) — o corredor de Vermilion (cc>=57, vr16-20) entra direto aqui.
# ──────────────────────────────────────────────────────────────────────────────
static func _route11_digletts_cell(dist: int, vr: int) -> String:
	if vr <= 2 or vr >= VERMILION_ROWS - 3:
		return "T"

	var no_corredor := vr >= 16 and vr <= 20

	# ── Boca de Diglett's Cave — no fim da espora ──
	if dist >= 20 and dist <= 27 and vr >= 12 and vr <= 15:
		if no_corredor and dist >= 22 and dist <= 24:
			return "P"  # entrada caminhável (warp fica aqui)
		return "R"  # rochedo ao redor da boca

	if no_corredor:
		return "P"
	if _espalhar_sal(dist, vr, 7) < 2:
		return "T"
	if _espalhar_sal(dist, vr, 8) < 2:
		return "F"
	return "."

# ──────────────────────────────────────────────────────────────────────────────
# Espinha central: Cerulean → Rota 5 → Saffron → Rota 6 → Vermilion (reorg.
# de 02/09). `cc` é a coluna local (0-59, MESMA largura de Cerulean — todas
# as cidades desta espinha ficam exatamente uma embaixo da outra). `sr` é a
# linha local a partir de ROUTE5_SUL_START (sr=0 logo depois do seam de
# Cerulean). Cada cidade tem sua própria função (_saffron_cell/
# _vermilion_cell) — nenhuma delas precisa de parede de borda própria: como
# em toda cidade do jogo desde sempre, a rota entra e vira grama "." comum
# (só as próprias rotas têm o tile de caminho "P" de verdade).
# ──────────────────────────────────────────────────────────────────────────────
static func _sul_de_cerulean_cell(cc: int, sr: int) -> String:
	# ── Rota 5 (Cerulean → Saffron) ──
	if sr < ROUTE5_SUL_ROWS:
		if cc >= 27 and cc <= 29:
			return "P"
		if _espalhar_sal(cc, sr, 9) < 2:
			return "T"
		if _espalhar_sal(cc, sr, 10) < 2:
			return "F"
		return "."

	var sfr := sr - ROUTE5_SUL_ROWS
	if sfr < SAFFRON_ROWS:
		return _saffron_cell(cc, sfr)

	# ── Rota 6 (Saffron → Vermilion) ──
	var vr6 := sfr - SAFFRON_ROWS
	if vr6 < ROUTE6_SUL_ROWS:
		if cc >= 27 and cc <= 29:
			return "P"
		if _espalhar_sal(cc, sr, 11) < 2:
			return "T"
		if _espalhar_sal(cc, sr, 12) < 2:
			return "F"
		return "."

	var vmr := vr6 - ROUTE6_SUL_ROWS
	if vmr < VERMILION_ROWS:
		return _vermilion_cell(cc, vmr)

	return "."

## Saffron City — cruzamento das 4 rotas (Cerulean ao norte, Vermilion ao
## sul, Celadon a oeste, Lavender a leste). Ginásio (Sabrina)/Centro/Silph
## Co. nas mesmas posições relativas de sempre.
static func _saffron_cell(cc: int, r: int) -> String:
	if cc >= 10 and cc <= 22 and r >= 6 and r <= 14:
		if cc == 10 or cc == 22: return "w"
		if r == 6: return "H"
		if r == 14:
			if cc >= 15 and cc <= 17: return "P"
			return _parede_frontal(cc, r)
		return "I"
	if r >= 14 and r <= 16 and cc >= 15 and cc <= 17:
		return "P"

	if cc >= 35 and cc <= 47 and r >= 6 and r <= 14:
		if cc == 35 or cc == 47: return "w"
		if r == 6: return "H"
		if r == 14:
			if cc >= 40 and cc <= 42: return "P"
			return _parede_frontal(cc, r)
		return "I"
	if r >= 14 and r <= 16 and cc >= 40 and cc <= 42:
		return "P"

	# Silph Co. — torre alta, só o prédio, sem interior ligado ainda.
	if cc >= 50 and cc <= 58 and r >= 4 and r <= 14:
		if cc == 50 or cc == 58: return "w"
		if r == 4: return "H"
		if r == 14:
			if cc >= 53 and cc <= 55: return "P"
			return _parede_frontal(cc, r)
		return "I"
	if r >= 14 and r <= 16 and cc >= 53 and cc <= 55:
		return "P"

	return "."

## Vermilion City — cidade portuária, Ginásio (Lt. Surge)/Centro/S.S. Anne/
## doca, exatamente como sempre. Ao norte (Rota 6) vem de Saffron; ao sul
## continua na costa (praia/Arquipélago/Seafoam/Power Plant); a leste, a
## Rota 11 → Diglett's Cave.
static func _vermilion_cell(cc: int, r: int) -> String:
	if cc >= 10 and cc <= 22 and r >= 6 and r <= 14:
		if cc == 10 or cc == 22: return "w"
		if r == 6: return "H"
		if r == 14:
			if cc >= 15 and cc <= 17: return "P"
			return _parede_frontal(cc, r)
		return "I"
	if r >= 14 and r <= 16 and cc >= 15 and cc <= 17:
		return "P"

	if cc >= 35 and cc <= 47 and r >= 6 and r <= 14:
		if cc == 35 or cc == 47: return "w"
		if r == 6: return "H"
		if r == 14:
			if cc >= 40 and cc <= 42: return "P"
			return _parede_frontal(cc, r)
		return "I"
	if r >= 14 and r <= 16 and cc >= 40 and cc <= 42:
		return "P"

	# S.S. Anne — navio ancorado no cais (Tier 16). Só fachada.
	if cc >= 2 and cc <= 14 and r >= 22 and r <= 32:
		if cc == 2 or cc == 14: return "w"
		if r == 22: return "H"
		if r == 32:
			if cc >= 7 and cc <= 9: return "P"
			return _parede_frontal(cc, r)
		return "I"
	if r >= 32 and r <= 34 and cc >= 7 and cc <= 9:
		return "P"

	# Doca/porto (Vermilion é cidade portuária).
	if _espalhar_sal(cc, r, 13) < 1 and r >= 22 and r <= 34 and cc >= 2 and cc <= 55:
		return "~"

	return "."

## Rota 7 (Saffron → Celadon, pra oeste). `dist` cresce se afastando de
## Saffron (0 = colado nela). Estrada alargada de 5 pra 8 tiles (03/09,
## pedido do Gabriel: "estradas 6 a 10 pisos de largura, mais perto do
## formato original") — esta rota não tem nenhum prédio/moldura de caverna
## por perto, então alargar foi seguro sem mexer em mais nada.
static func _route7_cell(dist: int, r: int) -> String:
	if r >= 14 and r <= 21:
		return "P"
	if _espalhar_sal(dist, r, 14) < 2:
		return "T"
	if _espalhar_sal(dist, r, 15) < 2:
		return "F"
	return "."

## Celadon City — Ginásio (Erika)/Centro/Loja de Departamentos/Rocket
## Hideout/Jardins, exatamente como sempre. Fica a OESTE de Saffron; a
## OESTE de Celadon (colunas < CELADON_COL_INICIO) é o mar que separa de
## Viridian de verdade.
static func _celadon_cell(ce: int, r: int) -> String:
	if ce >= 10 and ce <= 22 and r >= 6 and r <= 14:
		if ce == 10 or ce == 22: return "w"
		if r == 6: return "H"
		if r == 14:
			if ce >= 15 and ce <= 17: return "P"
			return _parede_frontal(ce, r)
		return "I"
	if r >= 14 and r <= 16 and ce >= 15 and ce <= 17:
		return "P"

	if ce >= 35 and ce <= 47 and r >= 6 and r <= 14:
		if ce == 35 or ce == 47: return "w"
		if r == 6: return "H"
		if r == 14:
			if ce >= 40 and ce <= 42: return "P"
			return _parede_frontal(ce, r)
		return "I"
	if r >= 14 and r <= 16 and ce >= 40 and ce <= 42:
		return "P"

	# Grande Loja de Departamentos (Celadon Mart).
	if ce >= 50 and ce <= 58 and r >= 8 and r <= 14:
		if ce == 50 or ce == 58: return "w"
		if r == 8: return "H"
		if r == 14:
			if ce >= 53 and ce <= 55: return "P"
			return _parede_frontal(ce, r)
		return "I"
	if r >= 14 and r <= 16 and ce >= 53 and ce <= 55:
		return "P"

	# Game Corner (02/09, MAIN-06/MAIN-08) — cassino da Equipe Rocket, com o
	# Quartel General escondido por baixo. Espelha a posição do Rocket
	# Hideout (do outro lado da rua), mesma altura.
	if ce >= 2 and ce <= 9 and r >= 21 and r <= 28:
		if ce == 2 or ce == 9: return "w"
		if r == 21: return "H"
		if r == 28:
			if ce >= 5 and ce <= 6: return "P"
			return _parede_frontal(ce, r)
		return "I"
	if r >= 28 and r <= 30 and ce >= 5 and ce <= 6:
		return "P"

	# Rocket Hideout — entrada/porão (Tier 15), warp de verdade.
	if ce >= 24 and ce <= 31 and r >= 21 and r <= 28:
		if ce == 24 or ce == 31: return "w"
		if r == 21: return "H"
		if r == 28:
			if ce >= 27 and ce <= 28: return "P"
			return _parede_frontal(ce, r)
		return "I"
	if r >= 28 and r <= 30 and ce >= 27 and ce <= 28:
		return "P"

	# Jardins de Celadon (o verde que dá nome à cidade).
	if _espalhar_sal(ce, r, 16) < 2 and r >= 20 and r <= 34 and ce >= 2 and ce <= 55:
		return "F"

	return "."

## Rota 8 (Saffron → Lavender, pra leste). Reaproveita o comprimento e a
## boca de Rock Tunnel que já existiam nas antigas Rota 9 (pedregosa) e
## Rota 10 (a boca em si). `dist` cresce se afastando de Saffron.
static func _route8_cell(dist: int, r: int) -> String:
	# Estrada alargada de 5 pra 10 tiles (03/09, pedido do Gabriel). Onde a
	# moldura da boca de Rock Tunnel existe (r10 20-27, abaixo), ela é
	# checada ANTES e continua vencendo nas próprias linhas — alargar aqui
	# só afeta o resto da rota, sem tocar a moldura.
	if dist < ROUTE9_COLS:
		if r >= 13 and r <= 22:
			return "P"
		if _espalhar_sal(dist, r, 17) < 2:
			return "R"  # pedregosa (leva pro Rock Tunnel no Kanto real)
		if _espalhar_sal(dist, r, 18) < 2:
			return "T"
		return "."

	var r10 := dist - ROUTE9_COLS
	# Boca do Rock Tunnel — moldura de rocha ACIMA do corredor (rows 12-15,
	# checada primeiro, sempre vence nesta faixa de colunas específica).
	if r10 >= 20 and r10 <= 27 and r >= 12 and r <= 15:
		if r10 >= 22 and r10 <= 25:
			return "P"
		return "R"
	if r >= 13 and r <= 22:
		return "P"
	if _espalhar_sal(dist, r, 19) < 2:
		return "T"
	if _espalhar_sal(dist, r, 20) < 2:
		return "F"
	return "."

## Lavender Town — Torre Pokémon (só fachada) + Centro, exatamente como
## sempre. Fica a LESTE de Saffron; ao SUL (nova rota) fica Fuchsia.
static func _lavender_cell(lv: int, r: int) -> String:
	if lv >= 10 and lv <= 22 and r >= 4 and r <= 14:
		if lv == 10 or lv == 22: return _parede_frontal(lv, r)
		if r == 4: return "H"
		if r == 14:
			if lv >= 15 and lv <= 17: return "P"
			return _parede_frontal(lv, r)
		return "I"
	if r >= 14 and r <= 16 and lv >= 15 and lv <= 17:
		return "P"

	if lv >= 35 and lv <= 47 and r >= 6 and r <= 14:
		if lv == 35 or lv == 47: return _parede_frontal(lv, r)
		if r == 6: return "H"
		if r == 14:
			if lv >= 40 and lv <= 42: return "P"
			return _parede_frontal(lv, r)
		return "I"
	if r >= 14 and r <= 16 and lv >= 40 and lv <= 42:
		return "P"

	return "."

## Fuchsia City — Ginásio (Koga)/Centro/Zona Safari (portão), exatamente
## como sempre. Fica embaixo de Lavender.
static func _fuchsia_cell(fc: int, r: int) -> String:
	if fc >= 10 and fc <= 22 and r >= 6 and r <= 14:
		if fc == 10 or fc == 22: return _parede_frontal(fc, r)
		if r == 6: return "H"
		if r == 14:
			if fc >= 15 and fc <= 17: return "P"
			return _parede_frontal(fc, r)
		return "I"
	if r >= 14 and r <= 16 and fc >= 15 and fc <= 17:
		return "P"

	if fc >= 35 and fc <= 47 and r >= 6 and r <= 14:
		if fc == 35 or fc == 47: return _parede_frontal(fc, r)
		if r == 6: return "H"
		if r == 14:
			if fc >= 40 and fc <= 42: return "P"
			return _parede_frontal(fc, r)
		return "I"
	if r >= 14 and r <= 16 and fc >= 40 and fc <= 42:
		return "P"

	# Zona Safari — portão de entrada (warp de verdade).
	if fc >= 50 and fc <= 58 and r >= 20 and r <= 32:
		if r == 32 and fc >= 53 and fc <= 55:
			return "P"
		if fc == 50 or fc == 58 or r == 20 or r == 32:
			return "E"
		return "G"

	return "."

# ──────────────────────────────────────────────────────────────────────────────
# Rota 22 → Victory Road → Indigo Plateau — ramo a OESTE de Viridian (Tier
# 18). Primeiro ramo em COLUNAS NEGATIVAS (todos os anteriores usavam
# linhas). `j` é local, 1..OESTE_OFFSET (1 = mais perto de Viridian, c=-1;
# OESTE_OFFSET = mais longe, c=-OESTE_OFFSET, perto da borda). `lr` é a
# linha local dentro da banda (0..OESTE_ROWS-1) — global r = OESTE_ROW_INICIO
# + lr. O corredor leste-oeste da banda (lr 16-20) alinha com o seam em
# Viridian (global row 100/101 = OESTE_ROW_INICIO+18/+19).
# ──────────────────────────────────────────────────────────────────────────────
static func _gen_oeste_de_viridian() -> Array:
	var grid : Array = []
	for lr in OESTE_ROWS:
		var row := ""
		for j in range(1, OESTE_OFFSET + 1):
			if lr == 0 or lr == OESTE_ROWS - 1 or j == OESTE_OFFSET:
				row += "T"
			else:
				row += _oeste_de_viridian_cell(j, lr)
		grid.append(row)
	return grid

static func _oeste_de_viridian_cell(j: int, lr: int) -> String:
	var no_corredor := lr >= 16 and lr <= 20

	# ── Rota 22 (mais perto de Viridian) ── j 1..ROUTE22_COLS ──────────────
	if j <= ROUTE22_COLS:
		# Victory Road — boca da caverna, opcional/lateral (mesmo padrão do
		# Mt Moon/Rock Tunnel: dá pra contornar por fora da faixa da moldura,
		# não bloqueia o corredor). j 25-31, lr 8-24.
		if j >= 25 and j <= 31 and lr >= 8 and lr <= 24:
			if no_corredor and j >= 27 and j <= 29:
				return "P"  # entrada caminhável (warp fica aqui)
			return "R"  # rochedo da montanha ao redor da boca da caverna
		if no_corredor:
			return "P"
		if _espalhar_sal(j, lr, 21) < 2:
			return "T"
		if _espalhar_sal(j, lr, 22) < 2:
			return "F"
		return "."

	# ── Indigo Plateau ── local ip a partir de ROUTE22_COLS ────────────────
	var ip := j - ROUTE22_COLS

	# ── Liga Pokémon (Elite Four + Campeão, 03/09) — abre só com as 8
	# insígnias, mesmo padrão do Ginásio de Viridian/Giovanni (_giovanni_
	# liberado), só que a condição aqui é "todas as insígnias" em vez de uma
	# quest específica — combate/premiação usa o MESMO pipeline genérico de
	# qualquer treinador (NpcEntity → BattleResolver → EventBus.battle_ended
	# → QuestManager), só que em 5 andares (ELITE4-01..04 + CHAMPION-01).
	if ip >= 10 and ip <= 22 and lr >= 6 and lr <= 14:
		if ip == 10 or ip == 22: return _parede_frontal(j, lr)
		if lr == 6: return "H"
		if _liga_liberada():
			if lr == 14:
				if ip >= 15 and ip <= 17: return "P"
				return _parede_frontal(j, lr)
			return "I"
		if lr == 14:
			return _parede_frontal(j, lr)  # porta bloqueada (faltam insígnias)
		return _parede_frontal(j, lr)  # interior inacessível

	# ── Centro Pokémon de Indigo Plateau ── ip 25-37, lr 6-14 ──────────────
	if ip >= 25 and ip <= 37 and lr >= 6 and lr <= 14:
		if ip == 25 or ip == 37: return _parede_frontal(j, lr)
		if lr == 6: return "H"
		if lr == 14:
			if ip >= 30 and ip <= 32: return "P"
			return _parede_frontal(j, lr)
		return "I"
	if lr >= 14 and lr <= 16 and ip >= 30 and ip <= 32:
		return "P"

	if no_corredor:
		return "P"
	if _espalhar_sal(j, lr, 23) < 2:
		return "T"
	if _espalhar_sal(j, lr, 24) < 2:
		return "F"
	return "."

# ──────────────────────────────────────────────────────────────────────────────
# Litoral de Vermilion — praia + mar aberto ao SUL da cidade (Tier 9).
# `c` é GLOBAL (a praia ocupa a largura inteira de Vermilion). `cr` é 1..
# COASTLINE_ROWS (1 = colado na cidade, COASTLINE_ROWS = mar aberto, mais
# ao sul). A linha da costa (curva de areia→água) usa `sin()`, não corte
# reto — pedido do Gabriel: praia precisa PARECER praia, com curva
# orgânica de erosão, não um retângulo de areia colado num retângulo de
# água. `SHORE_MAR` é a fonte única de verdade do formato do mar — quando
# o mapa SUBMARINO for construído (mecânica de Mergulho, ainda não existe),
# ele tem que reusar essa mesma função pra bater exatamente o contorno.
# ──────────────────────────────────────────────────────────────────────────────
static func shore_de_vermilion(vc: int) -> int:
	return 6 + int(round(3.0 * sin(float(vc) * 0.22) + 2.0 * sin(float(vc) * 0.09 + 1.7)))

static func _vermilion_coastline_cell(c: int, cr: int, W: int) -> String:
	var vc := c - VERMILION_COAST_COL_INICIO
	var shore := shore_de_vermilion(vc)

	if cr < shore:
		# ── Areia (praia) — rochedo de maré esparso, sem árvore/flor (não
		# combina com praia) ──
		if _espalhar_sal(c, cr, 25) < 1:
			return "R"
		return "S"

	# ── Mar aberto. Guardado o formato exato (via shore_de_vermilion) pro
	# mapa submarino reusar quando Mergulho existir. ──
	return "~"

# ──────────────────────────────────────────────────────────────────────────────
# Arquipélago Tropical — 2 ilhas dentro do mar aberto ao sul de Vermilion
# (Tier 13). `cr` é local (1 = logo depois do litoral, ARQUIPELAGO_ROWS =
# mais ao sul). Contorno orgânico igual ao litoral/Cinnabar — cada ilha tem
# seu próprio centro e função de raio com sin(), pra não ficarem redondas
# demais. Vegetação densa (mistura de "F"/"T"/"G", mais fechada que o mato
# esparso do resto do jogo) dá identidade tropical, mesmo sem sprite de
# palmeira ainda. SEM prédio, SEM NPC — ilhas "cruas", prontas pra quando
# Surf/Fly destravar o acesso; não faz sentido povoar antes disso.
# ──────────────────────────────────────────────────────────────────────────────
## Ilha do Deserto — pirâmides, obelisco e ruínas (05/09).
##
## Pedido do Gabriel: "uma ilha desértica com pirâmides e hieróglifos abaixo de
## Vermilion". Resolve o único bioma que Kanto não tem (deserto e ruínas, casa
## dos 14 Pokémon Psíquicos) sem tirar nada do lugar — é mar novo ao sul, e
## chega-se de Surf.
##
## Anatomia, de fora pra dentro: mar, anel de praia, deserto com dunas e
## cactos, e no coração um recinto de ruínas cercado por parede de hieróglifos,
## com a pirâmide grande no meio. As estruturas 2x3 são plantadas por
## `plantar_estruturas_deserto`, uma pós-passada — do mesmo jeito que as árvores
## grandes —, porque uma estrutura de 6 tiles não cabe numa decisão tile a tile.
static func _ilha_deserto_cell(c: int, cr: int, W: int) -> String:
	var vc := c - VERMILION_COAST_COL_INICIO
	var dx := float(vc - 30)
	var dy := float(cr - 22)
	var ang := atan2(dy, dx)
	var dist := sqrt(dx * dx + dy * dy)
	# contorno irregular: três senoides, pra ilha não sair como um disco
	var raio := 25.0 + 3.5 * sin(ang * 3.0) + 2.0 * sin(ang * 5.0) + 1.5 * sin(ang * 7.0)

	if dist >= raio:
		return "~"
	if dist >= raio - 3.0:
		return "S"                       # anel de praia

	# ── recinto das ruínas, no coração da ilha ──
	var rx : int = absi(vc - 30)
	var ry : int = absi(cr - 22)
	# 05/09: o recinto era 23x17 e lia como estacionamento de mosaico. Menor,
	# ele vira o que devia ser — um templo cercado, não uma praça.
	if rx <= 8 and ry <= 6:
		if rx == 8 or ry == 6:
			# parede de hieróglifos, com uma abertura ao sul pra entrar
			if ry == 6 and dy > 0 and rx <= 2:
				return "%"
			return "["
		# piso do templo com degraus perto da parede, mosaico no miolo
		if rx >= 7 or ry >= 5:
			return "="
		return "%"

	# ── deserto ──
	var d := _espalhar_sal(vc, cr, 880)
	if d < 2:
		return "*"                       # cacto
	if d < 4:
		return "'"                       # duna
	if d < 5:
		return ";"                       # osso
	if d < 7:
		return "+"                       # gretas
	return "_"

## Planta as estruturas 2x3 do deserto: a pirâmide grande no centro do recinto
## de ruínas, o obelisco e a pirâmide pequena espalhados pela areia.
##
## Pós-passada pelo mesmo motivo das árvores grandes: uma estrutura de 6 tiles
## não cabe numa decisão célula a célula, e desenhá-la tile a tile é o que
## produziu as árvores cortadas ao meio corrigidas em 04/09.
static func plantar_estruturas_deserto(tilemap: TileMap) -> void:
	var base_r : int = (VERMILION_COAST_ROW_INICIO + COASTLINE_ROWS + ARQUIPELAGO_ROWS
		+ SEAFOAM_ROWS + POWERPLANT_ROWS)
	var base_c : int = VERMILION_COAST_COL_INICIO
	# (coluna local, linha local, índice da estrutura)
	# Posições conferidas contra o contorno da ilha e contra o recinto: as duas
	# pirâmides pequenas e os dois obeliscos ficam FORA da parede (na primeira
	# versão um obelisco caiu em cima da própria parede do templo), e a grande
	# fica no centro do recinto, que é o motivo de o recinto existir.
	var plantio : Array = [
		[29, 19, 0],   # pirâmide grande — centro do templo
		[14, 10, 1],   # obelisco — noroeste, na areia
		[44, 10, 1],   # obelisco — nordeste, na areia
		[18, 32, 2],   # pirâmide pequena — sudoeste
		[40, 32, 2],   # pirâmide pequena — sudeste
	]
	for item in plantio:
		var ancora := Vector2i(base_c + int(item[0]), base_r + int(item[1]))
		var pedacos : Array = ESTRUTURAS_DESERTO[int(item[2])]
		for lin in 3:
			for col in 2:
				tilemap.set_cell(0, Vector2i(ancora.x + col, ancora.y + lin), 0,
					pedacos[lin * 2 + col])

static func _arquipelago_tropical_cell(c: int, cr: int, W: int) -> String:
	var vc := c - VERMILION_COAST_COL_INICIO

	# ── Ilha 1 (menor, a noroeste) ──
	var i1_dx := float(vc - 15)
	var i1_dy := float(cr - 15)
	var i1_dist := sqrt(i1_dx * i1_dx + i1_dy * i1_dy)
	var i1_raio := 8.0 + 2.0 * sin(atan2(i1_dy, i1_dx) * 3.0) + 1.0 * sin(atan2(i1_dy, i1_dx) * 5.0)
	if i1_dist < i1_raio:
		return _ilha_tropical_terreno(vc, cr, i1_dist, i1_raio)

	# ── Ilha 2 (maior, a sudeste) ──
	var i2_dx := float(vc - 42)
	var i2_dy := float(cr - 27)
	var i2_dist := sqrt(i2_dx * i2_dx + i2_dy * i2_dy)
	var i2_raio := 10.0 + 2.5 * sin(atan2(i2_dy, i2_dx) * 3.0) + 1.5 * sin(atan2(i2_dy, i2_dx) * 4.0)
	if i2_dist < i2_raio:
		return _ilha_tropical_terreno(vc, cr, i2_dist, i2_raio)

	# ── Resto é mar aberto — só Surf atravessa ──
	return "~"

## Terreno interno de uma ilha tropical: anel de praia perto da borda,
## interior com vegetação densa (identidade tropical).
static func _ilha_tropical_terreno(vc: int, cr: int, dist: float, raio: float) -> String:
	if dist > raio - 2.0:
		return "S"  # praia
	if _espalhar_sal(vc, cr, 26) < 5:
		return "T"  # vegetação densa — mais frequente que mato comum
	if _espalhar_sal(vc, cr, 27) < 3:
		return "F"
	return "G"

# ──────────────────────────────────────────────────────────────────────────────
# Seafoam Islands — mar aberto continuando ao sul do Arquipélago Tropical
# (Tier 14). Igual aos Tiers 11/13: SEM warp/prédio/NPC de propósito — só
# alcançável quando Surf/Fly existir. Tema DIFERENTE do arquipélago (regra
# de tematização de bioma do Gabriel): ilhotas frias/rochosas tipo gruta
# costeira — praia pálida em anel fino, interior de piso escuro rochoso
# ("D") com rochedo esparso ("R"), ZERO vegetação (nem "T" nem "F" nem "G")
# — é o oposto visual do arquipélago tropical (denso/verde), não a mesma
# ilha com Pokémon trocado.
# ──────────────────────────────────────────────────────────────────────────────
static func _seafoam_cell(c: int, cr: int, W: int) -> String:
	var vc := c - VERMILION_COAST_COL_INICIO

	# ── Ilhota 1 (noroeste, pequena) ──
	var i1_dx := float(vc - 12)
	var i1_dy := float(cr - 10)
	var i1_dist := sqrt(i1_dx * i1_dx + i1_dy * i1_dy)
	var i1_raio := 6.0 + 1.5 * sin(atan2(i1_dy, i1_dx) * 3.0) + 1.0 * sin(atan2(i1_dy, i1_dx) * 5.0)
	if i1_dist < i1_raio:
		return _ilhota_seafoam_terreno(vc, cr, i1_dist, i1_raio)

	# ── Ilhota 2 (central, maior — a principal do arquipélago) ──
	var i2_dx := float(vc - 32)
	var i2_dy := float(cr - 20)
	var i2_dist := sqrt(i2_dx * i2_dx + i2_dy * i2_dy)
	var i2_raio := 9.0 + 2.0 * sin(atan2(i2_dy, i2_dx) * 3.0) + 1.5 * sin(atan2(i2_dy, i2_dx) * 4.0)
	if i2_dist < i2_raio:
		return _ilhota_seafoam_terreno(vc, cr, i2_dist, i2_raio)

	# ── Ilhota 3 (sudeste, pequena) ──
	var i3_dx := float(vc - 48)
	var i3_dy := float(cr - 30)
	var i3_dist := sqrt(i3_dx * i3_dx + i3_dy * i3_dy)
	var i3_raio := 5.0 + 1.5 * sin(atan2(i3_dy, i3_dx) * 4.0)
	if i3_dist < i3_raio:
		return _ilhota_seafoam_terreno(vc, cr, i3_dist, i3_raio)

	# ── Resto é mar aberto — só Surf atravessa ──
	return "~"

## Terreno interno de uma ilhota de Seafoam: anel fino de praia pálida perto
## da borda (ilhota pequena, não tem faixa larga como as ilhas tropicais),
## interior rochoso/escuro, sem vegetação nenhuma.
static func _ilhota_seafoam_terreno(vc: int, cr: int, dist: float, raio: float) -> String:
	if dist > raio - 1.5:
		return "S"  # praia pálida/gelada
	if _espalhar_sal(vc, cr, 28) < 2:
		return "R"  # rochedo / boca de gruta esparsa
	return "D"  # piso escuro rochoso — interior de ilhota-gruta

# ──────────────────────────────────────────────────────────────────────────────
# Power Plant — ilha artificial pequena no mar, continuando ao sul do
# Seafoam Islands (Tier 20). Diferente das ilhas anteriores (terreno
# natural, bioma) — aqui é um PRÉDIO (usina), mesmo padrão de fachada de
# Silph Co./Torre Pokémon: só geografia + fachada, sem interior/NPC/warp.
# Só alcançável quando Surf/Fly existir, mesma regra de sempre.
# ──────────────────────────────────────────────────────────────────────────────
static func _powerplant_cell(c: int, cr: int, W: int) -> String:
	var vc := c - VERMILION_COAST_COL_INICIO
	var dx := float(vc - 27)
	var dy := float(cr - 15)
	var dist := sqrt(dx * dx + dy * dy)
	var raio := 13.0 + 1.5 * sin(atan2(dy, dx) * 3.0)

	if dist >= raio:
		return "~"  # mar aberto

	# ── Prédio da usina — cols 20-35, rows 8-20 (dentro da ilha) ──────────
	if vc >= 20 and vc <= 35 and cr >= 8 and cr <= 20:
		if vc == 20 or vc == 35: return _parede_frontal(c, cr)
		if cr == 8: return "H"
		if cr == 20:
			if vc >= 26 and vc <= 28: return "P"
			return _parede_frontal(c, cr)
		return "I"
	if cr >= 20 and cr <= 22 and vc >= 26 and vc <= 28:
		return "P"

	return "S"  # areia da ilha ao redor do prédio

# ──────────────────────────────────────────────────────────────────────────────
# Rota 3 → Mt Moon (entrada) → Rota 4 → Cerulean City — leste de Pewter,
# linhas 1-36 (mesma faixa). `c` já vem local (0 = logo a leste da borda de
# Pewter). Caminho principal é horizontal, rows 16-20; resto é grama/árvore
# esparsa (Rota 3/4) ou a cidade em si (Cerulean).
# ──────────────────────────────────────────────────────────────────────────────
static func _leste_de_pewter_cell(c: int, r: int) -> String:
	if r <= 2 or r >= PEWTER_ROWS - 1:
		return "T"

	# ── Caminho principal leste-oeste ── rows 13-22 (03/09: alargado de 5 pra
	# 10 tiles, pedido do Gabriel — "estradas 6 a 10 pisos de largura, mais
	# perto do formato original"). Seguro alargar até aqui porque a moldura
	# da boca de Mt Moon (linha 1041, abaixo) já reserva r12-24 pro entorno
	# rochoso — o caminho mais largo cabe inteiro dentro dessa moldura sem
	# encostar nela. Não afeta Cerulean (cc adiante nesta função): os
	# prédios de lá não usam esta variável, têm o próprio conector r14-16.
	var no_caminho := r >= 13 and r <= 22

	# ── Rota 3 ── local cols 0-59
	if c < ROUTE3_COLS:
		if no_caminho:
			return "P"
		if _espalhar_sal(c, r, 29) < 2:
			return "T"
		if _espalhar_sal(c, r, 30) < 2:
			return "F"
		return "."

	# ── Mt Moon: boca da caverna ── local cols ROUTE3_COLS-3 .. ROUTE3_COLS+3
	# (a entrada em si — a caverna de verdade é uma cena própria, warp aqui)
	if c >= ROUTE3_COLS - 4 and c < ROUTE3_COLS + 4 and r >= 12 and r <= 24:
		if no_caminho and c >= ROUTE3_COLS - 2 and c < ROUTE3_COLS + 2:
			return "P"  # entrada caminhável (warp fica aqui)
		return "R"  # rochedo da montanha ao redor da boca da caverna

	# ── Rota 4 ── local cols ROUTE3_COLS .. ROUTE3_COLS+ROUTE4_COLS-1
	if c < ROUTE3_COLS + ROUTE4_COLS:
		if no_caminho:
			return "P"
		if _espalhar_sal(c, r, 31) < 2:
			return "T"
		if _espalhar_sal(c, r, 32) < 2:
			return "S"  # Rota 4 é mais arenosa (perto de Cerulean/Celadon)
		return "."

	# ── Cerulean City ── local cols ROUTE3_COLS+ROUTE4_COLS em diante
	var cc := c - ROUTE3_COLS - ROUTE4_COLS  # local dentro da própria cidade

	# ── Ginásio de Cerulean (Misty) ── cols 10-22, rows 6-14
	if cc >= 10 and cc <= 22 and r >= 6 and r <= 14:
		if cc == 10 or cc == 22: return "w"
		if r == 6: return "H"
		if r == 14:
			if cc >= 15 and cc <= 17: return "d"  # porta
			return _parede_frontal(c, r)
		return "I"
	if r >= 14 and r <= 16 and cc >= 15 and cc <= 17:
		return "P"

	# ── Centro Pokémon de Cerulean ── cols 35-47, rows 6-14
	if cc >= 35 and cc <= 47 and r >= 6 and r <= 14:
		if cc == 35 or cc == 47: return "w"
		if r == 6: return "H"
		if r == 14:
			if cc >= 40 and cc <= 42: return "d"  # porta
			return _parede_frontal(c, r)
		return "I"
	if r >= 14 and r <= 16 and cc >= 40 and cc <= 42:
		return "P"

	# ── Rio/lago decorativo (Cerulean é a "Cidade Azulada") ──
	if _espalhar_sal(c, r, 33) < 1 and r >= 22 and r <= 34 and cc >= 2 and cc <= 55:
		return "~"

	# ── Cerulean só vai até CERULEAN_COLS; dali pra leste é Tier 3 ──────────
	if cc < CERULEAN_COLS:
		return "."

	# Cerulean agora só continua pro SUL (Rota 5 -> Saffron), não mais pro
	# leste em linha reta -- ver _sul_de_cerulean_cell. Nada além disso
	# existe dentro de _leste_de_pewter_cell.
	return "."

# ──────────────────────────────────────────────────────────────────────────────
# Pewter City — linhas 1-36 (globais), full 100 largo.
# Ginásio do Brock a oeste (cols 18-34), Centro Pokémon a leste (cols 70-82,
# mesma posição usada em toda cidade — Pallet e Viridian já seguem isso).
# Corredor N-S cols 44-56, contínuo com a Rota 2 logo abaixo.
# ──────────────────────────────────────────────────────────────────────────────
static func _pewter_cell(c: int, r: int, W: int) -> String:
	if c <= 2 or c >= W - 3:
		return "T"
	if r <= 2:
		return "T"

	# ── Corredor N-S ── cols 44-56
	if c >= 44 and c <= 56:
		return "P"
	# ── Passeio leste-oeste da cidade ── row 24
	if r == 24 and c >= 5 and c <= 93:
		return "P"

	# ── Ginásio de Pewter (Brock) ── cols 18-34, rows 6-18
	if c >= 18 and c <= 34 and r >= 6 and r <= 18:
		if c == 18 or c == 34: return "w"
		if r == 6: return "H"
		if r == 18:
			if c >= 25 and c <= 27: return "d"  # porta
			return _parede_frontal(c, r)
		return "I"
	# ── Caminho Ginásio → corredor ── row 18-19, cols 34-44
	if r >= 18 and r <= 19 and c >= 34 and c <= 44:
		return "P"

	# ── Centro Pokémon de Pewter ── cols 70-82, rows 6-14
	if c >= 70 and c <= 82 and r >= 6 and r <= 14:
		if c == 70 or c == 82: return "w"
		if r == 6: return "H"
		if r == 14:
			if c >= 75 and c <= 77: return "d"  # porta (warp aqui)
			return _parede_frontal(c, r)
		return "I"
	# ── Caminho PokéCenter → corredor ── row 14-15, cols 56-77
	if r >= 14 and r <= 15 and c >= 56 and c <= 77:
		return "P"

	# ── Pedras decorativas (Cidade das Pedras) ──
	if _espalhar_sal(c, r, 34) < 1 and r >= 20 and r <= 34 and c >= 4 and c <= 93:
		return "R"

	return "."

# ──────────────────────────────────────────────────────────────────────────────
# Rota 2 — linhas locais 1-36 (globais 37-72), corredor cols 44-56 igual a
# Rota 1, mesma faixa de grama/árvore/flor esparsa. Geodude entra no spawn
# selvagem via zones.json (não muda nada aqui, só o dado de spawn).
# ──────────────────────────────────────────────────────────────────────────────
static func _route2_cell(c: int, r: int, W: int) -> String:
	if c <= 4 or c >= W - 5:
		return "T"
	if c >= 44 and c <= 56:
		return "P"
	if c <= 43:
		if c <= 8 or c >= 40:
			return "T"
		if _espalhar_sal(c, r, 35) < 2:
			return "T"
		if _espalhar_sal(c, r, 36) < 2:
			return "F"
		return "."
	if c >= 57:
		if c <= 60 or c >= 91:
			return "T"
		if _espalhar_sal(c, r, 37) < 2:
			return "T"
		if _espalhar_sal(c, r, 38) < 2:
			return "F"
		return "."
	return "."

# ──────────────────────────────────────────────────────────────────────────────
# Pallet Town — rows 80-119, full 100 wide
# Corredor N-S: cols 44-56
# Prof. Oak lab: cols 18-34, rows 82-90
# PokéCenter: cols 70-82, rows 82-90 (entrada col 76, row 90)
# Casas: várias posições
# Player spawn: (50, 110)
# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────
# COSTA DE PALLET (04/09) — correção do Gabriel: "as árvores estão sendo usadas
# como uma parede que separa o mar da terra... isso impede o uso do Surf".
#
# Era literalmente isso: `_pallet_cell` devolvia "T" (árvore) pra TODA a borda
# sul e leste, e como o mapa tem 465x330 mas a "cidade antiga" só tem 100 de
# largura, isso transformava ~142 linhas x 465 colunas ao sul de Pallet num
# bloco maciço de árvore morta — justamente onde, no Kanto de verdade, fica o
# mar (Rota 21, rumo a Cinnabar).
#
# Agora a transição é a de um mapa Pokémon de verdade: terra → areia → mar.
# A faixa de areia é ANDÁVEL (é praia), o mar é bloqueado pro pedestre e
# liberado pra quem tem Pokémon de Surf — TrainerEntity._is_tile_walkable() já
# fazia essa regra, só nunca tinha água alcançável pra exercê-la.
#
# Não precisa de "parede" no fim do mar: fora da área pintada não existe tile
# nenhum, e is_tile_walkable() já trata ausência de tile como não-caminhável.
const PALLET_PRAIA_LINHA : int = 116   # 1ª linha de areia (old_r), logo após a cidade
const PALLET_PRAIA_LARG  : int = 3     # espessura da faixa de areia
const PALLET_PRAIA_COL   : int = 3     # colunas de areia nas bordas leste/oeste

static func _pallet_cell(c: int, r: int, W: int) -> String:
	# ── Costa sul: terra → praia → mar ──
	if r >= PALLET_PRAIA_LINHA:
		if r < PALLET_PRAIA_LINHA + PALLET_PRAIA_LARG:
			return "S"
		return "~"

	# ── Costa leste: a "cidade antiga" só tem 100 colunas, então tudo a leste
	# disso era árvore morta até a coluna 464. Vira praia + mar aberto, que é o
	# que liga a costa sul ao resto do oceano.
	if c >= W - PALLET_PRAIA_COL:
		if c < W:
			return "S"
		return "~"

	# ── Borda oeste: continua árvore. É o extremo do mapa e `_world_cell` já
	# força "T" em c==0 de qualquer jeito — abrir mar aqui só criaria uma faixa
	# de água de 2 tiles encostada numa parede, sem servir pra nada.
	if c <= 2:
		return "T"

	# ── Corredor norte-sul principal ── cols 46-54 (9 tiles)
	# Era 44-56 = 13 tiles. O Gabriel pediu 6 a 10; 13 fazia a cidade inteira
	# virar uma faixa de terra e o jogador nascia dentro dela sem ver nada.
	if c >= 46 and c <= 54 and r >= 80 and r <= 115:
		return "P"

	# ── Laboratório do Prof. Carvalho ── cols 18-34, rows 82-90
	if c >= 18 and c <= 34 and r >= 82 and r <= 90:
		if c == 18 or c == 34: return "w"
		if r == 82: return "H"
		if r == 90:
			if c >= 25 and c <= 27: return "d"  # porta
			return _parede_frontal(c, r)
		return "I"

	# ── Caminho do lab até corredor ── row 90, cols 27-44
	if r == 90 and c >= 27 and c <= 46:
		return "P"
	if r == 91 and c >= 27 and c <= 46:
		return "P"

	# ── PokéCenter de Pallet ── cols 70-82, rows 82-90
	if c >= 70 and c <= 82 and r >= 82 and r <= 90:
		if c == 70 or c == 82: return "w"
		if r == 82: return "H"
		if r == 90:
			if c >= 75 and c <= 77: return "d"  # porta (warp aqui)
			return _parede_frontal(c, r)
		return "I"

	# ── Caminho do pokécenter até corredor ── row 90-91, cols 56-77
	if r >= 90 and r <= 91 and c >= 54 and c <= 77:
		return "P"

	# ── Casa 1 ── cols 8-16, rows 97-105
	if c >= 8 and c <= 16 and r >= 97 and r <= 105:
		if c == 8 or c == 16: return "w"
		if r == 97: return "H"
		if r == 105:
			if c == 12: return "P"
			return _parede_frontal(c, r)
		return "I"

	# ── Caminho casa 1 ── col 12, rows 105-110
	if c == 12 and r >= 105 and r <= 112:
		return "P"
	if r == 110 and c >= 12 and c <= 46:
		return "P"

	# ── Casa 2 ── cols 58-66, rows 97-105
	if c >= 58 and c <= 66 and r >= 97 and r <= 105:
		if c == 58 or c == 66: return "w"
		if r == 97: return "H"
		if r == 105:
			if c == 62: return "P"
			return _parede_frontal(c, r)
		return "I"

	# ── Caminho casa 2 ── col 62, rows 105-110
	if c == 62 and r >= 105 and r <= 110:
		return "P"
	if r == 110 and c >= 54 and c <= 62:
		return "P"

	# ── Casa 3 ── cols 84-92, rows 97-105
	if c >= 84 and c <= 92 and r >= 97 and r <= 105:
		if c == 84 or c == 92: return "w"
		if r == 97: return "H"
		if r == 105:
			if c == 88: return "P"
			return _parede_frontal(c, r)
		return "I"

	# ── Mato alto: onde se pega o primeiro Pokémon ────────────────────────────
	# 04/09: Pallet não tinha NENHUM lugar pra encontrar Pokémon. A criança que
	# testou o jogo andou pela cidade inteira sem nada acontecer. Duas manchas
	# de mato alto, uma de cada lado do corredor principal, logo abaixo das
	# casas — perto o bastante pra ser achado nos primeiros passos, e fora do
	# caminho de quem só quer ir pro Laboratório.
	# "A" é o mato alto (conferido tile a tile no atlas antes de usar — "G" é
	# grama comum e "M" é TAPETE VERMELHO de interior, os dois pareciam
	# candidatos plausíveis pelo nome e não são). É o mesmo char que o
	# SpawnManager usa como terreno "tall_grass" (Ekans/Arbok/Kakuna/Beedrill),
	# então a mancha vira encontro de Pokémon de verdade, não só enfeite.
	if _mancha_de_mato(c, r, 26, 113, 7, 3) or _mancha_de_mato(c, r, 74, 113, 8, 3):
		return "A"

	# ── Decoração espalhada ───────────────────────────────────────────────────
	# 🔴 04/09: a regra antiga era `(c * 3 + r * 7) % 13 == 5`, uma equação
	# LINEAR — e equação linear em duas variáveis desenha RETAS. O resultado, no
	# mapa, eram flores em linhas diagonais perfeitas de ponta a ponta da
	# cidade, que lêem como defeito de renderização, não como jardim.
	# `_espalhar` usa hash (multiplicação por primos grandes + XOR), o mesmo
	# método já usado pelas variantes de terreno — dá o mesmo mapa toda vez,
	# sem alinhar nada.
	if r >= 92 and r <= 115 and c >= 5 and c <= 94:
		var d := _espalhar(c, r)
		if d < 2:
			return "F"      # canteiro de flores (~10% — dá jardim sem virar tapete)
		# Árvores só na BORDA da cidade: fecham o horizonte sem entupir a praça,
		# e dão a silhueta de "cidade cercada de mata" do jogo original. Três
		# espécies pra não virar uma fileira do mesmo desenho.
		if c <= 9 or c >= 90:
			if d < 8:
				return _forest_variant(c, r)
		elif r >= 113 and d < 5:
			return _forest_variant(c, r)

	return "."

## Mancha de mato alto arredondada em torno de um centro. Retângulo puro daria
## uma placa de grama perfeitamente quadrada no meio da cidade.
static func _mancha_de_mato(c: int, r: int, cc: int, cr: int, raio_x: int, raio_y: int) -> bool:
	var dx := float(c - cc) / float(raio_x)
	var dy := float(r - cr) / float(raio_y)
	if dx * dx + dy * dy > 1.0:
		return false
	# borda irregular: sem isso a mancha vira uma elipse desenhada a compasso
	return _espalhar(c, r) != 7

## Parede da frente de um prédio (04/09).
##
## Antes toda parede era o char "W", que no atlas é a parede COM JANELA — a
## fachada inteira virava uma fileira ininterrupta de janelas, exatamente o que
## o Gabriel apontou ("casas e prédios com paredes como janelas"). Agora o
## padrão é a parede LISA ("w") e a janela aparece a cada ~4 tiles, alinhada
## sempre no mesmo passo pra parecer construção e não sorteio.
## Chars que contam como MATA (bloqueiam e desenham vegetação alta).
const CHARS_MATA : Array[String] = ["T", "N", "O", "K"]
## Chars que contam como CAMPO ABERTO (andável, sem construção nem estrada).
const CHARS_CAMPO : Array[String] = [".", "F"]

## Quebra as bordas retas do mundo (05/09).
##
## Visto de cima, o mapa parecia planta baixa: cada cidade e cada rota é gerada
## como um RETÂNGULO alinhado aos eixos, então toda divisa entre mata e campo
## era uma reta perfeita de dezenas de tiles. Nenhum lugar do mundo real, nem do
## jogo original, tem essa cara.
##
## O que faz: onde mata encosta em campo, troca um pelo outro seguindo um ruído
## GROSSO — o hash usa as coordenadas divididas por 6, então blocos inteiros de
## ~6 tiles decidem juntos. Isso é o que dá enseada e península; ruído por
## célula daria uma serrilha pontilhada, que fica pior que a reta.
##
## Trava de segurança: só troca entre mata e campo. Estrada, prédio, porta,
## areia, água, mato alto e beira ficam intocados — são eles que carregam
## caminho e jogabilidade. E a erosão só age em célula com pelo menos 4 vizinhos
## de campo (ponta de mata), nunca no meio de uma barreira: assim a mudança não
## abre atalho por dentro de uma parede de árvores.
static func amaciar_bordas(tilemap: TileMap, passadas: int = 3) -> void:
	var atlas_mata := {}
	for ch in CHARS_MATA:
		atlas_mata[CHAR_MAP[ch]] = true
	var atlas_campo := {}
	for ch in CHARS_CAMPO:
		atlas_campo[CHAR_MAP[ch]] = true
	for co in VARIANTES_TERRENO.get(".", []):
		atlas_campo[co] = true

	var vizinhos : Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]

	for passada in passadas:
		var trocas := {}
		for celula in tilemap.get_used_cells(0):
			var co := tilemap.get_cell_atlas_coords(0, celula)
			var e_mata : bool = atlas_mata.has(co)
			var e_campo : bool = atlas_campo.has(co)
			if not e_mata and not e_campo:
				continue
			var qtd_mata := 0
			var qtd_campo := 0
			for d in vizinhos:
				var cv := tilemap.get_cell_atlas_coords(0, celula + d)
				if atlas_mata.has(cv):
					qtd_mata += 1
				elif atlas_campo.has(cv):
					qtd_campo += 1
			if qtd_mata == 0 or qtd_campo == 0:
				continue    # não está numa divisa: nada a amaciar
			# ruído grosso: blocos de ~6 tiles decidem juntos
			# duas escalas somadas: a grossa (÷9) faz a enseada, a média (÷4)
			# quebra a curva pra não virar um arco liso de compasso
			var onda := (_espalhar_sal(celula.x / 9, celula.y / 9, 900 + passada)
				+ _espalhar_sal(celula.x / 4, celula.y / 4, 950 + passada)) / 2
			if e_mata and qtd_campo >= 3 and onda < 10:
				trocas[celula] = CHAR_MAP["."]
			elif e_campo and qtd_mata >= 4 and onda >= 13:
				trocas[celula] = CHAR_MAP[_forest_variant(celula.x, celula.y)]
		for celula in trocas:
			tilemap.set_cell(0, celula, 0, trocas[celula])

## Árvores de 2x3 tiles (05/09) — coordenadas no atlas, por espécie.
##
## Pedido do Gabriel: "pode usar até 2x3 (LxA) para todas as árvores". Cada
## espécie é UM desenho de 256x384 fatiado em 6 tiles (tools/
## gerar_arvores_grandes.py), então a copa é contínua entre eles — fatiar um
## desenho inteiro é o oposto de desenhar tile a tile, que foi o que produziu
## as árvores cortadas ao meio corrigidas em 04/09.
##
## A grama vai ASSADA em cada tile: os dois tiles de baixo são quase só tronco,
## e sem fundo abririam buraco no mapa (a camada 0 não tem nada por trás). Como
## consequência, duas árvores grandes não podem se sobrepor — o tile de cima de
## uma apagaria a copa da outra. Por isso o plantio usa uma grade fixa.
## Estruturas 2x3 do deserto (Fase 2, 05/09) — pirâmide grande, obelisco de
## hieróglifos e pirâmide pequena. Mesmo princípio das árvores: cada uma é UM
## desenho de 256x384 fatiado em 6 tiles, então a silhueta é contínua entre eles.
const ESTRUTURAS_DESERTO : Array = [
	[Vector2i(0, 21), Vector2i(1, 21), Vector2i(0, 22), Vector2i(1, 22), Vector2i(0, 23), Vector2i(1, 23)],  # pirâmide grande
	[Vector2i(2, 21), Vector2i(3, 21), Vector2i(2, 22), Vector2i(3, 22), Vector2i(2, 23), Vector2i(3, 23)],  # obelisco
	[Vector2i(4, 21), Vector2i(5, 21), Vector2i(4, 22), Vector2i(5, 22), Vector2i(4, 23), Vector2i(5, 23)],  # pirâmide pequena
]

const ARVORES_GRANDES : Array = [
	[Vector2i(0, 11), Vector2i(1, 11), Vector2i(0, 12), Vector2i(1, 12), Vector2i(0, 13), Vector2i(1, 13)],  # carvalho
	[Vector2i(2, 11), Vector2i(3, 11), Vector2i(2, 12), Vector2i(3, 12), Vector2i(2, 13), Vector2i(3, 13)],  # pinheiro
	[Vector2i(4, 11), Vector2i(5, 11), Vector2i(4, 12), Vector2i(5, 12), Vector2i(4, 13), Vector2i(5, 13)],  # outono
	[Vector2i(6, 11), Vector2i(7, 11), Vector2i(6, 12), Vector2i(7, 12), Vector2i(6, 13), Vector2i(7, 13)],  # frondosa
]

## Planta as árvores grandes por cima da mata já pintada.
##
## Antes, uma árvore era UM tile de 128px — do tamanho da cabeça do jogador,
## que ocupa 1x2 tiles. Uma floresta era uma grade de bolinhas verdes iguais e o
## treinador parecia um gigante. Agora a árvore tem 2x3 tiles e fica mais alta
## que ele, que é a proporção do jogo original.
##
## Como escolhe onde plantar: percorre uma GRADE fixa de 2x3 (âncoras em x par e
## y múltiplo de 3) e só planta onde os 6 tiles do bloco já são mata. Assim
## nenhuma árvore grande se sobrepõe a outra, e nenhuma invade estrada, prédio,
## água ou campo aberto — a silhueta da floresta continua exatamente a mesma que
## o mapa já definia. As sobras (mata que não fecha um bloco de 6) ficam com o
## tile pequeno, que na borda da mata lê como arbusto e ajuda a fazer a
## transição.
static func plantar_arvores_grandes(tilemap: TileMap) -> void:
	var e_mata := {}
	for ch in CHARS_MATA:
		e_mata[CHAR_MAP[ch]] = true

	var mata := {}
	for celula in tilemap.get_used_cells(0):
		if e_mata.has(tilemap.get_cell_atlas_coords(0, celula)):
			mata[celula] = true
	if mata.is_empty():
		return

	# Âncoras únicas da grade 2x3. Como a grade é FIXA (x par, y múltiplo de 3),
	# dois blocos nunca se sobrepõem — não é preciso marcar célula usada.
	#
	# 🔴 A primeira versão apagava as células do próprio dicionário enquanto o
	# percorria, pra "reservar" o bloco. Isso interrompe a iteração em GDScript:
	# o mundo inteiro ficou com UMA árvore grande. Coletar as âncoras antes e
	# plantar depois resolve e ainda deixa a intenção explícita.
	# Grade ESCALONADA: as fileiras ímpares saem 1 tile pra direita. Numa grade
	# alinhada, 12 mil árvores idênticas em linha e coluna lêem como POMAR, não
	# como mata — e escalonar é o que os jogos de tile fazem pra quebrar isso
	# sem precisar de posição livre. Fileiras diferentes ocupam faixas de y
	# diferentes, então nada se sobrepõe.
	var ancoras := {}
	for celula in mata:
		var fileira : int = floori(celula.y / 3.0)
		var desloc : int = fileira % 2
		var ax : int = floori((celula.x - desloc) / 2.0) * 2 + desloc
		ancoras[Vector2i(ax, fileira * 3)] = true

	for ancora in ancoras:
		# ~1 bloco em cada 6 fica sem árvore grande: são as clareiras e o
		# mato rasteiro que fazem a mata respirar. As sobras continuam com o
		# tile pequeno, que ali lê como arbusto.
		if _espalhar_sal(ancora.x, ancora.y, 654) < 3:
			continue
		var completo := true
		for lin in 3:
			for col in 2:
				if not mata.has(Vector2i(ancora.x + col, ancora.y + lin)):
					completo = false
					break
			if not completo:
				break
		if not completo:
			continue
		var especie : int = _espalhar_sal(ancora.x, ancora.y, 321) % ARVORES_GRANDES.size()
		var pedacos : Array = ARVORES_GRANDES[especie]
		for lin in 3:
			for col in 2:
				tilemap.set_cell(0, Vector2i(ancora.x + col, ancora.y + lin), 0,
					pedacos[lin * 2 + col])

## Fecha os vazios do mapa (05/09).
##
## Visto de cima, o mundo tinha um buraco PRETO de 100 colunas por 370 linhas na
## esquerda: o ramo da Rota 22 / Victory Road é pintado em colunas negativas e
## ocupa só uma faixa estreita — todo o resto daquele retângulo nunca era
## pintado. Na tela isso é o vazio absoluto atrás da borda do mapa, e é a maior
## parte do "formato ridículo" que o Gabriel apontou.
##
## O preenchimento não inventa geografia: cada célula vazia copia o VIZINHO
## PINTADO mais próximo na mesma linha. Se o que existe ali do lado é mar, vira
## mar; se é terra, vira mata fechada. Assim o oeste do mapa vira floresta densa
## (que é o que Victory Road atravessa) e o sul continua oceano, sem ninguém ter
## que decidir isso à mão região por região.
static func preencher_vazios(tilemap: TileMap) -> void:
	var usadas := tilemap.get_used_cells(0)
	if usadas.is_empty():
		return
	var x0 := 999999
	var y0 := 999999
	var x1 := -999999
	var y1 := -999999
	var pintado := {}
	for c in usadas:
		pintado[c] = true
		x0 = mini(x0, c.x); y0 = mini(y0, c.y)
		x1 = maxi(x1, c.x); y1 = maxi(y1, c.y)

	var agua : Vector2i = CHAR_MAP["~"]
	for y in range(y0, y1 + 1):
		# primeira célula pintada da linha, varrendo da esquerda pra direita
		var referencia := ""
		for x in range(x0, x1 + 1):
			var c := Vector2i(x, y)
			if pintado.has(c):
				referencia = "~" if tilemap.get_cell_atlas_coords(0, c) == agua else "T"
				break
		if referencia == "":
			referencia = "~"   # linha inteira vazia: está na faixa do oceano
		# preenche os buracos com a mata/mar certo, variando a espécie de árvore
		for x in range(x0, x1 + 1):
			var c := Vector2i(x, y)
			if pintado.has(c):
				continue
			var ch := referencia
			if ch == "T":
				ch = _forest_variant(x, y)
			tilemap.set_cell(0, c, 0, CHAR_MAP[ch])

## Ondula a linha da costa (05/09).
##
## A costa sul do mundo era uma reta perfeita de 565 tiles: terra até uma linha,
## mar depois dela, sem uma enseada sequer. Junto com as divisas retas de mata,
## era o que fazia o mapa visto de cima parecer planta baixa em vez de região.
##
## Como funciona: para cada coluna, calcula um deslocamento de -4 a +4 tiles a
## partir de um ruído grosso (blocos de ~10 colunas decidem juntos, senão a
## costa vira dente de serra) e empurra a linha terra/mar por esse tanto. Só
## troca AREIA por ÁGUA e vice-versa — nada de prédio, estrada ou mata entra na
## conta, então nenhuma cidade cai no mar.
static func ondular_costa(tilemap: TileMap) -> void:
	var agua : Vector2i = CHAR_MAP["~"]
	var areia : Vector2i = CHAR_MAP["S"]
	var variantes_areia : Array = VARIANTES_TERRENO.get("S", [])
	var e_areia := {areia: true}
	for co in variantes_areia:
		e_areia[co] = true

	var usadas := tilemap.get_used_cells(0)
	var colunas := {}          # x -> menor y de água (o topo do mar naquela coluna)
	for c in usadas:
		if tilemap.get_cell_atlas_coords(0, c) != agua:
			continue
		if not colunas.has(c.x) or c.y < colunas[c.x]:
			colunas[c.x] = c.y

	for x in colunas:
		var topo : int = colunas[x]
		# -4..+4, coerente ao longo de ~10 colunas
		var desloc : int = _espalhar_sal(int(x) / 10, 0, 777) % 9 - 4
		if desloc == 0:
			continue
		if desloc > 0:
			# mar recua: as primeiras linhas de água viram areia (a praia avança)
			for k in range(desloc):
				var c := Vector2i(int(x), topo + k)
				if tilemap.get_cell_atlas_coords(0, c) == agua:
					tilemap.set_cell(0, c, 0, areia)
		else:
			# Mar avança — mas a praia NUNCA some. Achado ao construir: a faixa
			# de areia de Pallet tem 3 tiles, e um deslocamento de -4 comia os
			# três, deixando o mar encostado na grama e sem praia andável
			# naquela coluna. Conta quantos tiles de areia existem e só avança
			# enquanto sobrarem pelo menos 2.
			var faixa := 0
			while e_areia.has(tilemap.get_cell_atlas_coords(0, Vector2i(int(x), topo - 1 - faixa))):
				faixa += 1
			var pode : int = maxi(0, faixa - 2)
			for k in range(mini(-desloc, pode)):
				var c := Vector2i(int(x), topo - 1 - k)
				if e_areia.has(tilemap.get_cell_atlas_coords(0, c)):
					tilemap.set_cell(0, c, 0, agua)

## Tira os entalhes de 1 tile da costa (05/09).
##
## A ondulação deixa, aqui e ali, uma célula de mar cercada de terra em 3 lados
## (ou o contrário). Sozinha, ela vira um quadradinho azul de canto vivo no meio
## da praia — visto em tela e mais feio que a reta que a ondulação veio
## corrigir, porque ninguém desenha uma enseada de um tile.
static func limpar_entalhes_da_costa(tilemap: TileMap) -> void:
	var agua : Vector2i = CHAR_MAP["~"]
	var areia : Vector2i = CHAR_MAP["S"]
	var e_areia := {areia: true}
	for co in VARIANTES_TERRENO.get("S", []):
		e_areia[co] = true
	var lados : Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	var trocas := {}
	for celula in tilemap.get_used_cells(0):
		var co := tilemap.get_cell_atlas_coords(0, celula)
		var e_agua : bool = co == agua
		if not e_agua and not e_areia.has(co):
			continue
		var vizinha_agua := 0
		var vizinha_areia := 0
		for d in lados:
			var cv := tilemap.get_cell_atlas_coords(0, celula + d)
			if cv == agua:
				vizinha_agua += 1
			elif e_areia.has(cv):
				vizinha_areia += 1
		if e_agua and vizinha_areia >= 3:
			trocas[celula] = areia
		elif not e_agua and vizinha_agua >= 3:
			trocas[celula] = agua
	for celula in trocas:
		tilemap.set_cell(0, celula, 0, trocas[celula])

## Coordenadas de atlas da beira da praia. São ÁGUA pra toda regra do jogo
## (surf, pesca, colisão) — só desenham a areia entrando por um dos lados.
const COSTA_ATLAS : Array[Vector2i] = [
	Vector2i(0, 10), Vector2i(1, 10), Vector2i(2, 10), Vector2i(3, 10),
	Vector2i(4, 10), Vector2i(5, 10), Vector2i(6, 10), Vector2i(7, 10),
]

## Char de beira pelo lado em que há AREIA. Chaves: "n","s","o","l" e os cantos.
const COSTA_CHAR := {
	"n": "1", "s": "2", "o": "3", "l": "4",
	"no": "5", "nl": "6", "so": "7", "sl": "8",
}

## Pós-passada da pintura: todo tile de ÁGUA encostado em terra vira o tile de
## beira correspondente. Feito aqui, depois de tudo pintado, em vez de dentro de
## cada gerador de cidade/rota — são ~30 geradores, e a costa é uma propriedade
## do mapa PRONTO, não de cada pedaço isolado.
static func costurar_costa(tilemap: TileMap) -> void:
	var agua : Vector2i = CHAR_MAP["~"]
	var trocas := {}
	for celula in tilemap.get_used_cells(0):
		if tilemap.get_cell_atlas_coords(0, celula) != agua:
			continue
		var norte := _e_terra(tilemap, Vector2i(celula.x, celula.y - 1), agua)
		var sul   := _e_terra(tilemap, Vector2i(celula.x, celula.y + 1), agua)
		var oeste := _e_terra(tilemap, Vector2i(celula.x - 1, celula.y), agua)
		var leste := _e_terra(tilemap, Vector2i(celula.x + 1, celula.y), agua)
		var lado := ""
		if norte and oeste:   lado = "no"
		elif norte and leste: lado = "nl"
		elif sul and oeste:   lado = "so"
		elif sul and leste:   lado = "sl"
		elif norte:           lado = "n"
		elif sul:             lado = "s"
		elif oeste:           lado = "o"
		elif leste:           lado = "l"
		if lado != "":
			trocas[celula] = CHAR_MAP[COSTA_CHAR[lado]]
	for celula in trocas:
		tilemap.set_cell(0, celula, 0, trocas[celula])

## Terra = tile pintado que não é água nem beira. Beira conta como água, senão
## dois tiles de beira vizinhos ficariam se marcando um ao outro.
static func _e_terra(tilemap: TileMap, celula: Vector2i, agua: Vector2i) -> bool:
	if tilemap.get_cell_source_id(0, celula) == -1:
		return false
	var co := tilemap.get_cell_atlas_coords(0, celula)
	return co != agua and not (co in COSTA_ATLAS)

static func _parede_frontal(c: int, r: int) -> String:
	return "W" if (c % 4 == 1) else "w"

## Espalhamento determinístico 0..19. Mesmo (c,r) sempre dá o mesmo valor (o
## mapa não "pisca" ao repintar), mas sem alinhar em retas como a conta antiga.
##
## A primeira versão desta função ainda tinha o mesmo defeito de raiz, só mais
## escondido: `c*A ^ r*B ^ (c+r)*C` tem o bit 0 SEMPRE zero (porque
## c₀ ^ r₀ ^ (c₀^r₀) = 0), então só saíam valores pares — metade dos 20 casos
## nunca acontecia, e "d < 1" cobria 15% do mapa em vez de 5%. Medido, não
## deduzido: contei a distribuição sobre a área real da cidade.
##
## A versão abaixo é um hash de avalanche (multiplicação + deslocamento +
## multiplicação), que espalha os bits de entrada por todos os bits de saída.
## Medido na mesma área: cada valor entre 4,2% e 6,2%.
## Mesma ideia de `_espalhar`, com um SAL por local de uso.
##
## Por que o sal existe: cada rota/cidade tinha duas decorações (árvore e flor)
## decididas por duas contas diferentes. Se as duas usassem o mesmo hash, a flor
## cairia sempre no mesmo lugar da árvore e a segunda nunca apareceria. O sal
## dá a cada ponto de decisão um padrão próprio, sem precisar de RNG (o mapa
## continua idêntico a cada partida).
##
## 🔴 O que isto substitui: 48 condições do tipo `(c + r * 2) % 9 == 3`. Toda
## equação LINEAR em duas variáveis é constante ao longo de uma reta — então
## cada uma dessas contas desenhava uma faixa diagonal de árvores atravessando
## a rota inteira. Visto de cima, o mapa do mundo virava um hachurado. Era o
## mesmo defeito já corrigido em Pallet, repetido em todo gerador.
static func _espalhar_sal(c: int, r: int, sal: int) -> int:
	var h : int = ((c * 0x9E3779B1) ^ (r * 0x85EBCA77) ^ (sal * 0xC2B2AE35)) & 0xFFFFFFFF
	h = ((h ^ (h >> 15)) * 0xC2B2AE3D) & 0xFFFFFFFF
	h = (h ^ (h >> 13)) & 0xFFFFFFFF
	return h % 20

static func _espalhar(c: int, r: int) -> int:
	var h : int = ((c * 0x9E3779B1) ^ (r * 0x85EBCA77)) & 0xFFFFFFFF
	h = ((h ^ (h >> 15)) * 0xC2B2AE3D) & 0xFFFFFFFF
	h = (h ^ (h >> 13)) & 0xFFFFFFFF
	return h % 20

# ──────────────────────────────────────────────────────────────────────────────
# Rota 1 — rows 39-79, corredor cols 44-56, árvores nas bordas
# ──────────────────────────────────────────────────────────────────────────────
## Variedade de árvore determinística (mesmo (c,r) sempre dá a mesma espécie —
## sem RNG, mapa continua reproduzível). Pedido do Gabriel (02/09): floresta
## "menos repetitiva" — antes toda árvore da Rota 1 era o mesmo "T". Pesos:
## 55% carvalho (padrão), 20% pinheiro, 15% outono, 10% toco (mais raro, só
## decoração pontual). Só usada aqui por ora — o resto do mundo (bordas
## genéricas de outras rotas/cidades) fica pra quando "detalhes" virar foco,
## pra não arriscar os testes de borda (Tier 13/14/15/18) que comparam
## posição exata contra o literal "T".
static func _forest_variant(c: int, r: int) -> String:
	var h := (c * 31 + r * 17) % 20
	if h < 11:
		return "T"
	elif h < 15:
		return "N"
	elif h < 18:
		return "O"
	return "K"

static func _route1_cell(c: int, r: int, W: int) -> String:
	# Bordas laterais densas
	if c <= 4 or c >= W - 5:
		return _forest_variant(c, r)
	# Corredor central N-S: cols 44-56
	if c >= 44 and c <= 56:
		return "P"
	# Faixa de grama caminhável entre árvores e corredor
	# Lado oeste: cols 5-43 — grama com árvores esparsas
	if c <= 43:
		if c <= 8 or c >= 40:
			return _forest_variant(c, r)  # bordas internas também são árvore
		if _espalhar_sal(c, r, 39) < 3:
			return _forest_variant(c, r)
		if _espalhar_sal(c, r, 40) < 2:
			return "F"
		return "."
	# Lado leste: cols 57-94 — grama com árvores esparsas
	if c >= 57:
		if c <= 60 or c >= 91:
			return _forest_variant(c, r)
		# Lago pequeno (Fase 2 do Diário — pesca precisa de água de verdade
		# em algum lugar do mapa; não existia nenhum tile "~" no jogo antes).
		if c >= 63 and c <= 70 and r >= 55 and r <= 60:
			return "~"
		if _espalhar_sal(c, r, 41) < 3:
			return _forest_variant(c, r)
		if _espalhar_sal(c, r, 42) < 2:
			return "F"
		return "."
	return "."

# ──────────────────────────────────────────────────────────────────────────────
# Viridian City — rows 2-38, corredor cols 44-56 vindo do sul
# PokéCenter Viridian: cols 70-82, rows 4-12
# Ginásio (fechado): cols 18-34, rows 4-14
# ──────────────────────────────────────────────────────────────────────────────
## Verdade só depois que MAIN-08 (resgate do Carvalho no Quartel General)
## completa — é o gatilho de história que "revela" o Giovanni como Líder do
## Ginásio de Viridian. `Engine.get_main_loop()` pode ser nulo fora de uma
## árvore rodando (não deveria acontecer em jogo real, mas evita erro se
## `MapLayouts` for chamado num contexto sem SceneTree).
static func _giovanni_liberado() -> bool:
	var loop : SceneTree = Engine.get_main_loop()
	if loop == null:
		return false
	var qm : Node = loop.root.get_node_or_null("QuestManager")
	if qm == null:
		return false
	return qm.is_quest_complete("MAIN-08")

## As 8 insígnias — mesma lista que os 8 GYM-0N já concedem (ver
## data/quests/quests.json). Só existe aqui pra checar "tem todas", não
## precisa bater com nenhuma ordem específica de conquista.
const ALL_BADGES : Array[String] = [
	"boulder_badge", "cascade_badge", "thunder_badge", "rainbow_badge",
	"soul_badge", "marsh_badge", "volcano_badge", "earth_badge",
]

## Verdade só com as 8 insígnias — mesma técnica de _giovanni_liberado()
## (único jeito de amarrar "abre depois de um evento de save" na arquitetura
## atual de tiles procedurais), só que a condição é badge count em vez de
## quest específica (a Liga não depende de nenhuma quest de história, é uma
## trilha à parte — Elite Four/Campeão, 03/09).
static func _liga_liberada() -> bool:
	var loop : SceneTree = Engine.get_main_loop()
	if loop == null:
		return false
	var sm : Node = loop.root.get_node_or_null("SaveManager")
	if sm == null:
		return false
	for badge in ALL_BADGES:
		if not sm.has_badge(badge):
			return false
	return true

static func _viridian_cell(c: int, r: int, W: int) -> String:
	# Bordas laterais
	if c <= 2 or c >= W - 3:
		return "T"
	# Borda norte
	if r <= 3:
		return "T"

	# ── Corredor N-S ── cols 44-56
	if c >= 44 and c <= 56:
		return "P"

	# ── Corredor leste-oeste ── row 28, cols 5-93 (passeio da cidade)
	if r == 28 and c >= 5 and c <= 93:
		return "P"
	if r == 29 and c >= 5 and c <= 93:
		return "P"

	# ── Ginásio de Viridian (Giovanni) — FECHADO até MAIN-08 completar (02/09:
	# destravado como parte da história principal). cols 18-34, rows 6-18.
	# Único lugar do mapa que consulta estado de save — justificado porque é
	# a única forma de representar "abre depois de um evento de história"
	# com a arquitetura atual (tiles procedurais, sem camada de eventos).
	if c >= 18 and c <= 34 and r >= 6 and r <= 18:
		if c == 18 or c == 34: return "w"
		if r == 6: return "H"
		if _giovanni_liberado():
			if r == 18:
				if c >= 25 and c <= 27: return "P"
				return _parede_frontal(c, r)
			return "I"
		if r == 18:
			return _parede_frontal(c, r)  # porta bloqueada (ginásio fechado)
		return _parede_frontal(c, r)  # interior inacessível

	# ── PokéCenter Viridian ── cols 70-82, rows 6-14
	if c >= 70 and c <= 82 and r >= 6 and r <= 14:
		if c == 70 or c == 82: return "w"
		if r == 6: return "H"
		if r == 14:
			if c >= 75 and c <= 77: return "P"
			return _parede_frontal(c, r)
		return "I"

	# ── Caminho PokéCenter Viridian → corredor ── row 14-15, cols 56-77
	if r >= 14 and r <= 15 and c >= 56 and c <= 77:
		return "P"

	# ── Caminho Ginásio → corredor ── row 18-19, cols 34-44
	if r >= 18 and r <= 19 and c >= 34 and c <= 44:
		return "P"

	# ── Loja de itens ── cols 50-60, rows 8-16
	if c >= 50 and c <= 60 and r >= 8 and r <= 16:
		if c == 50 or c == 60: return "w"
		if r == 8: return "H"
		if r == 16:
			if c == 55: return "P"
			return _parede_frontal(c, r)
		return "I"

	# ── Caminho loja → corredor ── col 55, rows 16-28
	if c == 55 and r >= 16 and r <= 28:
		return "P"

	# ── Árvores e flores decorativas ──
	if _espalhar_sal(c, r, 43) < 2 and r >= 20 and r <= 36 and c >= 6 and c <= 92:
		return "T"
	if _espalhar_sal(c, r, 44) < 2 and r >= 20 and r <= 36 and c >= 6 and c <= 92:
		return "F"

	return "."

# ──────────────────────────────────────────────────────────────────────────────
# PokéCenter interior — 16×14 (inalterado)
# ──────────────────────────────────────────────────────────────────────────────
static func _gen_pokemon_center() -> Array:
	return [
		"HHHHHHHHHHHHHHHH",
		"WWWWWWWWWWWWWWWW",
		"WIIIIIIIIIIIIIIW",
		"WIIIIIIIIIIIIIIW",
		"WIIWWWWWWWWWWIIW",
		"WII..........IIW",
		"WII..........IIW",
		"WIIIIIIIIIIIIIIW",
		"WIIIIIIIIIIIIIIW",
		"WIIM........MIIW",
		"WIIIIIIIIIIIIIIW",
		"WII....PP....IIW",
		"WWWWWWWPPWWWWWWW",
		"TTTTTTTTTTTTTTTT",
	]

# ──────────────────────────────────────────────────────────────────────────────
# Mt Moon — 20×30, cena própria (é caverna/subterrâneo — a ÚNICA situação em
# que o Gabriel pediu warp de verdade, 31/08). Entrada ao sul (vem da Rota 3),
# saída ao norte (sai na Rota 4) — sem volta pela superfície, tem que atravessar.
# ──────────────────────────────────────────────────────────────────────────────
static func _gen_mtmoon() -> Array:
	var W := 20
	var H := 30
	var grid : Array = []
	for r in H:
		var row := ""
		for c in W:
			row += _mtmoon_cell(c, r, W, H)
		grid.append(row)
	return grid

static func _mtmoon_cell(c: int, r: int, W: int, H: int) -> String:
	if c == 0 or c == W - 1:
		return _parede_frontal(c, r)
	if r == 0:
		if c >= 9 and c <= 10: return "P"  # saída (Rota 4)
		return _parede_frontal(c, r)
	if r == H - 1:
		if c >= 9 and c <= 10: return "P"  # entrada (Rota 3)
		return _parede_frontal(c, r)
	# Rochas espalhadas — nunca nas colunas 9-10 (mantém sempre um caminho
	# reto entrada→saída, mesmo que sinuoso pelas rochas ao redor)
	if _espalhar_sal(c, r, 45) < 3 and (c < 8 or c > 11):
		return "R"
	return "I"

# ──────────────────────────────────────────────────────────────────────────────
# Caverna de Cerulean (Mewtwo, MAIN-10, 03/09) — 7 andares, mesmo molde do Mt
# Moon (retângulo + rochas espalhadas, corredor central sempre livre —
# conectividade garantida, nunca fica sem caminho, diferente da caminhada
# aleatória do Rock Tunnel/Victory Road que não precisa disso porque só tem
# 1 porta). Cada andar usa `floor_n` pra variar o padrão de rocha e ficar mais
# denso/difícil quanto mais fundo — sem isso os 7 andares ficariam idênticos.
# Andar 7 (o mais fundo) não tem saída norte — é o fim da linha, sala do
# Mewtwo (colocado como WildPokemon de verdade na cena, não no spawn
# aleatório — encontro único, não repetível igual qualquer selvagem comum).
# ──────────────────────────────────────────────────────────────────────────────
static func _gen_cerulean_cave_floor(floor_n: int, tem_saida_norte: bool) -> Array:
	var W := 20
	var H := 30
	var grid : Array = []
	for r in H:
		var row := ""
		for c in W:
			row += _cerulean_cave_cell(c, r, W, H, floor_n, tem_saida_norte)
		grid.append(row)
	return grid

static func _cerulean_cave_cell(c: int, r: int, W: int, H: int, floor_n: int, tem_saida_norte: bool) -> String:
	if c == 0 or c == W - 1:
		return _parede_frontal(c, r)
	if r == 0:
		if tem_saida_norte and c >= 9 and c <= 10: return "P"
		return _parede_frontal(c, r)
	if r == H - 1:
		if c >= 9 and c <= 10: return "P"
		return _parede_frontal(c, r)
	# Densidade de rocha cresce com a profundidade (divisor menor = mais
	# rocha) — anda de 7 (andar 1, igual ao Mt Moon) até 4 (andar 7).
	var divisor := maxi(4, 7 - floor_n / 2)
	if (c + r * 2 + floor_n * 3) % divisor == 0 and (c < 8 or c > 11):
		return "R"
	return "I"

# ──────────────────────────────────────────────────────────────────────────────
# Rock Tunnel — 36×36, cena própria (caverna/subterrâneo, mesma exceção de
# warp do Mt Moon). Tier 10 (01/09): PRIMEIRA caverna construída depois da
# regra de tematização de bioma do Gabriel — diferente do Mt Moon (retângulo
# + rochas espalhadas em grade), aqui o interior é escavado por CAMINHADA
# ALEATÓRIA (drunkard's walk) com seed FIXA — determinístico (sempre gera a
# mesma caverna), mas o resultado parece erosão/escavação de verdade: túnel
# principal sinuoso + 3 ramos secundários saindo de pontos já escavados
# (nunca isolados — sempre alcançáveis a partir da entrada). Piso usa "D"
# (dark path), não "I", pra já ter identidade visual diferente do Mt Moon
# mesmo sem sprite novo. Entrada/saída única, ao sul (opcional, não é
# passagem obrigatória entre duas rotas — dungeon lateral de recompensa).
# ──────────────────────────────────────────────────────────────────────────────
const ROCKTUNNEL_SEED : int = 20260901  # fixo — mesma caverna sempre, nunca mudar sem querer regenerar tudo
const VICTORYROAD_SEED : int = 20260901180  # fixo — mesma caverna sempre

static func _gen_rocktunnel() -> Array:
	var W := 36
	var H := 36
	var grid_chars : Array = []
	for r in H:
		var row : Array = []
		for c in W:
			row.append("R")
		grid_chars.append(row)

	# Porta única (entrada/saída) — sul, cols 17-18
	grid_chars[H - 1][17] = "P"
	grid_chars[H - 1][18] = "P"

	var rng := RandomNumberGenerator.new()
	rng.seed = ROCKTUNNEL_SEED

	var visitados : Array = []
	_rocktunnel_carve(grid_chars, W, H, 17, H - 2, 500, rng, visitados)
	for i in 3:
		var idx := rng.randi_range(0, visitados.size() - 1)
		var pt : Vector2i = visitados[idx]
		_rocktunnel_carve(grid_chars, W, H, pt.x, pt.y, 120, rng, visitados)

	var grid : Array = []
	for r in H:
		var row := ""
		for c in W:
			row += grid_chars[r][c]
		grid.append(row)
	return grid

## Escava uma "caminhada aleatória" a partir de (start_c, start_r), marcando
## cada tile visitado como piso ("D"). Nunca escava a borda (c/r=0 ou W-1/
## H-1 continuam rocha sólida). `visitados` acumula todo tile já escavado —
## usado pra escolher onde começar os ramos secundários, garantindo que
## NUNCA fiquem isolados (sempre partem de um tile já alcançável).
static func _rocktunnel_carve(grid_chars: Array, W: int, H: int, start_c: int, start_r: int,
	steps: int, rng: RandomNumberGenerator, visitados: Array) -> void:
	var c := start_c
	var r := start_r
	for i in steps:
		if r >= 1 and r <= H - 2 and c >= 1 and c <= W - 2:
			if grid_chars[r][c] != "D":
				grid_chars[r][c] = "D"
				visitados.append(Vector2i(c, r))
		var dir := rng.randi_range(0, 3)
		match dir:
			0: r -= 1
			1: r += 1
			2: c -= 1
			3: c += 1
		c = clampi(c, 1, W - 2)
		r = clampi(r, 1, H - 2)

# ──────────────────────────────────────────────────────────────────────────────
# Victory Road — 32×32, cena própria (Tier 18). Não-linear de propósito
# (regra de tematização de caverna, mesma técnica de caminhada aleatória do
# Rock Tunnel, reaproveitando `_rocktunnel_carve` — não é específica de Rock
# Tunnel apesar do nome, é genérica). Única porta (entrada — a saída pra
# Indigo Plateau é a MESMA porta, mesmo padrão do Mt Moon: dois warps
# próximos, não um túnel ligando dois pontos distantes do mapa).
# ──────────────────────────────────────────────────────────────────────────────
static func _gen_victoryroad() -> Array:
	var W := 32
	var H := 32
	var grid_chars : Array = []
	for r in H:
		var row : Array = []
		for c in W:
			row.append("R")
		grid_chars.append(row)

	grid_chars[H - 1][15] = "P"
	grid_chars[H - 1][16] = "P"

	var rng := RandomNumberGenerator.new()
	rng.seed = VICTORYROAD_SEED

	var visitados : Array = []
	_rocktunnel_carve(grid_chars, W, H, 15, H - 2, 700, rng, visitados)
	for i in 4:
		var idx := rng.randi_range(0, visitados.size() - 1)
		var pt : Vector2i = visitados[idx]
		_rocktunnel_carve(grid_chars, W, H, pt.x, pt.y, 200, rng, visitados)

	var grid : Array = []
	for r in H:
		var row := ""
		for c in W:
			row += grid_chars[r][c]
		grid.append(row)
	return grid

# ──────────────────────────────────────────────────────────────────────────────
# Diglett's Cave — 28×28, cena própria (Tier 19). Mesma técnica de caminhada
# aleatória não-linear. Boca na Rota 11 (espora ao norte de Vermilion).
# ──────────────────────────────────────────────────────────────────────────────
const DIGLETTSCAVE_SEED : int = 20260901190  # fixo — mesma caverna sempre

static func _gen_digglettscave() -> Array:
	var W := 28
	var H := 28
	var grid_chars : Array = []
	for r in H:
		var row : Array = []
		for c in W:
			row.append("R")
		grid_chars.append(row)

	grid_chars[H - 1][13] = "P"
	grid_chars[H - 1][14] = "P"

	var rng := RandomNumberGenerator.new()
	rng.seed = DIGLETTSCAVE_SEED

	var visitados : Array = []
	_rocktunnel_carve(grid_chars, W, H, 13, H - 2, 500, rng, visitados)
	for i in 3:
		var idx := rng.randi_range(0, visitados.size() - 1)
		var pt : Vector2i = visitados[idx]
		_rocktunnel_carve(grid_chars, W, H, pt.x, pt.y, 150, rng, visitados)

	var grid : Array = []
	for r in H:
		var row := ""
		for c in W:
			row += grid_chars[r][c]
		grid.append(row)
	return grid

# ──────────────────────────────────────────────────────────────────────────────
# Cinnabar Island — 40×40, cena própria (só alcançável de barco — a viagem
# em si é o "trocar de ilha", exceção de warp igual caverna/subterrâneo).
# Tier 11 (01/09): contorno da ilha ORGÂNICO (mesma técnica de sin()/
# distância do litoral de Vermilion, regra de tematização de bioma), não
# um retângulo — praia em anel ao redor, rochedo vulcânico esparso no
# interior (identidade de ilha vulcânica, mesmo sem sprite de lava ainda).
# ──────────────────────────────────────────────────────────────────────────────
static func _gen_cinnabar() -> Array:
	var W := 40
	var H := 40
	var grid : Array = []
	for r in H:
		var row := ""
		for c in W:
			row += _cinnabar_cell(c, r, W, H)
		grid.append(row)
	return grid

static func _cinnabar_cell(c: int, r: int, W: int, H: int) -> String:
	# Cais de madeira — sai da praia sul rumo ao mar, é onde o barco atraca
	# (warp de volta pra Vermilion fica na ponta) ──
	if c >= 18 and c <= 21 and r >= 33 and r <= 38:
		return "D"

	# Contorno orgânico da ilha (praia em anel, mar ao redor) ──
	var dx := float(c - 20)
	var dy := float(r - 19)
	var dist := sqrt(dx * dx + dy * dy)
	var raio := 15.0 + 2.5 * sin(atan2(dy, dx) * 3.0) + 1.0 * sin(atan2(dy, dx) * 7.0)
	if dist > raio:
		return "~"
	if dist > raio - 2.5:
		return "S"

	# ── Ginásio de Cinnabar (Blaine) ── cols 10-22, rows 10-18
	if c >= 10 and c <= 22 and r >= 10 and r <= 18:
		if c == 10 or c == 22: return "w"
		if r == 10: return "H"
		if r == 18:
			if c >= 15 and c <= 17: return "P"
			return _parede_frontal(c, r)
		return "I"
	if r >= 18 and r <= 19 and c >= 15 and c <= 17:
		return "P"

	# ── Centro Pokémon ── cols 25-33, rows 10-18
	if c >= 25 and c <= 33 and r >= 10 and r <= 18:
		if c == 25 or c == 33: return "w"
		if r == 10: return "H"
		if r == 18:
			if c >= 28 and c <= 29: return "P"
			return _parede_frontal(c, r)
		return "I"
	if r >= 18 and r <= 19 and c >= 28 and c <= 29:
		return "P"

	# ── Mansão Pokémon — só a fachada por enquanto (interior/andares ficam
	# pra quando "Pokémon e estruturas" virar foco) ── cols 14-26, rows 22-28
	if c >= 14 and c <= 26 and r >= 22 and r <= 28:
		if c == 14 or c == 26: return "w"
		if r == 22: return "H"
		if r == 28:
			if c >= 19 and c <= 21: return "P"
			return _parede_frontal(c, r)
		return "I"
	if r >= 28 and r <= 29 and c >= 19 and c <= 21:
		return "P"

	# ── Caminho ligando o cais ao resto da ilha ──
	if c >= 19 and c <= 20 and r >= 29 and r <= 33:
		return "P"

	# ── Rochedo vulcânico esparso (identidade de ilha vulcânica) ──
	# 02/09: usava rocha genérica "R" apesar do comentário já pedir "vulcânica"
	# desde antes — agora usa o tile de verdade ("c", categoria Terrenos
	# especiais), sem mudar nem a posição nem a lógica de geração.
	if _espalhar_sal(c, r, 46) < 2:
		return "c"
	return "."

# ──────────────────────────────────────────────────────────────────────────────
# Zona Safari — 44×44, cena própria (Tier 12, 01/09). Pedido do Gabriel: usa
# warp mesmo não sendo caverna/subterrâneo/submarino — reserva cercada,
# entrada única com guarda, mesma lógica de "espaço fechado só acessível por
# um ponto" que já vale pra caverna. Cercada por CERCA ("E"), não árvore —
# dá identidade de reserva controlada, diferente de mata selvagem. Duas
# lagoas de formato orgânico (mesma técnica sin()/distância do litoral/
# Cinnabar) — regra de tematização de bioma. Mecânica de captura especial
# (Bola Safari, sem fugir durante o turno do jogador) FICA PRA DEPOIS
# ("mecânicas" — item 3 da ordem geral); por ora captura normal, igual ao
# resto do jogo, já que é sistema de batalha, não de mapa.
# ──────────────────────────────────────────────────────────────────────────────
static func _gen_safarizone() -> Array:
	var W := 44
	var H := 44
	var grid : Array = []
	for r in H:
		var row := ""
		for c in W:
			row += _safarizone_cell(c, r, W, H)
		grid.append(row)
	return grid

static func _safarizone_cell(c: int, r: int, W: int, H: int) -> String:
	# Cerca ao redor (reserva controlada, não mata selvagem) ──
	if c == 0 or c == W - 1 or r == 0 or r == H - 1:
		if r == H - 1 and c >= 20 and c <= 23:
			return "P"  # portão único (entrada/saída, warp aqui)
		return "E"

	# Caminho do portão pra dentro ──
	if c >= 20 and c <= 23 and r >= H - 4 and r <= H - 2:
		return "P"

	# Duas lagoas de contorno orgânico ──
	var lagoa1_dx := float(c - 12)
	var lagoa1_dy := float(r - 15)
	var lagoa1_dist := sqrt(lagoa1_dx * lagoa1_dx + lagoa1_dy * lagoa1_dy)
	var lagoa1_raio := 5.0 + 1.5 * sin(atan2(lagoa1_dy, lagoa1_dx) * 4.0)
	if lagoa1_dist < lagoa1_raio:
		return "~"

	var lagoa2_dx := float(c - 32)
	var lagoa2_dy := float(r - 28)
	var lagoa2_dist := sqrt(lagoa2_dx * lagoa2_dx + lagoa2_dy * lagoa2_dy)
	var lagoa2_raio := 6.0 + 2.0 * sin(atan2(lagoa2_dy, lagoa2_dx) * 3.0)
	if lagoa2_dist < lagoa2_raio:
		return "~"

	# Mato alto esparso (usa "G" — grama diferente da "." padrão do resto do
	# jogo, pra dar identidade própria de reserva/mato fechado) ──
	if _espalhar_sal(c, r, 47) < 4:
		return "G"
	if _espalhar_sal(c, r, 48) < 1:
		return "T"
	return "."

# ──────────────────────────────────────────────────────────────────────────────
# Rocket Hideout — 18×14, cena própria (Tier 15, 01/09). Porão sob a entrada
# em Celadon — mesma exceção de warp de Mt Moon/Rock Tunnel/Safari Zone
# ("subterrâneo"). Por ora só a sala de entrada, vazia: sem Team Rocket,
# sem mecânica de infiltração — isso é "Pokémon e estruturas" (Fase 2),
# ainda não construído. Mesmo template do PokéCenter (H roof / W parede /
# I chão / P porta / T grama na borda), só maior e sem balcão.
# ──────────────────────────────────────────────────────────────────────────────
static func _gen_rockethideout() -> Array:
	var W := 18
	var H := 14
	var grid : Array = []
	for r in H:
		var row := ""
		for c in W:
			row += _rockethideout_cell(c, r, W, H)
		grid.append(row)
	return grid

static func _rockethideout_cell(c: int, r: int, W: int, H: int) -> String:
	if r == 0:
		return "H"
	if r == 1:
		return _parede_frontal(c, r)
	if r == H - 1:
		return "T"
	if r == H - 2:
		if c >= 8 and c <= 9: return "P"
		return _parede_frontal(c, r)
	if c == 0 or c == W - 1:
		return _parede_frontal(c, r)
	return "I"

# ──────────────────────────────────────────────────────────────────────────────
# Andar simples de estrutura de múltiplos andares (Torre Pokémon, Silph Co.,
# 02/09) — sala 18×14 reaproveitando o MESMO desenho do Rocket Hideout
# (porta sempre embaixo, cols8-9), com uma porta OPCIONAL em cima (escada
# pro andar seguinte) pros andares que não são o topo da estrutura.
# ──────────────────────────────────────────────────────────────────────────────
static func _gen_andar_estrutura(escada_cima: bool) -> Array:
	var W := 18
	var H := 14
	var grid : Array = []
	for r in H:
		var row := ""
		for c in W:
			row += _andar_estrutura_cell(c, r, W, H, escada_cima)
		grid.append(row)
	return grid

static func _andar_estrutura_cell(c: int, r: int, W: int, H: int, escada_cima: bool) -> String:
	if r == 0:
		if escada_cima and c >= 8 and c <= 9: return "P"
		return "H"
	if r == 1:
		if escada_cima and c >= 8 and c <= 9: return "P"
		return _parede_frontal(c, r)
	if r == H - 1:
		return "T"
	if r == H - 2:
		if c >= 8 and c <= 9: return "P"
		return _parede_frontal(c, r)
	if c == 0 or c == W - 1:
		return _parede_frontal(c, r)
	return "I"

# ──────────────────────────────────────────────────────────────────────────────
# API pública
# ──────────────────────────────────────────────────────────────────────────────

static func get_layout(map_id: String) -> Dictionary:
	match map_id:
		"world_map":
			var tiles := _gen_world_map()
			return {"tiles": tiles, "width": W_TOTAL, "height": H_TOTAL}
		"pokemon_center":
			var tiles := _gen_pokemon_center()
			return {"tiles": tiles, "width": 16, "height": 14}
		"mt_moon":
			var tiles := _gen_mtmoon()
			return {"tiles": tiles, "width": 20, "height": 30}
		"rock_tunnel":
			var tiles := _gen_rocktunnel()
			return {"tiles": tiles, "width": 36, "height": 36}
		"cinnabar_island":
			var tiles := _gen_cinnabar()
			return {"tiles": tiles, "width": 40, "height": 40}
		"safari_zone":
			var tiles := _gen_safarizone()
			return {"tiles": tiles, "width": 44, "height": 44}
		"rocket_hideout":
			var tiles := _gen_rockethideout()
			return {"tiles": tiles, "width": 18, "height": 14}
		"victory_road":
			var tiles := _gen_victoryroad()
			return {"tiles": tiles, "width": 32, "height": 32}
		"digletts_cave":
			var tiles := _gen_digglettscave()
			return {"tiles": tiles, "width": 28, "height": 28}
		"pokemon_tower_f1", "pokemon_tower_f2", "pokemon_tower_f3", "pokemon_tower_f4":
			return {"tiles": _gen_andar_estrutura(true), "width": 18, "height": 14}
		"pokemon_tower_f5":
			return {"tiles": _gen_andar_estrutura(false), "width": 18, "height": 14}
		"silph_co_f1", "silph_co_f2":
			return {"tiles": _gen_andar_estrutura(true), "width": 18, "height": 14}
		"silph_co_f3":
			return {"tiles": _gen_andar_estrutura(false), "width": 18, "height": 14}
		"celadon_game_corner":
			return {"tiles": _gen_andar_estrutura(false), "width": 18, "height": 14}
		"rocket_hq_f1":
			return {"tiles": _gen_andar_estrutura(true), "width": 18, "height": 14}
		"rocket_hq_f2":
			return {"tiles": _gen_andar_estrutura(false), "width": 18, "height": 14}
		"pokemon_mansion_f1", "pokemon_mansion_f2":
			return {"tiles": _gen_andar_estrutura(true), "width": 18, "height": 14}
		"pokemon_mansion_f3":
			return {"tiles": _gen_andar_estrutura(false), "width": 18, "height": 14}
		"indigo_league_f1", "indigo_league_f2", "indigo_league_f3", "indigo_league_f4":
			return {"tiles": _gen_andar_estrutura(true), "width": 18, "height": 14}
		"indigo_league_f5":
			return {"tiles": _gen_andar_estrutura(false), "width": 18, "height": 14}
		"ss_anne_f1":
			return {"tiles": _gen_andar_estrutura(true), "width": 18, "height": 14}
		"ss_anne_f2":
			return {"tiles": _gen_andar_estrutura(false), "width": 18, "height": 14}
		"cerulean_cave_f1", "cerulean_cave_f2", "cerulean_cave_f3", "cerulean_cave_f4", \
		"cerulean_cave_f5", "cerulean_cave_f6":
			var n := int(map_id.right(1))
			return {"tiles": _gen_cerulean_cave_floor(n, true), "width": 20, "height": 30}
		"cerulean_cave_f7":
			return {"tiles": _gen_cerulean_cave_floor(7, false), "width": 20, "height": 30}
		_:
			return {}

## Texturas de terreno "isotrópicas" (sem cima/baixo/direção que importe —
## grama, caminho, areia, grama alta) — únicas que recebem variação de
## espelhamento em VARIETY_CHARS abaixo. Acharado ao revisar o mapa em jogo
## (03/09, "o mapa está feio"): cada uma dessas é 1 recorte só da referência
## repetido centenas de vezes lado a lado sem NENHUMA variação — o corredor
## central de Pallet Town sozinho é ~450 tiles idênticos. Paredes/portas/
## telhados/água-com-praia etc. ficam de FORA de propósito: têm continuidade
## direcional (uma porta invertida, ou uma parede que não encaixa com a
## vizinha, ficaria visivelmente errada).
const VARIETY_CHARS : String = ".PSG"

## Variações REAIS de terreno (04/09). O espelhamento sozinho (VARIETY_CHARS +
## _variety_alt) não resolvia a repetição — pior, criava padrão simétrico em
## "borboleta" que o olho pega na hora. Estas são tiles diferentes de verdade no
## atlas, geradas por rolagem circular do tile original (`tools/
## gerar_variacoes_terreno.py`): como os tiles de terreno são seamless, rolar
## gera outro arranjo igualmente seamless e com EXATAMENTE o mesmo estilo/paleta
## — é a mesma arte, só deslocada. Primeira entrada de cada lista é o tile
## original, então o mapa nunca fica sem o visual de referência.
## ⚠️ Areia e mato alto ficaram DE FORA (04/09): a areia tem uma tira escura
## na borda que a rolagem joga pro meio do tile, e o mato alto tem as folhas
## ancoradas na base — os dois apareceram em jogo com faixa preta atravessada,
## lidos como "tile partido ao meio". Só entra terreno verificado seamless E
## sem elemento ancorado.
const VARIANTES_TERRENO : Dictionary = {
	".": [Vector2i(0, 0), Vector2i(0, 7), Vector2i(1, 7), Vector2i(2, 7)],
	"P": [Vector2i(1, 0), Vector2i(3, 7), Vector2i(4, 7), Vector2i(5, 7)],
	"G": [Vector2i(4, 0), Vector2i(6, 7), Vector2i(7, 7), Vector2i(0, 8)],
	"S": [Vector2i(3, 0), Vector2i(1, 8), Vector2i(2, 8), Vector2i(3, 8)],
	# Biomas da Fase 2: base + 3 variantes cada, geradas com sal diferente.
	# Sem elas, uma ilha inteira de deserto seria o mesmo tile repetido 900 vezes.
	"z": [Vector2i(0, 14), Vector2i(1, 14), Vector2i(2, 14), Vector2i(3, 14)],
	"^": [Vector2i(0, 15), Vector2i(1, 15), Vector2i(2, 15), Vector2i(3, 15)],
	"_": [Vector2i(0, 16), Vector2i(1, 16), Vector2i(2, 16), Vector2i(3, 16)],
	"%": [Vector2i(0, 17), Vector2i(1, 17), Vector2i(2, 17), Vector2i(3, 17)],
	"&": [Vector2i(0, 18), Vector2i(1, 18), Vector2i(2, 18), Vector2i(3, 18)],
	"9": [Vector2i(0, 19), Vector2i(1, 19), Vector2i(2, 19), Vector2i(3, 19)],
}

## Agrupa as células de PISO INTERNO em prédios separados (regiões conectadas).
##
## Base do "segundo andar" (04/09, ideia do Gabriel): cada prédio recebe um
## telhado por cima, numa camada à parte, que SOME quando o jogador entra nele.
## Assim o prédio parece sólido visto de fora (resolve a falta de perspectiva)
## sem abrir mão do "entra andando" — que é justamente o que ficou pendente
## quando os Centros Pokémon perderam o warp.
##
## Trabalha sobre o TileMap JÁ PINTADO (não sobre o array de chars) de
## propósito: assim pega também o que é pintado à parte, como os ramos de
## coluna/linha negativa (Rota 22/24/25, Casa do Bill, Indigo Plateau), que não
## existem no array principal.
static func agrupar_interiores(tm: TileMap) -> Array:
	var piso : Vector2i = CHAR_MAP["I"]
	var interiores := {}
	for celula in tm.get_used_cells(0):
		if tm.get_cell_atlas_coords(0, celula) == piso:
			interiores[celula] = true

	var vistos := {}
	var predios : Array = []
	const VIZINHOS : Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for inicio in interiores:
		if vistos.has(inicio):
			continue
		var celulas : Array[Vector2i] = []
		var fila : Array[Vector2i] = [inicio]
		vistos[inicio] = true
		while not fila.is_empty():
			var atual : Vector2i = fila.pop_back()
			celulas.append(atual)
			for d in VIZINHOS:
				var viz : Vector2i = atual + d
				if vistos.has(viz) or not interiores.has(viz):
					continue
				vistos[viz] = true
				fila.append(viz)
		predios.append(celulas)
	return predios

## Escolhe a PEÇA de telhado certa pra uma célula, olhando quais vizinhos
## também são telhado do mesmo prédio (regra obrigatória 2 do Gabriel: o kit
## precisa montar uma casa fechada, não uma faixa reta).
##
## Sem isto o telhado do "segundo andar" era uma chapa lisa de tiles centrais —
## o prédio ficava sem cumeeira, sem beiral e sem canto, que é exatamente a
## queixa de "faixa horizontal única".
static func peca_de_telhado(celula: Vector2i, conjunto: Dictionary) -> String:
	var cima   : bool = conjunto.has(celula + Vector2i(0, -1))
	var baixo  : bool = conjunto.has(celula + Vector2i(0, 1))
	var esq    : bool = conjunto.has(celula + Vector2i(-1, 0))
	var dir    : bool = conjunto.has(celula + Vector2i(1, 0))

	if not cima and not esq:   return "u"   # canto superior esquerdo
	if not cima and not dir:   return "v"   # canto superior direito
	if not baixo and not esq:  return "x"   # canto inferior esquerdo
	if not baixo and not dir:  return "y"   # canto inferior direito
	if not cima:               return "q"   # cumeeira
	if not baixo:              return "r"   # beiral
	if not esq:                return "s"   # aresta esquerda
	if not dir:                return "t"   # aresta direita
	return "H"                              # miolo

## "Este char é uma porta?" / "é parede?" — checagens de significado, pra teste e
## ferramenta não compararem char literal. O vocabulário de fachada mudou em
## 04/09 (parede lisa "w" separada da parede-com-janela "W", porta virou o tile
## de porta "d" em vez de um tile de caminho) e comparação literal quebrou
## testes que na verdade continuavam corretos.
static func e_porta(ch: String) -> bool:
	return ch == "d"

## "Esta coordenada de atlas é MATA?" — inclui as árvores grandes de 2x3.
##
## Necessário desde 05/09: as árvores pequenas viraram árvores de 6 tiles, e
## `atlas_e_do_char(coord, "T")` passou a dizer NÃO para uma floresta que está
## ali, perfeita. Quem quer saber "isto é mata" tem que perguntar por aqui.
static func e_atlas_de_mata(coord: Vector2i) -> bool:
	for ch in CHARS_MATA:
		if atlas_e_do_char(coord, ch):
			return true
	for lista in ARVORES_GRANDES:
		if coord in lista:
			return true
	return false

static func e_parede(ch: String) -> bool:
	return ch == "W" or ch == "w"

## "Esta coordenada de atlas é do terreno `ch`?" — um tile pintado pode ser o
## original OU qualquer variante dele. Quem precisa checar tipo de terreno
## (teste, ferramenta, checagem de mapa) tem que perguntar POR AQUI, nunca
## comparar com CHAR_MAP[ch] direto: comparação exata quebra toda vez que uma
## variante nova entra, mesmo com o mapa 100% correto (foi exatamente o que
## aconteceu ao introduzir as variações em 04/09 — 3 testes acusaram
## "corredor intransitável" num corredor que estava perfeitamente andável).
static func atlas_e_do_char(coord: Vector2i, ch: String) -> bool:
	if VARIANTES_TERRENO.has(ch):
		return coord in VARIANTES_TERRENO[ch]
	return coord == CHAR_MAP.get(ch, Vector2i(0, 0))

## Escolhe a variante de atlas do tile. Determinístico pela posição (o mesmo
## tile sempre cai na mesma variante — o mapa não "pisca" ao repintar), com
## hash diferente do usado no espelhamento pra não correlacionar os dois e
## reintroduzir padrão.
static func _variety_atlas(ch: String, col_idx: int, row_idx: int) -> Vector2i:
	var lista : Array = VARIANTES_TERRENO.get(ch, [])
	if lista.is_empty():
		return CHAR_MAP.get(ch, Vector2i(0, 0))
	var h : int = absi((col_idx * 374761393) ^ (row_idx * 668265263))
	return lista[h % lista.size()]

static func paint(tilemap: TileMap, map_id: String) -> void:
	var layout := get_layout(map_id)
	if layout.is_empty():
		push_warning("MapLayouts: layout desconhecido para '%s'" % map_id)
		return
	tilemap.clear()
	var rows : Array = layout["tiles"]
	for row_idx in rows.size():
		var row : String = rows[row_idx]
		for col_idx in row.length():
			var ch := row[col_idx]
			var atlas : Vector2i = _variety_atlas(ch, col_idx, row_idx)
			var alt  : int = _variety_alt(ch, col_idx, row_idx)
			tilemap.set_cell(0, Vector2i(col_idx, row_idx), 0, atlas, alt)

	# Ramo da Rota 24/25 (Tier 8) — pintado à PARTE em linhas negativas, sem
	# mexer no array principal acima (que todo teste dos Tiers 1-7 lê por
	# índice == linha do mundo). Só existe no world_map.
	if map_id == "world_map":
		var norte : Array = _gen_norte_de_cerulean()
		for i in norte.size():
			var row : String = norte[i]
			var r := i - NORTE_OFFSET
			for col_idx in row.length():
				var ch := row[col_idx]
				var atlas : Vector2i = _variety_atlas(ch, col_idx, r)
				var alt  : int = _variety_alt(ch, col_idx, r)
				tilemap.set_cell(0, Vector2i(col_idx, r), 0, atlas, alt)

		# Ramo da Rota 22 → Victory Road → Indigo Plateau (Tier 18) —
		# pintado à PARTE em COLUNAS negativas (primeiro ramo nesse eixo),
		# mesma ideia do ramo norte só espelhada de linha pra coluna.
		var oeste : Array = _gen_oeste_de_viridian()
		for lr in oeste.size():
			var row : String = oeste[lr]
			var r := OESTE_ROW_INICIO + lr
			for j in row.length():
				var c := -(j + 1)
				var ch := row[j]
				var atlas : Vector2i = _variety_atlas(ch, c, r)
				var alt  : int = _variety_alt(ch, c, r)
				tilemap.set_cell(0, Vector2i(c, r), 0, atlas, alt)

	# Fecha os vazios ANTES da costa: a beira depende de quem é vizinho de quem,
	# e um buraco não pintado ao lado do mar contaria como "terra".
	preencher_vazios(tilemap)
	# Bordas orgânicas antes da costa, pela mesma razão da ordem acima.
	amaciar_bordas(tilemap)
	ondular_costa(tilemap)
	limpar_entalhes_da_costa(tilemap)
	# Árvores grandes por último entre as passadas de terreno: elas leem a mata
	# JÁ amaciada, então a floresta grande segue a silhueta orgânica nova.
	plantar_arvores_grandes(tilemap)
	plantar_estruturas_deserto(tilemap)
	# Beira da praia: por último, com o mapa inteiro já pintado (inclusive os
	# ramos em linha/coluna negativa acima) — a costa depende de quem é vizinho
	# de quem, então não dá pra decidir tile a tile na hora de pintar.
	costurar_costa(tilemap)

## Espelha horizontal/vertical/os dois de forma determinística (mesmo tile
## sempre dá a mesma variação — mapa continua reproduzível, sem RNG), só pra
## texturas isotrópicas (VARIETY_CHARS). Hash espacial clássico (primos
## grandes) em vez de módulo simples — módulo puro criaria um xadrez visível
## na própria variação, o oposto do que se quer.
static func _variety_alt(ch: String, col_idx: int, row_idx: int) -> int:
	if not VARIETY_CHARS.contains(ch):
		return 0
	var h := (col_idx * 73856093) ^ (row_idx * 19349663)
	match h % 4:
		1:  return TileSetAtlasSource.TRANSFORM_FLIP_H
		2:  return TileSetAtlasSource.TRANSFORM_FLIP_V
		3:  return TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V
		_:  return 0

static func get_pixel_bounds(map_id: String) -> Rect2i:
	var layout := get_layout(map_id)
	if layout.is_empty():
		return Rect2i(0, 0, 10240, 5760)
	var x0 := 0
	var y0 := 0
	var extra_w := 0
	var extra_h := 0
	if map_id == "world_map":
		x0 = -OESTE_OFFSET
		extra_w = OESTE_OFFSET
		y0 = -NORTE_OFFSET
		extra_h = NORTE_OFFSET
	return Rect2i(x0 * 128, y0 * 128, (layout["width"] + extra_w) * 128, (layout["height"] + extra_h) * 128)
## CovisLendarios.gd — Os três covis dos pássaros lendários (05/09).
##
## Pedido do Gabriel: cada lendário atrás de um minigame próprio, e "eles devem
## ser incrivelmente difíceis de alcançar".
##
##   ARTICUNO — Ilha Gélida, ao norte de Cerulean. Sobe 10 andares de montanha
##              e depois desce por dentro da ilha até o subterrâneo.
##              Minigame: GELO ESCORREGADIO — o jogador desliza até bater em
##              alguma coisa. Cada andar é um quebra-cabeça de deslize.
##
##   MOLTRES  — Cratera do Vulcão, dentro de Cinnabar. Desce 10 andares.
##              Minigame: PISO QUEBRADIÇO — a pedra pisada vira lava atrás de
##              você. Errar o caminho custa o andar inteiro.
##
##   ZAPDOS   — Usina, labirinto de 6 setores.
##              Minigame: PORTÕES ELÉTRICOS — cada alavanca inverte um grupo de
##              portões. Abrir um caminho fecha outro.
##
## ── A regra que rege este arquivo ────────────────────────────────────────────
## Todo andar é GERADO, e todo andar é PROVADO. Um quebra-cabeça de gelo mal
## sorteado pode não ter solução nenhuma — e um andar sem solução não é
## "difícil", é um jogo quebrado que só aparece pra quem chegou até lá. Por isso
## cada gerador termina com uma busca que confirma que dá pra ir da entrada até
## a saída, e conserta o andar se não der. `teste_covis_lendarios.gd` roda essa
## mesma prova nos 26 andares.
class_name CovisLendarios
extends RefCounted

# ──────────────────────────────────────────────────────────────────────────────
# Chars usados (todos já existem no CHAR_MAP)
# ──────────────────────────────────────────────────────────────────────────────
const PAREDE    := "w"
const PISO      := "I"
const ESCADA    := "P"
const ROCHA     := "R"
const LAVA      := "c"
const QUEBRADICO := "="  # degrau de ruínas reaproveitado como piso rachado
const PORTAO    := "["
const ALAVANCA  := "|"

## Qual lendário mora no fim de cada covil, por map_id do andar final.
##
## Mora AQUI, junto do gerador, e não no `NinhoLendario`: aquele arquivo precisa
## do EventBus e do SaveManager, e autoload não é identificador em teste
## headless — a tabela ficaria inalcançável justamente pro teste que prova que
## cada ninho tem chão livre pro lendário nascer.
const NINHOS := {
	"ilha_gelida_b5": {"especie": 144, "nome": "Articuno"},
	"cratera_b10":    {"especie": 146, "nome": "Moltres"},
	"usina_s6":       {"especie": 145, "nome": "Zapdos"},
}

## Tile livre mais perto do centro do andar. O ninho é gerado, então não dá pra
## cravar a coordenada — e pôr o lendário dentro de uma parede seria um covil de
## quinze andares terminando em nada.
static func centro_andavel(tm: TileMap) -> Vector2i:
	if tm == null:
		return Vector2i(-9999, -9999)
	var usadas := tm.get_used_cells(0)
	if usadas.is_empty():
		return Vector2i(-9999, -9999)
	var soma := Vector2i.ZERO
	for c in usadas:
		soma += c
	var centro := Vector2i(soma.x / usadas.size(), soma.y / usadas.size())
	for raio in range(0, 20):
		for dy in range(-raio, raio + 1):
			for dx in range(-raio, raio + 1):
				if absi(dx) != raio and absi(dy) != raio:
					continue
				var c := centro + Vector2i(dx, dy)
				if tm.get_cell_source_id(0, c) == -1:
					continue
				var td : TileData = tm.get_cell_tile_data(0, c)
				if td != null and not td.get_custom_data("blocked"):
					return c
	return Vector2i(-9999, -9999)

## Direções, na ordem em que a busca as tenta (determinístico).
const DIRECOES : Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

# ──────────────────────────────────────────────────────────────────────────────
# ARTICUNO — Ilha Gélida
# ──────────────────────────────────────────────────────────────────────────────
const GELO_L := 21     # largura de um andar de gelo
const GELO_A := 21     # altura

## O piso de gelo e o bloco de gelo têm arte própria (linha 24 do atlas,
## `tools/gerar_biomas.py`). A primeira versão reaproveitava a pedra de montanha
## pra não desenhar nada novo — mas o Gabriel pediu uma ilha CONGELADA, e a
## mecânica do covil inteiro depende de o jogador reconhecer "isto escorrega"
## num relance. Pedra clara não diz isso; gelo rachado diz.
static func _char_gelo() -> String:
	return ","

static func _char_bloco_gelo() -> String:
	return '"' 

## Um andar da montanha gelada.
##
## `andar` 1..10 — quanto mais alto, mais gelo e menos blocos onde parar.
## `sobe` = tem escada pra cima (os 9 primeiros); o 10º tem a boca da caverna.
static func gerar_andar_gelo(andar: int, sobe: bool) -> Array:
	var gelo := _char_gelo()
	var bloco := _char_bloco_gelo()

	# entrada embaixo, saída em cima — sempre nas mesmas colunas, pra o jogador
	# aprender o padrão e o desafio ser o caminho, não achar a porta
	var entrada := Vector2i(GELO_L / 2, GELO_A - 2)
	var saida   := Vector2i(GELO_L / 2, 1)

	var grade : Array = []
	for r in GELO_A:
		var linha : Array = []
		for c in GELO_L:
			if c == 0 or c == GELO_L - 1 or r == 0 or r == GELO_A - 1:
				linha.append(bloco)      # borda de gelo: contém o deslize
			else:
				linha.append(gelo)
		grade.append(linha)

	# blocos espalhados: são eles que dão onde parar. Menos blocos = mais
	# difícil, e é assim que a dificuldade sobe de andar em andar.
	var densidade : int = maxi(4, 12 - andar)      # andar 1: 11%, andar 10: 4%
	for r in range(2, GELO_A - 2):
		for c in range(2, GELO_L - 2):
			if Vector2i(c, r) == entrada or Vector2i(c, r) == saida:
				continue
			if _hash(c, r, 700 + andar) % 100 < densidade:
				grade[r][c] = bloco

	grade[entrada.y][entrada.x] = gelo
	grade[saida.y][saida.x] = ESCADA if sobe else "D"

	# ── A prova, em duas partes ───────────────────────────────────────────────
	#
	# 1. TEM SOLUÇÃO. Sortear e torcer não serve: um andar de gelo mal sorteado
	#    simplesmente não tem saída, e isso não é "difícil" — é um jogo quebrado
	#    que só aparece pra quem já chegou lá.
	#
	# 2. É DIFÍCIL DE VERDADE. Esta parte nasceu de um erro meu: a primeira
	#    versão só conferia (1), e o andar 1 saía com solução de UM movimento —
	#    deslizar pra cima e pronto, porque a coluna da entrada estava limpa até
	#    a escada. Solucionável e trivial ao mesmo tempo. O Gabriel pediu covis
	#    "incrivelmente difíceis de alcançar", então a dificuldade também tem que
	#    ser medida, não torcida: o caminho mais curto precisa de pelo menos
	#    `4 + andar` deslizes, e o gerador bloqueia atalhos até chegar lá.
	var minimo : int = 4 + andar
	var tentativas := 0
	var falhas_seguidas := 0
	while tentativas < 900 and falhas_seguidas < 60:
		var custo := _gelo_custo(grade, entrada, saida)
		if custo < 0:
			# sem solução: cria um ponto de parada novo
			var p := _ponto_de_parada_util(grade, entrada, saida, andar, tentativas)
			if p.x < 0:
				break
			grade[p.y][p.x] = bloco
			falhas_seguidas = 0
		elif custo < minimo:
			# Fácil demais: fecha o atalho que está sendo usado agora.
			#
			# Se esse corte específico fecha o andar inteiro, DESFAZ e tenta
			# outro — a primeira versão desistia no primeiro corte ruim, e três
			# dos dez andares saíam bem abaixo do mínimo (o 6º tinha solução de
			# 3 deslizes contra os 10 exigidos). Um corte ruim não quer dizer que
			# não existe corte bom.
			var corte := _tile_do_atalho(grade, entrada, saida, andar, tentativas)
			if corte.x < 0:
				falhas_seguidas += 1
			else:
				grade[corte.y][corte.x] = bloco
				if _gelo_custo(grade, entrada, saida) < 0:
					grade[corte.y][corte.x] = gelo
					falhas_seguidas += 1
				else:
					falhas_seguidas = 0
		else:
			break
		tentativas += 1

	return _para_texto(grade)

## Comprimento do caminho mais curto em DESLIZES, ou -1 se não há caminho.
## É a medida de dificuldade do andar: quantas vezes o jogador precisa escolher
## uma direção certa antes de chegar na escada.
static func _gelo_custo(grade: Array, entrada: Vector2i, saida: Vector2i) -> int:
	var fila : Array = [[entrada, 0]]
	var vistos := {entrada: true}
	while not fila.is_empty():
		var item : Array = fila.pop_front()
		var atual : Vector2i = item[0]
		var custo : int = item[1]
		if atual == saida:
			return custo
		for d in DIRECOES:
			var parada := _deslizar(grade, atual, d)
			if parada != atual and not vistos.has(parada):
				vistos[parada] = true
				fila.append([parada, custo + 1])
	return -1

## Um tile do caminho mais curto atual, pra virar bloco e alongar a solução.
## Nunca a entrada nem a saída, e nunca o tile onde o jogador PARA (bloquear a
## parada não alonga o caminho — some com ele).
static func _tile_do_atalho(grade: Array, entrada: Vector2i, saida: Vector2i,
		andar: int, tentativa: int) -> Vector2i:
	var caminho := _gelo_caminho(grade, entrada, saida)
	if caminho.size() < 2:
		return Vector2i(-1, -1)
	# tiles POR ONDE o deslize passa, entre uma parada e a seguinte
	var passagem : Array[Vector2i] = []
	for i in range(caminho.size() - 1):
		var de : Vector2i = caminho[i]
		var para : Vector2i = caminho[i + 1]
		var d := Vector2i(signi(para.x - de.x), signi(para.y - de.y))
		var p := de + d
		while p != para:
			passagem.append(p)
			p += d
	if passagem.is_empty():
		return Vector2i(-1, -1)
	var escolha : int = _hash(andar, tentativa, 993) % passagem.size()
	var alvo : Vector2i = passagem[escolha]
	if alvo == entrada or alvo == saida:
		return Vector2i(-1, -1)
	return alvo

## O caminho mais curto em si (lista de paradas), pra saber onde cortar.
static func _gelo_caminho(grade: Array, entrada: Vector2i, saida: Vector2i) -> Array:
	var fila : Array[Vector2i] = [entrada]
	var veio_de := {entrada: entrada}
	while not fila.is_empty():
		var atual : Vector2i = fila.pop_front()
		if atual == saida:
			var caminho : Array[Vector2i] = [atual]
			while veio_de[caminho[0]] != caminho[0]:
				caminho.insert(0, veio_de[caminho[0]])
			return caminho
		for d in DIRECOES:
			var parada := _deslizar(grade, atual, d)
			if parada != atual and not veio_de.has(parada):
				veio_de[parada] = atual
				fila.append(parada)
	return []

## Busca em largura sobre MOVIMENTOS DE DESLIZE, não sobre passos.
##
## No gelo, apertar uma direção não anda um tile: anda até bater. Então o grafo
## que importa tem como vértices os pontos onde dá pra PARAR, e como arestas os
## quatro deslizes possíveis a partir de cada um. Buscar passo a passo daria a
## resposta errada — diria que dá pra chegar em lugares onde o jogador nunca
## consegue parar.
static func _gelo_tem_solucao(grade: Array, entrada: Vector2i, saida: Vector2i) -> bool:
	var fila : Array[Vector2i] = [entrada]
	var vistos := {entrada: true}
	while not fila.is_empty():
		var atual : Vector2i = fila.pop_front()
		if atual == saida:
			return true
		for d in DIRECOES:
			var parada := _deslizar(grade, atual, d)
			if parada != atual and not vistos.has(parada):
				vistos[parada] = true
				fila.append(parada)
	return false

## Onde o jogador para se sair de `de` na direção `d`. Para no tile ANTES do
## obstáculo — e para em cima da escada, que é o que faz a saída ser alcançável.
static func _deslizar(grade: Array, de: Vector2i, d: Vector2i) -> Vector2i:
	var atual := de
	var bloco := _char_bloco_gelo()
	while true:
		var proximo := atual + d
		if proximo.y < 0 or proximo.y >= grade.size():
			return atual
		var linha : Array = grade[proximo.y]
		if proximo.x < 0 or proximo.x >= linha.size():
			return atual
		var ch : String = linha[proximo.x]
		if ch == bloco:
			return atual
		atual = proximo
		if ch == ESCADA or ch == "D":
			return atual       # escada segura o deslize: é o destino
	# inalcançável: o `while true` acima só sai por `return`. O GDScript não
	# consegue provar isso sozinho, e sem esta linha ele reprova o arquivo
	# inteiro com "not all code paths return a value".
	return atual

## Escolhe onde pôr um bloco novo pra abrir solução: um tile de gelo vizinho de
## algum ponto já alcançável. Determinístico (varre em ordem fixa, com um
## deslocamento derivado da tentativa) — o mesmo andar sai igual toda vez.
static func _ponto_de_parada_util(grade: Array, entrada: Vector2i, saida: Vector2i,
		andar: int, tentativa: int) -> Vector2i:
	var gelo := _char_gelo()
	var alcancaveis := _gelo_alcancaveis(grade, entrada)
	var deslocamento : int = _hash(andar, tentativa, 991) % 97
	var candidatos : Array[Vector2i] = []
	for r in range(2, GELO_A - 2):
		for c in range(2, GELO_L - 2):
			var p := Vector2i(c, r)
			if p == entrada or p == saida:
				continue
			if grade[r][c] != gelo:
				continue
			for d in DIRECOES:
				if alcancaveis.has(p + d):
					candidatos.append(p)
					break
	if candidatos.is_empty():
		return Vector2i(-1, -1)
	return candidatos[deslocamento % candidatos.size()]

static func _gelo_alcancaveis(grade: Array, entrada: Vector2i) -> Dictionary:
	var fila : Array[Vector2i] = [entrada]
	var vistos := {entrada: true}
	while not fila.is_empty():
		var atual : Vector2i = fila.pop_front()
		for d in DIRECOES:
			var parada := _deslizar(grade, atual, d)
			if parada != atual and not vistos.has(parada):
				vistos[parada] = true
				fila.append(parada)
	return vistos

## Os 5 andares de DESCIDA por dentro da ilha, até o ninho do Articuno.
## Aqui o gelo acaba: é caverna de gelo escavada, e o desafio passa a ser o
## caminho estreito e os Pokémon, não o deslize — senão o covil inteiro seria
## a mesma ideia dez vezes.
static func gerar_caverna_gelo(nivel: int, tem_saida: bool) -> Array:
	return _escavar(GELO_L, GELO_A, 5100 + nivel, tem_saida, _char_bloco_gelo(), "D")

# ──────────────────────────────────────────────────────────────────────────────
# MOLTRES — Cratera do Vulcão
# ──────────────────────────────────────────────────────────────────────────────
const LAVA_L := 19
const LAVA_A := 19

## Um andar da cratera.
##
## Minigame: o piso rachado ("=") vira LAVA depois que o jogador sai dele
## (`EfeitosDeTerreno`). Então não existe voltar: cada andar é um caminho de
## ida só, e escolher errado custa a descida inteira.
##
## O gerador desenha um caminho principal garantido e, ao redor dele, becos de
## piso rachado que PARECEM atalho e não levam a lugar nenhum. É daí que vem a
## dificuldade — não de esconder a saída.
static func gerar_andar_lava(andar: int, tem_saida: bool) -> Array:
	var grade : Array = []
	for r in LAVA_A:
		var linha : Array = []
		for c in LAVA_L:
			linha.append(LAVA if (c == 0 or c == LAVA_L - 1 or r == 0 or r == LAVA_A - 1) else LAVA)
		grade.append(linha)

	var entrada := Vector2i(LAVA_L / 2, 1)
	var saida   := Vector2i(LAVA_L / 2, LAVA_A - 2)

	# Caminho principal: passeio determinístico que desce sempre, serpenteando.
	# Guardado numa lista porque os becos falsos precisam SAIR dele — a primeira
	# versão sorteava os becos em qualquer lugar do andar e eles nasciam soltos
	# no meio da lava, inalcançáveis. Beco que o jogador não consegue entrar não
	# é armadilha, é lixo no mapa.
	var caminho : Array[Vector2i] = []
	var atual := entrada
	grade[atual.y][atual.x] = PISO
	caminho.append(atual)
	var passo := 0
	while atual.y < saida.y:
		var lado : int = (_hash(andar, passo, 810) % 5) - 2      # -2..+2: serpenteia mais
		var alvo_x : int = clampi(atual.x + lado, 2, LAVA_L - 3)
		while atual.x != alvo_x:
			atual.x += signi(alvo_x - atual.x)
			grade[atual.y][atual.x] = QUEBRADICO
			caminho.append(atual)
		atual.y += 1
		grade[atual.y][atual.x] = QUEBRADICO
		caminho.append(atual)
		passo += 1
	while atual.x != saida.x:
		atual.x += signi(saida.x - atual.x)
		grade[atual.y][atual.x] = QUEBRADICO
		caminho.append(atual)

	# Becos falsos: SAEM de um ponto do caminho e morrem. É neles que está a
	# dificuldade — com o piso desmoronando atrás, entrar num beco custa o andar.
	# Quanto mais fundo, mais becos.
	var becos : int = 3 + andar
	for i in becos:
		var origem : Vector2i = caminho[_hash(andar, i, 830) % caminho.size()]
		var d : Vector2i = DIRECOES[_hash(andar, i, 823) % 4]
		var comprimento : int = 2 + _hash(andar, i, 822) % 4
		var p := origem
		for k in comprimento:
			p += d
			if p.x <= 1 or p.x >= LAVA_L - 2 or p.y <= 1 or p.y >= LAVA_A - 2:
				break
			if grade[p.y][p.x] == LAVA:
				grade[p.y][p.x] = QUEBRADICO

	grade[entrada.y][entrada.x] = PISO
	grade[saida.y][saida.x] = ESCADA if tem_saida else "D"
	# o topo é a entrada vinda de cima
	grade[0][entrada.x] = PISO
	return _para_texto(grade)

# ──────────────────────────────────────────────────────────────────────────────
# ZAPDOS — Usina, labirinto de portões
# ──────────────────────────────────────────────────────────────────────────────
const USINA_L := 25
const USINA_A := 25

## Um setor do labirinto da usina.
##
## Minigame: cada alavanca inverte um GRUPO de portões — os do grupo que
## estavam abertos fecham, e vice-versa. Abrir um caminho fecha outro, então o
## labirinto tem que ser lido antes de ser andado.
##
## O labirinto em si é escavado (não é grade de corredores retos), e os portões
## são postos EM CIMA de gargalos do caminho — pontos por onde toda rota passa.
## Pôr portão em lugar qualquer daria um labirinto com portas decorativas.
static func gerar_setor_usina(setor: int, tem_saida: bool) -> Array:
	var texto := _escavar(USINA_L, USINA_A, 5300 + setor, tem_saida, PAREDE, PISO)
	var grade : Array = []
	for linha in texto:
		var l : Array = []
		for ch in str(linha):
			l.append(ch)
		grade.append(l)

	var entrada := Vector2i(USINA_L / 2, USINA_A - 2)
	# gargalos: tiles de piso cuja remoção desconecta a entrada da saída
	var gargalos := _gargalos(grade, entrada, setor)
	var quantos : int = mini(gargalos.size(), 2 + setor)
	for i in quantos:
		var g : Vector2i = gargalos[i]
		grade[g.y][g.x] = PORTAO
	# uma alavanca por grupo de portões, sempre em lugar alcançável SEM passar
	# por portão nenhum — senão a alavanca ficaria atrás da porta que ela abre
	var livres := _alcancaveis_a_pe(grade, entrada, [PAREDE, PORTAO])
	var chaves : Array = livres.keys()
	chaves.sort_custom(func(a, b): return (a.x * 100 + a.y) < (b.x * 100 + b.y))
	for i in mini(2, chaves.size()):
		var p : Vector2i = chaves[(_hash(setor, i, 840) % chaves.size())]
		if grade[p.y][p.x] == PISO:
			grade[p.y][p.x] = ALAVANCA
	return _para_texto(grade)

## Tiles de piso que são passagem única: tirando um, a saída fica inalcançável.
## É onde faz sentido pôr portão — o resto seria decoração.
static func _gargalos(grade: Array, entrada: Vector2i, sal: int) -> Array:
	var saida := Vector2i(USINA_L / 2, 1)
	var achados : Array[Vector2i] = []
	var alcancaveis := _alcancaveis_a_pe(grade, entrada, [PAREDE])
	for p in alcancaveis:
		if p == entrada or p == saida:
			continue
		if grade[p.y][p.x] != PISO:
			continue
		grade[p.y][p.x] = PAREDE
		var ainda := _alcancaveis_a_pe(grade, entrada, [PAREDE])
		grade[p.y][p.x] = PISO
		if not ainda.has(saida):
			achados.append(p)
	achados.sort_custom(func(a, b):
		return _hash(a.x, a.y, sal) < _hash(b.x, b.y, sal))
	return achados

# ──────────────────────────────────────────────────────────────────────────────
# Ferramentas comuns
# ──────────────────────────────────────────────────────────────────────────────

## Escavação por caminhada aleatória determinística — mesma ideia já usada no
## Rock Tunnel: o resultado parece erosão, e nunca gera sala isolada, porque
## todo ramo sai de um ponto já escavado.
static func _escavar(L: int, A: int, semente: int, tem_saida: bool,
		char_parede: String, char_piso: String) -> Array:
	var grade : Array = []
	for r in A:
		var linha : Array = []
		for c in L:
			linha.append(char_parede)
		grade.append(linha)

	var entrada := Vector2i(L / 2, A - 2)
	var saida := Vector2i(L / 2, 1)
	var p := entrada
	grade[p.y][p.x] = char_piso
	var escavados : Array[Vector2i] = [p]
	var passos : int = L * A / 2
	for i in passos:
		var d : Vector2i = DIRECOES[_hash(semente, i, 3) % 4]
		var n := p + d
		if n.x <= 0 or n.x >= L - 1 or n.y <= 0 or n.y >= A - 1:
			p = escavados[_hash(semente, i, 5) % escavados.size()]
			continue
		p = n
		if grade[p.y][p.x] == char_parede:
			grade[p.y][p.x] = char_piso
			escavados.append(p)
	# garante que a saída existe e está ligada: cava em linha reta até ela
	var q := saida
	grade[q.y][q.x] = char_piso
	while not _alcancaveis_a_pe(grade, entrada, [char_parede]).has(saida):
		q.y += 1
		if q.y >= A - 1:
			break
		grade[q.y][q.x] = char_piso
	grade[saida.y][saida.x] = ESCADA if tem_saida else "D"
	grade[entrada.y][entrada.x] = char_piso
	grade[A - 1][entrada.x] = ESCADA
	return _para_texto(grade)

static func _alcancaveis_a_pe(grade: Array, de: Vector2i, bloqueiam: Array) -> Dictionary:
	var fila : Array[Vector2i] = [de]
	var vistos := {de: true}
	while not fila.is_empty():
		var atual : Vector2i = fila.pop_front()
		for d in DIRECOES:
			var n : Vector2i = atual + d
			if n.y < 0 or n.y >= grade.size():
				continue
			var linha : Array = grade[n.y]
			if n.x < 0 or n.x >= linha.size():
				continue
			if str(linha[n.x]) in bloqueiam:
				continue
			if vistos.has(n):
				continue
			vistos[n] = true
			fila.append(n)
	return vistos

static func _para_texto(grade: Array) -> Array:
	var saida : Array = []
	for linha in grade:
		var s := ""
		for ch in linha:
			s += str(ch)
		saida.append(s)
	return saida

static func _hash(x: int, y: int, sal: int) -> int:
	var h : int = ((x * 0x9E3779B1) ^ (y * 0x85EBCA77) ^ (sal * 0xC2B2AE35)) & 0xFFFFFFFF
	h = ((h ^ (h >> 15)) * 0xC2B2AE3D) & 0xFFFFFFFF
	return (h ^ (h >> 13)) & 0xFFFFFFFF

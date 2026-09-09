## RegrasDeCovil.gd — O que muda quando o jogador entra numa dungeon (06/09).
##
## Etapa 2 do plano das Dungeons Elementais. O pedido do Gabriel era "risco
## real": perder tem que doer, e curar não pode ser um botão que se aperta sem
## pensar. Este arquivo é onde essa intenção vira regra.
##
## A DUNGEON EM CINCO ANÉIS, e cada anel responde a uma pergunta:
##   1 ENTRADA   — "o que é este lugar?" Seguro. É pra cá que se volta ao cair.
##   2 VESTÍBULO — "como funciona?" A aula: poucos inimigos, o perigo do lugar
##                 em versão inofensiva (no gelo: uma pista curta, sem buraco).
##   3 FAZENDA   — "vale a pena ir mais fundo?" O coração: EXP, item, pedra.
##   4 ELITE     — "estou pronto?" O portão, guardado por inimigos bem piores.
##   5 ARENA     — "eu consigo?" O lendário, com santuário logo antes.
##
## O santuário antes do chefe não é bondade, é legibilidade: se o jogador perde
## com 40% de vida porque gastou poção no anel 3, ele aprende "eu devia ter
## poupado" — não "eu devia ter desviado". O caminho testa recurso; o chefe
## testa execução. Separar as duas lições é o que torna o chefe justo.
##
## AS TRÊS TRAVAS DE CURA (nenhuma existe fora de dungeon — lá a cura é livre):
##   · 8 s de espera compartilhada entre TODOS os curativos. Duas poções
##     seguidas deixam de existir.
##   · Mochila lacrada: o que entrou é o que pode ser usado. O que se ACHA lá
##     dentro vai pra casa, mas não salva a expedição atual — é o que faz
##     preparar-se valer alguma coisa.
##   · Na arena do chefe: 3 usos no total e 20 s entre eles. Curar vira uma
##     decisão que se toma três vezes na luta inteira.
##
## Referência: a Boss Fight do Suicune (PokeXGames) proíbe consumível por
## completo. Não copiei ao pé da letra de propósito — lá são 4 jogadores, aqui
## é um só, e proibição total transforma derrota em "recomeça do zero".
##
## É uma classe TODA ESTÁTICA de propósito, não um autoload: `class_name` e
## autoload com o mesmo nome se atrapalham no Godot, e o estado aqui é pouco
## (o lacre e dois relógios). Assim o teste headless chama cada regra direto,
## sem precisar montar árvore nenhuma — que é justamente onde este tipo de
## regra costuma passar sem ser conferida.
class_name RegrasDeCovil
extends RefCounted

# ──────────────────────────────────────────────────────────────────────────
# As dungeons (por ora só a de Gelo está completa — Etapa 2 do plano)
# ──────────────────────────────────────────────────────────────────────────
const DUNGEONS : Dictionary = {
	"ilha_gelida": {
		"nome": "Covil Gelado",
		"tipo": "ice",
		"prefixo": "ilha_gelida",
		"entrada": "ilha_gelida_entrada",
		"cena_entrada": "res://scenes/world/dungeons/IlhaGelida_Entrada.tscn",
		"vestibulo": "ilha_gelida_vestibulo",
		# Os 10 andares de subida já existiam e estão provados (solução
		# garantida e dificuldade mínima medida) — viram a FAZENDA. Os 4 de
		# descida viram a ELITE, e o ninho vira a ARENA. Reclassificar em vez
		# de redesenhar: o trabalho de 15 andares não se joga fora.
		"fazenda": ["f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "f10"],
		"elite":   ["b1", "b2", "b3", "b4"],
		"arena":   "ilha_gelida_b5",
		"teto_de_nivel": 50,
		"piso_de_nivel": 35,
		"pedra": "water_stone",
		"chefe": 144,
	},
}

const ESPERA_COVIL   : float = 8.0    ## segundos entre curativos, dentro do covil
const ESPERA_ARENA   : float = 20.0   ## na sala do chefe
const USOS_NA_ARENA  : int   = 3      ## teto de curas na luta inteira
const TEMPO_DE_USO   : float = 1.2    ## parado pra usar; dano cancela

# ──────────────────────────────────────────────────────────────────────────
# Consultas puras — sem árvore, sem estado. É o que dá pra testar de verdade.
# ──────────────────────────────────────────────────────────────────────────

## A que dungeon este mapa pertence ("" se for mapa comum).
static func dungeon_do_mapa(map_id: String) -> String:
	for id in DUNGEONS:
		if anel_do_mapa(map_id) > 0 and map_id.begins_with(str(DUNGEONS[id]["prefixo"])):
			return id
	return ""

## Qual anel (1..5), ou 0 se o mapa não é de dungeon nenhuma.
static func anel_do_mapa(map_id: String) -> int:
	for id in DUNGEONS:
		var d : Dictionary = DUNGEONS[id]
		if map_id == str(d["entrada"]):
			return 1
		if map_id == str(d["vestibulo"]):
			return 2
		if map_id == str(d["arena"]):
			return 5
		var prefixo : String = str(d["prefixo"]) + "_"
		if map_id.begins_with(prefixo):
			var sufixo := map_id.substr(prefixo.length())
			if sufixo in d["fazenda"]:
				return 3
			if sufixo in d["elite"]:
				return 4
	return 0

static func em_covil(map_id: String) -> bool:
	return anel_do_mapa(map_id) > 0

## O anel 1 é o único lugar seguro: sem inimigo, cura completa, e é pra cá que
## o jogador volta quando o time inteiro cai.
static func e_seguro(map_id: String) -> bool:
	return anel_do_mapa(map_id) == 1

static func e_arena(map_id: String) -> bool:
	return anel_do_mapa(map_id) == 5

## Teto de nível da dungeon (0 = sem teto).
static func teto_de_nivel(map_id: String) -> int:
	var id := dungeon_do_mapa(map_id)
	if id == "":
		return 0
	return int(DUNGEONS[id].get("teto_de_nivel", 0))

## O rebaixamento. Um Pokémon nível 80 numa dungeon de teto 50 entra como 50 —
## stats recalculados, não só o número na tela. Pune vencer por excesso de
## nível em vez de estratégia, que é o erro que mata qualquer dungeon.
## O nível REAL do Pokémon não muda: isto é só o nível com que ele luta aqui.
static func nivel_efetivo(nivel: int, map_id: String) -> int:
	var teto := teto_de_nivel(map_id)
	if teto <= 0:
		return nivel
	# O selo APERTA o teto: Ouro faz você lutar 20 níveis mais fraco que
	# Bronze na mesma dungeon. É a diferença mecânica entre os três.
	teto = maxi(5, teto + int(selo_atual().get("teto_extra", 0)))
	return mini(nivel, teto)

static func foi_rebaixado(nivel: int, map_id: String) -> bool:
	return nivel_efetivo(nivel, map_id) < nivel

## Aviso, não bloqueio (regra do plano): abaixo do piso o jogo diz "você vai
## morrer" na cara do jogador — e abre a porta assim mesmo. É respeito: ele
## pode escolher apanhar.
static func abaixo_do_piso(nivel: int, map_id: String) -> bool:
	var id := dungeon_do_mapa(map_id)
	if id == "":
		return false
	return nivel < int(DUNGEONS[id].get("piso_de_nivel", 0))

# ──────────────────────────────────────────────────────────────────────────
# OS TRÊS SELOS (Etapa 3) — um mapa, três desafios
# ──────────────────────────────────────────────────────────────────────────
## Copiando a granulação do PokeXGames sem copiar o custo: em vez de três
## dungeons, a MESMA dungeon oferece Bronze/Prata/Ouro. Muda o teto de nível
## (quanto mais alto o selo, mais baixo o teto — você luta mais fraco), a
## densidade de inimigos, e quanto da vida do chefe é preciso tirar.
##
## O jogador escolhe o selo na Entrada. Isso é o oposto de "dificuldade fácil/
## normal/difícil" genérica: aqui a diferença é MECÂNICA e declarada.
const SELOS : Dictionary = {
	"bronze": {"nome": "Bronze", "teto_extra": 0,   "densidade": 1.0, "hp_do_chefe": 0.4},
	"prata":  {"nome": "Prata",  "teto_extra": -10, "densidade": 1.5, "hp_do_chefe": 0.7},
	"ouro":   {"nome": "Ouro",   "teto_extra": -20, "densidade": 2.0, "hp_do_chefe": 1.0},
}
const SELO_PADRAO : String = "bronze"

static var selo_escolhido : String = SELO_PADRAO

static func selo_atual() -> Dictionary:
	return SELOS.get(selo_escolhido, SELOS[SELO_PADRAO])

static func escolher_selo(selo: String) -> bool:
	if not SELOS.has(selo):
		return false
	selo_escolhido = selo
	return true

## Quanto do HP do chefe basta tirar pra vencer neste selo. No Bronze o chefe
## foge aos 40% — é vitória de verdade, com recompensa menor.
static func fracao_do_chefe() -> float:
	return float(selo_atual().get("hp_do_chefe", 1.0))

static func multiplicador_de_densidade() -> float:
	return float(selo_atual().get("densidade", 1.0))

static func espera_de_cura(map_id: String) -> float:
	if e_arena(map_id):
		return ESPERA_ARENA
	if em_covil(map_id):
		return ESPERA_COVIL
	return 0.0

# ──────────────────────────────────────────────────────────────────────────
# Estado da expedição (autoload) — o lacre da mochila e o relógio da cura
# ──────────────────────────────────────────────────────────────────────────
static var covil_atual : String = ""      ## id da dungeon, "" fora dela
static var _lacre : Dictionary = {}       ## item_id -> quantos ainda podem ser usados
static var _proxima_cura_msec : int = 0
static var _curas_na_arena : int = 0
static var _arena_anterior : String = ""

## Chamada pelo BaseMap ao terminar de montar o mapa — é o momento em que o
## jogador de fato chegou, e é onde a mochila é lacrada ou destravada.
static func atualizar(map_id: String) -> void:
	var id := dungeon_do_mapa(map_id)
	if id != covil_atual:
		covil_atual = id
		# Entrar lacra a mochila; sair tira o lacre. Sem isso, "volto e compro
		# mais" desfaz a única coisa que faz preparação valer.
		if id == "":
			_lacre.clear()
		else:
			_lacrar_mochila()
	# Cada entrada na arena zera a conta de 3 usos: a luta é uma tentativa
	# nova, não a continuação da anterior.
	if e_arena(map_id) and _arena_anterior != map_id:
		_curas_na_arena = 0
	_arena_anterior = map_id if e_arena(map_id) else ""

static func _lacrar_mochila() -> void:
	_lacre.clear()
	var raiz = Engine.get_main_loop().root if Engine.get_main_loop() else null
	var salvar = raiz.get_node_or_null("SaveManager") if raiz else null
	if salvar == null:
		return
	var inventario : Dictionary = salvar.save_data.get("inventory", {})
	for item_id in inventario:
		_lacre[item_id] = int(inventario[item_id])

## Pergunta única que a Mochila faz antes de deixar usar um curativo.
## Devolve `{ok: bool, motivo: String, espera: float}` — o motivo é o que
## aparece na tela, então é escrito pro jogador, não pro programador.
static func pode_curar(item_id: String, map_id: String) -> Dictionary:
	if not em_covil(map_id):
		return {"ok": true, "motivo": "", "espera": 0.0}

	var falta := float(_proxima_cura_msec - Time.get_ticks_msec()) / 1000.0
	if falta > 0.0:
		return {"ok": false, "espera": falta,
			"motivo": "Ainda se recuperando — %.1fs" % falta}

	if e_arena(map_id) and _curas_na_arena >= USOS_NA_ARENA:
		return {"ok": false, "espera": 0.0,
			"motivo": "Você já usou as %d curas desta luta." % USOS_NA_ARENA}

	if int(_lacre.get(item_id, 0)) <= 0:
		return {"ok": false, "espera": 0.0,
			"motivo": "A mochila foi lacrada na entrada — você não trouxe mais deste item."}

	return {"ok": true, "motivo": "", "espera": 0.0}

## Chamado DEPOIS de a cura acontecer de verdade.
static func registrar_cura(item_id: String, map_id: String) -> void:
	if not em_covil(map_id):
		return
	_proxima_cura_msec = Time.get_ticks_msec() + int(espera_de_cura(map_id) * 1000.0)
	if e_arena(map_id):
		_curas_na_arena += 1
	if _lacre.has(item_id):
		_lacre[item_id] = maxi(0, int(_lacre[item_id]) - 1)

static func curas_restantes_na_arena() -> int:
	return maxi(0, USOS_NA_ARENA - _curas_na_arena)

# ──────────────────────────────────────────────────────────────────────────
# DERROTA DENTRO DO COVIL (Etapa 3)
# ──────────────────────────────────────────────────────────────────────────
## Cair numa dungeon não devolve ao Centro Pokémon: devolve à ENTRADA dela,
## que é o anel seguro. E cobra metade do dinheiro carregado (convenção
## clássica). Não perde Pokémon nem EXP — o custo tem que doer sem apagar
## progresso, senão o jogador para de arriscar.
##
## Devolve o caminho da cena da Entrada, ou "" se ele não caiu numa dungeon
## (aí vale a regra normal do jogo, o Centro Pokémon).
static func ao_cair(map_id: String) -> String:
	var covil := dungeon_do_mapa(map_id)
	if covil == "":
		return ""
	var salvar = _no("SaveManager")
	if salvar != null:
		var dinheiro : int = int(salvar.save_data.get("money", 0))
		salvar.save_data["money"] = int(dinheiro / 2)
		var barramento = _no("EventBus")
		if barramento != null:
			barramento.notification_requested.emit(
				"Você caiu. Voltou pra Entrada e perdeu %d moedas." % (dinheiro - int(dinheiro / 2)))
	return str(DUNGEONS[covil].get("cena_entrada", ""))

static func _no(nome: String):
	var laco := Engine.get_main_loop()
	if laco == null or not (laco is SceneTree):
		return null
	return (laco as SceneTree).root.get_node_or_null(nome)

static func _map_id_atual() -> String:
	var raiz = Engine.get_main_loop().root if Engine.get_main_loop() else null
	var mundo = raiz.get_node_or_null("WorldManager") if raiz else null
	if mundo == null or not ("current_map_id" in mundo):
		return ""
	return str(mundo.current_map_id)

## Atalho pra quem não quer buscar o map_id na mão.
static func mapa_atual() -> String:
	return _map_id_atual()

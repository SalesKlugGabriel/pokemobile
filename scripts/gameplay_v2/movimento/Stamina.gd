## Stamina.gd — O fôlego do treinador (§5 da especificação de 13/09).
##
## Pedido do Gabriel, resumido: correr, nadar, escalar, pular, lançar Pokéball e
## trocar de Pokémon custam stamina. Enquanto gasta, não regenera. Ao chegar a
## zero, a lentidão vem em três degraus. Pra voltar a regenerar depois do zero,
## é preciso **parar** por cerca de 1 segundo.
##
## ── Por que classe pura ──────────────────────────────────────────────────────
##
## Isto é uma máquina de estados sobre números: entra `delta` e o que o jogador
## está fazendo, sai quanto sobrou e o quanto ele está lento. Nenhuma linha
## depende de nó, cena ou autoload — então dá pra provar os três degraus sem
## subir o jogo, que é a única forma de saber que a exaustão II começa aos 5 s e
## não aos 4,9.
##
## Quem tem corpo (`CorpoLivre`) só chama `passo()` uma vez por frame e obedece.
##
## ── A decisão de design que não estava no pedido ─────────────────────────────
##
## O Gabriel descreveu a exaustão em três faixas de tempo (0–5 s, 5–10 s, 10 s+)
## sem dizer quando o relógio zera. Escolhi: **o relógio da exaustão só corre
## enquanto a stamina está em zero**, e é zerado assim que ela sai do zero.
## A alternativa (contar desde o primeiro zero, independente de recuperar) faria
## um jogador que recuperou metade da barra continuar 50% mais lento, o que
## ninguém consegue ler na tela.
class_name Stamina
extends RefCounted

# ──────────────────────────────────────────────────────────────────────────────
# Os números
# ──────────────────────────────────────────────────────────────────────────────

const MAXIMO_BASE      : float = 100.0
const REGEN_BASE       : float = 18.0   ## por segundo, fora de gasto
const ATRASO_APOS_ZERO : float = 1.0    ## §5: parar ~1 s antes de voltar a regenerar

## Custo de cada ação. Contínuas são por SEGUNDO; instantâneas são por USO.
const CUSTO_POR_SEGUNDO : Dictionary = {
	"correr": 12.0,
	"nadar":  8.0,
	"escalar": 16.0,
}
const CUSTO_POR_USO : Dictionary = {
	"pular": 10.0,
	"pokeball": 14.0,
	"troca_rapida": 20.0,
}

## §5: os três degraus, e quanto cada um tira de velocidade.
const EXAUSTAO : Array[Dictionary] = [
	{"ate": 5.0,  "nivel": 1, "penalidade": 0.15},
	{"ate": 10.0, "nivel": 2, "penalidade": 0.30},
	{"ate": INF,  "nivel": 3, "penalidade": 0.50},
]

# ──────────────────────────────────────────────────────────────────────────────
# As três linhas de progressão (§5)
# ──────────────────────────────────────────────────────────────────────────────

## Cada ponto de RESERVE dá +1% do máximo base; REGENERATION, +1% da recuperação
## base; EFFICIENCY desconta do custo. Ficam como pontos, não como valor final,
## porque o valor final é conta — e conta guardada é conta que diverge.
var reserve      : int = 0
var regeneration : int = 0
var efficiency   : int = 0

# ──────────────────────────────────────────────────────────────────────────────
# Estado
# ──────────────────────────────────────────────────────────────────────────────

var atual          : float = MAXIMO_BASE
var _tempo_em_zero : float = 0.0   ## só corre enquanto `atual` é zero
var _espera        : float = 0.0   ## conta o 1 s parado depois de zerar
var _travada       : bool  = false ## true = zerou e ainda não cumpriu a espera

func _init(pontos: Dictionary = {}) -> void:
	reserve      = int(pontos.get("reserve", 0))
	regeneration = int(pontos.get("regeneration", 0))
	efficiency   = int(pontos.get("efficiency", 0))
	atual        = maximo()

# ──────────────────────────────────────────────────────────────────────────────
# As contas derivadas — sempre calculadas, nunca guardadas
# ──────────────────────────────────────────────────────────────────────────────

func maximo() -> float:
	return MAXIMO_BASE * (1.0 + 0.01 * float(reserve))

func regen_por_segundo() -> float:
	return REGEN_BASE * (1.0 + 0.01 * float(regeneration))

## EFFICIENCY barateia, mas nunca chega a zerar o custo: o teto de 60% existe
## pra correr continuar sendo uma decisão mesmo num personagem especializado.
func fator_de_custo() -> float:
	return maxf(0.4, 1.0 - 0.01 * float(efficiency))

func custo_continuo(acao: String) -> float:
	return float(CUSTO_POR_SEGUNDO.get(acao, 0.0)) * fator_de_custo()

func custo_de_uso(acao: String) -> float:
	return float(CUSTO_POR_USO.get(acao, 0.0)) * fator_de_custo()

func fracao() -> float:
	var m := maximo()
	return 0.0 if m <= 0.0 else clampf(atual / m, 0.0, 1.0)

# ──────────────────────────────────────────────────────────────────────────────
# Exaustão
# ──────────────────────────────────────────────────────────────────────────────

## 0 = normal. 1, 2 e 3 são os degraus da §5.
func nivel_de_exaustao() -> int:
	if atual > 0.0:
		return 0
	for faixa in EXAUSTAO:
		if _tempo_em_zero < float(faixa["ate"]):
			return int(faixa["nivel"])
	return 3

## O multiplicador de velocidade de movimento. 1,0 = normal; 0,5 = metade.
func fator_de_velocidade() -> float:
	var n := nivel_de_exaustao()
	if n == 0:
		return 1.0
	return 1.0 - float(EXAUSTAO[n - 1]["penalidade"])

## Nome do estado, pro sinal que a HUD consome. Ver `AGENTS.md`: a UI mostra,
## não decide.
func estado() -> String:
	var n := nivel_de_exaustao()
	return "normal" if n == 0 else "exaustao_%d" % n

# ──────────────────────────────────────────────────────────────────────────────
# O tick
# ──────────────────────────────────────────────────────────────────────────────

## Uma chamada por frame. `acoes_continuas` é o que o jogador está fazendo AGORA
## (ex: `["correr"]`); `parado` diz se ele está sem se mexer, que é o que libera
## a regeneração depois de zerar.
##
## Devolve true se alguma coisa mudou o bastante pra valer emitir sinal — evitar
## emitir 60 vezes por segundo um número que não mudou é a §63 na prática.
func passo(delta: float, acoes_continuas: Array = [], parado: bool = false) -> bool:
	var antes_valor  := atual
	var antes_estado := estado()

	var gasto : float = 0.0
	for a in acoes_continuas:
		gasto += custo_continuo(str(a))

	if gasto > 0.0:
		atual = maxf(0.0, atual - gasto * delta)
		# Gastar sempre interrompe a regeneração (§5), inclusive a espera: quem
		# tentou correr com a barra vazia recomeça o 1 s do zero.
		_espera = 0.0
	else:
		_regenerar(delta, parado)

	if atual <= 0.0:
		atual = 0.0
		_travada = true
		_tempo_em_zero += delta
	else:
		_tempo_em_zero = 0.0

	return not is_equal_approx(antes_valor, atual) or antes_estado != estado()

func _regenerar(delta: float, parado: bool) -> void:
	if _travada:
		# §5: depois do zero, precisa PARAR e esperar. Andar não conta como parar
		# aqui — só depois que a regeneração começou é que dá pra voltar a andar.
		if not parado:
			_espera = 0.0
			return
		_espera += delta
		if _espera < ATRASO_APOS_ZERO:
			return
		_travada = false
		_espera  = 0.0
	atual = minf(maximo(), atual + regen_por_segundo() * delta)

## Ação instantânea (pular, lançar ball, trocar). Devolve false e **não gasta**
## se não houver stamina suficiente — quem chama decide o que dizer ao jogador.
##
## Diferente do gasto contínuo de propósito: correr com pouca barra apenas
## acaba com ela, mas lançar uma Pokéball pela metade não existe.
func gastar(acao: String) -> bool:
	var c := custo_de_uso(acao)
	if c <= 0.0:
		return true
	if atual < c:
		return false
	atual = maxf(0.0, atual - c)
	_espera = 0.0
	if atual <= 0.0:
		_travada = true
	return true

## Só pra teste e pra carregar save: põe a barra num valor exato.
func definir(valor: float) -> void:
	atual = clampf(valor, 0.0, maximo())
	if atual > 0.0:
		_tempo_em_zero = 0.0
		_travada = false
		_espera = 0.0

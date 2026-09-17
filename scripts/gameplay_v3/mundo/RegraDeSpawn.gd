## RegraDeSpawn.gd — Quando, o quê e ONDE nasce um selvagem (Fase 11).
##
## Classe pura. Quem executa é o `SpawnerSelvagem3D`; aqui só se decide — e por
## isso dá pra provar "lugar perigoso tem menos encontro" sem subir o mundo.
##
## ── O que veio inteiro da V2, e não foi reescrito ───────────────────────────
##
## `PerigoDaZona` já resolve o pedido do Gabriel de *"sim, e também mais raro"*:
## o perigo sai do **nível dos Pokémon já cadastrados em `zones.json`** (fonte de
## verdade única — não existe uma segunda lista de "zonas perigosas" pra alguém
## manter em sincronia), e dele saem o intervalo entre encontros, a chance de
## elite e a correção dos pesos de sorteio.
##
## A inversão que a frase dele pede continua valendo: **lugar perigoso tem MENOS
## bicho, e cada um pesa mais.** Um lugar que joga 10 bichos fracos é cansativo;
## um que joga 1 forte é perigoso.
##
## ── A decisão nova desta fase: ONDE ────────────────────────────────────────
##
## Em 2D o spawn acontecia em qualquer tile livre da zona. Em 3D há um corpo
## físico envolvido, e isso muda tudo: **nascer em cima do jogador o catapulta**.
## Não é hipótese — é o achado de 17/09, medido: um corpo que aparece onde outro
## está em pé carrega o outro junto quando o colisor assenta.
##
## Por isso o nascimento é num **anel**: nunca mais perto que `RAIO_MINIMO`, nunca
## mais longe que `RAIO_MAXIMO`. O mínimo protege da física e da surpresa injusta
## (bicho materializando na sua cara); o máximo evita gastar população em bicho
## que o jogador nunca vai ver.
class_name RegraDeSpawn
extends RefCounted

## Um tile da V2 em pixels. Só pra converter as constantes legadas — as
## distâncias de `CombatBalance` estão em tiles, e em 3D 1 tile = 1 metro.
const PIXELS_POR_TILE : float = 128.0

## Segundos entre tentativas de spawn numa zona segura. O perigo ESTICA isto.
const INTERVALO_BASE : float = 6.0

## O anel de nascimento, em metros.
##
## `RAIO_MINIMO` é maior que o raio de aggro de um agressivo (5 m) de propósito:
## o bicho tem de aparecer **fora** do alcance de percepção e se aproximar. Nascer
## já em aggro tira do jogador a chance de ver a coisa vindo.
const RAIO_MINIMO : float = 12.0
const RAIO_MAXIMO : float = 28.0

## Além disto, o selvagem desaparece. Folgado em relação ao `RAIO_MAXIMO` pra o
## bicho não sumir no primeiro passo pra trás — sumiço na frente do jogador é
## pior que um bicho a mais no mundo.
const RAIO_DE_DESPEJO : float = 45.0

## População simultânea numa zona segura, e no lugar mais perigoso do jogo.
const POPULACAO_SEGURA  : int = 8
const POPULACAO_EXTREMA : int = 3

# ──────────────────────────────────────────────────────────────────────────────
# Quando
# ──────────────────────────────────────────────────────────────────────────────

## Segundos até a próxima tentativa, nesta zona.
static func intervalo(zona: Dictionary) -> float:
	return INTERVALO_BASE * PerigoDaZona.multiplicador_de_intervalo(zona)

## Quantos selvagens no máximo, ao mesmo tempo, nesta zona.
##
## Cai com o perigo — é a outra metade do "menos encontros". Sem isto, esticar só
## o intervalo produziria um acúmulo lento até a zona perigosa ficar tão povoada
## quanto a segura, e a intenção do Gabriel se perderia com o tempo de jogo.
static func populacao_maxima(zona: Dictionary) -> int:
	var p := PerigoDaZona.perigo(zona)
	return int(round(lerpf(float(POPULACAO_SEGURA), float(POPULACAO_EXTREMA), p)))

## Pode nascer alguém agora?
static func pode_nascer(zona: Dictionary, vivos: int, segundos_desde_o_ultimo: float) -> bool:
	if vivos >= populacao_maxima(zona):
		return false
	return segundos_desde_o_ultimo >= intervalo(zona)

# ──────────────────────────────────────────────────────────────────────────────
# O quê
# ──────────────────────────────────────────────────────────────────────────────

## Sorteia uma entrada da tabela da zona, com os pesos já corrigidos pelo perigo.
##
## `sorteio` 0→1 vem de fora — é o que deixa o teste forçar o primeiro e o último
## da tabela em vez de rodar mil vezes e torcer.
##
## Devolve `{}` quando a zona não tem tabela. **Zona sem `wild_pokemon` não é
## erro** (uma cidade não tem encontro), e não pode virar exceção nem bicho
## inventado.
static func sortear_especie(zona: Dictionary, sorteio: float) -> Dictionary:
	var tabela : Array = zona.get("wild_pokemon", [])
	if tabela.is_empty():
		return {}

	var total : float = 0.0
	for e in tabela:
		total += PerigoDaZona.peso_corrigido(float(e.get("weight", 1.0)), zona)
	if total <= 0.0:
		return {}

	var alvo : float = clampf(sorteio, 0.0, 0.999999) * total
	var acumulado : float = 0.0
	for e in tabela:
		acumulado += PerigoDaZona.peso_corrigido(float(e.get("weight", 1.0)), zona)
		if alvo < acumulado:
			return e
	return tabela[tabela.size() - 1]

## Este encontro é elite?
static func e_elite(zona: Dictionary, sorteio: float) -> bool:
	return sorteio < PerigoDaZona.chance_de_elite(zona)

## O nível do encontro — delega pra `PerigoDaZona`, que já decide como o elite
## empurra pro topo da faixa.
static func nivel(entrada: Dictionary, elite: bool, sorteio: float) -> int:
	return PerigoDaZona.nivel_do_encontro(entrada, elite, sorteio)

# ──────────────────────────────────────────────────────────────────────────────
# Onde
# ──────────────────────────────────────────────────────────────────────────────

## Um ponto no anel em volta do jogador, no plano. A altura quem resolve é o
## terreno — esta classe não sabe onde é o chão, e não deveria.
##
## `sorteio_angulo` e `sorteio_raio` 0→1, de fora.
static func ponto_no_anel(centro: Vector3, sorteio_angulo: float, sorteio_raio: float,
		raio_min: float = RAIO_MINIMO, raio_max: float = RAIO_MAXIMO) -> Vector3:
	var ang : float = clampf(sorteio_angulo, 0.0, 1.0) * TAU
	# Raiz quadrada no raio: sem ela, o sorteio uniforme concentra os pontos
	# perto do raio mínimo, porque a área de um anel cresce com o raio. É a
	# diferença entre "bicho sempre aparece a 12 m" e "aparece espalhado".
	var t : float = sqrt(clampf(sorteio_raio, 0.0, 1.0))
	var r : float = lerpf(raio_min, raio_max, t)
	return Vector3(centro.x + cos(ang) * r, centro.y, centro.z + sin(ang) * r)

## Este selvagem está longe o bastante pra desaparecer?
static func deve_desaparecer(distancia_ao_jogador: float,
		raio: float = RAIO_DE_DESPEJO) -> bool:
	return distancia_ao_jogador > raio

## O ponto nasceu longe o bastante? Usado como trava do executor — se o terreno
## ou um ajuste futuro empurrar o ponto pra perto, é aqui que se recusa.
static func distancia_segura(centro: Vector3, ponto: Vector3,
		raio_min: float = RAIO_MINIMO) -> bool:
	var d := Vector3(ponto.x - centro.x, 0.0, ponto.z - centro.z)
	return d.length() >= raio_min

# ──────────────────────────────────────────────────────────────────────────────
# Unidades
# ──────────────────────────────────────────────────────────────────────────────

## As distâncias de `ComportamentoSelvagem` estão em PIXELS (tiles × 128), porque
## a V2 era 2D. Em 3D, 1 tile = 1 metro.
##
## ⚠️ Esta conversão existe numa função só, com nome, pelo mesmo motivo da de
## `FormaDeArea3D`: um raio de aggro lido como 640 **metros** faria todo bicho do
## mapa perceber o jogador — e não daria erro nenhum.
static func pixels_para_metros(px: float) -> float:
	return px / PIXELS_POR_TILE

## Mergulho.gd — As regras de descer ao fundo do mar.
##
## Pedido do Gabriel (11/09/2026), palavras dele:
##
##   *"usando surf, terão áreas do oceano em que o player pode ir surfando e
##   quando chegar nessas áreas ele pode usar um comando (botão na tela ou
##   texto) para mergulhar, e quando mergulhar terá uma barra de oxigenio e
##   velocidade reduzida de movimentação, ali será um bioma 100% submarino com
##   algas, corais, profundidades diferentes e pokemons como tentacruel,
##   gyarados, kingler, poliwhrath, etc e um NPC irá entregar uma quest para
##   conseguir roupa de mergulho que devolve a velocidade do player e permite
##   respirar no fundo do mar"*
##
## ── A ideia de design, em uma frase ──────────────────────────────────────────
##
## Sem a roupa, o fundo do mar é **hostil e cronometrado**: você desce, olha,
## pega o que dá e sobe correndo. Com a roupa, ele vira **lugar**: você explora.
## A quest não desbloqueia a área — desbloqueia a *permanência* nela. É a
## diferença entre visitar e morar.
##
## ── Por que classe pura ──────────────────────────────────────────────────────
##
## Oxigênio, velocidade e profundidade são contas: dado entra, número sai.
## Ficam aqui pra poder ser provadas sem subir o jogo. Quem executa (descer,
## subir, desenhar a barra) é o `TrainerEntity` e a HUD.
class_name Mergulho
extends RefCounted

# ──────────────────────────────────────────────────────────────────────────────
# Oxigênio
# ──────────────────────────────────────────────────────────────────────────────

## Fôlego total, em segundos. 90 s é tempo pra atravessar um trecho e voltar,
## não pra explorar um mapa inteiro — a tensão é o ponto.
const OXIGENIO_MAXIMO : float = 90.0

## Quanto o fundo mais raso consome por segundo. A profundidade multiplica isso
## (ver `consumo_por_segundo`), então descer é uma decisão, não só um caminho.
const CONSUMO_BASE : float = 1.0

## Abaixo desta fração, o jogo avisa. É o aviso, não a punição.
const FRACAO_DE_ALERTA : float = 0.25

## Quando o ar acaba: o jogador é EXPULSO pra superfície e perde uma fração da
## vida do time. Não mata — afogar-se e perder o save seria punição desonesta
## num jogo que salva sozinho.
const DANO_AO_AFOGAR : float = 0.35

## Recuperar o fôlego na superfície é rápido: a punição foi ser expulso, e
## esperar barra encher não acrescenta nada.
const RECUPERACAO_POR_SEGUNDO : float = 12.0

# ──────────────────────────────────────────────────────────────────────────────
# Profundidade
# ──────────────────────────────────────────────────────────────────────────────

## As três faixas do fundo do mar. Mais fundo = mais ar gasto, fauna melhor.
## Os nomes casam com as faixas de bioma de `zones.json`.
const RASO    := "raso"
const MEIO    := "meio"
const ABISSO  := "abisso"

const PROFUNDIDADES : Dictionary = {
	RASO:   {"consumo": 1.0, "nome": "Recife raso"},
	MEIO:   {"consumo": 1.6, "nome": "Jardim de algas"},
	ABISSO: {"consumo": 2.4, "nome": "Abismo"},
}

# ──────────────────────────────────────────────────────────────────────────────
# A roupa
# ──────────────────────────────────────────────────────────────────────────────

## O item que a quest entrega. Com ele: fôlego infinito e velocidade normal.
const ROUPA : String = "roupa_de_mergulho"

## Quanto o mergulho custa de velocidade SEM a roupa. 1.8 = quase o dobro do
## tempo por passo — pesado o bastante pra doer, longe o bastante de travar.
const FATOR_LENTIDAO : float = 1.8

# ──────────────────────────────────────────────────────────────────────────────
# As contas
# ──────────────────────────────────────────────────────────────────────────────

## Quanto ar some por segundo nesta profundidade. Com a roupa, zero.
static func consumo_por_segundo(profundidade: String, tem_roupa: bool) -> float:
	if tem_roupa:
		return 0.0
	var f : Dictionary = PROFUNDIDADES.get(profundidade, PROFUNDIDADES[RASO])
	return CONSUMO_BASE * float(f["consumo"])

## Quanto tempo ainda dá pra ficar aqui embaixo, em segundos. -1 = pra sempre.
static func segundos_restantes(oxigenio: float, profundidade: String, tem_roupa: bool) -> float:
	var c := consumo_por_segundo(profundidade, tem_roupa)
	if c <= 0.0:
		return -1.0
	return oxigenio / c

## O multiplicador de duração do passo. Maior = mais lento.
static func fator_de_velocidade(tem_roupa: bool) -> float:
	return 1.0 if tem_roupa else FATOR_LENTIDAO

## O ar acabou?
static func afogou(oxigenio: float) -> bool:
	return oxigenio <= 0.0

## Já é hora de avisar?
static func em_alerta(oxigenio: float, tem_roupa: bool) -> bool:
	if tem_roupa:
		return false
	return oxigenio <= OXIGENIO_MAXIMO * FRACAO_DE_ALERTA

## O oxigênio depois de `delta` segundos aqui embaixo.
static func consumir(oxigenio: float, delta: float, profundidade: String,
		tem_roupa: bool) -> float:
	return maxf(0.0, oxigenio - consumo_por_segundo(profundidade, tem_roupa) * delta)

## O oxigênio depois de `delta` segundos na superfície.
static func recuperar(oxigenio: float, delta: float) -> float:
	return minf(OXIGENIO_MAXIMO, oxigenio + RECUPERACAO_POR_SEGUNDO * delta)

# ──────────────────────────────────────────────────────────────────────────────
# Onde se pode mergulhar
# ──────────────────────────────────────────────────────────────────────────────

## Os pontos de mergulho, por mapa. Cada um leva a um mapa submarino e a um
## tile de chegada — o mesmo contrato de qualquer warp do jogo.
##
## Mora em DADO aqui, e não espalhado em WarpZone nas cenas, por um motivo
## prático: mergulhar não é encostar num gatilho, é apertar um comando estando
## em cima do ponto. Um `WarpZone` levaria o jogador embora só de passar
## surfando por cima, que é exatamente o que não se quer.
const PONTOS : Dictionary = {
	"world_map": [
		{"tile": Vector2i(248, 196), "destino": "res://scenes/world/maps/FundoDoMar.tscn",
		 "chegada": Vector2i(60, 8), "nome": "Mar de Vermilion"},
		{"tile": Vector2i(250, 228), "destino": "res://scenes/world/maps/FundoDoMar.tscn",
		 "chegada": Vector2i(60, 8), "nome": "Arquipélago Tropical"},
		{"tile": Vector2i(248, 268), "destino": "res://scenes/world/maps/FundoDoMar.tscn",
		 "chegada": Vector2i(60, 8), "nome": "Ilhas Seafoam"},
	],
}

## O ponto de mergulho em que o jogador está, ou {} se não há nenhum.
##
## `raio` existe porque exigir o tile exato faria o jogador ficar tateando a
## água atrás de um pixel. Dois tiles de tolerância é generoso sem virar
## "mergulha em qualquer lugar".
static func ponto_em(map_id: String, tile: Vector2i, raio: int = 2) -> Dictionary:
	for p in PONTOS.get(map_id, []):
		var d : Vector2i = p["tile"] - tile
		if absi(d.x) <= raio and absi(d.y) <= raio:
			return p
	return {}

## Dá pra mergulhar agora? Devolve {"pode", "motivo", "ponto"} — o `motivo` é
## texto pro jogador, porque "não deu" sem dizer por quê é o pior retorno
## possível.
static func pode_mergulhar(map_id: String, tile: Vector2i, esta_surfando: bool) -> Dictionary:
	if not esta_surfando:
		return {"pode": false, "motivo": "Você precisa estar surfando para mergulhar.", "ponto": {}}
	var p : Dictionary = ponto_em(map_id, tile)
	if p.is_empty():
		return {"pode": false, "motivo": "A água aqui é rasa demais. Procure o mar aberto.", "ponto": {}}
	return {"pode": true, "motivo": "", "ponto": p}

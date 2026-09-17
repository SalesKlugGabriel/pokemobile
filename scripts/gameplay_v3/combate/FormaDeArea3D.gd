## FormaDeArea3D.gd — A geometria de quem um golpe acerta, em 3D (Fase 10, §21/§22).
##
## É a `FormaDeArea` da V2 com um eixo a mais, e **continua classe pura**: quem
## está dentro da forma é conta de vetor, e conta que mora fora do nó se prova
## sem subir o jogo. Quem varre o mundo pra achar candidatos é a entidade; aqui
## só se decide, de cada candidato, se ele está dentro.
##
## ── As 4 formas, e por que essas 4 ──────────────────────────────────────────
##
## `moves.json` só usa quatro: **single** (165 golpes), **circle** (25),
## **cone** (1) e **line** (1). Não é preciso inventar forma nenhuma pra cobrir
## o bestiário inteiro — o dado já diz qual é o vocabulário real.
##
## ── 🔴 A conversão de unidade, que é onde isto quebraria em silêncio ────────
##
## O dado da V2 mistura duas unidades no mesmo golpe:
##
## ```
## "range":  3.0     ← TILES        (gust)
## "radius": 384.0   ← PIXELS       (gust, = 3 tiles × 128)
## ```
##
## Em 3D a unidade é o metro, e **1 tile = 1 metro** (decorre da régua do
## mapa-múndi: 1 km = 1.000 tiles). Então `range` passa direto e `radius`
## precisa ser dividido por 128.
##
## Ler `radius: 384` como 384 metros daria um golpe que acerta o mapa inteiro —
## e não daria erro nenhum. É exatamente a classe de bug que este projeto
## encontrou seis vezes, então a conversão fica numa função só, com nome, e
## testada.
class_name FormaDeArea3D
extends RefCounted

const SINGLE : String = "single"
const CIRCLE : String = "circle"
const CONE   : String = "cone"
const LINE   : String = "line"

## Abertura TOTAL do cone, em graus — o mesmo número da V2, pra um Gust não
## mudar de área ao atravessar o pivô.
const ANGULO_DO_CONE_GRAUS : float = 70.0

## Largura de uma linha quando o golpe não declara `largura`. 2 m: larga o
## bastante pra pegar quem está ao lado de quem foi mirado, sem virar um círculo
## disfarçado.
const LARGURA_PADRAO_M : float = 2.0

## Quantos alvos, quando o golpe não diz.
const MAX_ALVOS_PADRAO : int = 6

## Um tile da V2 em pixels. Existe aqui só pra converter o dado legado.
const PIXELS_POR_TILE : float = 128.0

# ──────────────────────────────────────────────────────────────────────────────
# Unidades
# ──────────────────────────────────────────────────────────────────────────────

## O alcance do golpe em METROS.
##
## `range` no dado está em tiles, e 1 tile = 1 m. Passa direto — mas passa por
## aqui, e não espalhado pelo código, pra o dia em que a régua do mapa mudar ser
## uma linha e não uma caçada.
static func alcance_em_metros(golpe: Dictionary, padrao: float = 1.5) -> float:
	var r : float = float(golpe.get("range", padrao))
	return r if r > 0.0 else padrao

## O raio da área em METROS.
##
## `radius` no dado está em PIXELS (384 = 3 tiles × 128). Quando o golpe não
## declara raio, cai no alcance — um `circle` sem raio é um círculo do tamanho
## do próprio alcance, que é o que a V2 já fazia.
static func raio_em_metros(golpe: Dictionary, padrao: float = 1.5) -> float:
	var px : float = float(golpe.get("radius", 0.0))
	if px > 0.0:
		return px / PIXELS_POR_TILE
	return alcance_em_metros(golpe, padrao)

## A largura de uma linha, em METROS. `largura` também vem em pixels na V2.
static func largura_em_metros(golpe: Dictionary) -> float:
	var px : float = float(golpe.get("largura", 0.0))
	if px > 0.0:
		return px / PIXELS_POR_TILE
	return LARGURA_PADRAO_M

static func max_alvos(golpe: Dictionary) -> int:
	var n : int = int(golpe.get("max_targets", MAX_ALVOS_PADRAO))
	return maxi(1, n)

# ──────────────────────────────────────────────────────────────────────────────
# As formas
# ──────────────────────────────────────────────────────────────────────────────

## Este ponto está dentro da forma do golpe?
##
## `origem`   de onde o golpe sai
## `direcao`  pra onde aponta — só importa em `cone` e `line`
## `ponto`    a posição do candidato
## `raio_do_alvo`  o corpo dele; um bicho grande é alcançado antes
##
## **Tudo no plano horizontal.** Incluir altura faria um golpe errar um Diglett
## aos pés e um Onix acima da cabeça — e nenhum dos dois é o que o jogador vê.
## Altura entra no combate pela mira da câmera (§22), não pela forma da área.
static func dentro(golpe: Dictionary, origem: Vector3, direcao: Vector3,
		ponto: Vector3, raio_do_alvo: float = 0.0) -> bool:
	var forma : String = str(golpe.get("area_type", SINGLE))
	var delta := Vector3(ponto.x - origem.x, 0.0, ponto.z - origem.z)
	var dist : float = delta.length()
	var folga : float = maxf(0.0, raio_do_alvo)

	match forma:
		CIRCLE:
			return dist <= raio_em_metros(golpe) + folga
		CONE:
			if dist > raio_em_metros(golpe) + folga:
				return false
			return _no_arco(direcao, delta, deg_to_rad(ANGULO_DO_CONE_GRAUS) * 0.5)
		LINE:
			return _no_corredor(direcao, delta, alcance_em_metros(golpe) + folga,
				largura_em_metros(golpe) * 0.5 + folga)
		_:
			# `single` e qualquer forma que o dado invente: alcance + arco à
			# frente. Forma desconhecida NÃO cai num círculo silencioso — cai no
			# caso mais restrito, que é o que erra menos se o dado estiver errado.
			if dist > alcance_em_metros(golpe) + folga:
				return false
			return _no_arco(direcao, delta, deg_to_rad(ANGULO_DO_CONE_GRAUS) * 0.5)

## Quais, dos candidatos, o golpe acerta — já do mais perto pro mais longe e já
## limitados por `max_targets`.
##
## `candidatos` é uma lista de `{ "quem": Node, "posicao": Vector3, "raio": float }`.
## A entidade monta isso a partir do que a física achou; esta função não toca o
## mundo, e é por isso que ela é testável sem cena.
static func alvos(golpe: Dictionary, origem: Vector3, direcao: Vector3,
		candidatos: Array) -> Array:
	var dentro_da_forma : Array = []
	for c in candidatos:
		var pos : Vector3 = c.get("posicao", Vector3.ZERO)
		var raio : float = float(c.get("raio", 0.0))
		if dentro(golpe, origem, direcao, pos, raio):
			dentro_da_forma.append({
				"quem": c.get("quem"),
				"distancia": Vector3(pos.x - origem.x, 0.0, pos.z - origem.z).length(),
			})

	dentro_da_forma.sort_custom(func(a, b): return float(a["distancia"]) < float(b["distancia"]))

	var teto : int = max_alvos(golpe)
	var saida : Array = []
	var vistos : Array = []
	for d in dentro_da_forma:
		# Nunca o mesmo alvo duas vezes no mesmo cast — a mesma exigência que a
		# V2 já tinha, e o jeito de um golpe em área dobrar dano sem ninguém ver.
		if d["quem"] in vistos:
			continue
		vistos.append(d["quem"])
		saida.append(d["quem"])
		if saida.size() >= teto:
			break
	return saida

# ──────────────────────────────────────────────────────────────────────────────

static func _no_arco(direcao: Vector3, delta: Vector3, meio_angulo: float) -> bool:
	var d := Vector3(direcao.x, 0.0, direcao.z)
	if d.length_squared() <= 0.0 or delta.length_squared() <= 0.0:
		return false
	return d.normalized().angle_to(delta.normalized()) <= meio_angulo

## Corredor: até `comprimento` pra frente e até `meia_largura` pros lados.
## Atrás não conta — uma linha que pega quem está às costas é um retângulo
## centrado, e não é o que "line" quer dizer.
static func _no_corredor(direcao: Vector3, delta: Vector3,
		comprimento: float, meia_largura: float) -> bool:
	var d := Vector3(direcao.x, 0.0, direcao.z)
	if d.length_squared() <= 0.0:
		return false
	d = d.normalized()
	var ao_longo : float = delta.dot(d)
	if ao_longo < 0.0 or ao_longo > comprimento:
		return false
	var lateral : float = (delta - d * ao_longo).length()
	return lateral <= meia_largura

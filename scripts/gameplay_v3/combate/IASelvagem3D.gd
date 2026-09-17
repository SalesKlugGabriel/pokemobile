## IASelvagem3D.gd — A decisão de um selvagem, quadro a quadro (Fase 11).
##
## Classe pura, e é **adaptador, não reimplementação**: as sete personalidades,
## os raios, a coleira e a regra de fuga vivem em `ComportamentoSelvagem`, que
## atravessou o pivô sem uma linha alterada. O que esta classe faz é duas coisas
## que a V2 não precisava:
##
##   1. **converter pixel em metro** (as distâncias de lá são tiles × 128);
##   2. **juntar as perguntas numa decisão só**, porque em 3D o executor é um
##      `CharacterBody3D` que precisa de uma resposta por quadro, não de cinco
##      consultas soltas.
##
## ⚠️ **Não copiar regra pra cá.** Se uma personalidade mudar de comportamento,
## muda em `ComportamentoSelvagem` e as duas versões do jogo acompanham juntas.
## Uma segunda implementação é como a V2 e a V3 passam a discordar sobre o que
## "territorial" quer dizer.
class_name IASelvagem3D
extends RefCounted

## Os estados que o executor sabe executar. Palavra, não número: um log que diz
## `perseguir` é legível; um que diz `2` precisa de tabela.
const PARADO     := "parado"      ## não viu ninguém, ou é passivo
const PERSEGUIR  := "perseguir"   ## viu, e vai pra cima
const ATACAR     := "atacar"      ## está no alcance de bater
const VOLTAR     := "voltar"      ## estourou a coleira, volta pra casa
const FUGIR      := "fugir"       ## corre na direção oposta

# ──────────────────────────────────────────────────────────────────────────────
# Unidades — a conversão vive aqui, e só aqui
# ──────────────────────────────────────────────────────────────────────────────

static func raio_de_aggro_m(personalidade: String) -> float:
	return RegraDeSpawn.pixels_para_metros(ComportamentoSelvagem.raio_de_aggro(personalidade))

static func raio_de_coleira_m(personalidade: String) -> float:
	return RegraDeSpawn.pixels_para_metros(ComportamentoSelvagem.raio_de_coleira(personalidade))

static func raio_do_bando_m() -> float:
	return RegraDeSpawn.pixels_para_metros(
		CombatBalance.PACK_RADIUS_TILES * RegraDeSpawn.PIXELS_POR_TILE)

# ──────────────────────────────────────────────────────────────────────────────
# A decisão
# ──────────────────────────────────────────────────────────────────────────────

## O que este selvagem faz agora.
##
## `personalidade`   uma das sete de `ComportamentoSelvagem`
## `dist_ao_alvo`    metros até o jogador (ou quem estiver hostil)
## `dist_de_casa`    metros até o ponto onde ele nasceu
## `fracao_de_vida`  0→1
## `ja_provocado`    já apanhou, ou já ouviu o grito do bando
## `alcance_de_bater` metros — vem do `CombatProfile` do próprio bicho
##
## ── A ordem das perguntas é a regra ─────────────────────────────────────────
##
## Fugir vem **antes** de tudo: um bicho com 10% de vida não deve escolher entre
## perseguir e voltar pra casa, deve correr. Depois a coleira, depois o aggro.
## Inverter isso produz o bug clássico — o bicho quase morto que continua
## perseguindo porque a checagem de aggro respondeu primeiro.
static func decidir(personalidade: String, dist_ao_alvo: float, dist_de_casa: float,
		fracao_de_vida: float, ja_provocado: bool,
		alcance_de_bater: float) -> String:
	var p := ComportamentoSelvagem.normalizar(personalidade)

	# 1. Fugir ganha de tudo.
	if ComportamentoSelvagem.deve_fugir(p, fracao_de_vida):
		# Passivo que nunca foi provocado não está fugindo de nada — está só
		# vivendo. Sem este caso, um mapa de Pokémon passivos seria um mapa de
		# bichos correndo à toa.
		if p == ComportamentoSelvagem.PASSIVO and not ja_provocado:
			return PARADO
		return FUGIR

	# 2. A coleira. Vale mesmo provocado: é o que impede a perseguição pelo mapa
	#    inteiro, que era o defeito que a §26 mandou corrigir.
	if dist_de_casa > raio_de_coleira_m(p):
		return VOLTAR

	# 3. Percebeu o alvo?
	var viu : bool = dist_ao_alvo <= raio_de_aggro_m(p)
	var hostil : bool = ja_provocado or (viu and ComportamentoSelvagem.comeca_briga(p))
	if not hostil:
		return PARADO

	# 4. Perto o bastante pra bater?
	if dist_ao_alvo <= alcance_de_bater:
		return ATACAR
	return PERSEGUIR

## Pra onde andar, dado o estado. Devolve direção normalizada no plano, ou zero.
##
## Separado de `decidir` de propósito: decidir é regra, andar é geometria, e é a
## geometria que muda entre 2D e 3D.
static func direcao(estado: String, minha_pos: Vector3, pos_do_alvo: Vector3,
		minha_casa: Vector3) -> Vector3:
	var plano := func(a: Vector3, b: Vector3) -> Vector3:
		var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
		return d.normalized() if d.length_squared() > 0.0001 else Vector3.ZERO

	match estado:
		PERSEGUIR: return plano.call(minha_pos, pos_do_alvo)
		VOLTAR:    return plano.call(minha_pos, minha_casa)
		FUGIR:     return -plano.call(minha_pos, pos_do_alvo)
		_:         return Vector3.ZERO

## Quem ouve o grito de quem entrou em briga, em 3D.
##
## Mesmas quatro travas da V2 (§25/§27), e elas continuam valendo palavra por
## palavra: só a MESMA espécie responde; só quem está dentro do raio do bando;
## no máximo `MAX_PACK_SIZE`, os mais próximos primeiro; e **quem foi chamado não
## grita de novo** — sem isso, A chama B, B chama C, e em segundos o mapa inteiro
## está em cima do jogador.
##
## `candidatos` é `[{ "quem": Node, "posicao": Vector3, "especie": int }]`.
static func quem_ouve_o_grito(pos_de_quem_gritou: Vector3, especie: int,
		candidatos: Array) -> Array:
	var raio := raio_do_bando_m()
	var perto : Array = []
	for c in candidatos:
		if int(c.get("especie", -1)) != especie:
			continue
		var pos : Vector3 = c.get("posicao", Vector3.ZERO)
		var d : float = Vector3(pos.x - pos_de_quem_gritou.x, 0.0,
								pos.z - pos_de_quem_gritou.z).length()
		if d > raio:
			continue
		perto.append({"quem": c.get("quem"), "d": d})

	perto.sort_custom(func(a, b): return float(a["d"]) < float(b["d"]))
	var saida : Array = []
	for item in perto:
		if saida.size() >= CombatBalance.MAX_PACK_SIZE:
			break
		saida.append(item["quem"])
	return saida

## Esta personalidade chama o bando? Delega — a lista de quem chama é da V2.
static func chama_o_bando(personalidade: String) -> bool:
	return ComportamentoSelvagem.chama_o_bando(
		ComportamentoSelvagem.normalizar(personalidade))

## ComportamentoSelvagem.gd — As personalidades do Pokémon selvagem.
##
## Itens 24 a 27 do pedido do Gabriel. Antes de 11/09/2026 existiam TRÊS
## comportamentos (`aggressive` / `neutral` / `flee`) contra os sete que ele
## pediu, e nenhum deles tinha bando, propagação de aggro nem coleira de
## perseguição — um selvagem que entrava em CHASE perseguia até o outro lado
## do mapa, porque a coleira só agia na patrulha.
##
## Aqui moram as REGRAS (decidir), não a execução (mover, bater). Quem executa
## continua sendo o `WildPokemon` — este arquivo só responde perguntas como
## "devo atacar este alvo?", "é hora de fugir?", "esse grito chega até mim?".
##
## Por que separado: o `WildPokemon` tem 44 KB e depende de meia dúzia de
## autoloads, então nada dentro dele é testável headless. Uma regra de IA que
## não dá pra testar vira uma regra que ninguém confere.
class_name ComportamentoSelvagem
extends RefCounted

# ──────────────────────────────────────────────────────────────────────────────
# As sete personalidades
# ──────────────────────────────────────────────────────────────────────────────

const PASSIVO     := "passive"      ## nunca começa briga; foge se apanhar
const AGRESSIVO   := "aggressive"   ## vê o jogador no raio e parte pra cima
const DEFENSIVO   := "defensive"    ## só reage se você chegar MUITO perto
const TERRITORIAL := "territorial"  ## defende a área dele, e volta pra ela
const BANDO       := "pack"         ## chama os vizinhos da mesma espécie
const PREDADOR    := "predator"     ## agressivo, e persegue mais longe
const FUGITIVO    := "fleeing"      ## corre desde o começo

const TODAS : Array[String] = [PASSIVO, AGRESSIVO, DEFENSIVO, TERRITORIAL, BANDO, PREDADOR, FUGITIVO]

## Como os três rótulos ANTIGOS viram os novos. `species.json` tem 151 espécies
## marcadas com os antigos e os dois lados precisam conviver — traduzir na
## leitura é mais seguro que reescrever 151 linhas de dado e torcer.
const DE_PARA_ANTIGO : Dictionary = {
	"aggressive": AGRESSIVO,
	"neutral":    DEFENSIVO,   ## "só ataca se atacado" é exatamente DEFENSIVO
	"flee":       FUGITIVO,
	"passive":    PASSIVO,
}

## Normaliza o que vier do dado. Rótulo desconhecido cai em DEFENSIVO — o mais
## inofensivo dos que ainda reagem, então um erro de digitação no JSON nunca
## vira um bicho que persegue o jogador pelo mapa inteiro.
static func normalizar(rotulo: String) -> String:
	var r := rotulo.to_lower().strip_edges()
	if r in TODAS:
		return r
	return str(DE_PARA_ANTIGO.get(r, DEFENSIVO))

# ──────────────────────────────────────────────────────────────────────────────
# Detecção
# ──────────────────────────────────────────────────────────────────────────────

## A que distância (em pixels) esta personalidade percebe o jogador.
##
## DEFENSIVO tem raio curto de propósito: ele não caça, só não gosta que
## encostem nele. PREDADOR tem o dobro do normal — é o que faz o jogador
## sentir que entrou no território errado.
static func raio_de_aggro(personalidade: String) -> float:
	var base : float = CombatBalance.AGGRO_RADIUS_TILES * CombatBalance.TILE_PX
	match personalidade:
		PASSIVO:     return 0.0           ## não persegue nunca
		FUGITIVO:    return base * 1.2    ## percebe cedo — pra fugir a tempo
		DEFENSIVO:   return base * 0.45   ## só quando encosta
		TERRITORIAL: return base * 0.8
		PREDADOR:    return base * 2.0
		BANDO:       return base
		_:           return base

## Começa a briga sozinho? (sem ter apanhado antes)
static func comeca_briga(personalidade: String) -> bool:
	return personalidade in [AGRESSIVO, TERRITORIAL, BANDO, PREDADOR, DEFENSIVO]

## Corre em vez de brigar?
static func foge_sempre(personalidade: String) -> bool:
	return personalidade == FUGITIVO

## Até onde persegue antes de desistir e voltar pra casa (item 26).
##
## O PREDADOR persegue mais longe, o TERRITORIAL bem menos (a graça dele é
## defender um lugar, não caçar). Nenhum é infinito — era esse o defeito.
static func raio_de_coleira(personalidade: String) -> float:
	var base : float = CombatBalance.LEASH_RADIUS_TILES * CombatBalance.TILE_PX
	match personalidade:
		TERRITORIAL: return base * 0.6
		PREDADOR:    return base * 1.6
		_:           return base

## Já é hora de fugir? Vale pro FUGITIVO desde o começo e pra qualquer um que
## esteja muito machucado — bicho nenhum luta até a última gota.
static func deve_fugir(personalidade: String, fracao_de_vida: float) -> bool:
	if personalidade == FUGITIVO:
		return true
	if personalidade == PASSIVO:
		return true
	return fracao_de_vida <= CombatBalance.FRACAO_HP_PRA_FUGIR

# ──────────────────────────────────────────────────────────────────────────────
# Bando e propagação de aggro (itens 25 e 27)
# ──────────────────────────────────────────────────────────────────────────────

## Quem responde ao grito de um bicho que acabou de entrar em briga.
##
## Três travas, as três de propósito:
##   1. só a MESMA espécie responde — um Beedrill não convoca Rattatas;
##   2. só quem estiver dentro do PACK_RADIUS ouve;
##   3. no máximo MAX_PACK_SIZE respondem, os mais próximos primeiro.
##
## E o `saltos` é a quarta: quem foi chamado NÃO grita de novo
## (`AGGRO_CHAIN_MAX_HOPS = 1`). Sem isso, A chama B, B chama C, e em poucos
## segundos o mapa inteiro está em cima do jogador — a "aggro chain" que o
## item 27 manda evitar.
static func quem_ouve_o_grito(gritou: Node2D, candidatos: Array, especie: int,
		saltos_ja_dados: int = 0) -> Array:
	if saltos_ja_dados >= CombatBalance.AGGRO_CHAIN_MAX_HOPS:
		return []
	if gritou == null or not is_instance_valid(gritou):
		return []

	var raio : float = CombatBalance.PACK_RADIUS_TILES * CombatBalance.TILE_PX
	var origem : Vector2 = gritou.global_position
	var ouviram : Array = []
	for no in candidatos:
		if no == gritou or not is_instance_valid(no):
			continue
		if not (no is Node2D):
			continue
		# `get` devolve null em nó que não tem a propriedade — sem esta guarda,
		# um nó qualquer que caia no grupo derruba a busca inteira.
		var sid = no.get("species_id")
		if sid == null or int(sid) != especie:
			continue
		if origem.distance_to(no.global_position) > raio:
			continue
		ouviram.append(no)

	ouviram.sort_custom(func(a, b):
		return origem.distance_squared_to(a.global_position) < origem.distance_squared_to(b.global_position))
	return ouviram.slice(0, CombatBalance.MAX_PACK_SIZE)

## Esta personalidade chama os outros quando entra em briga?
static func chama_o_bando(personalidade: String) -> bool:
	return personalidade == BANDO

# ──────────────────────────────────────────────────────────────────────────────
# Escolha de golpe (item 29: previsível e barata, não uma IA esperta)
# ──────────────────────────────────────────────────────────────────────────────

## Qual dos golpes usar agora.
##
## A regra é deliberadamente simples e LEGÍVEL pelo jogador — o item 29 pede
## "previsibilidade e performance", não esperteza: entre os golpes prontos
## (fora de recarga) e que alcançam o alvo, usa o de maior potência. Se nenhum
## alcança, devolve -1 e quem chamou aproxima.
##
## Ler a briga fica possível: se o bicho está longe, você sabe que vem o golpe
## de longe; se ele encostou, vem o forte de perto.
static func escolher_golpe(golpes: Array, recargas: Array, distancia: float) -> int:
	var melhor : int = -1
	var melhor_power : int = -1
	for i in golpes.size():
		var dados : Dictionary = golpes[i]
		if dados.is_empty():
			continue
		if i < recargas.size() and float(recargas[i]) > 0.0:
			continue
		var alcance : float = FormaDeArea.alcance_px(dados)
		if distancia > alcance:
			continue
		var power : int = int(dados.get("power", 0))
		if power > melhor_power:
			melhor_power = power
			melhor = i
	return melhor

## O alcance do golpe MAIS LONGO que este bicho tem — é a distância em que ele
## para de correr e começa a atacar. Antes isso era uma constante
## (`WILD_ATTACK_RADIUS = 384`) igual pra todo mundo: um Onix de golpe corpo a
## corpo e um Alakazam de feixe paravam à mesma distância.
static func alcance_util(golpes: Array) -> float:
	var maior : float = 0.0
	for dados in golpes:
		if dados.is_empty():
			continue
		maior = maxf(maior, FormaDeArea.alcance_px(dados))
	if maior <= 0.0:
		return CombatBalance.ALCANCE_PADRAO_TILES * CombatBalance.TILE_PX
	return maior

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

## Qual golpe usar agora — por PONTUAÇÃO, não por "o mais forte que couber".
##
## 🔴 Fase 2: a primeira versão escolhia o golpe de maior `power` entre os
## prontos e no alcance. Dava dois comportamentos bobos: gastava a ultimate num
## alvo quase morto, e insistia num golpe forte mas ineficaz (Normal contra
## Fantasma = 0) enquanto tinha um fraco e super eficaz na mão.
##
## A conta agora é a do item 11:
##
##   nota = power × efetividade × adequação-de-alcance × potencial-de-alvos
##          × valor-tático × fator-aleatório
##
## Continua barata (uma passada por até 4 golpes) e PREVISÍVEL: o jogador
## consegue aprender que bicho encurralado usa área, que bicho longe usa o
## golpe de longe, e que ninguém desperdiça a ultimate num alvo com 5 de vida.
##
## `contexto` traz o que a conta precisa saber do mundo: tipos do alvo, fração
## de vida do alvo e a minha, e quantos alvos estão agrupados.
static func escolher_golpe(golpes: Array, recargas: Array, distancia: float,
		contexto: Dictionary = {}) -> int:
	var melhor : int = -1
	var melhor_nota : float = 0.0
	for i in golpes.size():
		var dados : Dictionary = golpes[i]
		if dados.is_empty():
			continue
		if i < recargas.size() and float(recargas[i]) > 0.0:
			continue
		if distancia > FormaDeArea.alcance_px(dados):
			continue
		var nota : float = nota_do_golpe(dados, distancia, contexto)
		if nota > melhor_nota:
			melhor_nota = nota
			melhor = i
	return melhor

## A nota de um golpe. Separada pra poder ser conferida sozinha num teste —
## "por que ele escolheu esse?" tem que ter resposta.
static func nota_do_golpe(golpe: Dictionary, distancia: float, contexto: Dictionary = {}) -> float:
	var power : float = maxf(float(golpe.get("power", 0)), 1.0)

	# 1. Efetividade contra o tipo do alvo. Imune zera a nota — nunca escolher
	#    um golpe que não vai fazer nada.
	var tipos_do_alvo : Array = contexto.get("tipos_do_alvo", [])
	var efetividade : float = 1.0
	if not tipos_do_alvo.is_empty():
		efetividade = DamageCalculator.get_type_multiplier(
			str(golpe.get("type", "Normal")), tipos_do_alvo)
	if efetividade <= 0.0:
		return 0.0

	# 2. Adequação do alcance: vale mais o golpe feito pra ESTA distância.
	#    Usar um golpe de 6 tiles com o alvo colado desperdiça alcance; usar um
	#    de 1,5 tile no limite dele é arriscado (o alvo sai andando).
	var alcance : float = maxf(FormaDeArea.alcance_px(golpe), 1.0)
	var folga : float = clampf(distancia / alcance, 0.0, 1.0)
	var adequacao : float = 1.0 - absf(folga - 0.6) * 0.5   # ótimo a ~60% do alcance

	# 3. Potencial de alvos: área só vale mais quando há mais de um alvo perto.
	var agrupados : int = int(contexto.get("alvos_agrupados", 1))
	var potencial : float = 1.0
	if str(golpe.get("area_type", "single")) != "single":
		potencial = 1.0 + 0.35 * float(mini(agrupados, int(golpe.get("max_targets", 1))) - 1)

	# 4. Valor tático: não desperdiçar golpe caro em alvo quase morto, e dar
	#    preferência a golpe rápido quando eu mesmo estou mal (preciso acertar
	#    algo AGORA, não conjurar por um segundo).
	var vida_do_alvo : float = float(contexto.get("fracao_vida_alvo", 1.0))
	var minha_vida : float = float(contexto.get("minha_fracao_vida", 1.0))
	var tatico : float = 1.0
	var caro : bool = power >= 100.0 or float(golpe.get("cooldown", 0.0)) >= 6.0
	if caro and vida_do_alvo < 0.25:
		tatico *= 0.35                      # o alvo já está caindo, guarde
	if minha_vida < 0.35 and float(golpe.get("cast_time", 0.0)) >= 0.8:
		tatico *= 0.5                       # conjuração longa é luxo de quem está bem
	if float(golpe.get("status_chance", 0.0)) > 0.0 and vida_do_alvo > 0.6:
		tatico *= 1.15                      # status rende mais cedo na briga

	# 5. Um empurrãozinho aleatório pra não ser um robô 100% previsível — o
	#    suficiente pra variar entre dois golpes parecidos, nunca pra escolher
	#    o pior de dois muito diferentes.
	var sorte : float = RNGManager.randf_range(0.92, 1.08)

	return power * efetividade * adequacao * potencial * tatico * sorte

# ──────────────────────────────────────────────────────────────────────────────
# Prioridade de alvo (item 12)
# ──────────────────────────────────────────────────────────────────────────────

## Qual alvo perseguir, entre os candidatos.
##
## 🔴 Fase 2: antes era literalmente "o primeiro Follower vivo que eu achar na
## lista" — a ordem da árvore de cena decidia a briga. Agora cada candidato
## recebe uma nota e o maior ganha.
##
## `dados` por candidato: {"no": Node2D, "distancia": float,
##   "me_atacou": bool, "fracao_vida": float, "e_treinador": bool}
static func escolher_alvo(candidatos: Array, personalidade: String,
		minha_posicao: Vector2, meu_lar: Vector2) -> Node2D:
	var melhor : Node2D = null
	var melhor_nota : float = -1.0
	for c in candidatos:
		var no : Node2D = c.get("no")
		if no == null or not is_instance_valid(no):
			continue
		var nota : float = nota_do_alvo(c, personalidade, minha_posicao, meu_lar)
		if nota > melhor_nota:
			melhor_nota = nota
			melhor = no
	return melhor

## A nota de um alvo. Quanto maior, mais ele me interessa.
static func nota_do_alvo(dados: Dictionary, personalidade: String,
		minha_posicao: Vector2, meu_lar: Vector2) -> float:
	var nota : float = 100.0

	# 1. Distância: perto vale mais, sempre. Cai suave, não em degrau, pra não
	#    ficar trocando de alvo a cada passo do jogador.
	var dist_tiles : float = float(dados.get("distancia", 9999.0)) / CombatBalance.TILE_PX
	nota /= (1.0 + dist_tiles * 0.35)

	# 2. Quem me bateu vira prioridade — é a regra mais importante pro combate
	#    "fazer sentido" (o item 12 cita exatamente este caso).
	if bool(dados.get("me_atacou", false)):
		nota *= 3.0

	# 3. Alvo machucado atrai: é o instinto do predador, e faz o jogador ter que
	#    proteger o Pokémon ferido em vez de só empurrar o mais forte pra frente.
	var vida : float = clampf(float(dados.get("fracao_vida", 1.0)), 0.05, 1.0)
	if personalidade == PREDADOR:
		nota *= 1.0 + (1.0 - vida) * 1.2
	else:
		nota *= 1.0 + (1.0 - vida) * 0.4

	# 4. Territorial persegue quem INVADIU, não quem está longe do ninho.
	if personalidade == TERRITORIAL and meu_lar != Vector2.ZERO:
		var no : Node2D = dados.get("no")
		if no != null and is_instance_valid(no):
			var invasao : float = meu_lar.distance_to(no.global_position) / CombatBalance.TILE_PX
			nota *= clampf(2.0 - invasao * 0.15, 0.3, 2.0)

	# 5. O Pokémon do jogador vem antes do treinador — é ele que está na frente
	#    pra brigar. Bater no treinador direto, com o Pokémon vivo ao lado, lê
	#    como bug mesmo quando a conta permite.
	if bool(dados.get("e_treinador", false)):
		nota *= 0.45

	return nota

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

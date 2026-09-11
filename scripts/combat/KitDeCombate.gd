## KitDeCombate.gd — Quantos golpes um Pokémon carrega, e quais.
##
## Nasce de um pedido do Gabriel na Fase 2, que é a melhor ideia de design que
## apareceu nesta reengenharia:
##
##   *"conforme o pokemon vai subindo de nível ele poderia ter mais skills...
##   um charmander lvl 100 em vez de 4 skills > 6 skills, um charmeleon 7, um
##   charizard 8... para que não seja possível derrotar um moltres lvl 5 com um
##   magikarp lvl 100 que só tem surf"*
##
## O problema que isso resolve é real e não era coberto por nada: com slots
## fixos em 4, evoluir só mexia em NÚMERO (stats sobem). Um Magikarp Lv100
## tinha exatamente a mesma capacidade de ação que um Gyarados Lv100 — a mesma
## quantidade de botões, as mesmas decisões possíveis. Evoluir não mudava COMO
## se joga, e é o "como se joga" que faz um lendário ser difícil.
##
## A conta:
##
##     slots = 4 (base) + estágio evolutivo (0-2) + bônus de nível (0-2)
##
## O que dá exatamente a escada que ele descreveu:
##
##     Charmander Lv.100   4 + 0 + 2 = 6
##     Charmeleon Lv.100   4 + 1 + 2 = 7
##     Charizard  Lv.100   4 + 2 + 2 = 8
##
## E, de quebra, resolve o caso do Magikarp sem nenhuma regra especial: ele é
## estágio 0 e o learnset dele tem 3 golpes no total, então os 6 slots dele
## nunca enchem. Gyarados é estágio 1, ganha 7 slots E tem learnset pra
## preencher. A diferença de poder vira diferença de REPERTÓRIO, não só de
## número — que era o pedido.
##
## Classe pura: a conta precisa ser testável sem subir o jogo.
class_name KitDeCombate
extends RefCounted

## Quantos slots um Pokémon tem no melhor caso.
const SLOTS_BASE : int = 4
const SLOTS_MAXIMO : int = 8

## Em que níveis o Pokémon ganha um slot extra. Dois degraus: um no meio da
## jornada, outro perto do teto.
const NIVEIS_DE_SLOT_EXTRA : Array[int] = [40, 80]

## Teto de golpes de um selvagem comum (item 14: "não transformar todo Pokémon
## selvagem em um mini-player completo").
const SLOTS_SELVAGEM_COMUM : int = 3
const SLOTS_SELVAGEM_ALPHA : int = 4

## As faixas do item 13 — quantos golpes OFENSIVOS o Pokémon do jogador deveria
## ter em cada fase do jogo. Não é trava: é o alvo que o preenchimento
## persegue, pra um Pokémon de nível 5 não abrir o jogo com 4 botões.
const FAIXAS_OFENSIVAS : Array[Dictionary] = [
	{"ate_nivel": 14,  "min": 1, "max": 2},   ## iniciante
	{"ate_nivel": 39,  "min": 2, "max": 3},   ## intermediário
	{"ate_nivel": 100, "min": 3, "max": 4},   ## avançado
]

## Golpe básico de cada tipo — a rede de segurança pra ninguém abrir o jogo sem
## conseguir machucar nada. Todos causam DANO (a primeira versão desta tabela
## dava `string_shot` pro Bug e `sand_attack` pro Ground, que são golpes de
## status: o Pokémon enchia os slots e continuava sem ter o que fazer).
const GOLPE_BASICO_POR_TIPO : Dictionary = {
	"Normal": "tackle", "Fire": "ember", "Water": "water_gun", "Grass": "vine_whip",
	"Electric": "thundershock", "Ice": "ice_beam", "Fighting": "karate_chop",
	"Poison": "poison_sting", "Ground": "bonemerang", "Flying": "gust",
	"Psychic": "confusion", "Bug": "fury_cutter", "Rock": "rock_throw",
	"Ghost": "lick", "Dragon": "dragon_rage",
}

# ──────────────────────────────────────────────────────────────────────────────
# Estágio evolutivo
# ──────────────────────────────────────────────────────────────────────────────

## 0 = forma base · 1 = primeira evolução · 2 = forma final de uma linha de três.
##
## Calculado a partir de `evolution_to` em `species.json`: quantos passos esta
## espécie está DEPOIS do começo da linha dela. Não precisa de tabela nova —
## o dado que responde isso já existia.
##
## `especies` é o dicionário inteiro de `species.json` (chave = id como texto),
## passado por fora pra esta classe não depender de autoload.
static func estagio_evolutivo(species_id: int, especies: Dictionary) -> int:
	var passos : int = 0
	var atual : int = species_id
	# Sobe a linha: quem evolui PARA mim? Repete até ninguém evoluir pra mim.
	for _i in 4:
		var anterior : int = _quem_evolui_para(atual, especies)
		if anterior <= 0:
			break
		passos += 1
		atual = anterior
	return mini(passos, 2)

static func _quem_evolui_para(species_id: int, especies: Dictionary) -> int:
	for chave in especies:
		var e : Dictionary = especies[chave]
		# 🔴 `evolution_to` é NULL nas formas finais (Charizard, Gyarados...) e
		# `int(null)` não converte: lança "Nonexistent 'int' constructor" e
		# interrompe o laço inteiro. Sem esta guarda, a busca abortava na
		# PRIMEIRA forma final que encontrasse e devolvia 0 pra todo mundo —
		# ou seja, o estágio evolutivo de todas as 151 espécies era 0 e a
		# escada de kit que o Gabriel pediu não existia de fato.
		var evolui_para = e.get("evolution_to")
		if evolui_para == null:
			continue
		if int(evolui_para) == species_id:
			return int(e.get("id", 0))
	return 0

# ──────────────────────────────────────────────────────────────────────────────
# Capacidade
# ──────────────────────────────────────────────────────────────────────────────

## Quantos slots este Pokémon tem, neste nível.
static func capacidade(species_id: int, nivel: int, especies: Dictionary) -> int:
	var slots : int = SLOTS_BASE + estagio_evolutivo(species_id, especies)
	for degrau in NIVEIS_DE_SLOT_EXTRA:
		if nivel >= degrau:
			slots += 1
	return mini(slots, SLOTS_MAXIMO)

## Quantos golpes OFENSIVOS mirar neste nível (item 13).
static func alvo_de_ofensivos(nivel: int) -> Dictionary:
	for faixa in FAIXAS_OFENSIVAS:
		if nivel <= int(faixa["ate_nivel"]):
			return faixa
	return FAIXAS_OFENSIVAS[FAIXAS_OFENSIVAS.size() - 1]

# ──────────────────────────────────────────────────────────────────────────────
# Montagem do kit
# ──────────────────────────────────────────────────────────────────────────────

## Monta a lista de golpes de um Pokémon.
##
## `aprendidos` é a saída de `GameData.get_learnable_moves()` (lista de
## {level, move}); `dados_dos_golpes` é um dicionário id→move usado pra saber
## quem causa dano. Devolve os ids, na ordem em que devem entrar nos slots.
##
## As regras, em ordem:
##   1. golpes de DANO mais recentes primeiro — são o que se usa;
##   2. respeitar a faixa ofensiva do nível (iniciante não abre com 4 botões);
##   3. completar com golpe de status, se ainda couber (utilidade tem valor);
##   4. garantir SEMPRE pelo menos um golpe que tira vida, caindo no básico do
##      tipo da espécie quando o learnset não oferece nenhum;
##   5. nunca passar da capacidade.
static func montar(species_id: int, nivel: int, aprendidos: Array,
		dados_dos_golpes: Dictionary, tipos: Array, especies: Dictionary,
		teto_extra: int = 0) -> Array:
	var limite : int = capacidade(species_id, nivel, especies)
	if teto_extra > 0:
		limite = mini(limite, teto_extra)

	var de_dano : Array[String] = []
	var de_status : Array[String] = []
	for entrada in aprendidos:
		var mid : String = str(entrada.get("move", ""))
		if mid.is_empty() or mid in de_dano or mid in de_status:
			continue
		var dados : Dictionary = dados_dos_golpes.get(mid, {})
		if dados.is_empty():
			continue
		if int(dados.get("power", 0)) > 0:
			de_dano.append(mid)
		else:
			de_status.append(mid)
	de_dano.reverse()
	de_status.reverse()

	var faixa : Dictionary = alvo_de_ofensivos(nivel)
	var teto_ofensivo : int = mini(int(faixa["max"]), limite)
	# Quem tem capacidade extra (evoluído e/ou de nível alto) ganha os slots a
	# mais em golpes OFENSIVOS — é exatamente o que faz o kit de um Charizard
	# ser melhor que o de um Charmander, e não só maior.
	if limite > SLOTS_BASE:
		teto_ofensivo = mini(teto_ofensivo + (limite - SLOTS_BASE), limite)

	var escolhidos : Array[String] = []
	for mid in de_dano:
		if escolhidos.size() >= teto_ofensivo:
			break
		escolhidos.append(mid)

	# Rede de segurança: pelo menos UM golpe que tira vida, sempre.
	if escolhidos.is_empty():
		var socorro : String = golpe_de_socorro(tipos, dados_dos_golpes)
		if not socorro.is_empty():
			escolhidos.append(socorro)

	for mid in de_status:
		if escolhidos.size() >= limite:
			break
		escolhidos.append(mid)

	return escolhidos

## O golpe básico do primeiro tipo da espécie que exista nos dados.
static func golpe_de_socorro(tipos: Array, dados_dos_golpes: Dictionary) -> String:
	for tipo in (tipos + ["Normal"]):
		var mid : String = str(GOLPE_BASICO_POR_TIPO.get(str(tipo), ""))
		if not mid.is_empty() and dados_dos_golpes.has(mid):
			return mid
	return ""

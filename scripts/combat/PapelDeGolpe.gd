## PapelDeGolpe.gd — Pra que serve cada golpe.
##
## Item P2 da Fase 3. Não é uma trava: nada aqui impede combinação nenhuma. É
## uma LENTE — serve pra analisar, balancear, alimentar a IA, escrever teste e
## diagnosticar learnset pobre.
##
## A pergunta que isso responde e nenhum outro dado respondia: *um Charizard
## joga diferente de um Charmander, ou só bate mais forte?* Contar slots não
## responde — oito golpes de dano direto são oito botões que fazem a mesma
## coisa. Contar PAPÉIS responde.
##
## Os papéis são DERIVADOS dos campos que já existem em `moves.json`
## (target_type, power, effect, category, knockback...), nunca escritos à mão
## golpe a golpe. Isso tem duas consequências boas: um golpe novo já nasce
## classificado, e mudar a regra reclassifica os 192 de uma vez.
class_name PapelDeGolpe
extends RefCounted

const DANO      := "DAMAGE"     ## tira vida, e é isso
const BURST     := "BURST"      ## tira MUITA vida de uma vez (power alto)
const AREA      := "AOE"        ## acerta mais de um
const CONTINUO  := "DOT"        ## queima/veneno: dano ao longo do tempo
const CONTROLE  := "CONTROL"    ## paralisia/sono/congelamento/confusão/empurrão
const MOBILIDADE := "MOBILITY"  ## muda posição (própria ou do alvo)
const DEFENSIVO := "DEFENSIVE"  ## cura, protege, sobe defesa
const COBERTURA := "COVERAGE"   ## golpe de tipo diferente do próprio Pokémon
const UTILIDADE := "UTILITY"    ## o resto do que não causa dano

const TODOS : Array[String] = [DANO, BURST, AREA, CONTINUO, CONTROLE,
	MOBILIDADE, DEFENSIVO, COBERTURA, UTILIDADE]

## A partir daqui um golpe conta como BURST.
const POWER_DE_BURST : int = 100

## Efeitos que caracterizam cada papel. Casam por prefixo, porque o campo
## `effect` carrega a chance no nome ("burn_10").
const EFEITOS_CONTINUOS : Array[String] = ["burn", "poison", "bad_poison", "leech", "drain"]
const EFEITOS_DE_CONTROLE : Array[String] = ["paralysis", "sleep", "freeze", "confuse",
	"trap", "force_switch", "flinch"]
const EFEITOS_DEFENSIVOS : Array[String] = ["heal", "recover", "soft_boiled", "protect",
	"buff_def", "bulk_up", "cure_status", "reflect", "barrier", "withdraw", "harden"]
const EFEITOS_DE_MOBILIDADE : Array[String] = ["two_turn_fly", "teleport", "agility", "baton_pass"]

## Os papéis deste golpe. Um golpe pode ter vários (Blizzard é AOE + BURST +
## CONTROL); nenhum golpe fica sem papel.
##
## COBERTURA não sai daqui: depende de QUEM está usando (é cobertura se o tipo
## do golpe não é o do Pokémon), então mora em `papeis_do_kit()`.
static func papeis(golpe: Dictionary) -> Array:
	var saida : Array[String] = []
	var power : int = int(golpe.get("power", 0))
	var efeito : String = str(golpe.get("effect", "none"))
	var categoria : String = str(golpe.get("category", "physical"))

	if power > 0:
		saida.append(DANO)
		if power >= POWER_DE_BURST:
			saida.append(BURST)
	if str(golpe.get("target_type", "single")) == "area":
		saida.append(AREA)
	if _casa(efeito, EFEITOS_CONTINUOS):
		saida.append(CONTINUO)
	if _casa(efeito, EFEITOS_DE_CONTROLE) or float(golpe.get("knockback", 0.0)) > 0.0:
		saida.append(CONTROLE)
	if _casa(efeito, EFEITOS_DEFENSIVOS):
		saida.append(DEFENSIVO)
	if _casa(efeito, EFEITOS_DE_MOBILIDADE):
		saida.append(MOBILIDADE)

	# Golpe sem dano e sem papel específico ainda serve pra alguma coisa —
	# fica como utilidade em vez de ficar sem classificação nenhuma.
	if saida.is_empty() or (power <= 0 and categoria == "status" and saida.size() == 0):
		saida.append(UTILIDADE)
	return saida

static func _casa(efeito: String, lista: Array) -> bool:
	for chave in lista:
		if efeito == chave or efeito.begins_with(chave + "_"):
			return true
	return false

# ──────────────────────────────────────────────────────────────────────────────
# Análise de um kit inteiro
# ──────────────────────────────────────────────────────────────────────────────

## Que papéis este kit cobre, e quantos golpes servem cada um.
##
## `kit` são ids de golpe; `tipos_do_pokemon` decide o que conta como
## COBERTURA. Devolve {papel: quantidade}, só com os papéis presentes.
static func papeis_do_kit(kit: Array, dados_dos_golpes: Dictionary,
		tipos_do_pokemon: Array = []) -> Dictionary:
	var conta : Dictionary = {}
	for mid in kit:
		var golpe : Dictionary = dados_dos_golpes.get(str(mid), {})
		if golpe.is_empty():
			continue
		for papel in papeis(golpe):
			conta[papel] = int(conta.get(papel, 0)) + 1
		# Cobertura: golpe de DANO cujo tipo não é o do próprio Pokémon. É o
		# que permite resolver um confronto ruim sem trocar de Pokémon.
		if int(golpe.get("power", 0)) > 0 and not tipos_do_pokemon.is_empty():
			if not (str(golpe.get("type", "")) in tipos_do_pokemon):
				conta[COBERTURA] = int(conta.get(COBERTURA, 0)) + 1
	return conta

## Quantos papéis DIFERENTES o kit cobre. É a medida de "quantas coisas
## diferentes esse Pokémon sabe fazer" — a que separa um kit grande de um kit
## profundo.
static func variedade(kit: Array, dados_dos_golpes: Dictionary,
		tipos_do_pokemon: Array = []) -> int:
	return papeis_do_kit(kit, dados_dos_golpes, tipos_do_pokemon).size()

## Quantos TIPOS diferentes de dano o kit oferece. Duas espécies podem ter a
## mesma variedade de papéis e cobertura muito diferente.
static func tipos_ofensivos(kit: Array, dados_dos_golpes: Dictionary) -> Array:
	var tipos : Array[String] = []
	for mid in kit:
		var golpe : Dictionary = dados_dos_golpes.get(str(mid), {})
		if int(golpe.get("power", 0)) <= 0:
			continue
		var tipo : String = str(golpe.get("type", ""))
		if not tipo.is_empty() and not (tipo in tipos):
			tipos.append(tipo)
	return tipos

## Um diagnóstico curto e legível do kit — usado no relatório por linha
## evolutiva e nos testes.
##
## `pobre` marca o kit que não dá pra jogar de verdade. O critério foi APERTADO
## na Fase 3: a primeira versão pedia só "menos de 2 papéis ou nenhum dano", e
## com isso o Magikarp (3 golpes, 1 tipo ofensivo, zero área, zero controle)
## passava como aceitável — o diagnóstico não pegava nem o caso que motivou a
## fase inteira. Agora é pobre quem tem **menos de 4 golpes**, **menos de 2
## tipos ofensivos** ou **nenhum golpe de dano**.
##
## É sinal de "esta espécie precisa de conteúdo", nunca de "o código quebrou".
static func diagnostico(kit: Array, dados_dos_golpes: Dictionary,
		tipos_do_pokemon: Array = []) -> Dictionary:
	var conta : Dictionary = papeis_do_kit(kit, dados_dos_golpes, tipos_do_pokemon)
	var tipos : Array = tipos_ofensivos(kit, dados_dos_golpes)
	return {
		"golpes": kit.size(),
		"papeis": conta,
		"variedade": conta.size(),
		"tipos_ofensivos": tipos.size(),
		"tem_dano": conta.has(DANO),
		"tem_area": conta.has(AREA),
		"tem_controle": conta.has(CONTROLE),
		"tem_cobertura": conta.has(COBERTURA),
		"pobre": kit.size() < 4 or tipos.size() < 2 or not conta.has(DANO),
	}

## RegraDeMaquina.gd — O que uma MT ou MO faz (Fase 16).
##
## Classe pura. Quem guarda item é o save; quem mostra tela é o Codex; quem
## move o corpo é o controlador. Aqui só se decide.
##
## ── §30, e é a frase inteira que importa ────────────────────────────────────
##
## *"HM pode afetar combate, travessia ou os dois. **Não presumir que faz sempre
## as duas coisas.**"*
##
## Por isso o que cada máquina desbloqueia sai do **dado** (campo `unlocks` em
## `items.json`), nunca de uma tabela cravada aqui. Hoje, no nosso mundo 3D:
## Voar abre o ar, Surf abre a água, e **Cortar e Força abrem nada** — porque
## não existe árvore pra cortar nem pedra pra empurrar na V3 ainda. Declarar
## `""` é dizer isso em voz alta; presumir "MO = travessia" criaria uma MO que
## promete passagem e não entrega — zero silencioso com nome bonito.
##
## ── A decisão que esta fase tinha que tomar ─────────────────────────────────
##
## As Fases 14 e 15 resolveram travessia por **arquétipo**: quem nada, nada.
## Isso deixou uma pergunta aberta — se a espécie já decide, **o que sobra pra
## MO fazer?** Porta-la da V2 sem responder isso faria a MO Surf ensinar um
## golpe e não mudar nada no mundo.
##
## A resposta, que é a do gênero e a que §30 descreve: são **duas perguntas
## diferentes**.
##
##   **capacidade** — o corpo consegue? → arquétipo (`RegraDeTravessia`)
##   **permissão**  — o jogador pode?   → a MO (esta classe)
##
## Atravessar exige as duas. Um Gyarados selvagem nada porque é Gyarados; o
## jogador só atravessa o mar quando tem a MO, mesmo sendo o mesmo Gyarados.
##
## ⚠️ E a permissão é do **jogador**, não do corpo. Selvagem nunca é barrado:
## exigir carteira de um bicho é o tipo de regra que transforma o mundo num
## cartório e faria todo teste de Fase 11 reprovar por um motivo inventado.
##
## ── §31 ─────────────────────────────────────────────────────────────────────
##
## *"TM adiciona ao Move Pool e não equipa sozinha."* MT ensina e acabou; MO
## ensina **e abre a troca de kit**, que custa os 25 níveis de `TrocaDeKit` —
## constante configurável, que vale só pra troca ligada a MO (§33). Essa conta
## não é redeclarada aqui: ela mora lá, num lugar só.
class_name RegraDeMaquina
extends RefCounted

## O que uma máquina pode desbloquear de travessia. Vazio é resposta válida e
## comum — a maioria das máquinas só mexe em combate.
const TRAVESSIA_NENHUMA := ""
const TRAVESSIA_AGUA    := "agua"
const TRAVESSIA_AR      := "ar"

const TRAVESSIAS : Array[String] = [TRAVESSIA_AGUA, TRAVESSIA_AR]

## A categoria que `items.json` usa pras duas.
const CATEGORIA := "tm_hm"

# ──────────────────────────────────────────────────────────────────────────────
# Que bicho é este item
# ──────────────────────────────────────────────────────────────────────────────

static func e_maquina(item: Dictionary) -> bool:
	return str(item.get("category", "")) == CATEGORIA

## MO — a que abre a troca de kit. A distinção mora em `TrocaDeKit` desde
## 11/09; reusar em vez de recriar o prefixo evita duas definições de "é MO"
## discordando no dia em que uma delas mudar.
static func e_mo(item_id: String) -> bool:
	return TrocaDeKit.e_mo(item_id)

static func e_mt(item: Dictionary) -> bool:
	return e_maquina(item) and not e_mo(str(item.get("id", "")))

## §31: MT só ensina. MO ensina e abre a tela.
static func so_ensina(item: Dictionary) -> bool:
	return e_mt(item)

## Gasta ao usar? Sai do dado (`single_use`), porque MO é reutilizável e a MT
## de ouro também — e é o dado que sabe disso, não o prefixo do id.
static func gasta_ao_usar(item: Dictionary) -> bool:
	return bool(item.get("single_use", true))

# ──────────────────────────────────────────────────────────────────────────────
# O que ela faz
# ──────────────────────────────────────────────────────────────────────────────

## `{"golpe": String, "travessia": String}` — as duas metades da §30, cada uma
## podendo ser vazia, **independentemente** da outra.
##
## Um valor de `unlocks` que não é travessia conhecida vira vazio **com aviso**:
## um erro de digitação no JSON não pode virar uma permissão que nunca chega.
static func efeitos(item: Dictionary) -> Dictionary:
	var golpe := str(item.get("teaches", ""))
	var travessia := str(item.get("unlocks", TRAVESSIA_NENHUMA))
	if travessia != TRAVESSIA_NENHUMA and not (travessia in TRAVESSIAS):
		push_warning("máquina '%s' declara travessia desconhecida '%s' (§30); ignorada"
			% [str(item.get("id", "?")), travessia])
		travessia = TRAVESSIA_NENHUMA
	return {"golpe": golpe, "travessia": travessia}

static func ensina_golpe(item: Dictionary) -> bool:
	return str(efeitos(item)["golpe"]) != ""

static func abre_travessia(item: Dictionary) -> bool:
	return str(efeitos(item)["travessia"]) != TRAVESSIA_NENHUMA

## Frase pro jogador, porque "o que esta MO faz?" é pergunta de tela e a
## resposta é regra de gameplay.
static func resumo(item: Dictionary, nome_do_golpe: String = "") -> String:
	var e := efeitos(item)
	var partes : Array[String] = []
	if str(e["golpe"]) != "":
		partes.append("ensina %s" % (nome_do_golpe if nome_do_golpe != "" else str(e["golpe"])))
	match str(e["travessia"]):
		TRAVESSIA_AGUA: partes.append("permite atravessar água funda")
		TRAVESSIA_AR:   partes.append("permite voar")
	if partes.is_empty():
		return "Não faz nada."
	return String(" e ").join(partes).capitalize()

# ──────────────────────────────────────────────────────────────────────────────
# Permissões do jogador
# ──────────────────────────────────────────────────────────────────────────────

## As permissões que a mochila concede. Derivada, **não guardada**: ter a MO é
## ter a permissão, então não existe um segundo estado pra salvar, migrar e
## divergir do primeiro.
##
## `itens` é `{id: quantidade}` ou uma lista de ids — a mochila da V2 usa o
## primeiro formato, e aceitar os dois evita que o chamador converta.
static func permissoes_de(itens, catalogo: Dictionary) -> Array[String]:
	var ids : Array = []
	if itens is Dictionary:
		for id in itens.keys():
			if int(itens[id]) > 0:
				ids.append(id)
	elif itens is Array:
		ids = itens
	var fora : Array[String] = []
	for id in ids:
		var item : Dictionary = catalogo.get(str(id), {})
		if item.is_empty():
			continue
		var t := str(efeitos(item)["travessia"])
		if t != TRAVESSIA_NENHUMA and not (t in fora):
			fora.append(t)
	return fora

## De que permissão esta superfície precisa. Água rasa não precisa de nenhuma —
## andar com água no joelho é andar (Fase 14).
static func travessia_exigida(superficie: String) -> String:
	if superficie == RegraDeTravessia.AGUA_PROFUNDA:
		return TRAVESSIA_AGUA
	return TRAVESSIA_NENHUMA

# ──────────────────────────────────────────────────────────────────────────────
# As duas perguntas, juntas
# ──────────────────────────────────────────────────────────────────────────────

## Capacidade **e** permissão. Devolve `{"pode", "motivo"}` — e o motivo diz
## QUAL das duas faltou, porque "não dá" sem dizer o quê é a recusa que mais
## irrita: o jogador não sabe se troca de Pokémon ou vai procurar uma MO.
##
## `permissoes` vazio é o padrão e é restritivo de propósito (falha fechada):
## permissão que se concede sozinha por omissão não é permissão.
static func pode_atravessar(arquetipo: String, superficie: String,
		permissoes: Array = []) -> Dictionary:
	if not RegraDeTravessia.pode_estar_em(arquetipo, superficie):
		return {"pode": false, "motivo": "Este Pokémon não nada."}
	var exigida := travessia_exigida(superficie)
	if exigida == TRAVESSIA_NENHUMA:
		return {"pode": true, "motivo": ""}
	# Voar por cima não é atravessar a água: quem voa não está nela.
	if MovementProfile.voa(arquetipo):
		return {"pode": true, "motivo": ""}
	if exigida in permissoes:
		return {"pode": true, "motivo": ""}
	return {"pode": false, "motivo": "Você ainda não pode atravessar água funda."}

## Decolar exige permissão do ar **além** da regra de zona (§29). A zona diz
## onde é proibido voar; a MO diz se o jogador aprendeu a voar. São recusas
## diferentes e merecem frases diferentes.
static func pode_decolar(arquetipo: String, zona: Dictionary,
		permissoes: Array = []) -> Dictionary:
	var r : Dictionary = RegraDeTravessia.pode_voar(arquetipo, zona)
	if not bool(r["pode"]):
		return r
	if TRAVESSIA_AR in permissoes:
		return {"pode": true, "motivo": ""}
	return {"pode": false, "motivo": "Você ainda não pode voar."}

# ──────────────────────────────────────────────────────────────────────────────
# A troca de kit, que continua morando em `TrocaDeKit`
# ──────────────────────────────────────────────────────────────────────────────

## §33, e a palavra que importa é **ligada a MO**: usar uma MT não custa nível
## nenhum, porque MT não troca kit — ela só ensina.
static func custa_niveis(item: Dictionary) -> bool:
	return e_maquina(item) and e_mo(str(item.get("id", "")))

static func custo_em_niveis() -> int:
	return TrocaDeKit.CUSTO_EM_NIVEIS

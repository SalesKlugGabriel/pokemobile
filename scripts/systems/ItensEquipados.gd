## ItensEquipados.gd — Os dois encaixes de item do Pokémon (09/09).
##
## Item 03 da fila. A regra que veio do PokeXGames e que faz held ser uma
## ESCOLHA em vez de uma pilha de bônus: **dois encaixes por Pokémon, um de
## COMBATE e um de UTILIDADE**, e só um item em cada. Bater mais forte custa
## abrir mão de ganhar mais EXP, achar mais loot ou se curar sozinho.
##
## 🔴 O que eu achei ao começar: `SaveManager.equip_held_item()` existia desde
## sempre e **a Mochila nunca soube chamá-lo** — a categoria "held" caía no
## "só pode ser usado numa batalha", igual acontecia com os remédios. Equipar
## item era, na prática, impossível. Terceiro sistema "pronto" que era fachada.
##
## Este arquivo é a FONTE DE VERDADE ÚNICA dos modificadores: quem quiser saber
## "quanto dano a mais", "quanta EXP a mais", "quanto de recarga a menos"
## pergunta aqui. Espalhar essa conta por sete arquivos é como um bônus vira
## dois números diferentes na mesma tela.
class_name ItensEquipados
extends RefCounted

const ENCAIXES : Array[String] = ["combate", "utilidade"]

## Onde cada encaixe é guardado no save do Pokémon.
const CAMPO := {"combate": "held_combate", "utilidade": "held_utilidade"}

# ──────────────────────────────────────────────────────────────────────────
# Leitura
# ──────────────────────────────────────────────────────────────────────────
## O item equipado num encaixe ("" se vazio). Migra sozinho o campo antigo
## `held_item` (um encaixe só) pro encaixe de combate — nenhum save perde item.
static func equipado(poke: Dictionary, encaixe: String) -> String:
	var atual := str(poke.get(CAMPO.get(encaixe, ""), ""))
	if atual != "":
		return atual
	if encaixe == "combate":
		return str(poke.get("held_item", ""))
	return ""

## Soma dos valores de um efeito nos dois encaixes. Devolve 0.0 se nenhum item
## equipado tem esse efeito.
static func valor(poke: Dictionary, efeito: String, tipo_do_golpe: String = "") -> float:
	var total := 0.0
	for encaixe in ENCAIXES:
		var item_id := equipado(poke, encaixe)
		if item_id == "":
			continue
		var dados := _item(item_id)
		if str(dados.get("held_effect", "")) != efeito:
			continue
		# O held de dano só vale pro tipo dele — é o que impede um item só
		# resolver o jogo inteiro.
		if efeito == "dano_tipo":
			var tipo := str(dados.get("held_type", ""))
			if tipo != "" and tipo != tipo_do_golpe:
				continue
		total += float(dados.get("held_value", 0.0))
	return total

## Atalho pro Pokémon que está lutando (slot 0 do time).
static func valor_do_lider(efeito: String, tipo_do_golpe: String = "") -> float:
	var salvar = _no("SaveManager")
	if salvar == null or not salvar.has_method("get_pokemon_at"):
		return 0.0
	var lider : Dictionary = salvar.get_pokemon_at(0)
	if lider.is_empty():
		return 0.0
	return valor(lider, efeito, tipo_do_golpe)

# ──────────────────────────────────────────────────────────────────────────
# Equipar / tirar
# ──────────────────────────────────────────────────────────────────────────
## Equipa no encaixe DO ITEM (ele mesmo diz qual é). Se já havia outro ali, ele
## volta pra mochila — troca, nunca perde. Devolve {ok, texto}.
static func equipar(indice: int, item_id: String) -> Dictionary:
	var salvar = _no("SaveManager")
	if salvar == null:
		return {"ok": false, "texto": "Não deu pra equipar agora."}
	var dados := _item(item_id)
	var encaixe := str(dados.get("held_slot", ""))
	if encaixe == "":
		return {"ok": false, "texto": "Esse item não é equipável."}
	if not salvar.has_item(item_id, 1):
		return {"ok": false, "texto": "Você não tem esse item."}

	var time : Array = salvar.get_team()
	if indice < 0 or indice >= time.size():
		return {"ok": false, "texto": "Pokémon inválido."}
	var poke : Dictionary = time[indice]

	var antigo := equipado(poke, encaixe)
	salvar.remove_item(item_id, 1)
	if antigo != "":
		salvar.add_item(antigo, 1)
	poke[CAMPO[encaixe]] = item_id
	# O campo antigo some quando o novo assume, pra não sobrar duas verdades.
	if encaixe == "combate":
		poke["held_item"] = ""
	salvar.update_team_pokemon(indice, poke)
	salvar.save_game()
	var texto := "Equipou %s." % str(dados.get("name", item_id))
	if antigo != "":
		texto += " %s voltou pra mochila." % str(_item(antigo).get("name", antigo))
	return {"ok": true, "texto": texto}

static func tirar(indice: int, encaixe: String) -> Dictionary:
	var salvar = _no("SaveManager")
	if salvar == null:
		return {"ok": false, "texto": ""}
	var time : Array = salvar.get_team()
	if indice < 0 or indice >= time.size():
		return {"ok": false, "texto": "Pokémon inválido."}
	var poke : Dictionary = time[indice]
	var item_id := equipado(poke, encaixe)
	if item_id == "":
		return {"ok": false, "texto": "Esse encaixe está vazio."}
	poke[CAMPO[encaixe]] = ""
	if encaixe == "combate":
		poke["held_item"] = ""
	salvar.update_team_pokemon(indice, poke)
	salvar.add_item(item_id, 1)
	salvar.save_game()
	return {"ok": true, "texto": "%s voltou pra mochila." % str(_item(item_id).get("name", item_id))}

# ──────────────────────────────────────────────────────────────────────────
# Fusão — 3 iguais viram 1 do tier acima
# ──────────────────────────────────────────────────────────────────────────
## É o destino do held repetido, que senão vira lixo na mochila. Custa dinheiro
## de propósito: dá pra que serve o dinheiro do loot depois que a mochila já
## está cheia de poção.
const QUANTIDADE_FUSAO : int = 3

static func pode_fundir(item_id: String) -> Dictionary:
	var salvar = _no("SaveManager")
	if salvar == null:
		return {"ok": false, "motivo": ""}
	var dados := _item(item_id)
	var alvo := str(dados.get("fuses_into", ""))
	if alvo == "":
		return {"ok": false, "motivo": "Esse item já está no tier máximo."}
	if not salvar.has_item(item_id, QUANTIDADE_FUSAO):
		return {"ok": false,
			"motivo": "Precisa de %d iguais pra fundir." % QUANTIDADE_FUSAO}
	var custo : int = int(dados.get("fusion_cost", 0))
	if int(salvar.save_data.get("money", 0)) < custo:
		return {"ok": false, "motivo": "Faltam moedas: a fusão custa %d." % custo}
	return {"ok": true, "motivo": "", "alvo": alvo, "custo": custo}

static func fundir(item_id: String) -> Dictionary:
	var checagem := pode_fundir(item_id)
	if not bool(checagem.get("ok", false)):
		return {"ok": false, "texto": str(checagem.get("motivo", ""))}
	var salvar = _no("SaveManager")
	var alvo := str(checagem["alvo"])
	var custo : int = int(checagem["custo"])
	salvar.remove_item(item_id, QUANTIDADE_FUSAO)
	salvar.save_data["money"] = int(salvar.save_data.get("money", 0)) - custo
	salvar.add_item(alvo, 1)
	salvar.save_game()
	return {"ok": true,
		"texto": "Fundiu %d %s em 1 %s!" % [QUANTIDADE_FUSAO,
			str(_item(item_id).get("name", item_id)), str(_item(alvo).get("name", alvo))]}

# ──────────────────────────────────────────────────────────────────────────
static func _item(item_id: String) -> Dictionary:
	var dados = _no("GameData")
	if dados == null or not dados.has_method("get_item"):
		return {}
	return dados.get_item(item_id)

static func _no(nome: String):
	var laco := Engine.get_main_loop()
	if laco == null or not (laco is SceneTree):
		return null
	return (laco as SceneTree).root.get_node_or_null(nome)

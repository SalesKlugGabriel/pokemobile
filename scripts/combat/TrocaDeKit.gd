## TrocaDeKit.gd — Mudar o kit de um Pokémon custa níveis.
##
## Pedido do Gabriel (11/09/2026):
##
##   *"com a possibilidade de alterar usando HM's futuramente, depois de um HM
##   ser usado, deve ter uma tela de seleção de kit que pode ser alterado mas o
##   pokemon perde 25 niveis para cada alteração de HM"*
##
## ── Por que um custo tão alto ───────────────────────────────────────────────
## Sem custo, o loadout deixa de ser uma decisão: você trocaria o kit inteiro
## antes de cada luta e sempre teria a resposta perfeita. **25 níveis** é caro o
## bastante pra você pensar duas vezes — e é reversível, porque nível se
## recupera jogando. É um custo de TEMPO, não de recurso perdido pra sempre.
##
## ── O que este arquivo faz e o que NÃO faz ──────────────────────────────────
## Faz: a REGRA — pode trocar? quanto custa? o que acontece com nível, vida e
## capacidade depois? Não faz: a tela. A tela de seleção é do Codex
## (ver `docs/rfc/`), e este arquivo existe justamente pra ela ter um contrato
## pronto em vez de recalcular regra de gameplay na apresentação.
##
## Classe pura: a conta precisa ser testável headless.
class_name TrocaDeKit
extends RefCounted

## Quanto custa cada alteração feita a partir de uma MO.
const CUSTO_EM_NIVEIS : int = 25

## Nível mínimo pra poder pagar. Precisa SOBRAR nível: um Pokémon de nível 25
## que pagasse 25 voltaria ao nível 0, que não existe. Exigir mais que o custo
## também tem um efeito bom de design — trocar kit é coisa de Pokémon já
## criado, não de bicho recém-capturado.
const NIVEL_MINIMO : int = CUSTO_EM_NIVEIS + 1

## As MOs do jogo e o golpe que cada uma ensina. Sai de `items.json`
## (campo `teaches`) — aqui fica só a lista de quais itens são MO, porque MO
## tem regra diferente de MT: ela abre a tela de troca.
const PREFIXO_DE_MO : String = "hm"

static func e_mo(item_id: String) -> bool:
	return item_id.begins_with(PREFIXO_DE_MO)

# ──────────────────────────────────────────────────────────────────────────────
# Pode trocar?
# ──────────────────────────────────────────────────────────────────────────────

## Devolve {"pode": bool, "motivo": String, "nivel_depois": int}.
##
## O `motivo` é texto pro jogador, não código de erro — quem mostra a tela
## precisa dizer POR QUE não dá, e a razão é regra de gameplay, não de UI.
static func pode_trocar(poke: Dictionary) -> Dictionary:
	if poke.is_empty():
		return {"pode": false, "motivo": "Nenhum Pokémon selecionado.", "nivel_depois": 0}
	var nivel : int = int(poke.get("level", 1))
	if nivel < NIVEL_MINIMO:
		return {
			"pode": false,
			"motivo": "Precisa ser pelo menos nível %d — trocar o kit custa %d níveis." \
				% [NIVEL_MINIMO, CUSTO_EM_NIVEIS],
			"nivel_depois": nivel,
		}
	return {"pode": true, "motivo": "", "nivel_depois": nivel - CUSTO_EM_NIVEIS}

## Quanto ele perde, e com o que fica. Usado pela tela pra mostrar o preço
## ANTES de o jogador confirmar — ninguém deve descobrir o custo depois.
static func previsao(poke: Dictionary, especies: Dictionary) -> Dictionary:
	var nivel : int = int(poke.get("level", 1))
	var depois : int = maxi(1, nivel - CUSTO_EM_NIVEIS)
	var id : int = int(poke.get("species_id", 1))
	var base : Dictionary = especies.get(str(id), {}).get("base_stats", {})
	var iv : int = int(poke.get("ivs", {}).get("hp", 31))
	return {
		"nivel_antes": nivel,
		"nivel_depois": depois,
		"custo": CUSTO_EM_NIVEIS,
		"slots_antes": KitDeCombate.capacidade(id, nivel, especies),
		"slots_depois": KitDeCombate.capacidade(id, depois, especies),
		"hp_antes": StatsDePokemon.hp_maximo(int(base.get("hp", 45)), nivel, iv),
		"hp_depois": StatsDePokemon.hp_maximo(int(base.get("hp", 45)), depois, iv),
	}

# ──────────────────────────────────────────────────────────────────────────────
# A troca
# ──────────────────────────────────────────────────────────────────────────────

## Aplica a troca. `novo_equipado` são ids de golpe, na ordem dos slots.
##
## Devolve {"ok": bool, "motivo": String, "poke": Dictionary}. O dicionário
## devolvido é o registro ATUALIZADO — quem chamou grava.
##
## O que muda, e nesta ordem (a ordem importa: o kit precisa caber na
## capacidade DEPOIS da perda, senão o jogador pagaria por slots que vai
## perder no mesmo instante):
##
##   1. confere que dá pra pagar;
##   2. confere que todo golpe escolhido é CONHECIDO e não repete;
##   3. desconta os níveis e recalcula vida (mantendo a fração — quem estava
##      com metade continua com metade, mesma regra da migração de save);
##   4. corta o kit na capacidade nova;
##   5. grava os equipados.
static func aplicar(poke: Dictionary, novo_equipado: Array, especies: Dictionary,
		golpes: Dictionary) -> Dictionary:
	var checagem : Dictionary = pode_trocar(poke)
	if not bool(checagem["pode"]):
		return {"ok": false, "motivo": str(checagem["motivo"]), "poke": poke}

	var conhecidos : Array = poke.get("known_moves", [])
	var vistos : Array = []
	for mid in novo_equipado:
		var id_str : String = str(mid)
		if id_str.is_empty():
			continue
		if not (id_str in conhecidos):
			return {"ok": false, "motivo": "Este Pokémon não conhece %s." % id_str, "poke": poke}
		if id_str in vistos:
			return {"ok": false, "motivo": "O mesmo golpe não pode ocupar dois espaços.", "poke": poke}
		vistos.append(id_str)

	var id : int = int(poke.get("species_id", 1))
	var nivel_novo : int = maxi(1, int(poke.get("level", 1)) - CUSTO_EM_NIVEIS)
	var base : Dictionary = especies.get(str(id), {}).get("base_stats", {})
	var iv : int = int(poke.get("ivs", {}).get("hp", 31))

	var hp_max_antes : int = int(poke.get("hp_max", 1))
	var hp_max_novo : int = StatsDePokemon.hp_maximo(int(base.get("hp", 45)), nivel_novo, iv)
	poke["hp_current"] = StatsDePokemon.migrar_hp(
		int(poke.get("hp_current", hp_max_antes)), hp_max_antes, hp_max_novo)
	poke["hp_max"] = hp_max_novo
	poke["level"] = nivel_novo
	poke["exp"] = nivel_novo * nivel_novo * nivel_novo

	var capacidade : int = KitDeCombate.capacidade(id, nivel_novo, especies)
	var equipados : Array = []
	for mid in vistos:
		if equipados.size() >= capacidade:
			break
		var dados : Dictionary = golpes.get(str(mid), {})
		equipados.append({
			"id": str(mid),
			"pp_current": int(dados.get("pp", 10)),
			"pp_max": int(dados.get("pp", 10)),
		})
	poke["moves"] = equipados
	poke["trocas_de_kit"] = int(poke.get("trocas_de_kit", 0)) + 1
	return {"ok": true, "motivo": "", "poke": poke}

## RegraDeMovePool.gd — Quais golpes este Pokémon sabe, carrega e alcança.
##
## ── O que esta fase encontrou antes de escrever qualquer regra ──────────────
## 🔴 **Nenhum Pokémon da V3 tinha golpe nenhum.** `PokemonInstance3D.kit` é
## declarado (Fase 10) e **nunca era preenchido por ninguém** fora de um teste:
## o único `.kit =` do repositório inteiro estava em `teste_..._fase10.gd`. As
## quatro teclas existiam, o `UsoDeSkill` existia, o aviso e a área existiam — e
## apertar Q no jogo não fazia nada, sem erro nenhum. É a definição de zero
## silencioso, e é o buraco que esta fase fecha.
##
## ── As três camadas ────────────────────────────────────────────────────────
## A §17 pede "muitos golpes conhecidos, poucos ativos". Isso não são duas
## listas, são três — e achatá-las em duas é como o repertório some:
##
##   1. **conhecidos** — tudo que ele já aprendeu. Sem teto: o learnset até o
##      nível atual, mais o que MT e MO ensinaram. É memória, não capacidade.
##   2. **equipados** — o que ele leva pra briga. O teto aqui é a escada do
##      `KitDeCombate`, que já existe e **não muda nesta fase**.
##   3. **ativos** — o que o teclado alcança de verdade.
##
## A terceira camada é a que obriga a decisão desta fase, abaixo.
##
## ── 🔴 Divergência declarada com a RFC §17 ─────────────────────────────────
## A RFC diz "**4 ativos** (Q E R F)". Mas a escada do `KitDeCombate` nasceu de
## um pedido literal do Gabriel:
##
##   *"um charmander lvl 100 em vez de 4 skills > 6 skills, um charmeleon 7,
##   um charizard 8"*
##
## Com 4 teclas fixas, um Charizard equiparia 8 golpes e **alcançaria 4** — os
## outros quatro seriam repertório que o jogador vê e nunca usa. A escada
## inteira, que existe pra evoluir mudar COMO se joga, viraria enfeite; e
## viraria em silêncio, que é o erro que esta fase acabou de achar.
##
## Então **ativo = equipado**, com o teclado indo até 8 — e não foi preciso
## inventar tecla: `skill_1..skill_8` já existem no InputMap desde a V2
## (Q E R F + 1-4, e depois 5 6 7 8). O `for i in 4` da entidade é que estava
## cravado.
##
## Isso contraria a RFC de propósito e está escrito aqui pra não passar
## despercebido: a RFC é o desenho, o pedido do Gabriel é a decisão.
##
## Classe pura: nenhum autoload citado, nem indiretamente — a regra da Fase 11.
class_name RegraDeMovePool
extends RefCounted

## Quantas skills o teclado alcança. Sai do InputMap (`skill_1..skill_8`), não
## de um gosto meu — e casa com `KitDeCombate.SLOTS_MAXIMO`, que é 8.
const TECLAS_DE_SKILL : int = 8

## A categoria de quem é do jogador. Qualquer outra é encontro selvagem, e cai
## na régua de `KitDeCombate.slots_de_selvagem()`.
const CATEGORIA_JOGADOR := "jogador"
const CATEGORIA_PADRAO := "comum"

# ──────────────────────────────────────────────────────────────────────────────
# 1. Conhecidos — o que ele sabe
# ──────────────────────────────────────────────────────────────────────────────

## Tudo que este Pokémon aprendeu até aqui, sem teto.
##
## `learnset` é a lista de `{level, move}` da espécie (a saída crua de
## `GameData.get_learnable_moves`, ou o learnset inteiro — o nível filtra aqui
## de qualquer jeito, pra esta classe não depender de quem chamou ter filtrado).
## `ensinados` são os golpes que vieram de MT/MO, que não têm nível.
##
## Ordem: por nível crescente, e os ensinados por último — um golpe de MT é o
## mais novo que ele sabe, e quem monta o kit prioriza o mais recente.
static func conhecidos(learnset: Array, nivel: int, ensinados: Array = []) -> Array[String]:
	var fora : Array[String] = []
	for entrada in learnset:
		if not (entrada is Dictionary):
			continue
		if int(entrada.get("level", 0)) > nivel:
			continue
		var mid := str(entrada.get("move", ""))
		if mid.is_empty() or mid in fora:
			continue
		fora.append(mid)
	for mid_cru in ensinados:
		var mid := str(mid_cru)
		if mid.is_empty() or mid in fora:
			continue
		fora.append(mid)
	return fora

## §31: MT **adiciona ao pool e não equipa sozinha**.
##
## Devolve `{"conhecidos": [...], "novo": bool}`. Quem chamou grava — e repare
## que o kit equipado NÃO sai daqui: aprender é lembrar, equipar é decidir, e
## são momentos diferentes.
static func aprender(lista_conhecida: Array, move_id: String) -> Dictionary:
	var fora : Array[String] = []
	for mid in lista_conhecida:
		fora.append(str(mid))
	var id := move_id.strip_edges()
	if id.is_empty() or id in fora:
		return {"conhecidos": fora, "novo": false}
	fora.append(id)
	return {"conhecidos": fora, "novo": true}

# ──────────────────────────────────────────────────────────────────────────────
# 2. Equipados — o que ele carrega
# ──────────────────────────────────────────────────────────────────────────────

## Quantos slots este Pokémon tem. Uma porta só pras duas réguas que já
## existem, pra ninguém escolher a errada por descuido.
static func slots(species_id: int, nivel: int, especies: Dictionary,
		categoria: String = CATEGORIA_PADRAO) -> int:
	if categoria == CATEGORIA_JOGADOR:
		return KitDeCombate.capacidade(species_id, nivel, especies)
	return KitDeCombate.slots_de_selvagem(species_id, nivel, categoria, especies)

## O kit que vai pra briga.
##
## Toda a escolha de QUAIS golpes (dano antes de status, faixa ofensiva por
## nível, a rede de segurança do golpe básico do tipo) continua em
## `KitDeCombate.montar` — esta fase não reescreve nenhuma dessas regras, só
## decide o teto certo e entrega a lista pronta.
static func equipados(species_id: int, nivel: int, lista_conhecida: Array,
		dados_dos_golpes: Dictionary, tipos: Array, especies: Dictionary,
		categoria: String = CATEGORIA_PADRAO) -> Array[String]:
	var teto : int = slots(species_id, nivel, especies, categoria)
	# `montar` fala a língua do learnset (`{level, move}`); os conhecidos já
	# vêm na ordem certa, então o nível aqui só preserva essa ordem.
	var como_learnset : Array = []
	for i in lista_conhecida.size():
		como_learnset.append({"level": i, "move": str(lista_conhecida[i])})
	var crus : Array = KitDeCombate.montar(species_id, nivel, como_learnset,
		dados_dos_golpes, tipos, especies, teto)
	var fora : Array[String] = []
	for mid in crus:
		fora.append(str(mid))
	return fora

# ──────────────────────────────────────────────────────────────────────────────
# 3. Ativos — o que a mão alcança
# ──────────────────────────────────────────────────────────────────────────────

## Os golpes que têm tecla. Hoje é o kit inteiro, porque o teclado vai até 8 —
## mas passa por aqui de propósito: o dia em que um kit passar das teclas
## disponíveis, o corte tem um lugar só, e é este.
static func ativos(lista_equipada: Array) -> Array[String]:
	var fora : Array[String] = []
	for mid in lista_equipada:
		if fora.size() >= TECLAS_DE_SKILL:
			break
		fora.append(str(mid))
	return fora

## Que tecla aciona o slot. A HUD pergunta; ela não decide.
static func tecla_do_slot(indice: int) -> String:
	if indice < 0 or indice >= TECLAS_DE_SKILL:
		return ""
	return "skill_%d" % (indice + 1)

# ──────────────────────────────────────────────────────────────────────────────
# As três de uma vez
# ──────────────────────────────────────────────────────────────────────────────

## As três camadas num dicionário só — o que a entidade e a HUD pedem.
##
## `{"conhecidos": [...], "equipados": [...], "ativos": [...], "slots": int}`
##
## Devolver as três juntas é o que deixa a tela mostrar "sabe 11, leva 6" sem
## recalcular regra nenhuma na apresentação.
static func montar_pool(species_id: int, nivel: int, learnset: Array,
		dados_dos_golpes: Dictionary, tipos: Array, especies: Dictionary,
		categoria: String = CATEGORIA_PADRAO, ensinados: Array = []) -> Dictionary:
	var sabe : Array[String] = conhecidos(learnset, nivel, ensinados)
	var leva : Array[String] = equipados(species_id, nivel, sabe,
		dados_dos_golpes, tipos, especies, categoria)
	return {
		"conhecidos": sabe,
		"equipados": leva,
		"ativos": ativos(leva),
		"slots": slots(species_id, nivel, especies, categoria),
	}

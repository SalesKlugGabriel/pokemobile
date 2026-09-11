## RegrasDeLendario.gd — O que torna um lendário diferente de qualquer outro
## Pokémon do jogo.
##
## Pedido do Gabriel (11/09/2026):
##
##   *"os lendários quando selvagem sempre serão lvl 100, e a taxa de captura
##   deve ser a mais baixa do jogo todo, além disso, se a captura ocorrer, eles
##   são zerados ao nivel 1 para que não seja muito roubado e o player sinta
##   que ele vai crescer"*
##
## As três regras juntas resolvem uma tensão que o jogo tinha: um lendário de
## nível 100 capturado seria o fim da progressão — você ganharia o melhor
## Pokémon do jogo pronto, e tudo depois viraria passeio. Zerando pro nível 1,
## a captura deixa de ser um **prêmio final** e vira um **começo**: você
## conquistou o direito de criar aquele bicho, não de recebê-lo pronto.
##
## Por que existe um arquivo só pra isto: "quem é lendário" estava espalhado —
## `CovisLendarios.NINHOS` conhecia três, `species.json` tinha uma taxa de
## captura baixa em quatro, e Mew não estava em lugar nenhum (taxa 45, igual a
## um Bulbasaur). Uma pergunta, um lugar.
class_name RegrasDeLendario
extends RefCounted

## Os cinco lendários de Kanto. Mewtwo e Mew entram aqui mesmo não tendo covil
## próprio ainda — a regra vale pela ESPÉCIE, não por onde ela aparece.
const ESPECIES : Array[int] = [144, 145, 146, 150, 151]

## Nível em que um lendário SELVAGEM sempre nasce. Não é faixa, não sorteia:
## encontrar um lendário é sempre encontrar o teto do jogo.
const NIVEL_SELVAGEM : int = 100

## Nível em que ele fica ao ser capturado. É o coração da regra.
const NIVEL_AO_CAPTURAR : int = 1

## Taxa de captura. 3 é a mais baixa do jogo inteiro — o segundo lugar
## (Clefable/Snorlax) é 25, oito vezes mais fácil. Está cravada aqui, e um
## teste confere que `species.json` concorda e que ninguém mais desce tanto.
const TAXA_DE_CAPTURA : int = 3

static func e_lendario(species_id: int) -> bool:
	return species_id in ESPECIES

## O nível com que um lendário selvagem deve nascer. Devolve -1 pra quem não é
## lendário — quem chama continua com a lógica normal de faixa por zona.
static func nivel_de_spawn(species_id: int) -> int:
	return NIVEL_SELVAGEM if e_lendario(species_id) else -1

# ──────────────────────────────────────────────────────────────────────────────
# A captura
# ──────────────────────────────────────────────────────────────────────────────

## Transforma o registro de um lendário recém-capturado num Pokémon de nível 1.
##
## Mexe em TUDO que depende do nível, não só no número — deixar o nível em 1 e
## os stats de 100 seria pior que não fazer nada:
##
##   nível e experiência   voltam pro começo
##   HP máximo             recalculado pela fórmula única do jogo
##   vida atual            cheia (ele acabou de ser capturado)
##   golpes conhecidos     só o que a espécie sabe no nível 1
##   golpes equipados      idem, respeitando a capacidade do nível 1
##
## O que NÃO muda: IVs, nature e shiny. São o "quem ele é" — sorteados uma vez
## e para sempre. Rerolar isso na captura seria punir duas vezes.
##
## Recebe e devolve o dicionário de save (o mesmo formato de
## `SaveManager.make_caught_data`), pra poder ser testado sem subir o jogo.
static func zerar_ao_capturar(poke: Dictionary, especies: Dictionary,
		golpes: Dictionary, aprendiveis_nivel_1: Array) -> Dictionary:
	var id : int = int(poke.get("species_id", 0))
	if not e_lendario(id):
		return poke

	poke["level"] = NIVEL_AO_CAPTURAR
	poke["exp"] = NIVEL_AO_CAPTURAR * NIVEL_AO_CAPTURAR * NIVEL_AO_CAPTURAR

	var base : Dictionary = especies.get(str(id), {}).get("base_stats", {})
	var iv : int = int(poke.get("ivs", {}).get("hp", 31))
	var novo_hp : int = StatsDePokemon.hp_maximo(
		int(base.get("hp", 45)), NIVEL_AO_CAPTURAR, iv)
	poke["hp_max"] = novo_hp
	poke["hp_current"] = novo_hp
	poke["status"] = "none"

	# O kit também volta pro começo. Um Articuno nível 1 com Sky Attack seria
	# exatamente o "muito roubado" que a regra existe pra evitar.
	var tipos : Array = especies.get(str(id), {}).get("types", [])
	var kit : Array = KitDeCombate.montar(id, NIVEL_AO_CAPTURAR,
		aprendiveis_nivel_1, golpes, tipos, especies)
	var conhecidos : Array = []
	for entrada in aprendiveis_nivel_1:
		var mid : String = str(entrada.get("move", ""))
		if not mid.is_empty() and not (mid in conhecidos):
			conhecidos.append(mid)
	poke["known_moves"] = conhecidos

	var equipados : Array = []
	for mid in kit:
		var dados : Dictionary = golpes.get(str(mid), {})
		equipados.append({
			"id": str(mid),
			"pp_current": int(dados.get("pp", 10)),
			"pp_max": int(dados.get("pp", 10)),
		})
	poke["moves"] = equipados

	# Marca de origem: quem quiser contar história depois (Pokédex, tela de
	# resumo) sabe que este bicho foi capturado como lendário de nível 100.
	poke["capturado_como_lendario"] = true
	return poke

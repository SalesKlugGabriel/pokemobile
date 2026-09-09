## LootTable.gd — O que cada Pokémon deixa cair (reescrito em 09/09).
##
## 🔴 O que havia aqui antes, e por que foi jogado fora: uma tabela por "tier"
## que sorteava poção, pokébola, revive e Doce Raro. Ou seja, o jogo dava de
## GRAÇA exatamente o que o Gabriel disse que devia ser só de compra — e não
## dava nada do que devia dar. Um Magikarp e um Onix dropavam da mesma lista.
##
## Agora o drop é **por espécie**, lido de `species.json`, em três camadas
## (estrutura do otPokemon, que é a que faz a economia funcionar):
##
##   FRAGMENTO do tipo  55%  — o troco do dia a dia
##   AMULETO do tipo    14%  — o drop que anima
##   PEÇA DE ESPÉCIE     6%  — só aquele bicho dropa; é o que dá motivo pra
##                             caçar UM Pokémon em vez de qualquer um
##   PEDRA DE EVOLUÇÃO  0,4% — a única fonte no mundo aberto
##   MT DO TIPO         0,5% — **só de evolução final** (regra do Gabriel), e a
##                             única fonte dessas MTs no jogo inteiro
##
## Cada linha é sorteada SEPARADAMENTE: um mesmo Pokémon pode largar fragmento
## e MT no mesmo golpe. É o que faz o drop raro ser uma surpresa em cima do
## normal, e não uma alternativa a ele.
##
## A tabela em si mora em `data/pokemon/species.json`, gerada por
## `tools/gerar_loot.py` — que é também onde ficam os preços (o dossiê).
class_name LootTable
extends RefCounted

## Sorteia TUDO o que este Pokémon deixou cair. Devolve uma lista de
## `{id, quantity}` — pode vir vazia, pode vir com mais de um item.
## `sorte` (pontos de sorte do treinador) só empurra as camadas raras, nunca as
## comuns: sorte deve mudar o que é possível, não inflacionar o troco.
static func sortear_drops(species_id: int, sorte: int = 0) -> Array:
	var dados := _especie(species_id)
	var lista : Array = dados.get("drops", [])
	if lista.is_empty():
		return []
	# Sorte do treinador + item equipado de sorte (09/09) — os dois empurram só
	# as camadas raras (ver o filtro abaixo).
	var bonus : float = 1.0 + clampf(float(sorte) * 0.05, 0.0, 1.0) \
		+ ItensEquipados.valor_do_lider("sorte")
	var caiu : Array = []
	for linha in lista:
		var chance : float = float(linha.get("chance", 0.0))
		# Sorte só ajuda no que é raro (abaixo de 20%).
		if chance < 0.2:
			chance *= bonus
		if randf() > chance:
			continue
		var faixa : Array = linha.get("quantidade", [1, 1])
		var quantos : int = randi_range(int(faixa[0]), int(faixa[faixa.size() - 1]))
		caiu.append({"id": str(linha.get("id", "")), "quantity": maxi(1, quantos)})
	return caiu

## Mantida com o nome antigo porque `BattleResolver` já chamava assim; agora
## devolve o PRIMEIRO drop (ou vazio) pra quem só sabe lidar com um.
func roll_drop(_pokemon_level: int, luck_points: int, species_id: int = 0) -> Dictionary:
	var tudo := sortear_drops(species_id, luck_points)
	return tudo[0] if not tudo.is_empty() else {}

static func _especie(species_id: int) -> Dictionary:
	var laco := Engine.get_main_loop()
	if laco == null or not (laco is SceneTree):
		return {}
	var dados = (laco as SceneTree).root.get_node_or_null("GameData")
	if dados == null or not dados.has_method("get_species"):
		return {}
	return dados.get_species(species_id)

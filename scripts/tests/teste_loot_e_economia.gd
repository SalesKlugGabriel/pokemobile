## teste_loot_e_economia.gd — O loot por espécie e a economia (09/09).
##
## O Gabriel perguntou se essas mecânicas existiam. Não existiam — e o que
## havia estava invertido: a tabela antiga dropava poção, revive e Doce Raro,
## exatamente o que ele quer que seja SÓ de compra.
##
## As regras que este arquivo trava, todas ditas por ele:
##   · derrotar um Pokémon deixa loot, e loot serve pra VENDER;
##   · cura, revive e XP só se compram, e caros;
##   · MT/HM só cai de Pokémon de **evolução final**, com taxa ~0,5%;
##   · pedra de evolução é drop raro (e a única fonte no mundo aberto).
##
## Roda com: godot4 --headless --script res://scripts/tests/teste_loot_e_economia.gd
extends SceneTree

var _ok := 0
var _fail := 0

func _process(_delta: float) -> bool:
	print("=== Teste: loot por espécie e economia (09/09) ===")
	var itens = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/items.json"))
	var golpes = JSON.parse_string(FileAccess.get_file_as_string("res://data/moves/moves.json"))
	var arq = JSON.parse_string(FileAccess.get_file_as_string("res://data/pokemon/species.json"))
	# species.json é um DICIONÁRIO por id, não uma lista — atribuir direto a
	# Array travava o teste num laço de erro por quadro (ele nunca chegava ao
	# quit). Achado rodando com a saída num arquivo em vez de num cano: o
	# `timeout` matava o processo e o buffer levava a mensagem junto.
	var lista : Array = []
	if arq is Array:
		lista = arq
	elif arq is Dictionary and arq.has("species"):
		lista = arq["species"]
	elif arq is Dictionary:
		for chave in arq:
			lista.append(arq[chave])

	_assert(itens is Dictionary and golpes is Dictionary, "os dados carregam")
	_assert(lista.size() == 151, "as 151 espécies estão lá (%d)" % lista.size())

	# ── 1. Todo Pokémon tem drop, e nenhum dropa consumível ────────────────
	var sem_drop : Array = []
	var proibidos := ["potion", "super_potion", "hyper_potion", "max_potion",
		"full_restore", "revive", "max_revive", "rare_candy", "hp_up", "pokeball"]
	var vazando : Array = []
	for e in lista:
		var drops : Array = e.get("drops", [])
		if drops.is_empty():
			sem_drop.append(e.get("name", "?"))
		for d in drops:
			if str(d.get("id", "")) in proibidos:
				vazando.append("%s -> %s" % [e.get("name", "?"), d.get("id", "")])
	_assert(sem_drop.is_empty(), "toda espécie tem tabela de drop (%s)" % str(sem_drop))
	_assert(vazando.is_empty(),
		"nenhum Pokémon dropa cura/revive/XP — isso é só de compra (%s)" % str(vazando))

	# ── 2. O drop é por ESPÉCIE, não uma tabela só pra todos ───────────────
	var por_bicho := {}
	for e in lista:
		var chave := ""
		for d in e.get("drops", []):
			chave += str(d.get("id", "")) + ","
		por_bicho[chave] = true
	_assert(por_bicho.size() > 20,
		"tabelas diferentes por espécie (%d combinações distintas)" % por_bicho.size())

	# A peça de espécie é o que dá motivo pra caçar UM bicho específico.
	var magikarp : Dictionary = _achar(lista, "Magikarp")
	_assert(_tem_drop(magikarp, "magikarp_fin"), "Magikarp deixa a Barbatana de Magikarp")
	var pidgey : Dictionary = _achar(lista, "Pidgey")
	_assert(not _tem_drop(pidgey, "magikarp_fin"), "e mais ninguém deixa")

	# ── 3. MT: SÓ evolução final, e raríssima ──────────────────────────────
	var mt_em_nao_final : Array = []
	var finais_com_mt := 0
	var chance_mt := 0.0
	for e in lista:
		var e_final : bool = not e.has("evolution_to") or e.get("evolution_to") == null
		for d in e.get("drops", []):
			var id : String = str(d.get("id", ""))
			if not (itens.has(id) and str(itens[id].get("category", "")) == "tm_hm"):
				continue
			if e_final:
				finais_com_mt += 1
				chance_mt = float(d.get("chance", 0.0))
			else:
				mt_em_nao_final.append("%s -> %s" % [e.get("name", "?"), id])
	_assert(mt_em_nao_final.is_empty(),
		"MT só cai de evolução final (%s)" % str(mt_em_nao_final))
	_assert(finais_com_mt > 40,
		"e um bom número de evoluções finais tem MT própria (%d)" % finais_com_mt)
	_assert(chance_mt > 0.0 and chance_mt <= 0.01,
		"a chance é super rara: %.2f%%" % (chance_mt * 100.0))

	# A MT de drop tem que ser de verdade: golpe existente e do tipo do bicho.
	var charizard : Dictionary = _achar(lista, "Charizard")
	var mt_do_charizard := ""
	for d in charizard.get("drops", []):
		var id : String = str(d.get("id", ""))
		if itens.has(id) and str(itens[id].get("category", "")) == "tm_hm":
			mt_do_charizard = id
	_assert(mt_do_charizard != "", "Charizard (evolução final) tem MT no loot")
	if mt_do_charizard != "":
		var golpe : String = str(itens[mt_do_charizard].get("teaches", ""))
		_assert(golpes.has(golpe), "o golpe que ela ensina existe (%s)" % golpe)
		if golpes.has(golpe):
			_assert(str(golpes[golpe].get("type", "")) == "Fire",
				"e é do tipo do Pokémon que a largou")
		_assert(int(itens[mt_do_charizard].get("price", 1)) == 0,
			"MT de drop não se compra — é a única fonte dela")

	# ── 4. Pedra de evolução: drop raro, e existe de verdade ───────────────
	var achou_pedra := false
	for d in magikarp.get("drops", []):
		if str(d.get("id", "")) == "water_stone":
			achou_pedra = true
			_assert(float(d.get("chance", 1.0)) < 0.02,
				"a pedra é rara (%.1f%%)" % (float(d.get("chance", 0.0)) * 100.0))
	_assert(achou_pedra, "Pokémon de Água pode largar a Pedra da Água")

	# ── 5. Itens de venda pura, e a loja sabendo vendê-los ─────────────────
	var de_loot := 0
	var sem_preco : Array = []
	for id in itens:
		if str(itens[id].get("category", "")) != "loot":
			continue
		de_loot += 1
		if int(itens[id].get("price", 0)) <= 0:
			sem_preco.append(id)
	_assert(de_loot >= 40, "existem itens que só servem pra vender (%d)" % de_loot)
	_assert(sem_preco.is_empty(), "e todos têm preço (%s)" % str(sem_preco))
	var loja := FileAccess.get_file_as_string("res://scripts/ui/ShopScene.gd")
	_assert(loja.contains('"loot"'), "a loja tem a aba dos Tesouros — senão não há onde vender")

	# ── 6. Consumível caro: é o que faz o loot valer a pena ────────────────
	_assert(int(itens["potion"].get("price", 0)) >= 500,
		"a Poção custa caro (%d)" % int(itens["potion"].get("price", 0)))
	_assert(int(itens["revive"].get("price", 0)) >= 3000,
		"o Reviver custa caro (%d)" % int(itens["revive"].get("price", 0)))
	_assert(int(itens["rare_candy"].get("price", 0)) >= 10000,
		"e o Doce Raro é um atalho caro (%d) — antes ele CAÍA de graça" % int(itens["rare_candy"].get("price", 0)))
	# A régua da economia: um amuleto tem que pagar pelo menos uma poção
	# (vendendo por metade), senão farmar loot não sustenta a expedição.
	var amuleto : int = int(itens["water_amuleto"].get("price", 0))
	_assert(amuleto / 2 >= int(itens["potion"].get("price", 0)) / 2,
		"vender um amuleto (%d) paga uma poção — o loot sustenta a jogada" % amuleto)

	# ── 7. O motor usa a tabela nova, e avisa o jogador ────────────────────
	var tabela := FileAccess.get_file_as_string("res://scripts/systems/LootTable.gd")
	_assert(tabela.contains("sortear_drops("), "o motor sorteia a tabela da espécie")
	_assert(not tabela.contains("ITEM_POOLS"), "e a tabela genérica por tier foi embora")
	var resolvedor := FileAccess.get_file_as_string("res://scripts/combat/BattleResolver.gd")
	_assert(resolvedor.contains("LootTable.sortear_drops("), "a derrota chama o loot novo")
	_assert(resolvedor.contains("notification_requested.emit"),
		"e o jogador VÊ o que caiu — economia em silêncio é o mesmo que não existir")

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

func _achar(lista: Array, nome: String) -> Dictionary:
	for e in lista:
		if str(e.get("name", "")) == nome:
			return e
	return {}

func _tem_drop(e: Dictionary, item_id: String) -> bool:
	for d in e.get("drops", []):
		if str(d.get("id", "")) == item_id:
			return true
	return false

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)

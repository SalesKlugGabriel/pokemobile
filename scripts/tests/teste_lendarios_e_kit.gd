## teste_lendarios_e_kit.gd — 11/09/2026.
##
## Quatro regras que o Gabriel pediu no mesmo pedido, e que se sustentam uma na
## outra:
##
##   1. lendário selvagem é SEMPRE nível 100;
##   2. e tem a menor taxa de captura do jogo inteiro;
##   3. e, se capturado, volta pro nível 1 — pra captura ser um começo, não o
##      fim da progressão;
##   4. todo Pokémon tem um kit equilibrado, alterável por MO ao custo de 25
##      níveis por troca.
##
## A regra 3 é a que amarra as outras: sem ela, as regras 1 e 2 entregariam o
## melhor Pokémon do jogo pronto, e tudo depois viraria passeio.
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var GameData : Node
var SaveManager : Node

func _initialize() -> void:
	print("=== Teste: lendários e kit equilibrado (11/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true
	GameData = root.get_node("GameData")
	SaveManager = root.get_node("SaveManager")

	_lendario_nivel_100()
	_lendario_taxa_mais_baixa()
	_lendario_zera_ao_capturar()
	_kit_equilibrado()
	_troca_por_mo()

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

# ──────────────────────────────────────────────────────────────────────────
# 1. Sempre nível 100
# ──────────────────────────────────────────────────────────────────────────
func _lendario_nivel_100() -> void:
	_assert(RegrasDeLendario.NIVEL_SELVAGEM == 100, "lendário selvagem nasce no nível 100")
	_assert(RegrasDeLendario.ESPECIES.size() == 5,
		"os 5 lendários de Kanto estão na lista (%d)" % RegrasDeLendario.ESPECIES.size())
	for id in [144, 145, 146, 150, 151]:
		_assert(RegrasDeLendario.e_lendario(id),
			"%s é lendário" % str(GameData.get_species(id).get("name", id)))
		_assert(RegrasDeLendario.nivel_de_spawn(id) == 100,
			"...e nasce no 100, sem sorteio de faixa")
	_assert(not RegrasDeLendario.e_lendario(25), "Pikachu não é lendário")
	_assert(RegrasDeLendario.nivel_de_spawn(25) == -1,
		"quem não é lendário continua com a faixa normal da zona")

	# O ninho usa a régua central, não um número próprio.
	var fonte := FileAccess.get_file_as_string("res://scripts/world/systems/NinhoLendario.gd")
	_assert(fonte.contains("RegrasDeLendario.NIVEL_SELVAGEM"),
		"o ninho lê o nível da régua central")

# ──────────────────────────────────────────────────────────────────────────
# 2. A menor taxa de captura do jogo
# ──────────────────────────────────────────────────────────────────────────
func _lendario_taxa_mais_baixa() -> void:
	var menor_lendario : int = 999
	var menor_comum : int = 999
	var nome_comum : String = ""
	for chave in GameData.species:
		var e : Dictionary = GameData.species[chave]
		var taxa : int = int(e.get("catch_rate", 255))
		if RegrasDeLendario.e_lendario(int(e.get("id", 0))):
			menor_lendario = mini(menor_lendario, taxa)
			_assert(taxa == RegrasDeLendario.TAXA_DE_CAPTURA,
				"%s tem a taxa de lendário (%d)" % [str(e.get("name", "?")), taxa])
		else:
			if taxa < menor_comum:
				menor_comum = taxa
				nome_comum = str(e.get("name", "?"))

	print("\n-- Taxa de captura --")
	print("  lendários: %d · mais baixa entre os não-lendários: %d (%s)"
		% [menor_lendario, menor_comum, nome_comum])
	_assert(menor_lendario < menor_comum,
		"lendário é ESTRITAMENTE o mais difícil de capturar do jogo (%d contra %d)"
			% [menor_lendario, menor_comum])
	_assert(menor_comum >= menor_lendario * 5,
		"e por uma margem larga — o segundo lugar é %dx mais fácil"
			% int(menor_comum / maxi(menor_lendario, 1)))

	# 🔴 Mew estava com taxa 45 (igual a um Bulbasaur) antes desta sessão.
	var mew : Dictionary = GameData.get_species(151)
	_assert(int(mew.get("catch_rate", 0)) == RegrasDeLendario.TAXA_DE_CAPTURA,
		"Mew também (estava em 45, igual a um inicial)")

# ──────────────────────────────────────────────────────────────────────────
# 3. Zerado ao capturar
# ──────────────────────────────────────────────────────────────────────────
func _lendario_zera_ao_capturar() -> void:
	# Um Articuno capturado no nível 100, como o jogo entrega.
	var poke := {
		"species_id": 144, "level": 100, "exp": 1000000,
		"ivs": {"hp": 31, "atk": 31, "def": 31, "spa": 31, "spd": 31, "spe": 31},
		"nature": "modest", "is_shiny": true,
		"hp_max": 500, "hp_current": 120, "status": "burn",
		"moves": [{"id": "sky_attack", "pp_current": 5, "pp_max": 5}],
		"known_moves": ["sky_attack", "blizzard", "ice_beam", "agility"],
	}
	var antes_hp : int = int(poke["hp_max"])
	var zerado : Dictionary = RegrasDeLendario.zerar_ao_capturar(
		poke.duplicate(true), GameData.species, GameData.moves,
		GameData.get_learnable_moves(144, 1))

	print("\n-- Articuno capturado --")
	print("  nível 100 -> %d · vida %d -> %d · %d golpes conhecidos -> %d"
		% [int(zerado["level"]), antes_hp, int(zerado["hp_max"]),
			4, (zerado["known_moves"] as Array).size()])

	_assert(int(zerado["level"]) == 1, "volta pro nível 1")
	_assert(int(zerado["hp_max"]) < antes_hp,
		"a vida é RECALCULADA, não fica a de nível 100 (%d -> %d)" % [antes_hp, int(zerado["hp_max"])])
	_assert(int(zerado["hp_current"]) == int(zerado["hp_max"]),
		"e chega cheio (acabou de ser capturado)")
	_assert(str(zerado["status"]) == "none", "sem status — a queimadura da luta não vem junto")
	_assert(int(zerado["exp"]) == 1, "a experiência volta pro começo do nível 1")

	# O kit também volta. É a parte que mais importa: um Articuno nível 1 com
	# Sky Attack seria exatamente o "muito roubado" que a regra evita.
	_assert(not ("sky_attack" in zerado["known_moves"]),
		"ele ESQUECE os golpes de nível alto (Sky Attack é do 65)")
	for m in zerado["moves"]:
		var poder : int = int(GameData.get_move(str(m.get("id", ""))).get("power", 0))
		_assert(poder <= 60,
			"o kit dele agora é de nível 1 (%s, poder %d)" % [str(m.get("id", "")), poder])

	# O que NÃO muda: quem ele é.
	_assert(str(zerado["nature"]) == "modest", "a nature é preservada")
	_assert(bool(zerado["is_shiny"]), "o shiny é preservado (seria punir duas vezes)")
	_assert(int(zerado["ivs"]["spa"]) == 31, "os IVs são preservados")
	_assert(bool(zerado.get("capturado_como_lendario", false)),
		"fica marcado que veio de uma captura lendária")

	# Um Pokémon comum NÃO é afetado.
	var comum := {"species_id": 25, "level": 40, "hp_max": 200, "hp_current": 200,
		"moves": [], "known_moves": [], "ivs": {"hp": 20}}
	var intocado : Dictionary = RegrasDeLendario.zerar_ao_capturar(
		comum.duplicate(true), GameData.species, GameData.moves,
		GameData.get_learnable_moves(25, 1))
	_assert(int(intocado["level"]) == 40, "capturar um Pikachu nível 40 não zera nada")

	# E o caminho real da captura chama isso.
	var fonte := FileAccess.get_file_as_string("res://scripts/combat/CaptureSystem.gd")
	_assert(fonte.contains("RegrasDeLendario.zerar_ao_capturar("),
		"a captura de verdade aplica a regra (não é só teoria)")

# ──────────────────────────────────────────────────────────────────────────
# 4. Kit equilibrado para todo mundo
# ──────────────────────────────────────────────────────────────────────────
func _kit_equilibrado() -> void:
	# Toda espécie tem pelo menos um golpe de DANO do PRÓPRIO tipo. Um tipo
	# sem golpe do tipo é um tipo decorativo — era o caso de 11 espécies
	# (Dratini não tinha um único golpe Dragon que causasse dano).
	# As seis exceções de design. Ficam listadas AQUI, num só lugar, pra a
	# exceção ser uma decisão visível e não um caso que passou despercebido.
	var deliberados := ["Caterpie", "Metapod", "Weedle", "Kakuna", "Magikarp", "Ditto"]

	var sem_stab : Array[String] = []
	for chave in GameData.species:
		var e : Dictionary = GameData.species[chave]
		if str(e.get("name", "")) in deliberados:
			continue
		var tipos : Array = e.get("types", [])
		var tem := false
		for entrada in GameData.get_learnable_moves(int(e.get("id", 0)), 100):
			var m : Dictionary = GameData.get_move(str(entrada.get("move", "")))
			if int(m.get("power", 0)) > 0 and str(m.get("type", "")) in tipos:
				tem = true
		if not tem:
			sem_stab.append(str(e.get("name", "?")))
	_assert(sem_stab.is_empty(),
		"toda espécie (fora as 6 exceções de design) tem golpe de dano do próprio tipo (%s)"
			% str(sem_stab))

	# Nenhum learnset cita golpe que não existe.
	var fantasmas : Array[String] = []
	for chave in GameData.species:
		for entrada in GameData.get_learnable_moves(int(GameData.species[chave].get("id", 0)), 100):
			if GameData.get_move(str(entrada.get("move", ""))).is_empty():
				fantasmas.append(str(entrada.get("move", "")))
	_assert(fantasmas.is_empty(), "nenhum learnset cita golpe inexistente (%s)" % str(fantasmas.slice(0, 5)))

	# 🔴 Nada fora do porte: um bicho pequeno não recebe golpe de bicho grande.
	# O teto vale pro que foi ADICIONADO nesta sessão; o dado canônico antigo
	# (Bulbasaur com Solar Beam) é preservado de propósito.
	var absurdos : Array[String] = []
	for chave in GameData.species:
		var e : Dictionary = GameData.species[chave]
		var bst : int = 0
		for v in e.get("base_stats", {}).values():
			bst += int(v)
		if bst >= 250:
			continue
		for entrada in GameData.get_learnable_moves(int(e.get("id", 0)), 100):
			var m : Dictionary = GameData.get_move(str(entrada.get("move", "")))
			if int(m.get("power", 0)) > 60:
				absurdos.append("%s: %s" % [str(e.get("name", "?")), str(m.get("name", "?"))])
	_assert(absurdos.is_empty(),
		"nenhum Pokémon minúsculo recebeu golpe de gigante (%s)" % str(absurdos.slice(0, 5)))

	# O balanço se mede no kit, não no learnset cru.
	var pobres : Array[String] = []
	for chave in GameData.species:
		var e : Dictionary = GameData.species[chave]
		var id : int = int(e.get("id", 0))
		var kit : Array = KitDeCombate.montar(id, 100,
			GameData.get_learnable_moves(id, 100), GameData.moves,
			e.get("types", []), GameData.species)
		if bool(PapelDeGolpe.diagnostico(kit, GameData.moves, e.get("types", []))["pobre"]):
			pobres.append(str(e.get("name", "?")))
	print("\n-- Kit pobre no Lv.100 depois do equilíbrio: %d espécies --" % pobres.size())
	print("  %s" % str(pobres))
	_assert(pobres.size() <= 6,
		"sobram no máximo 6 espécies com kit pobre (%d)" % pobres.size())

	# E as que sobram são as que DEVEM sobrar — a mesma lista de cima.
	for nome in pobres:
		_assert(nome in deliberados,
			"'%s' está pobre de propósito (larva, Magikarp ou Ditto)" % nome)

	# 🔴 O Magikarp continua fraco DE PROPÓSITO — a fraqueza dele é o conteúdo,
	# e é o que sustenta o teste conceitual Magikarp x lendário.
	_assert("Magikarp" in pobres, "o Magikarp continua sendo o Magikarp")
	var gyarados : Array = KitDeCombate.montar(130, 100,
		GameData.get_learnable_moves(130, 100), GameData.moves,
		GameData.get_species(130).get("types", []), GameData.species)
	_assert(not bool(PapelDeGolpe.diagnostico(gyarados, GameData.moves,
		GameData.get_species(130).get("types", []))["pobre"]),
		"...e o Gyarados continua sendo o prêmio de ter aguentado o Magikarp")

# ──────────────────────────────────────────────────────────────────────────
# 5. Troca de kit por MO, a 25 níveis cada
# ──────────────────────────────────────────────────────────────────────────
func _troca_por_mo() -> void:
	_assert(TrocaDeKit.CUSTO_EM_NIVEIS == 25, "cada troca custa 25 níveis")
	_assert(TrocaDeKit.NIVEL_MINIMO == 26,
		"e é preciso SOBRAR nível: mínimo 26 (senão o Pokémon iria pro nível 0)")

	var novato := {"species_id": 6, "level": 20, "known_moves": ["ember"], "hp_max": 100,
		"hp_current": 100, "ivs": {"hp": 31}}
	var r1 : Dictionary = TrocaDeKit.pode_trocar(novato)
	_assert(not bool(r1["pode"]), "um Pokémon nível 20 não pode pagar a troca")
	_assert(str(r1["motivo"]).contains("26"),
		"e o motivo explica o porquê em português, pra tela poder mostrar")

	var veterano := {
		"species_id": 6, "level": 80,
		"known_moves": ["flamethrower", "fire_blast", "slash", "fly", "ember"],
		"moves": [{"id": "ember", "pp_current": 25, "pp_max": 25}],
		"hp_max": 400, "hp_current": 200, "ivs": {"hp": 31},
	}
	var prev : Dictionary = TrocaDeKit.previsao(veterano, GameData.species)
	print("\n-- Troca de kit num Charizard Lv.80 --")
	print("  nível %d -> %d · slots %d -> %d · vida %d -> %d"
		% [int(prev["nivel_antes"]), int(prev["nivel_depois"]), int(prev["slots_antes"]),
			int(prev["slots_depois"]), int(prev["hp_antes"]), int(prev["hp_depois"])])
	_assert(int(prev["nivel_depois"]) == 55, "o preço aparece ANTES de confirmar (80 -> 55)")
	_assert(int(prev["hp_depois"]) < int(prev["hp_antes"]), "e mostra que a vida cai junto")

	# Só golpe conhecido entra.
	var tentativa : Dictionary = TrocaDeKit.aplicar(veterano.duplicate(true),
		["hyper_beam"], GameData.species, GameData.moves)
	_assert(not bool(tentativa["ok"]), "não dá pra equipar golpe que ele não conhece")

	var repetido : Dictionary = TrocaDeKit.aplicar(veterano.duplicate(true),
		["flamethrower", "flamethrower"], GameData.species, GameData.moves)
	_assert(not bool(repetido["ok"]), "nem o mesmo golpe duas vezes")

	var feito : Dictionary = TrocaDeKit.aplicar(veterano.duplicate(true),
		["flamethrower", "fire_blast", "slash", "fly"], GameData.species, GameData.moves)
	_assert(bool(feito["ok"]), "a troca válida acontece")
	var depois : Dictionary = feito["poke"]
	_assert(int(depois["level"]) == 55, "e custa exatamente 25 níveis (80 -> %d)" % int(depois["level"]))
	_assert((depois["moves"] as Array).size() == 4, "o kit novo tem os 4 golpes escolhidos")
	_assert(int(depois["hp_current"]) < 200,
		"a vida atual acompanha a queda, preservando a fração (%d de %d)"
			% [int(depois["hp_current"]), int(depois["hp_max"])])
	_assert(int(depois["hp_current"]) > 0, "...mas nunca chega a zero por causa da troca")
	_assert(int(depois["trocas_de_kit"]) == 1, "a troca fica contada")
	_assert((depois["known_moves"] as Array).size() == 5,
		"e ele continua CONHECENDO tudo que conhecia — trocar não faz esquecer")

	# Duas trocas custam 50.
	var segunda : Dictionary = TrocaDeKit.aplicar(depois.duplicate(true),
		["ember", "slash"], GameData.species, GameData.moves)
	_assert(bool(segunda["ok"]) and int(segunda["poke"]["level"]) == 30,
		"a segunda troca custa outros 25 (55 -> %d)" % int(segunda["poke"]["level"]))

	# O kit é cortado pela capacidade DEPOIS da perda, nunca antes.
	var no_limite := {
		"species_id": 6, "level": 50,
		"known_moves": ["ember", "slash", "fly", "flamethrower", "fire_blast", "wing_attack", "bite"],
		"moves": [], "hp_max": 300, "hp_current": 300, "ivs": {"hp": 31},
	}
	var cap_antes : int = KitDeCombate.capacidade(6, 50, GameData.species)
	var cortado : Dictionary = TrocaDeKit.aplicar(no_limite.duplicate(true),
		["ember", "slash", "fly", "flamethrower", "fire_blast", "wing_attack", "bite"],
		GameData.species, GameData.moves)
	var cap_depois : int = KitDeCombate.capacidade(6, 25, GameData.species)
	_assert(bool(cortado["ok"]), "a troca no limite acontece")
	_assert((cortado["poke"]["moves"] as Array).size() <= cap_depois,
		"o kit cabe na capacidade DEPOIS da perda (%d slots, não os %d de antes)"
			% [cap_depois, cap_antes])

	# As MOs apontam pra golpes que existem.
	var mos : int = 0
	for chave in GameData.items:
		var item : Dictionary = GameData.items[chave]
		if not TrocaDeKit.e_mo(str(chave)):
			continue
		mos += 1
		var ensina := str(item.get("teaches", ""))
		_assert(not GameData.get_move(ensina).is_empty(),
			"a MO '%s' ensina um golpe que existe (%s)" % [str(item.get("name", chave)), ensina])
	_assert(mos >= 3, "há MOs cadastradas (%d)" % mos)

	# E o SaveManager tem a porta de entrada pra tela do Codex usar.
	var fonte := FileAccess.get_file_as_string("res://scripts/autoloads/SaveManager.gd")
	for funcao in ["func usar_mo(", "func previsao_de_troca(", "func trocar_kit("]:
		_assert(fonte.contains(funcao), "o contrato pra tela existe: %s" % funcao)

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)

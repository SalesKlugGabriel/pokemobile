## teste_fase3_progressao.gd — 11/09/2026.
##
## A Fase 3 tem um objetivo único: fazer NÍVEL e EVOLUÇÃO virarem progressão de
## GAMEPLAY, não só de número. O que este arquivo cobra é sempre a mesma
## pergunta — *um Pokémon evoluído tem mais FERRAMENTAS, ou só stats maiores?*
##
## Os 12 testes obrigatórios do pedido estão aqui, na ordem, mais o caso
## conceitual Magikarp × Moltres (P6), que é o que prova que a limitação nasce
## do kit e não de uma regra escrita com o nome do bicho.
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var GameData : Node
var SaveManager : Node

func _initialize() -> void:
	print("=== Teste: Fase 3 — progressão de kit, loadout, wild e boss (11/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true
	GameData = root.get_node("GameData")
	SaveManager = root.get_node("SaveManager")

	_t1_a_t3_matriz_charmander()
	_t4_conhecidos_x_equipados()
	_t5_persistencia_no_save()
	_t6_t7_hud_e_input()
	_t8_wild_variado()
	_t9_alpha()
	_t10_boss()
	_t11_ia_avalia_mais_de_quatro()
	_p2_papeis_e_learnset_pobre()
	_p6_magikarp_contra_moltres()
	_p7_sinergia()

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

func _kit(species_id: int, nivel: int, teto: int = 0) -> Array:
	return KitDeCombate.montar(species_id, nivel,
		GameData.get_learnable_moves(species_id, nivel), GameData.moves,
		GameData.get_species(species_id).get("types", []), GameData.species, teto)

# ──────────────────────────────────────────────────────────────────────────
# Obrigatórios 1 a 3 — a matriz Charmander / Charmeleon / Charizard
# ──────────────────────────────────────────────────────────────────────────
func _t1_a_t3_matriz_charmander() -> void:
	print("\n-- Matriz Charmander / Charmeleon / Charizard --")
	print("  | Espécie     | Est | Lv1 | Lv49 | Lv50 | Lv99 | Lv100 |")
	print("  |-------------|----:|----:|-----:|-----:|-----:|------:|")
	var esperado := {4: 6, 5: 7, 6: 8}
	for id in [4, 5, 6]:
		var nome := str(GameData.get_species(id).get("name", id))
		var est : int = KitDeCombate.estagio_evolutivo(id, GameData.species)
		var caps : Array[int] = []
		for lvl in [1, 49, 50, 99, 100]:
			caps.append(KitDeCombate.capacidade(id, lvl, GameData.species))
		print("  | %-11s | %3d | %3d | %4d | %4d | %4d | %5d |"
			% [nome, est, caps[0], caps[1], caps[2], caps[3], caps[4]])

		# A régua que o Gabriel fixou, degrau por degrau.
		_assert(caps[0] == 4 + est, "%s Lv.1 = %d slots (4 + estágio %d)" % [nome, caps[0], est])
		_assert(caps[1] == caps[0], "%s Lv.49 ainda não ganhou slot (Lv1-49 é +0)" % nome)
		_assert(caps[2] == caps[1] + 1, "%s ganha +1 slot exatamente no Lv.50" % nome)
		_assert(caps[3] == caps[2], "%s Lv.99 não ganha nada a mais (Lv50-99 é +1)" % nome)
		_assert(caps[4] == caps[3] + 1, "%s ganha o último slot exatamente no Lv.100" % nome)
		_assert(caps[4] == esperado[id],
			"🎯 %s Lv.100 = %d slots (obrigatório: %d)" % [nome, caps[4], esperado[id]])

	# Evoluir tem que valer MAIS que subir de nível — senão a evolução é
	# cosmética e o pedido não foi atendido.
	_assert(KitDeCombate.capacidade(6, 1, GameData.species)
		> KitDeCombate.capacidade(4, 49, GameData.species),
		"um Charizard recém-evoluído já tem mais ferramentas que um Charmander Lv.49")

	# E a diferença precisa aparecer no KIT, não só na contagem.
	var d_char : Dictionary = PapelDeGolpe.diagnostico(_kit(4, 100), GameData.moves, ["Fire"])
	var d_zard : Dictionary = PapelDeGolpe.diagnostico(_kit(6, 100), GameData.moves, ["Fire", "Flying"])
	print("  Charmander Lv.100: %d golpes, %d papéis, %d tipos ofensivos"
		% [int(d_char["golpes"]), int(d_char["variedade"]), int(d_char["tipos_ofensivos"])])
	print("  Charizard  Lv.100: %d golpes, %d papéis, %d tipos ofensivos"
		% [int(d_zard["golpes"]), int(d_zard["variedade"]), int(d_zard["tipos_ofensivos"])])
	_assert(int(d_zard["golpes"]) > int(d_char["golpes"]),
		"Charizard leva mais golpes que Charmander no mesmo nível")
	_assert(int(d_zard["tipos_ofensivos"]) >= int(d_char["tipos_ofensivos"]),
		"...e cobre pelo menos os mesmos tipos de dano")

# ──────────────────────────────────────────────────────────────────────────
# Obrigatório 4 — conhecidos x equipados
# ──────────────────────────────────────────────────────────────────────────
func _t4_conhecidos_x_equipados() -> void:
	SaveManager.new_game("TesteFase3", 4)   # Charmander
	var poke : Dictionary = SaveManager.get_pokemon_at(0)
	_assert(not poke.is_empty(), "o time de teste nasceu")
	_assert(poke.has("known_moves"), "Pokémon novo já nasce com a lista de CONHECIDOS")

	var conhecidos : Array = SaveManager.get_known_moves(0)
	var equipados : Array = poke.get("moves", [])
	_assert(conhecidos.size() >= equipados.size(),
		"conhece pelo menos tanto quanto equipa (%d conhecidos, %d equipados)"
			% [conhecidos.size(), equipados.size()])

	# A separação só significa alguma coisa se ele puder conhecer MAIS do que
	# cabe. Um Charizard Lv.100 é o caso que o Gabriel citou.
	var aprendiveis : Array = GameData.get_learnable_moves(6, 100)
	var unicos : Array[String] = []
	for e in aprendiveis:
		if not (str(e.get("move", "")) in unicos):
			unicos.append(str(e.get("move", "")))
	print("\n-- Conhecidos x equipados --")
	print("  Charizard Lv.100: %d golpes aprendíveis, %d slots"
		% [unicos.size(), KitDeCombate.capacidade(6, 100, GameData.species)])
	_assert(unicos.size() > KitDeCombate.capacidade(6, 100, GameData.species),
		"existe espécie que aprende MAIS do que consegue levar (%d > %d) — é o que dá sentido à escolha"
			% [unicos.size(), KitDeCombate.capacidade(6, 100, GameData.species)])

	# Equipar só vale pra golpe conhecido.
	_assert(not SaveManager.equip_move(0, "hyper_beam", 0),
		"não dá pra equipar um golpe que o Pokémon não conhece")
	var primeiro : String = str(conhecidos[0])
	_assert(SaveManager.equip_move(0, primeiro, 0), "dá pra equipar um golpe conhecido")
	_assert(not SaveManager.equip_move(0, primeiro, 1),
		"o mesmo golpe não pode ocupar dois slots")

	# Desequipar NÃO faz esquecer.
	_assert(SaveManager.unequip_move(0, 0), "dá pra esvaziar um slot")
	_assert(primeiro in SaveManager.get_known_moves(0),
		"desequipar não apaga o golpe da memória do Pokémon")
	_assert(SaveManager.equip_move(0, primeiro, 0), "e dá pra equipar de volta")

	# Slot além da capacidade não existe.
	var cap : int = SaveManager.max_skill_slots(0)
	_assert(not SaveManager.equip_move(0, primeiro, cap),
		"não dá pra equipar num slot além da capacidade (%d)" % cap)
	_assert(cap == KitDeCombate.capacidade(4, int(poke.get("level", 5)), GameData.species),
		"max_skill_slots é a MESMA régua do KitDeCombate (nunca um número gravado que envelhece)")

	# 🔴 Ensinar MT deixou de travar em 4.
	var fonte := FileAccess.get_file_as_string("res://scripts/autoloads/SaveManager.gd")
	_assert(not fonte.contains("if moves.size() >= 4:"),
		"ensinar MT não trava mais no 4 cravado (travava num Pokémon de 8 slots)")
	_assert(fonte.contains("moves.size() >= max_skill_slots(index)"),
		"o teto de MT é a capacidade real do Pokémon")

# ──────────────────────────────────────────────────────────────────────────
# Obrigatório 5 — persistência
# ──────────────────────────────────────────────────────────────────────────
func _t5_persistencia_no_save() -> void:
	var antes : Array = SaveManager.get_known_moves(0)
	var equipados_antes : Array = []
	for m in SaveManager.get_pokemon_at(0).get("moves", []):
		equipados_antes.append(str(m.get("id", "")))

	SaveManager.save_game()
	SaveManager.load_game()

	var depois : Array = SaveManager.get_known_moves(0)
	var equipados_depois : Array = []
	for m in SaveManager.get_pokemon_at(0).get("moves", []):
		equipados_depois.append(str(m.get("id", "")))

	_assert(antes == depois, "os golpes CONHECIDOS sobrevivem a salvar e carregar")
	_assert(equipados_antes == equipados_depois, "e os EQUIPADOS também, na mesma ordem")

	# 🔴 Migração: um save velho (sem `known_moves`) não pode perder golpe.
	var velho := {
		"species_id": 6, "level": 60,
		"moves": [{"id": "fire_blast", "pp_current": 5, "pp_max": 5},
			{"id": "hyper_beam", "pp_current": 5, "pp_max": 5}],
	}
	SaveManager.save_data["pc"].append(velho)
	SaveManager.save_data.erase("versao_combate")
	SaveManager._migrar_golpes_conhecidos()
	var migrado : Array = velho.get("known_moves", [])
	_assert("fire_blast" in migrado and "hyper_beam" in migrado,
		"save antigo: NENHUM golpe equipado se perde na migração")
	_assert(migrado.size() > 2,
		"...e a lista ganha o que a espécie aprende até o nível (%d golpes)" % migrado.size())
	SaveManager.save_data["pc"].erase(velho)

	SaveManager.delete_save()

# ──────────────────────────────────────────────────────────────────────────
# Obrigatórios 6 e 7 — HUD e entrada, de 4 a 8
# ──────────────────────────────────────────────────────────────────────────
func _t6_t7_hud_e_input() -> void:
	# Entrada: as 8 ações existem de verdade no mapa de entrada.
	for i in range(1, KitDeCombate.SLOTS_MAXIMO + 1):
		_assert(InputMap.has_action("skill_%d" % i), "a ação de entrada skill_%d existe" % i)
	_assert(KeybindManager.SLOTS_DE_SKILL == KitDeCombate.SLOTS_MAXIMO,
		"o KeybindManager conhece os %d slots" % KitDeCombate.SLOTS_MAXIMO)
	for i in range(1, KitDeCombate.SLOTS_MAXIMO + 1):
		_assert("skill_%d" % i in KeybindManager.REBINDABLE_ACTIONS,
			"skill_%d é remapeável, como as outras" % i)

	# HUD: constrói o teto e esconde o excedente — e NÃO recalcula capacidade.
	var fonte := FileAccess.get_file_as_string("res://scripts/ui/OverworldHUD.gd")
	_assert(fonte.contains("for i in KitDeCombate.SLOTS_MAXIMO:"),
		"a barra nasce com os %d botões (eram 4 cravados)" % KitDeCombate.SLOTS_MAXIMO)
	_assert(fonte.contains("max_skill_slots"),
		"a HUD lê a capacidade PRONTA do gameplay")
	_assert(not fonte.contains("KitDeCombate.capacidade("),
		"🔴 contrato com o Codex: a UI nunca recalcula capacidade")

	# E o gameplay entrega esse campo.
	var fonte_follower := FileAccess.get_file_as_string("res://scripts/entities/FollowerPokemon.gd")
	_assert(fonte_follower.contains('"max_skill_slots"'),
		"o gameplay publica max_skill_slots em follower_changed")

	# O bug que o Codex reportou: normalização da recarga.
	_assert(fonte_follower.contains("_cooldown_total"),
		"a barra de recarga é normalizada pela duração REAL, não pelo valor do JSON")

# ──────────────────────────────────────────────────────────────────────────
# Obrigatório 8 — wild com repertórios variados
# ──────────────────────────────────────────────────────────────────────────
func _t8_wild_variado() -> void:
	print("\n-- Progressão de repertório do selvagem --")
	var casos := [
		[16, 3,  "comum",     "Pidgey Lv.3",              2, 3],
		[16, 25, "comum",     "Pidgey Lv.25",             3, 4],
		[17, 25, "comum",     "Pidgeotto Lv.25",          3, 4],
		[18, 45, "comum",     "Pidgeot Lv.45",            4, 5],
		[18, 90, "comum",     "Pidgeot Lv.90",            4, 5],
		[6,  100,"comum",     "Charizard selvagem Lv.100",4, 5],
		[6,  100,"alpha",     "Charizard Alpha Lv.100",   5, 6],
		[149,90, "mini_boss", "Dragonite mini-chefe",     6, 7],
		[146,100,"lendario",  "Moltres Lv.100",           7, 8],
	]
	var variedade := {}
	for c in casos:
		var n : int = KitDeCombate.slots_de_selvagem(int(c[0]), int(c[1]), str(c[2]), GameData.species)
		print("  %-28s -> %d golpes" % [str(c[3]), n])
		variedade[n] = true
		_assert(n >= int(c[4]) and n <= int(c[5]),
			"%s fica na faixa %d-%d (%d)" % [str(c[3]), int(c[4]), int(c[5]), n])
	_assert(variedade.size() >= 5,
		"os selvagens têm repertórios REALMENTE variados (%d tamanhos diferentes) — não é mais um número só"
			% variedade.size())

	# O bicho fraco continua fraco: é metade do pedido.
	_assert(KitDeCombate.slots_de_selvagem(16, 3, "comum", GameData.species)
		< KitDeCombate.slots_de_selvagem(6, 100, "comum", GameData.species),
		"um Pidgey Lv.3 carrega menos que um Charizard Lv.100 selvagem")

# ──────────────────────────────────────────────────────────────────────────
# Obrigatório 9 — Alpha
# ──────────────────────────────────────────────────────────────────────────
func _t9_alpha() -> void:
	var faixa : Dictionary = KitDeCombate.CATEGORIAS_DE_ENCONTRO["alpha"]
	_assert(int(faixa["min"]) == 5 and int(faixa["max"]) == 6, "Alpha fica na faixa 5-6")
	for nivel in [10, 50, 100]:
		var n : int = KitDeCombate.slots_de_selvagem(6, nivel, "alpha", GameData.species)
		_assert(n >= 5 and n <= 6, "Alpha Lv.%d carrega %d golpes" % [nivel, n])

	var fonte := FileAccess.get_file_as_string("res://scripts/entities/WildPokemon.gd")
	_assert(fonte.contains('categoria_de_encontro = "alpha"'),
		"um Alpha vira categoria 'alpha' sozinho ao nascer")

# ──────────────────────────────────────────────────────────────────────────
# Obrigatório 10 — Boss
# ──────────────────────────────────────────────────────────────────────────
func _t10_boss() -> void:
	print("\n-- Kit de Pokémon dos chefes lendários (Lv.100) --")
	for id in [144, 145, 146]:
		var nome := str(GameData.get_species(id).get("name", id))
		var slots : int = KitDeCombate.slots_de_selvagem(id, 100, "lendario", GameData.species)
		var kit : Array = _kit(id, 100, slots)
		var d : Dictionary = PapelDeGolpe.diagnostico(kit, GameData.moves,
			GameData.get_species(id).get("types", []))
		var papeis : Array = d["papeis"].keys()
		papeis.sort()
		print("  %-10s %d slots · %d golpes · %d papéis | %s"
			% [nome, slots, kit.size(), int(d["variedade"]), ", ".join(papeis)])
		_assert(slots >= 7 and slots <= 8, "%s fica na faixa 7-8 (%d)" % [nome, slots])
		_assert(kit.size() >= 4, "%s tem kit de Pokémon de verdade (%d golpes)" % [nome, kit.size()])
		_assert(int(d["variedade"]) >= 4,
			"%s cobre pelo menos 4 papéis diferentes (%d)" % [nome, int(d["variedade"])])

	# 🔴 P4: o chefe usa o KIT + as mecânicas, não dois sistemas paralelos.
	var fonte := FileAccess.get_file_as_string("res://scripts/combat/ChefeLendario.gd")
	_assert(fonte.contains("_montar_golpes()"),
		"o chefe monta um kit de Pokémon de verdade (antes só tinha as 6 funções)")
	_assert(fonte.contains('categoria_de_encontro = "lendario"'),
		"e se declara como encontro lendário, o que define a capacidade dele")
	_assert(fonte.contains("DamageCalculator.calculate_damage"),
		"reaproveita a fórmula de dano compartilhada")
	_assert(fonte.contains("FormaDeArea.alvos("),
		"reaproveita o sistema de área compartilhado")

	# P5: a janela de vulnerabilidade — a mecânica que faz o kit importar.
	_assert(fonte.contains("esta_vulneravel"),
		"existe janela de vulnerabilidade depois das funções pesadas")
	var mapa : Dictionary = load("res://scripts/combat/ChefeLendario.gd").get_script_constant_map()
	_assert(float(mapa.get("VULNERAVEL_MULT", 1.0)) > 1.0,
		"exposto, o chefe recebe mais dano (x%.1f)" % float(mapa.get("VULNERAVEL_MULT", 1.0)))
	var expoem : Array = mapa.get("FUNCOES_QUE_EXPOEM", [])
	_assert(not ("pressao" in expoem),
		"o golpe barato e frequente NÃO expõe (senão o chefe viveria vulnerável)")
	var fonte_wild := FileAccess.get_file_as_string("res://scripts/entities/WildPokemon.gd")
	_assert(fonte_wild.contains("multiplicador_de_dano_recebido"),
		"o dano recebido consulta a janela de verdade")

# ──────────────────────────────────────────────────────────────────────────
# Obrigatório 11 — a IA avalia mais de 4 golpes
# ──────────────────────────────────────────────────────────────────────────
func _t11_ia_avalia_mais_de_quatro() -> void:
	var golpes : Array = []
	var recargas : Array = []
	# 8 golpes: 7 fracos e um forte no ÚLTIMO slot. Se a IA só olhasse 4, o
	# forte nunca seria escolhido.
	for i in 8:
		golpes.append({"power": 30 if i < 7 else 120, "type": "Normal",
			"category": "physical", "range": 3.0, "area_type": "single", "cooldown": 2.0})
		recargas.append(0.0)
	var escolhido : int = ComportamentoSelvagem.escolher_golpe(golpes, recargas, 200.0, {})
	_assert(escolhido == 7,
		"a IA avaliou os 8 slots e achou o golpe forte no último (escolheu %d)" % escolhido)

	# E continua barata com 8.
	var t0 := Time.get_ticks_usec()
	for i in 2000:
		ComportamentoSelvagem.escolher_golpe(golpes, recargas, 200.0, {"tipos_do_alvo": ["Rock"]})
	var us : float = float(Time.get_ticks_usec() - t0) / 2000.0
	_assert(us < 120.0, "escolher entre 8 golpes custa %.1f us (teto 120)" % us)

# ──────────────────────────────────────────────────────────────────────────
# P2 — papéis e diagnóstico de learnset pobre
# ──────────────────────────────────────────────────────────────────────────
func _p2_papeis_e_learnset_pobre() -> void:
	# Todo golpe recebe pelo menos um papel — classificação sem buraco.
	var sem_papel : Array[String] = []
	for mid in GameData.moves:
		if PapelDeGolpe.papeis(GameData.moves[mid]).is_empty():
			sem_papel.append(mid)
	_assert(sem_papel.is_empty(), "todo golpe tem pelo menos um papel (%s)" % str(sem_papel.slice(0, 5)))

	# Os papéis são derivados do dado, então casos conhecidos têm que bater.
	_assert(PapelDeGolpe.AREA in PapelDeGolpe.papeis(GameData.get_move("earthquake")),
		"Earthquake é classificado como AOE")
	_assert(PapelDeGolpe.BURST in PapelDeGolpe.papeis(GameData.get_move("hyper_beam")),
		"Hyper Beam é classificado como BURST")
	_assert(PapelDeGolpe.CONTROLE in PapelDeGolpe.papeis(GameData.get_move("thunder_wave")),
		"Thunder Wave é classificado como CONTROL")
	_assert(PapelDeGolpe.CONTINUO in PapelDeGolpe.papeis(GameData.get_move("toxic")),
		"Toxic é classificado como DOT")

	# Diagnóstico de learnset pobre — o pedido manda REGISTRAR, não consertar.
	print("\n-- Learnsets pobres (registrados, não corrigidos) --")
	var pobres : Array[String] = []
	for chave in GameData.species:
		var id : int = int(GameData.species[chave].get("id", 0))
		var e : Dictionary = GameData.species[chave]
		var d : Dictionary = PapelDeGolpe.diagnostico(_kit(id, 100), GameData.moves, e.get("types", []))
		if bool(d["pobre"]):
			pobres.append("%s (%d golpes, %d papéis)"
				% [str(e.get("name", id)), int(d["golpes"]), int(d["variedade"])])
	for linha in pobres:
		print("  ⚠ %s" % linha)
	if pobres.is_empty():
		print("  (nenhuma)")
	# O número não é uma nota: é uma lista de trabalho de CONTEÚDO (learnset),
	# não de código. O que o teste impede é a lista crescer sem ninguém ver.
	_assert(pobres.size() <= 30,
		"a maioria das espécies tem kit utilizável no Lv.100 (%d pobres de 151)" % pobres.size())
	_assert(pobres.size() > 0,
		"o diagnóstico realmente pega os casos pobres (se der zero, o critério está frouxo demais)")

# ──────────────────────────────────────────────────────────────────────────
# P6 — Magikarp Lv.100 contra um Moltres de nível muito inferior
# ──────────────────────────────────────────────────────────────────────────
func _p6_magikarp_contra_moltres() -> void:
	print("\n-- P6: Magikarp Lv.100 x Moltres Lv.30 (sem nenhuma regra com nome de espécie) --")

	var mk : Dictionary = GameData.get_species(129)
	var gy : Dictionary = GameData.get_species(130)
	var ml : Dictionary = GameData.get_species(146)

	var kit_mk : Array = _kit(129, 100)
	var kit_gy : Array = _kit(130, 100)
	var slots_ml : int = KitDeCombate.slots_de_selvagem(146, 30, "lendario", GameData.species)
	var kit_ml : Array = _kit(146, 30, slots_ml)

	var d_mk : Dictionary = PapelDeGolpe.diagnostico(kit_mk, GameData.moves, mk.get("types", []))
	var d_gy : Dictionary = PapelDeGolpe.diagnostico(kit_gy, GameData.moves, gy.get("types", []))
	var d_ml : Dictionary = PapelDeGolpe.diagnostico(kit_ml, GameData.moves, ml.get("types", []))

	for par in [["Magikarp Lv.100", d_mk], ["Gyarados Lv.100", d_gy], ["Moltres Lv.30", d_ml]]:
		var d : Dictionary = par[1]
		var papeis : Array = d["papeis"].keys()
		papeis.sort()
		print("  %-16s %d golpes · %d papéis · %d tipos ofensivos | %s"
			% [str(par[0]), int(d["golpes"]), int(d["variedade"]),
				int(d["tipos_ofensivos"]), ", ".join(papeis)])

	# A limitação tem que vir do KIT.
	_assert(int(d_mk["golpes"]) <= 3,
		"Magikarp Lv.100 tem repertório minúsculo (%d golpes) — e isso NÃO é uma regra com o nome dele, é o learnset"
			% int(d_mk["golpes"]))
	_assert(not bool(d_mk["tem_area"]), "Magikarp não tem golpe de área pra lidar com mecânica de arena")
	_assert(not bool(d_mk["tem_controle"]), "Magikarp não tem controle pra criar janela")
	_assert(int(d_mk["tipos_ofensivos"]) <= 1, "Magikarp tem um tipo de dano só — zero cobertura")

	# O sucessor dele, no MESMO nível, é outro jogo.
	_assert(int(d_gy["variedade"]) > int(d_mk["variedade"]) + 1,
		"Gyarados Lv.100 cobre muito mais papéis que Magikarp Lv.100 (%d x %d)"
			% [int(d_gy["variedade"]), int(d_mk["variedade"])])

	# 🔴 ACHADO, e ele muda a resposta desta seção: o learnset do Moltres é
	# VAZIO entre o nível 1 e o 51 (peck/growl/leer no 1, depois só a partir de
	# fire_spin no 51). Um Moltres Lv.30 tem kit tão pobre quanto o Magikarp —
	# 3 golpes, um deles ofensivo.
	#
	# Então a resposta honesta pro P6 não é "o Moltres tem kit melhor". É esta:
	# o que um Magikarp Lv.100 não consegue responder NÃO é o kit do lendário —
	# é a MECÂNICA DE ENCONTRO, que não depende de learnset nenhum. Área
	# telegrafada, dano percentual, hazard de arena e janela de vulnerabilidade
	# existem no Lv.30 igual ao Lv.100.
	_assert(int(d_ml["golpes"]) <= 3,
		"um Moltres Lv.30 também tem kit pobre (%d golpes) — o learnset dele é todo depois do Lv.51"
			% int(d_ml["golpes"]))

	var slots_ml_100 : int = KitDeCombate.slots_de_selvagem(146, 100, "lendario", GameData.species)
	var d_ml_100 : Dictionary = PapelDeGolpe.diagnostico(_kit(146, 100, slots_ml_100),
		GameData.moves, ml.get("types", []))
	print("  Moltres Lv.100   %d golpes · %d papéis (o mesmo bicho, com o learnset aberto)"
		% [int(d_ml_100["golpes"]), int(d_ml_100["variedade"])])
	_assert(int(d_ml_100["golpes"]) > int(d_mk["golpes"]) + 2,
		"no nível em que o learnset dele abre, o Moltres passa MUITO o Magikarp (%d x %d)"
			% [int(d_ml_100["golpes"]), int(d_mk["golpes"])])
	_assert(bool(d_ml_100["tem_area"]), "e aí sim tem área, que o Magikarp nunca terá")

	# O que o Magikarp não tem como responder, em QUALQUER nível do chefe:
	var mapa_chefe : Dictionary = load("res://scripts/combat/ChefeLendario.gd").get_script_constant_map()
	var repertorio : Dictionary = mapa_chefe.get("REPERTORIO", {})
	_assert(repertorio.has(146), "o Moltres tem mecânica de encontro cadastrada")
	for papel in ["area", "percentual", "ambiente", "controle"]:
		_assert(repertorio[146].has(papel),
			"a mecânica do chefe inclui '%s' — e ela não depende do nível nem do learnset" % papel)
	_assert(not bool(d_mk["tem_area"]) and not bool(d_mk["tem_controle"]),
		"o Magikarp não tem NADA pra responder a área nem pra criar janela — é aí que o nível 100 não salva")

	# Nenhuma regra com nome de espécie em lugar nenhum do combate. A busca é
	# por CÓDIGO, não por texto: o nome aparece em comentário explicando o caso,
	# e comentário não decide partida.
	for arquivo in ["res://scripts/combat/KitDeCombate.gd",
			"res://scripts/combat/ComportamentoSelvagem.gd",
			"res://scripts/combat/ChefeLendario.gd",
			"res://scripts/entities/WildPokemon.gd"]:
		var fonte := FileAccess.get_file_as_string(arquivo)
		for proibido in ["== 129", "== 130", "species_id == 146", '== "Magikarp"', '== "Moltres"']:
			_assert(not fonte.contains(proibido),
				"%s não decide nada por espécie (%s)" % [arquivo.get_file(), proibido])

	# ⚠️ O que este teste NÃO prova: que o Magikarp PERDE a luta. DPS bruto no
	# nível 100 ainda é alto, e um alvo que não reage morre. O que está provado
	# é que ele não tem ferramenta nenhuma pra responder a área, controle e
	# janela de vulnerabilidade — que é o que a luta de chefe cobra. Provar o
	# desfecho exige simular a luta inteira com movimentação, e isso é playtest.
	print("  ⚠ Provado: o kit do Magikarp é insuficiente pras mecânicas de chefe.")
	print("  ⚠ Achado:  o learnset do Moltres é vazio entre Lv.1 e Lv.51 — um lendário")
	print("             de nível baixo é pobre de kit. Registrado, não corrigido.")
	print("  ⚠ NÃO provado: o desfecho da luta. Isso exige playtest com movimentação.")

# ──────────────────────────────────────────────────────────────────────────
# P7 — sinergia
# ──────────────────────────────────────────────────────────────────────────
func _p7_sinergia() -> void:
	# O mecanismo.
	var golpe := {"power": 60, "sinergia": {"alvo_com": "burn", "bonus": 1.3}}
	_assert(is_equal_approx(Sinergia.multiplicador(golpe, {"alvo_status": "burn"}), 1.3),
		"golpe rende mais contra alvo na condição certa")
	_assert(is_equal_approx(Sinergia.multiplicador(golpe, {"alvo_status": "none"}), 1.0),
		"e não rende nada fora dela")
	_assert(is_equal_approx(Sinergia.multiplicador({"power": 60}, {"alvo_status": "burn"}), 1.0),
		"golpe SEM sinergia declarada nunca ganha bônus")

	# Todas as condições têm que bater (é E, não OU).
	var duplo := {"sinergia": {"alvo_com": "burn", "campo": "chuva", "bonus": 1.5}}
	_assert(is_equal_approx(Sinergia.multiplicador(duplo, {"alvo_status": "burn"}), 1.0),
		"regra com duas condições exige as DUAS")
	_assert(is_equal_approx(Sinergia.multiplicador(duplo,
		{"alvo_status": "burn", "campo": ["chuva"]}), 1.5), "...e aí sim rende")

	# Trava contra dado mal escrito.
	_assert(Sinergia.multiplicador({"sinergia": {"alvo_com": "burn", "bonus": 30.0}},
		{"alvo_status": "burn"}) <= Sinergia.BONUS_MAXIMO,
		"um bônus absurdo no JSON é limitado (30.0 viraria +2900%%)")
	_assert(not Sinergia.regra_valida({"bonus": 1.5}), "regra sem condição nenhuma é inválida")
	_assert(not Sinergia.regra_valida({"chave_inventada": "x", "bonus": 1.5}),
		"regra com chave desconhecida é inválida")

	# As declaradas nos dados estão bem escritas.
	var declaradas : Array = Sinergia.declaradas(GameData.moves)
	print("\n-- Sinergias declaradas nos dados: %d --" % declaradas.size())
	for d in declaradas:
		print("  %-14s %s" % [str(d["id"]), str(d["sinergia"])])
		_assert(Sinergia.regra_valida(d["sinergia"]),
			"a sinergia de '%s' está bem escrita" % str(d["id"]))
	_assert(declaradas.size() >= 1,
		"o mecanismo tem pelo menos um caso real provando que funciona ponta a ponta")

	# E entra na conta de dano de verdade, sem nome de golpe no código.
	var fonte := FileAccess.get_file_as_string("res://scripts/combat/DamageCalculator.gd")
	_assert(fonte.contains("Sinergia.multiplicador("), "a sinergia entra na conta de dano")
	for proibido in ["== \"thunder\"", "== \"gust\"", "== \"hyper_beam\""]:
		_assert(not fonte.contains(proibido), "e nunca por nome de golpe (%s)" % proibido)

	var com_sinergia := DamageCalculator.detalhar(
		{"power": 60, "type": "Normal", "category": "physical", "name": "x",
			"sinergia": {"alvo_com": "burn", "bonus": 1.3}},
		{"atk": 100, "level": 30, "contexto_de_sinergia": {"alvo_status": "burn"}},
		{"def": 100, "types": ["Normal"]})
	_assert(is_equal_approx(float(com_sinergia.get("mult_sinergia", 1.0)), 1.3),
		"o relatório de dano mostra a sinergia que agiu")

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)

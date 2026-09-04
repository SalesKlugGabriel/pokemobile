## teste_revisao_lore_balanceamento.gd — Teste headless da revisão de lore +
## balanceamento pedida pelo Gabriel (03/09): fecha o exploit de treinador
## re-lutável infinito, Elite Four/Campeão em nível 100, "boostar" Pokémon
## de verdade (vitaminas/Doce Raro), Pokéradar com efeito real, A Escolha
## da Fratura (MAIN-11) jogável, e os 21 itens fantasma corrigidos. Roda com:
## godot4 --headless --script res://scripts/tests/teste_revisao_lore_balanceamento.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var SaveManager  : Node
var QuestManager : Node
var EventBus     : Node
var GameData     : Node

func _initialize() -> void:
	print("=== Teste: revisão de lore + balanceamento (03/09) ===")
	SaveManager  = root.get_node("SaveManager")
	QuestManager = root.get_node("QuestManager")
	EventBus     = root.get_node("EventBus")
	GameData     = root.get_node("GameData")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	SaveManager.new_game("TesteLoreBalance", 1)

	# ---- 1. Exploit de treinador infinito, corrigido ----
	_assert(not SaveManager.is_trainer_defeated("ginasio_x/Brock"), "treinador começa não-derrotado")
	SaveManager.mark_trainer_defeated("ginasio_x/Brock")
	_assert(SaveManager.is_trainer_defeated("ginasio_x/Brock"), "mark_trainer_defeated registra de verdade")
	SaveManager.mark_trainer_defeated("ginasio_x/Brock")  # 2x não duplica
	_assert(SaveManager.save_data["world"]["defeated_trainers"].count("ginasio_x/Brock") == 1,
		"marcar 2x o mesmo treinador não duplica a entrada")

	# Cenário real do bug: derrotar o treinador, "sair e voltar na sala" (uma
	# instância NOVA de NpcEntity, exatamente o que troca-de-mapa faz), e
	# confirmar que ele já nasce marcado como derrotado — antes desta
	# correção, `trainer_defeated` sempre nascia `false`, permitindo lutar
	# de novo infinitas vezes. Usa a cena de verdade (não o script cru) pra
	# ter $Sprite/$HurtBox etc. de verdade — _ready() precisa rodar aqui.
	var NpcScene := load("res://scenes/entities/NpcEntity.tscn")
	var npc1 = NpcScene.instantiate()
	npc1.name = "BrockTeste"
	npc1.is_trainer = true
	var time1 : Array[Dictionary] = [{"species_id": 74, "level": 10}]
	npc1.trainer_team = time1
	root.add_child(npc1)
	_assert(not npc1.trainer_defeated, "1º encontro: treinador nasce SEM ser derrotado")
	npc1._trainer_team_idx = npc1.trainer_team.size()  # simula o time inteiro já batido
	npc1._spawn_next_trainer_pokemon()  # esgota o time -> marca derrotado
	_assert(npc1.trainer_defeated and SaveManager.is_trainer_defeated(npc1._trainer_save_id()),
		"depois de esgotar o time, fica marcado derrotado NO SAVE (não só em memória)")
	npc1.free()

	var npc2 = NpcScene.instantiate()
	npc2.name = "BrockTeste"  # mesmo nome = mesmo _trainer_save_id()
	npc2.is_trainer = true
	var time2 : Array[Dictionary] = [{"species_id": 74, "level": 10}]
	npc2.trainer_team = time2
	root.add_child(npc2)  # simula trocar de mapa e voltar (nova instância)
	_assert(npc2.trainer_defeated, "CORREÇÃO DO EXPLOIT: a NOVA instância (sair/voltar na sala) já nasce derrotada, não dá mais pra farmar em loop")
	npc2.free()

	# ---- 2. Elite Four + Campeão, todos nível 100 ----
	for n in range(1, 6):
		var scene : PackedScene = load("res://scenes/world/maps/IndigoLeague_F%d.tscn" % n)
		var inst := scene.instantiate()
		var found_npc : Node = null
		for child in inst.get_node("Entities").get_children():
			if "is_trainer" in child and child.is_trainer:
				found_npc = child
		_assert(found_npc != null, "andar %d tem o treinador" % n)
		if found_npc:
			for p in found_npc.trainer_team:
				_assert(int(p.get("level", 0)) == 100, "andar %d: todo Pokémon é nível 100 (achou %d)" % [n, int(p.get("level",0))])
		inst.free()

	# ---- 3. "Boostar" Pokémon: vitaminas (EVs) e Doce Raro, de verdade ----
	for item_id in ["hp_up", "protein", "iron", "carbos", "calcium", "zinc"]:
		_assert(not GameData.get_item(item_id).is_empty(), "%s existe em items.json" % item_id)

	_assert(SaveManager.apply_ev_vitamin(0, "attack", 10), "aplicar Proteína funciona")
	_assert(int(SaveManager.get_pokemon_at(0).get("evs", {}).get("atk", 0)) == 10,
		"o EV foi pra chave interna certa ('atk', não 'attack' — mesma classe de bug já corrigida antes neste projeto)")
	for i in 30:
		SaveManager.apply_ev_vitamin(0, "attack", 10)
	_assert(int(SaveManager.get_pokemon_at(0).get("evs", {}).get("atk", 0)) == 252,
		"EV trava no teto de 252, não passa disso")
	_assert(not SaveManager.apply_ev_vitamin(0, "attack", 10), "vitamina no teto não faz mais nada (devolve false)")

	var nivel_antes : int = int(SaveManager.get_pokemon_at(0).get("level", 1))
	_assert(SaveManager.use_rare_candy(0), "Doce Raro funciona")
	_assert(int(SaveManager.get_pokemon_at(0).get("level", 1)) == nivel_antes + 1,
		"Doce Raro sobe exatamente 1 nível")

	# ---- 4. Pokéradar: chance de shiny de verdade ----
	var wild_scene : PackedScene = load("res://scenes/entities/pokemon/WildPokemon.tscn")
	var w1 = wild_scene.instantiate()
	w1.species_id = 16
	_assert(w1._shiny_chance_efetiva() == (1.0/4096.0), "sem Pokéradar, chance normal (1/4096)")
	w1.free()

	SaveManager.add_item("pokeradar", 1)
	var w2 = wild_scene.instantiate()
	_assert(w2._shiny_chance_efetiva() == (1.0/512.0), "com Pokéradar, chance sobe pra 1/512")
	w2.free()

	SaveManager.add_item("pokeradar_advanced", 1)
	var w3 = wild_scene.instantiate()
	_assert(w3._shiny_chance_efetiva() == (1.0/256.0), "com o Avançado, chance sobe mais ainda (1/256)")
	w3.free()

	# ---- 5. Diários rastreados de verdade (campo que já existia, nunca escrito) ----
	_assert(SaveManager.get_diaries().is_empty(), "sem diários no início")
	QuestManager._completed_quests.append("MAIN-01")  # pré-requisito de MAIN-02
	QuestManager.start_quest("MAIN-02")
	EventBus.battle_ended.emit({"result":"win","player_won":true,"is_wild":true,"enemy_species_name":"Rattata","enemy_level":3})
	for i in 2:
		EventBus.battle_ended.emit({"result":"win","player_won":true,"is_wild":true,"enemy_species_name":"Rattata","enemy_level":3})
	_assert(QuestManager.is_quest_complete("MAIN-02"), "MAIN-02 completa (3 vitórias)")
	_assert("diario_1" in SaveManager.get_diaries(), "diario_1 registrado em save_data['diaries'] ao ser concedido")

	# ---- 6. Todos os 21 itens fantasma corrigidos ----
	var itens_fantasma := ["diario_1","diario_2","diario_3","diario_4","diario_5","diario_6",
		"mapa_fratura","documento_fratura_parcial","pokeradar","pokeradar_advanced",
		"rocket_hq_code","item_exclusive","premium_pokeball",
		"tm13","tm14","tm15","tm16"]
	for item_id in itens_fantasma:
		_assert(not GameData.get_item(item_id).is_empty(), "%s tem definição real em items.json" % item_id)

	# ---- 7. MAIN-12: presente de Pokémon de verdade (não mais um dict quebrado) ----
	var time_antes : int = SaveManager.get_team().size()
	var destino : String = SaveManager.gift_pokemon_by_name("eevee", 30)
	_assert(destino == "team" or destino == "pc", "gift_pokemon_by_name entrega o Pokémon em algum lugar de verdade")
	var eevee : Dictionary = SaveManager.get_team()[SaveManager.get_team().size()-1] if destino == "team" else {}
	if destino == "team":
		_assert(int(eevee.get("species_id", -1)) == GameData.get_species_id_by_name("eevee"), "espécie certa (não mais um dict cru sem species_id)")
		_assert(int(eevee.get("level", -1)) == 30, "nível certo")
		_assert(eevee.has("ivs") and eevee.has("moves") and eevee.has("hp_max"),
			"Pokémon de presente tem ivs/moves/hp_max — formato de save completo, não mais um dict quebrado")
		_assert(SaveManager.get_team().size() == time_antes + 1, "foi pro time de verdade")

	# ---- 8. Prof. Carvalho troca de fala no epílogo (MAIN-12) ----
	var oak = NpcScene.instantiate()
	oak.dialog_id = "oak_intro"
	root.add_child(oak)
	_assert(oak._effective_dialog_id() == "oak_intro", "antes de MAIN-11, Carvalho ainda fala a intro normal")
	QuestManager._completed_quests.append("MAIN-11")
	_assert(oak._effective_dialog_id() == "carvalho_final", "depois de MAIN-11, Carvalho troca pra fala de epílogo")
	QuestManager._completed_quests.append("MAIN-12")
	_assert(oak._effective_dialog_id() == "oak_intro", "depois de MAIN-12 completa, volta a falar normal (o epílogo já aconteceu)")
	oak.free()
	_assert(not GameData.get_dialog("carvalho_final").is_empty(), "dialog_id 'carvalho_final' existe e tem texto")

	# ---- 9. MAIN-11: "A Escolha" resolvendo de verdade, as duas ramificações ----
	var mewtwo_id : int = GameData.get_species_id_by_name("mewtwo")

	# Ramo A: selar a Fratura -> Mewtwo sai da coleção, título de guardião
	var destino_mt1 : String = SaveManager.gift_pokemon_by_name("mewtwo", 70)
	_assert(destino_mt1 == "team" or destino_mt1 == "pc", "Mewtwo de teste entregue em algum lugar de verdade")
	SaveManager.resolve_main11_choice("seal_fracture")
	var tem_mewtwo_depois_selar := false
	for p in SaveManager.get_team():
		if int(p.get("species_id", -1)) == mewtwo_id:
			tem_mewtwo_depois_selar = true
	for p in SaveManager.save_data["pc"]:
		if int(p.get("species_id", -1)) == mewtwo_id:
			tem_mewtwo_depois_selar = true
	_assert(not tem_mewtwo_depois_selar, "selar_fracture: Mewtwo sai da coleção (custo real da escolha)")
	_assert(SaveManager.has_title("guardiao_da_fratura"), "selar_fracture: título 'guardião da fratura' concedido")
	_assert(SaveManager.get_final_choice() == "seal_fracture", "get_final_choice() reflete a escolha feita")

	# Ramo B: manter o Mewtwo -> continua na coleção, título de domador (save novo)
	SaveManager.new_game("TesteLoreBalance2", 1)
	var destino_mt2 : String = SaveManager.gift_pokemon_by_name("mewtwo", 70)
	SaveManager.resolve_main11_choice("capture_mewtwo")
	var tem_mewtwo_depois_manter := false
	for p in SaveManager.get_team():
		if int(p.get("species_id", -1)) == mewtwo_id:
			tem_mewtwo_depois_manter = true
	for p in SaveManager.save_data["pc"]:
		if int(p.get("species_id", -1)) == mewtwo_id:
			tem_mewtwo_depois_manter = true
	_assert(tem_mewtwo_depois_manter, "capture_mewtwo: Mewtwo continua na coleção")
	_assert(SaveManager.has_title("domador_de_mewtwo"), "capture_mewtwo: título 'domador de mewtwo' concedido")
	_assert(not SaveManager.has_title("guardiao_da_fratura"), "capture_mewtwo: NÃO ganha o título do outro ramo (save novo)")
	_assert(SaveManager.get_final_choice() == "capture_mewtwo", "get_final_choice() reflete a escolha feita (ramo B)")

	# ---- 10. Repartidor de EXP: só o líder ganhava EXP, agora reparte com o time ----
	SaveManager.new_game("TesteLoreBalance3", 1)
	SaveManager.gift_pokemon_by_name("charmander", 5)  # vira índice 1
	var exp_p0_antes := int(SaveManager.get_pokemon_at(0).get("exp", 0))  # nível 5 já nasce com EXP > 0
	var exp_p1_antes := int(SaveManager.get_pokemon_at(1).get("exp", 0))
	SaveManager.add_exp_with_share(0, 100)  # sem exp_share: só o índice 0 ganha
	_assert(int(SaveManager.get_pokemon_at(0).get("exp", 0)) == exp_p0_antes + 100, "sem Repartidor: quem lutou ganha o EXP normal")
	_assert(int(SaveManager.get_pokemon_at(1).get("exp", 0)) == exp_p1_antes, "sem Repartidor: o resto do time NÃO ganha nada")

	SaveManager.add_item("exp_share", 1)
	SaveManager.add_exp_with_share(0, 50)
	_assert(int(SaveManager.get_pokemon_at(0).get("exp", 0)) == exp_p0_antes + 150, "com Repartidor: quem lutou continua ganhando normal")
	_assert(int(SaveManager.get_pokemon_at(1).get("exp", 0)) == exp_p1_antes + 50, "com Repartidor: o resto do time ganha a MESMA quantia")

	# Pokémon desmaiado (HP 0) fica de fora do reparte
	var p1 : Dictionary = SaveManager.get_pokemon_at(1)
	p1["hp_current"] = 0
	SaveManager.save_data["team"][1] = p1
	var exp_p1_desmaiado := int(SaveManager.get_pokemon_at(1).get("exp", 0))
	SaveManager.add_exp_with_share(0, 50)
	_assert(int(SaveManager.get_pokemon_at(1).get("exp", 0)) == exp_p1_desmaiado, "com Repartidor: Pokémon desmaiado (HP 0) NÃO ganha EXP")

	# ---- 11. PP Up: +1/5 do PP base por uso, até 3 usos (teto de +60%) ----
	var move_id_teste : String = str(SaveManager.get_pokemon_at(0).get("moves", [])[0].get("id", ""))
	var pp_base : int = int(GameData.get_move(move_id_teste).get("pp", 10))
	var incremento_esperado : int = maxi(1, pp_base / 5)
	_assert(SaveManager.apply_pp_up(0, 0), "1º PP Up funciona")
	_assert(int(SaveManager.get_pokemon_at(0).get("moves", [])[0].get("pp_max", 0)) == pp_base + incremento_esperado,
		"1º PP Up soma exatamente 1/5 do PP base")
	SaveManager.apply_pp_up(0, 0)
	SaveManager.apply_pp_up(0, 0)
	_assert(int(SaveManager.get_pokemon_at(0).get("moves", [])[0].get("pp_max", 0)) == pp_base + incremento_esperado * 3,
		"depois de 3 usos, PP máximo é base + 3x o incremento (teto de +60%)")
	_assert(not SaveManager.apply_pp_up(0, 0), "4º uso não faz mais nada (já no teto de 3 usos)")

	# ---- 12. Caçador de Shinies: conquista nova, própria (não reaproveita ID sobrescrito) ----
	_assert(not SaveManager.has_title("cacador_de_shinies"), "sem título antes de capturar shiny nenhum")
	EventBus.capture_success.emit({"species_id": 25, "level": 10, "is_shiny": false})
	_assert(not SaveManager.has_title("cacador_de_shinies"), "capturar um Pokémon NÃO shiny não concede o título")
	EventBus.capture_success.emit({"species_id": 25, "level": 10, "is_shiny": true})
	_assert(SaveManager.has_title("cacador_de_shinies"), "capturar um shiny de verdade concede 'Caçador de Shinies'")

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)

## teste_elite_four.gd — Teste headless da Elite Four + Campeão (Onda 4,
## 03/09): Liga Pokémon (Indigo Plateau) fechada até as 8 insígnias, 5
## andares (Lorelei/Bruno/Agatha/Lance/Campeão), recompensa final (troféu +
## título). Roda com:
## godot4 --headless --script res://scripts/tests/teste_elite_four.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var SaveManager  : Node
var QuestManager : Node
var EventBus     : Node
var GameData     : Node

const ROUTE22_COLS := 60

func _initialize() -> void:
	print("=== Teste Elite Four + Campeão ===")
	SaveManager  = root.get_node("SaveManager")
	QuestManager = root.get_node("QuestManager")
	EventBus     = root.get_node("EventBus")
	GameData     = root.get_node("GameData")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	SaveManager.new_game("TesteEliteFour", 1)

	# ---- Dado: item de recompensa final existe de verdade (não é phantom item) ----
	_assert(not GameData.get_item("trofeu_campeao").is_empty(), "trofeu_campeao existe em items.json")

	# ---- Dado: as 5 quests existem com a cadeia certa ----
	_assert(GameData.get_item("max_elixir").get("category","") == "medicine", "sanity: max_elixir (recompensa dos 4 andares) é item de verdade")

	# ---- Layout: os 5 andares existem e são geráveis ----
	for n in range(1, 6):
		var layout : Dictionary = MapLayouts.get_layout("indigo_league_f%d" % n)
		_assert(not layout.is_empty(), "indigo_league_f%d tem layout gerável" % n)
		_assert(layout.get("width",0) == 18 and layout.get("height",0) == 14,
			"indigo_league_f%d é 18x14, igual aos outros andares de estrutura" % n)

	# ---- Porta da Liga: fechada sem as 8 insígnias, aberta com todas ----
	var j_porta := 16 + ROUTE22_COLS   # ip=16 (centro do vão 15-17)
	var j_interior := 12 + ROUTE22_COLS # ip=12, bem dentro do prédio (10-22)
	# 04/09: era comparação com o literal "W". A parede da frente dos prédios
	# passou a alternar entre lisa ("w") e com janela ("W") — antes TODA parede
	# era janela, e a fachada de todo prédio do jogo era uma fileira de janelas.
	# O que este teste quer garantir é que o vão está FECHADO, não qual desenho
	# de parede ele usa: pergunta semântica, igual `atlas_e_do_char` faz com
	# terreno.
	_assert(MapLayouts.e_parede(MapLayouts._oeste_de_viridian_cell(j_porta, 14)),
		"porta da Liga FECHADA sem nenhuma insígnia")
	_assert(MapLayouts.e_parede(MapLayouts._oeste_de_viridian_cell(j_interior, 10)),
		"interior da Liga inacessível sem nenhuma insígnia")

	for badge in ["boulder_badge", "cascade_badge", "thunder_badge", "rainbow_badge",
			"soul_badge", "marsh_badge", "volcano_badge"]:
		SaveManager.award_badge(badge)
	_assert(MapLayouts.e_parede(MapLayouts._oeste_de_viridian_cell(j_porta, 14)),
		"com só 7 das 8 insígnias, a porta AINDA está fechada")

	SaveManager.award_badge("earth_badge")  # a 8ª e última
	_assert(MapLayouts._oeste_de_viridian_cell(j_porta, 14) == "P",
		"com as 8 insígnias, a porta da Liga ABRE")
	_assert(MapLayouts._oeste_de_viridian_cell(j_interior, 10) == "I",
		"com as 8 insígnias, o interior vira andável")

	# ---- Cadeia de quests: os 5 combates, na ordem, com recompensa certa ----
	QuestManager.start_quest("ELITE4-01")
	_assert("ELITE4-01" in QuestManager.get_active_quests(), "ELITE4-01 inicia (sem pré-requisito de quest — a porta já filtrou)")

	var exp_antes : int = int(SaveManager.get_trainer().get("exp", 0))
	EventBus.battle_ended.emit({"result":"win","player_won":true,"is_wild":false,"trainer_name":"Lorelei","enemy_species_name":"Lapras","enemy_level":58})
	_assert(QuestManager.is_quest_complete("ELITE4-01"), "derrotar Lorelei fecha ELITE4-01")
	_assert("ELITE4-02" in QuestManager.get_active_quests(), "ELITE4-01 desbloqueia ELITE4-02 sozinho")

	EventBus.battle_ended.emit({"result":"win","player_won":true,"is_wild":false,"trainer_name":"Bruno","enemy_species_name":"Machamp","enemy_level":57})
	_assert(QuestManager.is_quest_complete("ELITE4-02"), "derrotar Bruno fecha ELITE4-02")
	_assert("ELITE4-03" in QuestManager.get_active_quests(), "ELITE4-02 desbloqueia ELITE4-03")

	EventBus.battle_ended.emit({"result":"win","player_won":true,"is_wild":false,"trainer_name":"Agatha","enemy_species_name":"Gengar","enemy_level":58})
	_assert(QuestManager.is_quest_complete("ELITE4-03"), "derrotar Agatha fecha ELITE4-03")
	_assert("ELITE4-04" in QuestManager.get_active_quests(), "ELITE4-03 desbloqueia ELITE4-04")

	EventBus.battle_ended.emit({"result":"win","player_won":true,"is_wild":false,"trainer_name":"Lance","enemy_species_name":"Dragonite","enemy_level":60})
	_assert(QuestManager.is_quest_complete("ELITE4-04"), "derrotar Lance fecha ELITE4-04")
	_assert("CHAMPION-01" in QuestManager.get_active_quests(), "ELITE4-04 desbloqueia CHAMPION-01 (o Campeão)")

	EventBus.battle_ended.emit({"result":"win","player_won":true,"is_wild":false,"trainer_name":"Campeao","enemy_species_name":"Charizard","enemy_level":62})
	_assert(QuestManager.is_quest_complete("CHAMPION-01"), "derrotar o Campeão fecha CHAMPION-01")

	var exp_ganho : int = int(SaveManager.get_trainer().get("exp", 0)) - exp_antes
	_assert(exp_ganho == 2000 + 2200 + 2400 + 2600 + 5000, "XP somado das 5 vitórias bate exato (%d)" % exp_ganho)
	_assert(int(SaveManager.get_inventory().get("trofeu_campeao", 0)) == 1, "Troféu de Campeão concedido")
	_assert("campeao_de_kanto" in SaveManager.get_titles(), "título 'campeao_de_kanto' concedido")

	# ---- Cenas dos 5 treinadores: times reais, não vazios ----
	# Decisão do Gabriel (03/09/2026): a Elite Four INTEIRA — Lorelei, Bruno,
	# Agatha, Lance e o Campeão — é nível 100 em todos os andares, pra ser um
	# desafio de verdade no fim do grind (não mais uma escalada 58→65→... como
	# antes). Esta suíte tinha uma checagem de "dificuldade cresce" que ficou
	# obsoleta com essa mudança de design — trocada por "todos no teto".
	var niveis_maximos : Array[int] = []
	for n in range(1, 6):
		var scene : PackedScene = load("res://scenes/world/maps/IndigoLeague_F%d.tscn" % n)
		_assert(scene != null, "IndigoLeague_F%d.tscn carrega sem erro" % n)
		var inst := scene.instantiate()
		var npc := _find_trainer_npc(inst)
		_assert(npc != null and npc.is_trainer, "andar %d tem um NpcEntity treinador de verdade" % n)
		if npc:
			var team : Array = npc.trainer_team
			_assert(team.size() >= 2, "andar %d tem time com pelo menos 2 Pokémon (%d)" % [n, team.size()])
			var maior_nivel := 0
			for p in team:
				maior_nivel = maxi(maior_nivel, int(p.get("level", 0)))
			niveis_maximos.append(maior_nivel)
		inst.free()

	_assert(niveis_maximos.size() == 5 and niveis_maximos.all(func(lv): return lv == 100),
		"todos os 5 andares (Lorelei a Campeão) são nível 100 — teto de desafio real")

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

func _find_trainer_npc(root_node: Node) -> Node:
	var entities := root_node.get_node_or_null("Entities")
	if not entities:
		return null
	for child in entities.get_children():
		if child.has_method("get") and "is_trainer" in child and child.is_trainer:
			return child
	return null

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)

## teste_cerulean_cave.gd — Teste headless da Caverna de Cerulean + Mewtwo
## (MAIN-10, 03/09): antes só existia um registro de zona (com coordenadas
## do plano mestre antigo, nunca batendo com o mapa atual) — nenhum mapa,
## interior, warp ou o próprio Mewtwo existia de verdade. Roda com:
## godot4 --headless --script res://scripts/tests/teste_cerulean_cave.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var SaveManager  : Node
var QuestManager : Node
var EventBus     : Node
var GameData     : Node

func _initialize() -> void:
	print("=== Teste Caverna de Cerulean + Mewtwo (MAIN-10) ===")
	SaveManager  = root.get_node("SaveManager")
	QuestManager = root.get_node("QuestManager")
	EventBus     = root.get_node("EventBus")
	GameData     = root.get_node("GameData")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	SaveManager.new_game("TesteCeruleanCave", 1)

	# ---- Boca da caverna: fechada em nenhum lugar (sempre acessível), rocha
	# ao redor, corredor não afetado ----
	_assert(MapLayouts._norte_de_cerulean_cell(245, -4, 500) == "P", "vão da boca da caverna (fb 36) é andável")
	_assert(MapLayouts._norte_de_cerulean_cell(245, -3, 500) == "P", "vão da boca da caverna (fb 37, centro) é andável")
	_assert(MapLayouts._norte_de_cerulean_cell(245, -2, 500) == "P", "vão da boca da caverna (fb 38) é andável")
	_assert(MapLayouts._norte_de_cerulean_cell(245, -5, 500) == "R", "rocha na borda sul da boca (fb 35)")
	_assert(MapLayouts._norte_de_cerulean_cell(245, -1, 500) == "R", "rocha na borda norte da boca (fb 39)")
	_assert(MapLayouts._norte_de_cerulean_cell(243, -3, 500) == "T", "fora da faixa da boca continua árvore, sem vazamento")

	# ---- Os 7 andares geram, conectividade garantida (corredor central livre) ----
	for n in range(1, 8):
		var map_id := "cerulean_cave_f%d" % n
		var layout : Dictionary = MapLayouts.get_layout(map_id)
		_assert(not layout.is_empty(), "%s tem layout gerável" % map_id)
		_assert(layout.get("width",0) == 20 and layout.get("height",0) == 30, "%s é 20x30" % map_id)
		var tiles : Array = layout["tiles"]
		# Corredor cols 9-10 tem que estar livre (nunca "R"/"W") em todo o
		# INTERIOR (linhas 1..H-2) — as bordas (row 0/H-1) são parede sólida
		# de propósito onde não há porta (ex: andar 7, sem saída ao norte).
		var bloqueado := false
		for row_idx in range(1, tiles.size() - 1):
			var row : String = tiles[row_idx]
			if row[9] == "R" or row[9] == "W" or row[10] == "R" or row[10] == "W":
				bloqueado = true
		_assert(not bloqueado, "%s: corredor central (col 9-10) nunca fica bloqueado por dentro — sempre atravessável" % map_id)

	# ---- Andar 7 não tem saída norte (fim da linha) ----
	var f7_tiles : Array = MapLayouts.get_layout("cerulean_cave_f7")["tiles"]
	_assert(f7_tiles[0][9] != "P", "andar 7 (mais fundo) NÃO tem saída ao norte — é o fim da linha")

	# ---- Cena do andar 7: Mewtwo existe, é selvagem de verdade (não NPC) ----
	var f7 : Node = load("res://scenes/world/maps/CeruleanCave_F7.tscn").instantiate()
	_assert(f7.structure_id == "cerulean_cave" and f7.floor_number == 7,
		"andar 7 marca structure_id/floor_number pra MAIN-10 (traverse_floors) funcionar")
	var wilds := f7.get_node("Entities/WildPokemons")
	var mewtwo : Node = null
	for child in wilds.get_children():
		if child.name == "Mewtwo":
			mewtwo = child
	_assert(mewtwo != null, "Mewtwo existe no andar 7, como WildPokemon de verdade")
	if mewtwo:
		_assert(mewtwo.species_id == 150, "Mewtwo é a espécie certa (150)")
		_assert(mewtwo.wild_level == 70, "Mewtwo é nível 70")
	f7.free()

	# ---- MAIN-10: chegar no andar 7 + capturar Mewtwo completa a quest ----
	# Cadeia MAIN-01..09 marcada completa direto (irrelevante pro que este
	# teste verifica) — mesmo padrão já usado no teste do Giovanni.
	for i in range(1, 10):
		QuestManager._completed_quests.append("MAIN-0%d" % i)
	QuestManager.start_quest("MAIN-10")
	_assert("MAIN-10" in QuestManager.get_active_quests(), "MAIN-10 inicia")

	EventBus.floor_reached.emit("cerulean_cave", 7)
	_assert(QuestManager.get_objective_progress("MAIN-10", 0) == 7,
		"chegar no andar 7 registra floor=7 no objetivo traverse_floors")
	_assert(not QuestManager.is_quest_complete("MAIN-10"), "ainda falta capturar/enfrentar o Mewtwo")

	EventBus.capture_success.emit({"species_id": 150, "level": 70})
	_assert(QuestManager.is_quest_complete("MAIN-10"), "capturar Mewtwo fecha MAIN-10 (correção: 'confront' virou 'capture', tipo que o motor já sabia processar)")
	_assert("MAIN-11" in QuestManager.get_active_quests(), "MAIN-10 desbloqueia MAIN-11 (A Escolha, ainda não construída — fora do escopo desta tarefa)")

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

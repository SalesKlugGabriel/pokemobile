## teste_fase2_quest_floors.gd — Teste headless do handler reach_floor/
## traverse_floors no QuestManager (Fase 2: motor que faltava pra MAIN-05,
## MAIN-10 e UTIL-05 algum dia funcionarem — o conteúdo delas ainda não foi
## construído, só o motor). Roda com:
## godot4 --headless --script res://scripts/tests/teste_fase2_quest_floors.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var SaveManager  : Node
var QuestManager : Node
var EventBus     : Node

func _initialize() -> void:
	print("=== Teste Fase 2 (motor reach_floor/traverse_floors) ===")
	SaveManager  = root.get_node("SaveManager")
	QuestManager = root.get_node("QuestManager")
	EventBus     = root.get_node("EventBus")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	SaveManager.new_game("TesteAndares", 1)
	QuestManager.reload_from_save()
	_teste_geral()

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

func _assert(cond: bool, label: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % label)
	else:
		_fail += 1
		print("  FALHA - %s" % label)


func _teste_geral() -> void:
	# ---- 1. Contrato de dados: quests.json usa "target" = id da estrutura,
	# "floor" (reach_floor) ou "floors" (traverse_floors) = andar exigido ----
	var main05 : Dictionary = QuestManager.get_quest_data("MAIN-05")
	var obj05  : Dictionary = main05.get("objectives", [])[0]
	_assert(obj05.get("type", "") == "reach_floor" and obj05.get("target", "") == "pokemon_tower" and int(obj05.get("floor", 0)) == 5,
		"MAIN-05 (Sr. Fuji) pede reach_floor em 'pokemon_tower', andar 5")

	var main10 : Dictionary = QuestManager.get_quest_data("MAIN-10")
	var obj10  : Dictionary = main10.get("objectives", [])[0]
	_assert(obj10.get("type", "") == "traverse_floors" and obj10.get("target", "") == "cerulean_cave" and int(obj10.get("floors", 0)) == 7,
		"MAIN-10 pede traverse_floors em 'cerulean_cave', 7 andares")

	# ---- 2. floor_reached avança o objetivo reach_floor até o andar exigido ----
	# MAIN-05 exige MAIN-04 (não concluída neste save de teste) e tem um 2º
	# objetivo (derrotar agente_sombra_2) — por isso a ativação aqui pula
	# start_quest() (que recusaria pela pré-condição) e semeia o estado ativo
	# direto, só pra isolar o comportamento do objetivo reach_floor. A quest
	# INTEIRA não fecha (de propósito — falta o 2º objetivo, isso é correto).
	QuestManager._active_quests["MAIN-05"] = {"progress": [0, 0]}
	_assert("MAIN-05" in QuestManager.get_active_quests(), "MAIN-05 semeada como ativa pro teste")

	EventBus.floor_reached.emit("pokemon_tower", 3)
	_assert(QuestManager.get_objective_progress("MAIN-05", 0) == 3,
		"chegar no andar 3 da Torre Pokémon avança o progresso pra 3 (falta 2)")
	_assert(not QuestManager.is_quest_complete("MAIN-05"), "ainda não fechou — falta chegar no andar 5 E derrotar agente_sombra_2")

	EventBus.floor_reached.emit("pokemon_tower", 5)
	_assert(QuestManager.get_objective_progress("MAIN-05", 0) == 5,
		"chegar no andar 5 preenche o objetivo reach_floor (5/5)")
	_assert(not QuestManager.is_quest_complete("MAIN-05"),
		"mas a quest INTEIRA continua aberta — o 2º objetivo (derrotar agente_sombra_2) não foi tocado")

	# ---- 3. Estrutura errada não conta (target precisa bater) ----
	QuestManager._active_quests["MAIN-10"] = {"progress": [0, 0]}  # requer MAIN-09, mesma semeadura direta
	EventBus.floor_reached.emit("pokemon_tower", 5)  # andar de OUTRA estrutura
	_assert(QuestManager.get_objective_progress("MAIN-10", 0) == 0,
		"floor_reached de uma estrutura diferente ('pokemon_tower') não conta pra MAIN-10 ('cerulean_cave')")

	# ---- 4. Progresso usa o MAIOR andar já visto (voltar não regride) ----
	EventBus.floor_reached.emit("cerulean_cave", 4)
	_assert(QuestManager.get_objective_progress("MAIN-10", 0) == 4, "chegar no andar 4 registra progresso 4")
	EventBus.floor_reached.emit("cerulean_cave", 2)  # jogador voltou pra cima
	_assert(QuestManager.get_objective_progress("MAIN-10", 0) == 4,
		"voltar pro andar 2 NÃO reduz o progresso (continua 4, o maior já alcançado)")
	EventBus.floor_reached.emit("cerulean_cave", 7)
	_assert(QuestManager.get_objective_progress("MAIN-10", 0) == 7,
		"chegar no andar 7 preenche o objetivo traverse_floors (7/7)")
	_assert(not QuestManager.is_quest_complete("MAIN-10"),
		"quest inteira continua aberta — falta o 2º objetivo (confrontar Mewtwo)")

	# ---- 5. Pular direto pro andar final também completa (não precisa passar 1 a 1) ----
	QuestManager.start_quest("UTIL-05")
	EventBus.floor_reached.emit("seafoam_islands", 3)
	_assert(QuestManager.is_quest_complete("UTIL-05"),
		"chegar direto no andar 3 (sem passar pelos anteriores) já fecha UTIL-05 (andar exigido: 3)")

	# Nota: o retrocompatibilidade de FloorMap (structure_id="" e
	# floor_number=0 por padrão, sem emitir floor_reached à toa) não tem
	# unit test direto aqui — instanciar FloorMap.new() isolado esbarra numa
	# resolução de autoload que só funciona ao carregar a .tscn de verdade
	# (não via --script). Já fica coberta na prática: todos os arquivos
	# teste_fase3_tierN.gd que carregam cenas FloorMap existentes (Rock
	# Tunnel, Mt Moon, Torre Pokémon...) continuam passando sem emitir nada
	# novo — nenhum deles configura structure_id/floor_number.

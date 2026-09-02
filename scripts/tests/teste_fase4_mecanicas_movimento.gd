## teste_fase4_mecanicas_movimento.gd — Teste headless das Mecânicas de
## movimentação (Bicicleta/Surfar/Voar, 02/09). Roda com:
## godot4 --headless --script res://scripts/tests/teste_fase4_mecanicas_movimento.gd
##
## Cobre a camada de DADOS/LÓGICA (quest, SaveManager, mapa) — o mesmo nível
## já usado pelo teste de Pesca pra água/mapa. Movimento de entidade ao vivo
## (TrainerEntity andando de verdade sobre água/com corrida) fica pra
## conferência em navegador (Playwright), igual sempre foi feito aqui.
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var SaveManager  : Node
var QuestManager : Node
var EventBus     : Node
var GameData     : Node

func _initialize() -> void:
	print("=== Teste Fase 4 (Mecânicas de movimentação) ===")
	SaveManager  = root.get_node("SaveManager")
	QuestManager = root.get_node("QuestManager")
	EventBus     = root.get_node("EventBus")
	GameData     = root.get_node("GameData")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	SaveManager.new_game("TesteFase4", 1)
	QuestManager.reload_from_save()

	_teste_mapa_cerulean()
	_teste_bicicleta()
	_teste_team_knows_move()
	_teste_visited_maps()
	_teste_recompensas_surf_fly()

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

# ──────────────────────────────────────────────────────────────────────────────
# 1. A tile onde a Loja de Bicicletas de Cerulean foi colocada é de verdade
#    aberta (não em cima de parede/prédio) — conferido contra o gerador real
#    do mapa, não confiado de cabeça.
# ──────────────────────────────────────────────────────────────────────────────
func _teste_mapa_cerulean() -> void:
	var layout = MapLayouts.get_layout("world_map")
	var tiles : Array = layout["tiles"]
	_assert(tiles[19][245] == ".", "tile (245,19) — Loja de Bicicletas de Cerulean — é chão aberto")
	# Vizinhança livre também (o NPC ocupa 1 tile, mas não pode nascer colado
	# em parede dos dois lados a ponto de ficar inacessível).
	_assert(tiles[19][244] == "." or tiles[19][246] == ".",
		"pelo menos um vizinho horizontal também é chão aberto")

# ──────────────────────────────────────────────────────────────────────────────
# 2. UTIL-03 (A Bicicleta): inicia, o objetivo "talk" com o Marinheiro de
#    Vermilion completa a quest, e a recompensa dá o item "bicycle" de
#    verdade no inventário.
# ──────────────────────────────────────────────────────────────────────────────
func _teste_bicicleta() -> void:
	_assert(not SaveManager.has_item("bicycle", 1), "novo jogo começa sem bicicleta")

	QuestManager.start_quest("UTIL-03")
	_assert("UTIL-03" in QuestManager.get_active_quests(), "UTIL-03 inicia (dono: NPC da loja de Cerulean)")

	# Simula falar com o NPC "vermilion_local" — QuestManager._on_dialog_started
	# lê npc.get("dialog_id"), então basta um Node com essa propriedade.
	var npc := _NpcStub.new()
	npc.dialog_id = "vermilion_local"

	EventBus.dialog_started.emit(npc)
	EventBus.dialog_ended.emit()

	_assert(QuestManager.is_quest_complete("UTIL-03"), "UTIL-03 completa ao falar com o NPC certo em Vermilion")
	_assert(SaveManager.has_item("bicycle", 1), "UTIL-03 concluída dá a Bicicleta de verdade no inventário")

	npc.free()

class _NpcStub:
	extends Node
	var dialog_id : String = ""

# ──────────────────────────────────────────────────────────────────────────────
# 3. SaveManager.team_knows_move — base de Surfar/Voar (o time saber ou não
#    o golpe certo, ensinado via MT/MO na Mochila).
# ──────────────────────────────────────────────────────────────────────────────
func _teste_team_knows_move() -> void:
	SaveManager.save_data["team"] = [
		{
			"species_id": 7, "level": 10, "moves": [
				{"id": "tackle", "pp_current": 35, "pp_max": 35}
			]
		}
	]
	_assert(not SaveManager.team_knows_move("surf"), "time sem Surfar: team_knows_move('surf') é false")
	_assert(not SaveManager.team_knows_move("fly"),  "time sem Voar: team_knows_move('fly') é false")

	SaveManager.learn_move(0, "surf", -1)
	_assert(SaveManager.team_knows_move("surf"), "depois de aprender, team_knows_move('surf') é true")
	_assert(not SaveManager.team_knows_move("fly"), "aprender Surfar não faz o time saber Voar também")

# ──────────────────────────────────────────────────────────────────────────────
# 4. Cidades visitadas (base do Voar) — grava ao entrar na zona, sem duplicar.
# ──────────────────────────────────────────────────────────────────────────────
func _teste_visited_maps() -> void:
	SaveManager.save_data["world"]["visited_maps"] = []
	_assert(SaveManager.get_visited_maps().is_empty(), "novo jogo começa sem nenhuma cidade visitada")

	EventBus.zone_changed.emit("cerulean_city")
	_assert("cerulean_city" in SaveManager.get_visited_maps(), "entrar na zona registra a cidade como visitada")

	EventBus.zone_changed.emit("cerulean_city")
	_assert(SaveManager.get_visited_maps().count("cerulean_city") == 1,
		"visitar a mesma cidade de novo não duplica na lista")

	EventBus.zone_changed.emit("mt_moon")  # zona que NÃO é destino de Voar
	_assert("mt_moon" in SaveManager.get_visited_maps(),
		"zonas que não são cidade também entram na lista (o filtro de destino de Voar é na tela, não aqui)")

# ──────────────────────────────────────────────────────────────────────────────
# 5. GYM-05 (Koga) dá MT11 Surfar; GYM-07 (Sabrina) dá MO02 Voar — recompensa
#    de verdade no inventário ao completar a quest.
# ──────────────────────────────────────────────────────────────────────────────
func _teste_recompensas_surf_fly() -> void:
	# GYM-05 exige a cadeia GYM-01..04 completa antes (start_quest checa
	# "requires") — percorre igual o jogador percorreria jogando.
	for req in ["GYM-01", "GYM-02", "GYM-03", "GYM-04"]:
		QuestManager.start_quest(req)
		QuestManager.complete_quest(req)

	_assert(not SaveManager.has_item("tm11", 1), "antes do Ginásio de Fuchsia, sem MT11 Surfar")
	QuestManager.start_quest("GYM-05")
	QuestManager.complete_quest("GYM-05")
	_assert(SaveManager.has_item("tm11", 1), "Ginásio de Fuchsia (Koga) dá MT11 Surfar")

	_assert(not SaveManager.has_item("hm02", 1), "antes do Ginásio de Saffron, sem MO02 Voar")
	QuestManager.start_quest("GYM-07")  # só exige GYM-05, já completo acima
	QuestManager.complete_quest("GYM-07")
	_assert(SaveManager.has_item("hm02", 1), "Ginásio de Saffron (Sabrina) dá MO02 Voar")

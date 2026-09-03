## teste_giovanni_recompensa_dupla.gd — Trava a correção do bug de recompensa
## dupla ao derrotar Giovanni (03/09): MAIN-09 e GYM-08 tinham o MESMO
## objetivo ("defeat giovanni") e as MESMAS recompensas (badge/tm/exp) —
## como MAIN-08 desbloqueia as duas juntas, uma vitória só sobre Giovanni
## completava as duas ao mesmo tempo, dando insígnia/MT/XP em dobro.
## Roda com: godot4 --headless --script res://scripts/tests/teste_giovanni_recompensa_dupla.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var SaveManager  : Node
var QuestManager : Node
var EventBus     : Node
var GameData     : Node

func _initialize() -> void:
	print("=== Teste: recompensa de Giovanni não duplica (MAIN-09 x GYM-08) ===")
	SaveManager  = root.get_node("SaveManager")
	QuestManager = root.get_node("QuestManager")
	EventBus     = root.get_node("EventBus")
	GameData     = root.get_node("GameData")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	SaveManager.new_game("TesteGiovanniDup", 1)
	QuestManager.reload_from_save()

	# MAIN-08 exige MAIN-07 (que exige MAIN-06, que exige...) — sem interesse
	# nenhum pro que este teste verifica, então a cadeia MAIN-01..07 é
	# marcada completa direto (mesmo padrão de outros testes que escrevem
	# save_data direto pra pular contexto irrelevante). MAIN-08 em diante
	# roda pelos objetivos DE VERDADE, porque é ali que o bug mora.
	for i in range(1, 8):
		QuestManager._completed_quests.append("MAIN-0%d" % i)

	# MAIN-09 e GYM-08 exigem MAIN-08 completa (requires) — start_quest()
	# ignora silenciosamente sem isso (mesma trava usada pra toda quest com
	# pré-requisito). Completar MAIN-08 de verdade, pelos 3 objetivos reais,
	# é o jeito correto de chegar no cenário exato do bug: as DUAS
	# desbloqueadas ao mesmo tempo (unlocks:["MAIN-09","GYM-08"]).
	QuestManager.start_quest("MAIN-08")
	EventBus.zone_changed.emit("rocket_hq")  # objetivo 1: infiltrate

	var NpcScript := ResourceLoader.load("res://scripts/entities/NpcEntity.gd", "", ResourceLoader.CACHE_MODE_IGNORE)
	var npc = NpcScript.new()
	npc.dialog_id = "carvalho_resgate"
	EventBus.dialog_started.emit(npc)
	EventBus.dialog_ended.emit()  # objetivo 2: talk carvalho_resgate

	EventBus.battle_ended.emit({
		"result": "win", "player_won": true, "is_wild": false,
		"trainer_name": "Agente Sombra Final", "enemy_species_name": "Golbat", "enemy_level": 35,
	})  # objetivo 3: defeat agente_sombra_final — fecha MAIN-08

	_assert(QuestManager.is_quest_complete("MAIN-08"), "MAIN-08 completa pelos 3 objetivos reais")
	_assert("MAIN-09" in QuestManager.get_active_quests() and "GYM-08" in QuestManager.get_active_quests(),
		"MAIN-08 desbloqueia as duas juntas (unlocks) — cenário exato do bug")

	var exp_antes : int = int(SaveManager.get_trainer().get("exp", 0))

	EventBus.battle_ended.emit({
		"result": "win", "player_won": true, "is_wild": false,
		"trainer_name": "Giovanni", "enemy_species_name": "Rhydon", "enemy_level": 50,
	})

	_assert(QuestManager.is_quest_complete("MAIN-09"), "MAIN-09 completa ao derrotar Giovanni")
	_assert(QuestManager.is_quest_complete("GYM-08"), "GYM-08 completa ao derrotar Giovanni")

	var exp_ganho : int = int(SaveManager.get_trainer().get("exp", 0)) - exp_antes
	_assert(exp_ganho == 1800, "XP total é 300 (MAIN-09) + 1500 (GYM-08) = 1800, não 3000 (correção do bug)")

	_assert(SaveManager.get_badges().count("earth_badge") == 1,
		"earth_badge concedida exatamente 1 vez (não 2)")
	_assert(int(SaveManager.get_inventory().get("tm_terra_power", 0)) == 1,
		"tm_terra_power concedida exatamente 1 vez (não 2) — MAIN-09 não tem mais esse reward")

	# Segundo achado corrigido no mesmo lote: o guarda do Ginásio de Viridian
	# (zones.json) apontava pra um dialog_id que não existia em dialogs.json.
	var dialogo : Array = GameData.get_dialog("viridian_gym_closed")
	_assert(not dialogo.is_empty(), "dialog_id 'viridian_gym_closed' existe e tem texto (guarda do ginásio não fica mudo)")

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

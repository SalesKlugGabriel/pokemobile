## teste_ss_anne.gd — Teste headless do interior do S.S. Anne (Onda 3, 03/09):
## antes só existia a fachada; agora tem 2 andares de verdade, 3 marinheiros
## treinadores e o Capitão, que dá MO01 Cortar (nunca concedida em lugar
## nenhum do jogo até agora). Roda com:
## godot4 --headless --script res://scripts/tests/teste_ss_anne.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var SaveManager  : Node
var QuestManager : Node
var EventBus     : Node
var GameData     : Node

func _initialize() -> void:
	print("=== Teste S.S. Anne (interior) ===")
	SaveManager  = root.get_node("SaveManager")
	QuestManager = root.get_node("QuestManager")
	EventBus     = root.get_node("EventBus")
	GameData     = root.get_node("GameData")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	SaveManager.new_game("TesteSSAnne", 1)

	# ---- Layout: os 2 andares geram de verdade ----
	for map_id in ["ss_anne_f1", "ss_anne_f2"]:
		var layout : Dictionary = MapLayouts.get_layout(map_id)
		_assert(not layout.is_empty(), "%s tem layout gerável" % map_id)
		_assert(layout.get("width",0) == 18 and layout.get("height",0) == 14, "%s é 18x14" % map_id)

	# ---- Cenas: 3 marinheiros treinadores + Capitão (não-treinador, com presente) ----
	var f1 : Node = load("res://scenes/world/maps/SSAnne_F1.tscn").instantiate()
	var entities_f1 := f1.get_node("Entities")
	var marinheiros_f1 := 0
	for child in entities_f1.get_children():
		if "is_trainer" in child and child.is_trainer:
			marinheiros_f1 += 1
			_assert(child.trainer_team.size() >= 2, "marinheiro do F1 tem time de verdade")
	_assert(marinheiros_f1 == 2, "F1 (convés de baixo) tem 2 marinheiros treinadores")
	f1.free()

	var f2 : Node = load("res://scenes/world/maps/SSAnne_F2.tscn").instantiate()
	var entities_f2 := f2.get_node("Entities")
	var marinheiros_f2 := 0
	var capitao : Node = null
	for child in entities_f2.get_children():
		if "is_trainer" in child and child.is_trainer:
			marinheiros_f2 += 1
		if child.name == "Capitao":
			capitao = child
	_assert(marinheiros_f2 == 1, "F2 (convés de cima) tem 1 marinheiro treinador")
	_assert(capitao != null and not capitao.is_trainer, "o Capitão existe e NÃO é treinador (só dá o presente)")
	_assert(capitao.gift_item_id == "", "Capitão NÃO usa gift_item_id (correção do achado: dava hm01 em dobro junto com a quest)")
	_assert(capitao.starts_quest_id == "UTIL-19", "Capitão inicia UTIL-19 ao conversar")
	f2.free()

	# ---- Quest UTIL-19: falar com o Capitão dá hm01 exatamente 1 vez ----
	_assert(not SaveManager.has_item("hm01", 1), "sanity: hm01 não existe no inventário no início")
	QuestManager.start_quest("UTIL-19")
	_assert("UTIL-19" in QuestManager.get_active_quests(), "UTIL-19 inicia")

	var NpcScript := ResourceLoader.load("res://scripts/entities/NpcEntity.gd", "", ResourceLoader.CACHE_MODE_IGNORE)
	var npc = NpcScript.new()
	npc.dialog_id = "capitao_ssanne"
	EventBus.dialog_started.emit(npc)
	EventBus.dialog_ended.emit()

	_assert(QuestManager.is_quest_complete("UTIL-19"), "conversar com o Capitão completa UTIL-19")
	_assert(int(SaveManager.get_inventory().get("hm01", 0)) == 1, "hm01 concedida exatamente 1 vez (não 2)")

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

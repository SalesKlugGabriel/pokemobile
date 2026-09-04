## teste_npcs_em_tile_valido.gd — Nenhum NPC pode estar em cima de árvore,
## parede, cerca ou água (04/09).
##
## Correção do Gabriel: "existem NPCs aparecendo em cima de paredes de árvores...
## NPCs devem permanecer sobre áreas caminháveis válidas".
##
## Achados quando este teste foi escrito: "Colecionador de Insetos" estava em
## cima de uma ÁRVORE e o "Morador" de Fuchsia em cima de uma CERCA — os dois
## movidos 1 tile. O Giovanni parecia um terceiro caso, mas é falso positivo:
## ele fica DENTRO do Ginásio de Viridian, que é bloco de parede enquanto está
## fechado e vira piso andável quando a MAIN-08 completa. Por isso este teste
## abre o ginásio antes de checar — assim ele confere o estado em que o jogador
## de fato alcança cada NPC, em vez de reprovar um design correto.
##
## Roda com: godot4 --headless --script res://scripts/tests/teste_npcs_em_tile_valido.gd
extends SceneTree

var _ok := 0
var _fail := 0
var _rodou := false

var QuestManager : Node

const AGUA : Vector2i = Vector2i(1, 1)

func _initialize() -> void:
	print("=== Teste: NPCs em tile válido (04/09) ===")
	QuestManager = root.get_node("QuestManager")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	# Abre o Ginásio de Viridian: é a única estrutura do mapa cujo tile depende
	# de estado de save, e o Giovanni mora dentro dela.
	if not QuestManager.is_quest_complete("MAIN-08"):
		QuestManager._completed_quests.append("MAIN-08")

	var ts := load("res://assets/tilesets/overworld.tres") as TileSet
	var tm := TileMap.new()
	tm.tile_set = ts
	MapLayouts.paint(tm, "world_map")

	var cena := load("res://scenes/world/maps/WorldMap.tscn") as PackedScene
	var inst := cena.instantiate()

	var total := 0
	var ruins : Array[String] = []
	for no in inst.find_children("*", "", true, false):
		if not (no is Node2D):
			continue
		var script_path : String = no.get_script().resource_path if no.get_script() else ""
		if not script_path.ends_with("NpcEntity.gd"):
			continue
		total += 1
		var t := Vector2i(floori(no.position.x / 128.0), floori(no.position.y / 128.0))
		var td : TileData = tm.get_cell_tile_data(0, t)
		var vazio : bool = tm.get_cell_source_id(0, t) == -1
		var bloqueado : bool = td != null and td.get_custom_data("blocked")
		var agua : bool = tm.get_cell_atlas_coords(0, t) == AGUA
		if vazio or bloqueado or agua:
			var motivo := "fora do mapa" if vazio else ("água" if agua else "bloqueado")
			ruins.append("%s em %s (%s)" % [no.name, t, motivo])

	_assert(total >= 30, "achou os NPCs do mundo pra conferir (%d)" % total)
	_assert(ruins.is_empty(), "nenhum NPC em árvore/parede/cerca/água — %s" % (
		"ok" if ruins.is_empty() else str(ruins)))

	inst.free()
	tm.free()

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

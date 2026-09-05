## teste_costa_e_surf.gd — Trava a costa de Pallet e a regra do Surf (04/09).
##
## Correção do Gabriel: "as árvores estão sendo utilizadas como uma parede que
## separa o mar da terra... impede o uso do Surf" + "não existe praia ou borda
## adequada entre o mar e a terra firme".
##
## Roda com: godot4 --headless --script res://scripts/tests/teste_costa_e_surf.gd
extends SceneTree

var _ok := 0
var _fail := 0
var _rodou := false

var SaveManager : Node

func _initialize() -> void:
	print("=== Teste: costa de Pallet + Surf (04/09) ===")
	SaveManager = root.get_node("SaveManager")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	var layout := MapLayouts.get_layout("world_map")
	var tiles : Array = layout["tiles"]

	# ---- 1. Existe transição terra → areia → mar (não mais parede de árvore) ----
	var col := 50           # coluna do corredor principal de Pallet
	var seq : String = ""
	for r in range(184, 196):
		seq += (tiles[r] as String)[col]
	_assert(not seq.contains("T"), "costa sul de Pallet não tem mais parede de árvore (achou: %s)" % seq)
	_assert(seq.contains("S"), "existe faixa de AREIA (praia) na transição")
	_assert(seq.contains("~"), "existe MAR depois da praia")
	_assert(seq.find("S") < seq.find("~"), "a ordem é terra → areia → mar (praia antes do mar)")

	# ---- 2. A praia é andável e o mar não (pra quem anda a pé) ----
	var ts := load("res://assets/tilesets/overworld.tres") as TileSet
	var tm := TileMap.new()
	tm.tile_set = ts
	MapLayouts.paint(tm, "world_map")

	# 05/09: a linha da praia deixou de ser fixa. A costa passou a ser ONDULADA
	# (`MapLayouts.ondular_costa`) — era uma reta perfeita de 565 tiles, o que
	# fazia o mapa visto de cima parecer planta baixa. Fixar "praia = linha 189"
	# passou a estar errado por design; o teste procura a praia em vez de supor
	# onde ela está, que é o que ele sempre quis conferir.
	var tile_areia := Vector2i(col, -1)
	for r in range(180, 210):
		if MapLayouts.atlas_e_do_char(tm.get_cell_atlas_coords(0, Vector2i(col, r)), "S"):
			tile_areia = Vector2i(col, r)
			break
	var tile_mar   := Vector2i(col, 210)
	_assert(tile_areia.y >= 0, "existe praia nesta coluna (achada na linha %d)" % tile_areia.y)
	_assert(tm.get_cell_atlas_coords(0, tile_mar) == MapLayouts.CHAR_MAP["~"], "tile de mar é água mesma")

	var td_areia : TileData = tm.get_cell_tile_data(0, tile_areia)
	var td_mar   : TileData = tm.get_cell_tile_data(0, tile_mar)
	_assert(td_areia != null and not td_areia.get_custom_data("blocked"), "praia é CAMINHÁVEL (dá pra andar na areia)")
	_assert(td_mar != null and td_mar.get_custom_data("blocked"), "mar é bloqueado pra quem anda a pé")

	# ---- 3. O mar é grande de verdade, não um filete decorativo ----
	var mar := 0
	var areia := 0
	for row in tiles:
		mar += (row as String).count("~")
		areia += (row as String).count("S")
	_assert(mar > 20000, "o oceano tem área de verdade pra navegar (%d tiles)" % mar)
	_assert(areia > 500, "a praia existe ao longo da costa (%d tiles)" % areia)

	# ---- 4. Surf: a regra é por ESPÉCIE (SURF_SPECIES) e a água só libera com ela ----
	var TrainerScript := ResourceLoader.load("res://scripts/entities/TrainerEntity.gd", "", ResourceLoader.CACHE_MODE_IGNORE)
	var trainer = TrainerScript.new()

	SaveManager.new_game("TesteCosta", 1)
	SaveManager.save_data["team"] = [{"species_id": 25, "level": 10, "moves": []}]   # Pikachu
	_assert(not trainer._pode_surfar(), "sem Pokémon de Surf no time, não surfa")

	SaveManager.save_data["team"] = [{"species_id": 131, "level": 30, "moves": []}]  # Lapras
	_assert(trainer._pode_surfar(), "com Lapras no time, pode surfar")

	trainer.free()
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

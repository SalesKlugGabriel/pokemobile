## teste_fase3_tier11.gd — Teste headless do Tier 11 da expansão de mapa
## (Cinnabar Island — alcançável de barco, Capitão de Vermilion + Blaine/GYM-06).
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase3_tier11.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 3 Tier 11 (Cinnabar Island — barco) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true
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
	# ---- 1. Ilha: 40x40, contorno orgânico (não retângulo) ----
	var layout = MapLayouts.get_layout("cinnabar_island")
	var tiles : Array = layout["tiles"]
	_assert(layout["width"] == 40 and layout["height"] == 40, "cinnabar_island tem 40x40")
	_assert(tiles[0][0] == "~", "canto (0,0) é mar — a ilha não é um retângulo cheio")
	_assert(tiles[19][20] != "~" and tiles[19][20] != "S", "o centro da ilha é terreno de verdade, não mar/praia")

	var achou_praia := false
	for r in tiles.size():
		var row : String = tiles[r]
		for c in row.length():
			if row[c] == "S":
				achou_praia = true
	_assert(achou_praia, "existe praia (anel de areia) ao redor da ilha")

	# ---- 2. Cais + Ginásio + Centro Pokémon existem ----
	_assert(tiles[35][19] == "D", "cais de madeira existe (onde o barco atraca)")
	_assert(tiles[14][16] == "I", "Cinnabar: interior do Ginásio (Blaine) é piso")
	_assert(tiles[10][16] == "H", "Cinnabar: telhado do Ginásio existe")
	_assert(tiles[14][28] == "I", "Cinnabar: interior do Centro Pokémon é piso")

	# ---- 3. Cena carrega, Blaine tem time real, warp de volta existe ----
	var cinnabar_scene := load("res://scenes/world/maps/CinnabarIsland.tscn") as PackedScene
	_assert(cinnabar_scene != null, "CinnabarIsland.tscn carrega sem erro")
	if cinnabar_scene:
		var inst := cinnabar_scene.instantiate()
		var blaine := inst.get_node_or_null("Entities/Blaine")
		_assert(blaine != null, "Blaine existe em Cinnabar")
		if blaine:
			_assert(blaine.trainer_team.size() == 5 and blaine.trainer_team[0]["species_id"] == 58
				and blaine.trainer_team[1]["species_id"] == 77,
				"Blaine tem o time completo de 5 Pokémon tipo Fogo (Fase 5, 02/09)")
			_assert(blaine.starts_quest_id == "GYM-06", "Blaine inicia a GYM-06")
		var warps := inst.get_node_or_null("WarpZones")
		var achou_volta := false
		if warps:
			for w in warps.get_children():
				if w.target_map.contains("WorldMap") and w.spawn_tile == Vector2i(445, 27):
					achou_volta = true
		_assert(achou_volta, "existe warp de volta pra Vermilion, no tile certo perto do Capitão")
		inst.free()

	# ---- 4. WorldMap: Capitão existe, com a viagem condicionada à UTIL-02 ----
	var world_scene := load("res://scenes/world/maps/WorldMap.tscn") as PackedScene
	_assert(world_scene != null, "WorldMap.tscn carrega sem erro")
	if world_scene:
		var inst := world_scene.instantiate()
		var capitao := inst.get_node_or_null("Entities/CapitaoVermilion")
		_assert(capitao != null, "Capitão de Vermilion existe no WorldMap")
		if capitao:
			_assert(capitao.starts_quest_id == "UTIL-02", "Capitão inicia a UTIL-02 ao conversar")
			_assert(capitao.requires_quest_for_travel == "UTIL-02", "viagem do Capitão exige UTIL-02 completa")
			_assert(capitao.travel_target_map.contains("CinnabarIsland"),
				"Capitão leva pra CinnabarIsland.tscn quando a quest estiver completa")
			# ---- 4b. Diálogo muda de verdade antes/depois da quest completa ----
			var antes : String = capitao._effective_dialog_id()
			_assert(antes == "capitao_vermilion", "antes de completar UTIL-02, diálogo é o normal (%s)" % antes)
			var qm := root.get_node("QuestManager")
			qm._completed_quests.append("UTIL-02")
			var depois : String = capitao._effective_dialog_id()
			_assert(depois == "capitao_vermilion_liberado",
				"depois de completar UTIL-02, diálogo muda pro liberado (%s)" % depois)
			qm._completed_quests.erase("UTIL-02")
		inst.free()

	# ---- 5. quests.json: UTIL-02 e GYM-06 sem mecânica inexistente ----
	var quests_f := FileAccess.open("res://data/quests/quests.json", FileAccess.READ)
	var quests = JSON.parse_string(quests_f.get_as_text())
	quests_f.close()
	var util2_objs : Array = quests["UTIL-02"]["objectives"]
	var util2_ok : bool = util2_objs.size() == 1 and util2_objs[0].get("target","") == "gyarados"
	_assert(util2_ok, "UTIL-02 pede derrotar Gyarados de verdade — sem alpha_gyarados (mecânica que não existe)")
	var gym6_objs : Array = quests["GYM-06"]["objectives"]
	var tem_fetch_item := false
	for o in gym6_objs:
		if o.get("type","") == "fetch_item":
			tem_fetch_item = true
	_assert(not tem_fetch_item, "GYM-06 não pede mais fetch_item (mecânica que não existe) — trocado por defeat_count real")

	# ---- 6. zones.json: Gyarados alcançável, Cinnabar com spawn real ----
	var f := FileAccess.open("res://data/world/zones.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	var by_id := {}
	for z in data["zones"]:
		by_id[z["id"]] = z
	var achou_gyarados := false
	for w in by_id["mar_de_vermilion"].get("wild_pokemon", []):
		if int(w.get("id", 0)) == 130:
			achou_gyarados = true
	_assert(achou_gyarados, "Mar de Vermilion tem Gyarados (objetivo da UTIL-02 é alcançável)")
	var achou_growlithe := false
	for w in by_id["cinnabar_island"].get("wild_pokemon", []):
		if int(w.get("id", 0)) == 58:
			achou_growlithe = true
	_assert(achou_growlithe, "Cinnabar Island tem Growlithe (objetivo da GYM-06 é alcançável)")

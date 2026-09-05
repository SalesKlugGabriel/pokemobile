## teste_fase3_tier6.gd — Teste headless do Tier 6 (Saffron City + Ginásio
## da Sabrina). Reescrito em 02/09 (reorganização geográfica): Saffron fica
## embaixo de Cerulean agora — é o cruzamento das 4 rotas (Cerulean/
## Vermilion/Celadon/Lavender).
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase3_tier6.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 3 Tier 6 (Saffron, embaixo de Cerulean) ===")

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
	var layout = MapLayouts.get_layout("world_map")
	var tiles : Array = layout["tiles"]

	var cc0 := MapLayouts.SPINE_COL_INICIO
	var r0 := MapLayouts.SAFFRON_ROW_INICIO

	# ---- 1. Caminho contínuo de Cerulean até Saffron (corredor N-S) ----
	var quebras := 0
	for r in range(MapLayouts.ROUTE5_SUL_START, r0 + MapLayouts.SAFFRON_ROWS):
		var ch : String = tiles[r][cc0 + 28]
		if ch != "P" and ch != "." and ch != "I":
			quebras += 1
	_assert(quebras == 0, "caminho de Cerulean até Saffron é contínuo (%d quebras)" % quebras)

	_assert(tiles[r0 + 10][cc0 + 16] == "I", "Saffron: interior do Ginásio (Sabrina) é piso")
	_assert(tiles[r0 + 6][cc0 + 16] == "H", "Saffron: telhado do Ginásio existe")
	_assert(tiles[r0 + 10][cc0 + 41] == "I", "Saffron: interior do Centro Pokémon é piso")
	_assert(tiles[r0 + 10][cc0 + 54] == "I", "Saffron: interior da Silph Co. é piso")

	var world_scene := load("res://scenes/world/maps/WorldMap.tscn") as PackedScene
	_assert(world_scene != null, "WorldMap.tscn carrega sem erro")
	if world_scene:
		var inst := world_scene.instantiate()
		var sabrina := inst.get_node_or_null("Entities/Sabrina")
		_assert(sabrina != null, "Sabrina existe no WorldMap")
		if sabrina:
			_assert(sabrina.trainer_team.size() == 6 and sabrina.trainer_team[0]["species_id"] == 63
				and sabrina.trainer_team[1]["species_id"] == 96,
				"Sabrina tem o time completo de 6 Pokémon tipo Psíquico (Fase 5, 02/09)")
			_assert(sabrina.starts_quest_id == "GYM-07", "Sabrina inicia a GYM-07")

		var warp_zones := inst.get_node_or_null("WarpZones")
		var alvos_indevidos := 0
		if warp_zones:
			for w in warp_zones.get_children():
				if w.target_map != "" and not w.target_map.contains("PokemonCenter") \
				and not w.target_map.contains("MtMoon") and not w.target_map.contains("RockTunnel") and not w.target_map.contains("SafariZone") and not w.target_map.contains("RocketHideout") and not w.target_map.contains("VictoryRoad") and not w.target_map.contains("DiglettsCave") and not w.target_map.contains("PokemonTower") and not w.target_map.contains("SilphCo") and not w.target_map.contains("GameCorner") and not w.target_map.contains("RocketHQ") and not w.target_map.contains("PokemonMansion") and not w.target_map.contains("IndigoLeague") and not w.target_map.contains("SSAnne") and not w.target_map.contains("CeruleanCave") \
				and not w.target_map.contains("IlhaGelida"):
					alvos_indevidos += 1
		_assert(alvos_indevidos == 0,
			"nenhum warp de cidade/rota indevido sobrou (%d de sobra)" % alvos_indevidos)
		inst.free()

	var f := FileAccess.open("res://data/world/zones.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	var by_id := {}
	for z in data["zones"]:
		by_id[z["id"]] = z
	var achou_abra := false
	for w in by_id["saffron_city"].get("wild_pokemon", []):
		if int(w.get("id", 0)) == 63:
			achou_abra = true
	_assert(achou_abra, "Saffron tem Abra (objetivo 'capturar 3 Abra' da GYM-07 é alcançável)")

	var quests_f := FileAccess.open("res://data/quests/quests.json", FileAccess.READ)
	var quests = JSON.parse_string(quests_f.get_as_text())
	quests_f.close()
	var gym7_objs : Array = quests["GYM-07"]["objectives"]
	var tem_capture_abra := false
	for o in gym7_objs:
		if o.get("type","") == "capture_count" and o.get("target","") == "abra":
			tem_capture_abra = true
	_assert(tem_capture_abra, "GYM-07 pede capturar Abra — sem rocket_agent (mecânica que não existe fora das MAIN quests)")
	_assert(quests["GYM-07"]["requires"] == ["GYM-05"],
		"GYM-07 exige GYM-05 (não GYM-06/Blaine, que ainda não existe) — ajuste editorial documentado")

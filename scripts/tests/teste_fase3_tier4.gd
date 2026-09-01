## teste_fase3_tier4.gd — Teste headless do Tier 4 (Celadon City + Ginásio
## da Erika). Reescrito em 02/09 (reorganização geográfica): Celadon fica a
## OESTE de Saffron agora, não mais numa fileira reta a leste de Vermilion.
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase3_tier4.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 3 Tier 4 (Celadon, a oeste de Saffron) ===")

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

	# ---- 1. Caminho contínuo de Saffron até Celadon (corredor r16-20) ----
	var r0 := MapLayouts.SAFFRON_ROW_INICIO
	var quebras := 0
	for c in range(MapLayouts.CELADON_COL_INICIO, MapLayouts.SPINE_COL_INICIO):
		if tiles[r0 + 18][c] != "P" and tiles[r0 + 18][c] != ".":
			quebras += 1
	_assert(quebras == 0, "caminho de Celadon até Saffron é contínuo (%d quebras)" % quebras)

	var ce0 := MapLayouts.CELADON_COL_INICIO
	_assert(tiles[r0 + 10][ce0 + 16] == "I", "Celadon: interior do Ginásio (Erika) é piso")
	_assert(tiles[r0 + 6][ce0 + 16] == "H", "Celadon: telhado do Ginásio existe")
	_assert(tiles[r0 + 10][ce0 + 41] == "I", "Celadon: interior do Centro Pokémon é piso")
	_assert(tiles[r0 + 10][ce0 + 54] == "I", "Celadon: interior da Loja de Departamentos é piso")

	# ---- 2. Mar separando Celadon de Viridian, de verdade ----
	_assert(tiles[r0 + 10][MapLayouts.MAR_CELADON_VIRIDIAN_COL_INICIO + 5] == "~",
		"mar entre Celadon e Viridian existe (separação real)")

	var world_scene := load("res://scenes/world/maps/WorldMap.tscn") as PackedScene
	_assert(world_scene != null, "WorldMap.tscn carrega sem erro")
	if world_scene:
		var inst := world_scene.instantiate()
		var erika := inst.get_node_or_null("Entities/Erika")
		_assert(erika != null, "Erika existe no WorldMap")
		if erika:
			_assert(erika.trainer_team.size() == 2 and erika.trainer_team[0]["species_id"] == 45
				and erika.trainer_team[1]["species_id"] == 71,
				"Erika tem o time real (Vileplume + Victreebel)")
			_assert(erika.starts_quest_id == "GYM-04", "Erika inicia a GYM-04")

		var warp_zones := inst.get_node_or_null("WarpZones")
		var alvos_indevidos := 0
		if warp_zones:
			for w in warp_zones.get_children():
				if w.target_map != "" and not w.target_map.contains("PokemonCenter") \
				and not w.target_map.contains("MtMoon") and not w.target_map.contains("RockTunnel") and not w.target_map.contains("SafariZone") and not w.target_map.contains("RocketHideout") and not w.target_map.contains("VictoryRoad") and not w.target_map.contains("DiglettsCave") and not w.target_map.contains("PokemonTower") and not w.target_map.contains("SilphCo") and not w.target_map.contains("GameCorner") and not w.target_map.contains("RocketHQ") and not w.target_map.contains("PokemonMansion"):
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
	var achou_oddish_r7 := false
	for w in by_id["route_7"].get("wild_pokemon", []):
		if int(w.get("id", 0)) == 43:
			achou_oddish_r7 = true
	_assert(achou_oddish_r7, "Rota 7 tem Oddish (mais uma fonte pro objetivo 'capturar 3 Oddish' da GYM-04)")

	var quests_f := FileAccess.open("res://data/quests/quests.json", FileAccess.READ)
	var quests = JSON.parse_string(quests_f.get_as_text())
	quests_f.close()
	var gym4_objs : Array = quests["GYM-04"]["objectives"]
	var tem_capture_oddish := false
	for o in gym4_objs:
		if o.get("type","") == "capture_count" and o.get("target","") == "oddish":
			tem_capture_oddish = true
	_assert(tem_capture_oddish, "GYM-04 pede capturar Oddish — Oddish já é alcançável (Rota 5 e Rota 7)")

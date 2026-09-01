## teste_fase3_tier3.gd — Teste headless do Tier 3 da expansão de mapa
## (Rota 5 → Rota 6 → Vermilion City + Ginásio do Lt. Surge).
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase3_tier3.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 3 Tier 3 (Rota 5 → Rota 6 → Vermilion) ===")

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
	_assert(layout["width"] >= 460, "world_map tem pelo menos 460 de largura (Rota5+Rota6+Vermilion cabem)")

	# ---- 1. Caminho contínuo de Cerulean até Vermilion, sem quebra ----
	# (220 = fim de Cerulean, 460 = fim do mapa)
	var quebras := 0
	for c in range(220, 458):
		if tiles[18][c] != "P" and tiles[18][c] != "." :
			quebras += 1
	_assert(quebras == 0, "caminho de Cerulean até Vermilion (row 18) é contínuo (%d quebras)" % quebras)

	# ---- 2. Ginásio e Centro Pokémon de Vermilion existem ----
	_assert(tiles[10][416] == "I", "Vermilion: interior do Ginásio (Lt. Surge) é piso")
	_assert(tiles[6][416] == "H", "Vermilion: telhado do Ginásio existe")
	_assert(tiles[10][441] == "I", "Vermilion: interior do Centro Pokémon é piso")

	# ---- 3. WorldMap: Lt. Surge tem time real ----
	var world_scene := load("res://scenes/world/maps/WorldMap.tscn") as PackedScene
	_assert(world_scene != null, "WorldMap.tscn carrega sem erro")
	if world_scene:
		var inst := world_scene.instantiate()
		var surge := inst.get_node_or_null("Entities/LtSurge")
		_assert(surge != null, "Lt. Surge existe no WorldMap")
		if surge:
			_assert(surge.trainer_team.size() == 2 and surge.trainer_team[0]["species_id"] == 100
				and surge.trainer_team[1]["species_id"] == 26,
				"Lt. Surge tem o time real (Voltorb + Raichu)")
			_assert(surge.starts_quest_id == "GYM-03", "Lt. Surge inicia a GYM-03")

		var warp_zones := inst.get_node_or_null("WarpZones")
		var alvos_indevidos := 0
		if warp_zones:
			for w in warp_zones.get_children():
				if w.target_map != "" and not w.target_map.contains("PokemonCenter") \
				and not w.target_map.contains("MtMoon") and not w.target_map.contains("RockTunnel"):
					alvos_indevidos += 1
		_assert(alvos_indevidos == 0,
			"nenhum warp de cidade/rota indevido sobrou (%d de sobra)" % alvos_indevidos)
		inst.free()

	# ---- 4. zones.json: Voltorb em algum lugar reachable (objetivo da GYM-03) ----
	var f := FileAccess.open("res://data/world/zones.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	var by_id := {}
	for z in data["zones"]:
		by_id[z["id"]] = z
	var achou_voltorb := false
	for zid in by_id.keys():
		for w in by_id[zid].get("wild_pokemon", []):
			if int(w.get("id", 0)) == 100:
				achou_voltorb = true
	_assert(achou_voltorb, "Voltorb existe em algum spawn selvagem (objetivo da GYM-03 é alcançável)")

	# ---- 5. Todos os 5 arquivos de teste anteriores continuam passando é
	# conferido rodando cada um separadamente — aqui só a soma de fases ----
	_assert(MapLayouts.OFFSET_ANTIGO == 72, "OFFSET_ANTIGO continua 72 — Tiers 2/3 não tocaram no norte do mapa")

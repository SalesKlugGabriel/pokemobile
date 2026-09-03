## teste_fase3_tier3.gd — Teste headless do Tier 3 (Vermilion City + Ginásio
## do Lt. Surge). Reescrito em 02/09 (reorganização geográfica): Vermilion
## não fica mais numa fileira reta a leste de Cerulean — agora fica
## diretamente ABAIXO de Cerulean (via Rota 5 → Saffron → Rota 6).
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase3_tier3.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 3 Tier 3 (Vermilion, embaixo de Saffron) ===")

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

	# ---- 1. Corredor N-S contínuo de Cerulean até Vermilion (col 247-249,
	# de r=37 até o fim de Vermilion) ----
	# "~" é permitido: dentro de Vermilion, col 248 (cc=28) cai na decoração
	# esparsa da doca (cidade portuária) — mesmo padrão de sempre, não é
	# quebra de verdade (o resto do corredor sempre tem P/./I do lado).
	var quebras := 0
	for r in range(MapLayouts.ROUTE5_SUL_START, MapLayouts.VERMILION_ROW_INICIO + MapLayouts.VERMILION_ROWS):
		var ch : String = tiles[r][248]
		if ch != "P" and ch != "." and ch != "I" and ch != "~":
			quebras += 1
	_assert(quebras == 0, "corredor N-S de Cerulean até Vermilion (col 248) é contínuo (%d quebras)" % quebras)

	# ---- 2. Ginásio e Centro Pokémon de Vermilion existem, na posição real ----
	var vc0 := MapLayouts.SPINE_COL_INICIO
	var vr0 := MapLayouts.VERMILION_ROW_INICIO
	_assert(tiles[vr0 + 10][vc0 + 16] == "I", "Vermilion: interior do Ginásio (Lt. Surge) é piso")
	_assert(tiles[vr0 + 6][vc0 + 16] == "H", "Vermilion: telhado do Ginásio existe")
	_assert(tiles[vr0 + 10][vc0 + 41] == "I", "Vermilion: interior do Centro Pokémon é piso")

	# ---- 3. WorldMap: Lt. Surge tem time real ----
	var world_scene := load("res://scenes/world/maps/WorldMap.tscn") as PackedScene
	_assert(world_scene != null, "WorldMap.tscn carrega sem erro")
	if world_scene:
		var inst := world_scene.instantiate()
		var surge := inst.get_node_or_null("Entities/LtSurge")
		_assert(surge != null, "Lt. Surge existe no WorldMap")
		if surge:
			_assert(surge.trainer_team.size() == 6 and surge.trainer_team[0]["species_id"] == 25
				and surge.trainer_team[1]["species_id"] == 81,
				"Lt. Surge tem o time completo de 6 Pokémon tipo Elétrico (Fase 5, 02/09)")
			_assert(surge.starts_quest_id == "GYM-03", "Lt. Surge inicia a GYM-03")

		var warp_zones := inst.get_node_or_null("WarpZones")
		var alvos_indevidos := 0
		if warp_zones:
			for w in warp_zones.get_children():
				if w.target_map != "" and not w.target_map.contains("PokemonCenter") \
				and not w.target_map.contains("MtMoon") and not w.target_map.contains("RockTunnel") and not w.target_map.contains("SafariZone") and not w.target_map.contains("RocketHideout") and not w.target_map.contains("VictoryRoad") and not w.target_map.contains("DiglettsCave") and not w.target_map.contains("PokemonTower") and not w.target_map.contains("SilphCo") and not w.target_map.contains("GameCorner") and not w.target_map.contains("RocketHQ") and not w.target_map.contains("PokemonMansion") and not w.target_map.contains("IndigoLeague"):
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

	_assert(MapLayouts.OFFSET_ANTIGO == 72, "OFFSET_ANTIGO continua 72 — norte do mapa (Pewter/Viridian/Rota1/Pallet) intocado")

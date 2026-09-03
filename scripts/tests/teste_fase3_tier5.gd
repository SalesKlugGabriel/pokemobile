## teste_fase3_tier5.gd — Teste headless do Tier 5 (Fuchsia City + Ginásio
## do Koga). Reescrito em 02/09 (reorganização geográfica): Fuchsia fica
## embaixo de Lavender agora (rota N-S nova), não mais numa fileira reta a
## leste de Celadon. A zona "route_8" (com o Ekans da GYM-05) foi
## realocada pra essa rota nova — mesmo id, coordenada real diferente.
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase3_tier5.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 3 Tier 5 (Fuchsia, embaixo de Lavender) ===")

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

	# ---- 1. Caminho contínuo de Lavender até Fuchsia (corredor N-S, cols
	# LAVENDER_COL_INICIO+27..29) ----
	var col_meio := MapLayouts.LAVENDER_COL_INICIO + 28
	var r_ini := MapLayouts.SAFFRON_ROW_INICIO + MapLayouts.SAFFRON_ROWS
	var r_fim := MapLayouts.FUCHSIA_ROW_INICIO + MapLayouts.FUCHSIA_ROWS
	var quebras := 0
	for r in range(r_ini, r_fim):
		if tiles[r][col_meio] != "P" and tiles[r][col_meio] != "." and tiles[r][col_meio] != "I":
			quebras += 1
	_assert(quebras == 0, "caminho de Lavender até Fuchsia é contínuo (%d quebras)" % quebras)

	var fc0 := MapLayouts.LAVENDER_COL_INICIO
	var fr0 := MapLayouts.FUCHSIA_ROW_INICIO
	_assert(tiles[fr0 + 10][fc0 + 16] == "I", "Fuchsia: interior do Ginásio (Koga) é piso")
	_assert(tiles[fr0 + 6][fc0 + 16] == "H", "Fuchsia: telhado do Ginásio existe")
	_assert(tiles[fr0 + 10][fc0 + 41] == "I", "Fuchsia: interior do Centro Pokémon é piso")

	var world_scene := load("res://scenes/world/maps/WorldMap.tscn") as PackedScene
	_assert(world_scene != null, "WorldMap.tscn carrega sem erro")
	if world_scene:
		var inst := world_scene.instantiate()
		var koga := inst.get_node_or_null("Entities/Koga")
		_assert(koga != null, "Koga existe no WorldMap")
		if koga:
			_assert(koga.trainer_team.size() == 6 and koga.trainer_team[0]["species_id"] == 43
				and koga.trainer_team[1]["species_id"] == 44,
				"Koga tem o time completo de 6 Pokémon tipo Planta+Veneno (Fase 5, 02/09 — pedido do Gabriel, muda do Koffing/Weezing canônico)")
			_assert(koga.starts_quest_id == "GYM-05", "Koga inicia a GYM-05")

		var warp_zones := inst.get_node_or_null("WarpZones")
		var alvos_indevidos := 0
		if warp_zones:
			for w in warp_zones.get_children():
				if w.target_map != "" and not w.target_map.contains("PokemonCenter") \
				and not w.target_map.contains("MtMoon") and not w.target_map.contains("RockTunnel") and not w.target_map.contains("SafariZone") and not w.target_map.contains("RocketHideout") and not w.target_map.contains("VictoryRoad") and not w.target_map.contains("DiglettsCave") and not w.target_map.contains("PokemonTower") and not w.target_map.contains("SilphCo") and not w.target_map.contains("GameCorner") and not w.target_map.contains("RocketHQ") and not w.target_map.contains("PokemonMansion") and not w.target_map.contains("IndigoLeague") and not w.target_map.contains("SSAnne"):
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
	var achou_ekans_r8 := false
	for w in by_id["route_8"].get("wild_pokemon", []):
		if int(w.get("id", 0)) == 23:
			achou_ekans_r8 = true
	_assert(achou_ekans_r8, "Rota 8 (agora Lavender→Fuchsia) tem Ekans (objetivo 'derrotar 5 Ekans' da GYM-05 é alcançável)")

	var quests_f := FileAccess.open("res://data/quests/quests.json", FileAccess.READ)
	var quests = JSON.parse_string(quests_f.get_as_text())
	quests_f.close()
	var gym5_objs : Array = quests["GYM-05"]["objectives"]
	var tem_ekans_obj := false
	for o in gym5_objs:
		if o.get("type","") == "defeat_count" and o.get("target","") == "ekans" and o.get("zone","") == "route_8":
			tem_ekans_obj = true
	_assert(tem_ekans_obj, "GYM-05 pede derrotar Ekans na Rota 8 — sem alpha_arbok (mecânica que não existe)")

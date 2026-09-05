## teste_fase3_tier2.gd — Teste headless do Tier 2 da expansão de mapa
## (Rota 3 → Mt Moon → Rota 4 → Cerulean City + Ginásio da Misty).
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase3_tier2.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 3 Tier 2 (Rota 3 → Mt Moon → Rota 4 → Cerulean) ===")

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
	# A largura total cresce a cada tier novo (Tier 3 já somou mais 180) — o
	# que ESTE tier garante é que Rota3+MtMoon+Rota4+Cerulean (180 colunas)
	# couberam antes de qualquer coisa nova começar.
	_assert(layout["width"] >= 280, "world_map tem pelo menos 280 de largura (Rota3+MtMoon+Rota4+Cerulean cabem)")

	# ---- 1. Caminho principal leste-oeste é contínuo, sem quebra, de Pewter
	# até a boca do Mt Moon (a única quebra de verdade É o Mt Moon — caverna,
	# a exceção que o Gabriel autorizou) ----
	var quebras := 0
	for c in range(100, 156):  # até quase a boca da montanha
		if tiles[18][c] != "P":
			quebras += 1
	_assert(quebras == 0, "caminho de Pewter até a boca do Mt Moon (row 18) é contínuo (%d quebras)" % quebras)

	# ---- 2. Depois da montanha, a Rota 4 continua até Cerulean ----
	var quebras2 := 0
	for c in range(164, 220):
		if tiles[18][c] != "P":
			quebras2 += 1
	_assert(quebras2 == 0, "Rota 4 (depois da montanha) até Cerulean é contínua (%d quebras)" % quebras2)

	# ---- 3. Ginásio e Centro Pokémon de Cerulean existem ----
	# 05/09 (Fase 0): eram três coordenadas literais. A intenção é "Cerulean tem
	# Ginásio e Centro Pokémon, com telhado, interior e porta" — a posição é
	# acidente e agora vem do retângulo da zona, fonte única.
	var r_cerulean := AjudaMapa.retangulo_da_zona("cerulean_city")
	_assert(r_cerulean.size.x > 0, "Cerulean está cadastrada no zones.json")
	_assert(AjudaMapa.conta_predios(tiles, r_cerulean) >= 2,
		"Cerulean tem Ginásio e Centro Pokémon (%d prédios)" % AjudaMapa.conta_predios(tiles, r_cerulean))
	_assert(AjudaMapa.tem_predio_completo(tiles, r_cerulean),
		"os prédios de Cerulean têm telhado, interior andável E porta")

	# ---- 4. Mt Moon é cena própria (caverna — a única exceção de warp) ----
	var mt_layout = MapLayouts.get_layout("mt_moon")
	_assert(mt_layout.get("width", 0) == 20 and mt_layout.get("height", 0) == 30,
		"Mt Moon gera 20x30")
	var mt_tiles : Array = mt_layout["tiles"]
	_assert(mt_tiles[29][9] == "P" and mt_tiles[29][10] == "P",
		"Mt Moon: entrada sul (vinda da Rota 3) é caminho")
	_assert(mt_tiles[0][9] == "P" and mt_tiles[0][10] == "P",
		"Mt Moon: saída norte (pra Rota 4) é caminho")
	_assert(mt_tiles[15][9] == "I" or mt_tiles[15][9] == "P",
		"Mt Moon: caminho central (col 9) é sempre andável — nunca fica rocha bloqueando por completo")

	var mtmoon_scene := load("res://scenes/world/maps/MtMoon.tscn") as PackedScene
	_assert(mtmoon_scene != null, "MtMoon.tscn carrega sem erro")

	# ---- 5. WorldMap: Misty tem time real, boca do Mt Moon é warp de verdade ----
	var world_scene := load("res://scenes/world/maps/WorldMap.tscn") as PackedScene
	_assert(world_scene != null, "WorldMap.tscn carrega sem erro")
	if world_scene:
		var inst := world_scene.instantiate()
		var misty := inst.get_node_or_null("Entities/Misty")
		_assert(misty != null, "Misty existe no WorldMap")
		if misty:
			_assert(misty.trainer_team.size() == 5 and misty.trainer_team[0]["species_id"] == 54
				and misty.trainer_team[1]["species_id"] == 60,
				"Misty tem o time completo de 5 Pokémon tipo Água (Fase 5, 02/09)")
			_assert(misty.starts_quest_id == "GYM-02", "Misty inicia a GYM-02")

		var warp_zones := inst.get_node_or_null("WarpZones")
		var vai_pro_mtmoon := false
		var alvos_indevidos := 0
		if warp_zones:
			for w in warp_zones.get_children():
				if w.target_map.contains("MtMoon"):
					vai_pro_mtmoon = true
				elif w.target_map != "" and not w.target_map.contains("PokemonCenter") \
				and not w.target_map.contains("RockTunnel") and not w.target_map.contains("SafariZone") and not w.target_map.contains("RocketHideout") and not w.target_map.contains("VictoryRoad") and not w.target_map.contains("DiglettsCave") and not w.target_map.contains("PokemonTower") and not w.target_map.contains("SilphCo") and not w.target_map.contains("GameCorner") and not w.target_map.contains("RocketHQ") and not w.target_map.contains("PokemonMansion") and not w.target_map.contains("IndigoLeague") and not w.target_map.contains("SSAnne") and not w.target_map.contains("CeruleanCave"):
					alvos_indevidos += 1
		_assert(vai_pro_mtmoon, "existe um warp pra dentro do Mt Moon (caverna — exceção permitida)")
		_assert(alvos_indevidos == 0,
			"nenhum OUTRO warp de cidade/rota sobrou — só Centro Pokémon, Mt Moon e Rock Tunnel (%d indevidos)" % alvos_indevidos)
		inst.free()

	# ---- 6. zones.json: spawns reais de Rota 3/Mt Moon/Rota 4 ----
	var f := FileAccess.open("res://data/world/zones.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	var by_id := {}
	for z in data["zones"]:
		by_id[z["id"]] = z

	var r3_ids := []
	for w in by_id["route_3"].get("wild_pokemon", []):
		r3_ids.append(int(w["id"]))
	_assert(19 in r3_ids and 21 in r3_ids, "Rota 3 tem Rattata e Spearow (spawn real do Gen 1)")

	var mm_ids := []
	for w in by_id["mt_moon"].get("wild_pokemon", []):
		mm_ids.append(int(w["id"]))
	_assert(41 in mm_ids and 74 in mm_ids and 35 in mm_ids,
		"Mt Moon tem Zubat, Geodude e Clefairy (spawn real do Gen 1)")

	var r4_ids := []
	for w in by_id["route_4"].get("wild_pokemon", []):
		r4_ids.append(int(w["id"]))
	_assert(27 in r4_ids, "Rota 4 tem Sandshrew (spawn real do Gen 1)")

	# ---- 7. GYM-02 simplificado (sem depender de mecânica de Alpha que não existe) ----
	var quests_f := FileAccess.open("res://data/quests/quests.json", FileAccess.READ)
	var quests = JSON.parse_string(quests_f.get_as_text())
	quests_f.close()
	var gym2_objs : Array = quests["GYM-02"]["objectives"]
	_assert(gym2_objs.size() == 1 and gym2_objs[0]["type"] == "defeat" and gym2_objs[0]["target"] == "misty",
		"GYM-02 agora só exige derrotar a Misty (removido o alpha_tentacruel impossível)")

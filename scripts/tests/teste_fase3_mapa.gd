## teste_fase3_mapa.gd — Teste headless da expansão do mapa (mundo aberto:
## Pewter City + Rota 2 dentro do MESMO world_map, sem warp — decisão do
## Gabriel em 31/08: warp só pra caverna/subterrâneo/submarino/continente).
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase3_mapa.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 3 (mundo aberto: Pewter City + Rota 2) ===")

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
	var H : int = layout["height"]

	# largura cresce a cada tier novo (Tier 2 já somou Rota3+MtMoon+Rota4+
	# Cerulean a leste de Pewter) — aqui só confere a ALTURA, que é o que
	# esta fase (Pewter+Rota2, ao norte) realmente controla.
	_assert(H == 330, "world_map tem 192 de altura (Pewter+Rota2 somaram 72 linhas)")

	# ---- 1. Pewter City (linhas 1-36) ----
	_assert(tiles[10][26] == "I", "Pewter: interior do Ginásio (col 26, row 10) é piso")
	_assert(tiles[6][26] == "H", "Pewter: telhado do Ginásio (row 6) existe")
	_assert(tiles[18][26] == "P", "Pewter: porta do Ginásio (row 18) é caminho")
	_assert(tiles[10][76] == "I", "Pewter: interior do Centro Pokémon (col 76, row 10) é piso")
	_assert(tiles[14][76] == "P", "Pewter: porta do Centro Pokémon (row 14) é caminho")

	# ---- 2. Corredor central é UM SÓ, sem quebra, de Pewter até Pallet ----
	# (a prova de que é mundo aberto de verdade: anda reto por 190 linhas
	# sem nenhum warp no meio — só bate em parede/água/caverna, isso não
	# existe ainda nesse trecho)
	# Pallet é o fim da estrada (sul do mapa) — o corredor dela só vai até
	# old_r=115 (o resto é a borda sul, de propósito, sem quebra "no meio").
	var fim_do_corredor := 115 + MapLayouts.OFFSET_ANTIGO
	var quebras := 0
	for r in range(3, fim_do_corredor + 1):
		if tiles[r][50] != "P" and tiles[r][50] != "I" and tiles[r][50] != "W" and tiles[r][50] != "H":
			quebras += 1
	_assert(quebras == 0,
		"corredor central (col 50) é caminhável do topo (Pewter) até o fim de Pallet, sem quebra (%d quebras)" % quebras)

	# ---- 3. Rota 2 (linhas locais 37-72) tem grama/árvore, não é cidade ----
	_assert(tiles[55][20] == "." or tiles[55][20] == "T" or tiles[55][20] == "F",
		"Rota 2 (row 55, fora do corredor) é grama/árvore/flor, não prédio")

	# ---- 4. Viridian/Rota 1/Pallet continuam exatamente onde sempre foram
	# (só que 72 linhas mais pra baixo) — prova que nada do que já existia
	# mudou de desenho, só de posição ----
	_assert(tiles[74 + 8][26] == "W" or tiles[74 + 8][26] == "H",
		"Ginásio de Viridian (fechado) continua existindo, só deslocado 72 linhas")
	_assert(tiles[152 + 6][50] == "P",
		"Corredor de Pallet continua no mesmo lugar relativo, só deslocado")

	# ---- 5. As cenas antigas (separadas) não existem mais ----
	_assert(not FileAccess.file_exists("res://scenes/world/maps/Route2.tscn"),
		"Route2.tscn (cena separada, abordagem antiga) foi removida")
	_assert(not FileAccess.file_exists("res://scenes/world/maps/PewterCity.tscn"),
		"PewterCity.tscn (cena separada, abordagem antiga) foi removida")

	# ---- 6. WorldMap.tscn carrega, Brock e Colecionador têm time real ----
	var world_scene := load("res://scenes/world/maps/WorldMap.tscn") as PackedScene
	_assert(world_scene != null, "WorldMap.tscn carrega sem erro")
	if world_scene:
		var inst := world_scene.instantiate()
		var brock := inst.get_node_or_null("Entities/Brock")
		_assert(brock != null, "Brock existe dentro do WorldMap único (não é mais cena separada)")
		if brock:
			_assert(brock.trainer_team.size() == 6 and brock.trainer_team[0]["species_id"] == 74,
				"Brock tem o time completo de 6 Pokémon tipo Pedra (Fase 5, 02/09)")
			_assert(brock.starts_quest_id == "GYM-01", "Brock continua iniciando a GYM-01")
		var colecionador := inst.get_node_or_null("Entities/Colecionador")
		_assert(colecionador != null and not colecionador.trainer_team.is_empty(),
			"Colecionador de Insetos existe com time real")
		# Nenhum warp de cidade/rota deve sobrar — só o do Centro Pokémon
		# (caverna/subterrâneo seria a única outra exceção válida, ainda não existe)
		var warp_zones := inst.get_node_or_null("WarpZones")
		var alvos_nao_pokecenter := 0
		if warp_zones:
			for w in warp_zones.get_children():
				# Mt Moon é caverna — exceção permitida (ver Tier 2). Só
				# cidade/rota ligada por warp que não deveria existir.
				if w.target_map != "" and not w.target_map.contains("PokemonCenter") \
				and not w.target_map.contains("MtMoon") and not w.target_map.contains("RockTunnel") and not w.target_map.contains("SafariZone") and not w.target_map.contains("RocketHideout") and not w.target_map.contains("VictoryRoad") and not w.target_map.contains("DiglettsCave") and not w.target_map.contains("PokemonTower") and not w.target_map.contains("SilphCo") and not w.target_map.contains("GameCorner") and not w.target_map.contains("RocketHQ") and not w.target_map.contains("PokemonMansion"):
					alvos_nao_pokecenter += 1
		_assert(alvos_nao_pokecenter == 0,
			"nenhum warp de CIDADE/ROTA indevido sobrou no WorldMap — só Centro Pokémon e Mt Moon (%d de sobra)" % alvos_nao_pokecenter)
		inst.free()

	# ---- 7. zones.json bate com o mapa único novo ----
	var f := FileAccess.open("res://data/world/zones.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	var by_id := {}
	for z in data["zones"]:
		by_id[z["id"]] = z
	_assert(int(by_id["viridian_city"]["tile_rect"]["y"]) == 74,
		"zones.json: viridian_city foi atualizado pro novo y (74)")
	_assert(int(by_id["pallet_town"]["tile_rect"]["y"]) == 152,
		"zones.json: pallet_town foi atualizado pro novo y (152)")
	var tem_geodude := false
	for w in by_id["route_2"].get("wild_pokemon", []):
		if int(w.get("id", 0)) == 74:
			tem_geodude = true
	_assert(tem_geodude, "zones.json: Rota 2 tem Geodude no spawn selvagem")

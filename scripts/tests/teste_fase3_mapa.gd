## teste_fase3_mapa.gd — Teste headless da expansão do mapa (Rota 2 + Pewter
## City) e do Ginásio do Brock. Roda com:
## godot4 --headless --script res://scripts/tests/teste_fase3_mapa.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 3 (Rota 2 + Pewter City + Brock) ===")

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
	# ---- 1. Layouts existem e têm o tamanho certo ----
	var r2 = MapLayouts.get_layout("route_2")
	_assert(r2.get("width", 0) == 16 and r2.get("height", 0) == 50,
		"route_2 gera 16x50 (veio %sx%s)" % [r2.get("width"), r2.get("height")])
	var pc = MapLayouts.get_layout("pewter_city")
	_assert(pc.get("width", 0) == 40 and pc.get("height", 0) == 30,
		"pewter_city gera 40x30 (veio %sx%s)" % [pc.get("width"), pc.get("height")])

	# ---- 2. Rota 2: corredor central caminhável, bordas bloqueadas ----
	var r2_tiles : Array = r2["tiles"]
	_assert(r2_tiles[25][7] == "P", "Rota 2: corredor central (col 7) é caminho no meio do mapa")
	_assert(r2_tiles[25][0] == "T", "Rota 2: borda oeste é árvore (bloqueada)")
	_assert(r2_tiles[0][7] == "T" and r2_tiles[49][7] == "T",
		"Rota 2: bordas norte/sul são árvore — a saída de verdade é 1 tile antes")
	_assert(r2_tiles[1][7] == "P" and r2_tiles[48][7] == "P",
		"Rota 2: os tiles logo depois da borda (rows 1 e 48) são caminháveis — onde os warps ficam")

	# ---- 3. Pewter: Ginásio e Centro Pokémon existem, com porta ----
	var pc_tiles : Array = pc["tiles"]
	_assert(pc_tiles[10][14] == "I", "Pewter: interior do Ginásio (col 14, row 10) é piso caminhável")
	_assert(pc_tiles[6][14] == "H", "Pewter: telhado do Ginásio (row 6) existe")
	_assert(pc_tiles[14][14] == "P", "Pewter: porta do Ginásio (col 14, row 14) é caminho")
	_assert(pc_tiles[10][30] == "I", "Pewter: interior do Centro Pokémon (col 30, row 10) é piso")
	_assert(pc_tiles[28][20] == "P", "Pewter: corredor sul (col 20, row 28) caminhável — onde chega vindo da Rota 2")
	_assert(pc_tiles[29][20] == "T", "Pewter: borda sul (row 29) é árvore, exatamente como o resto do mapa")

	# ---- 4. As cenas carregam de verdade e o Brock tem time de batalha ----
	var route2_scene := load("res://scenes/world/maps/Route2.tscn") as PackedScene
	_assert(route2_scene != null, "Route2.tscn carrega sem erro")
	var pewter_scene := load("res://scenes/world/maps/PewterCity.tscn") as PackedScene
	_assert(pewter_scene != null, "PewterCity.tscn carrega sem erro")

	if pewter_scene:
		var inst := pewter_scene.instantiate()
		var brock := inst.get_node_or_null("Entities/Brock")
		_assert(brock != null, "Brock existe na cena de Pewter")
		if brock:
			_assert(brock.npc_name == "Brock", "nome do NPC é 'Brock' (bate com o alvo da quest GYM-01)")
			_assert(brock.is_trainer, "Brock está marcado como treinador")
			_assert(brock.trainer_team.size() == 2, "Brock tem um time de 2 Pokémon")
			_assert(brock.trainer_team[0]["species_id"] == 74, "primeiro Pokémon do Brock é Geodude (74)")
			_assert(brock.trainer_team[1]["species_id"] == 95, "segundo Pokémon do Brock é Onix (95)")
		inst.free()

	# ---- 5. zones.json: Rota 2 tem Geodude no spawn selvagem ----
	var f := FileAccess.open("res://data/world/zones.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	var route2_zone : Dictionary = {}
	for z in data["zones"]:
		if z["id"] == "route_2":
			route2_zone = z
	var tem_geodude := false
	for w in route2_zone.get("wild_pokemon", []):
		if int(w.get("id", 0)) == 74:
			tem_geodude = true
	_assert(tem_geodude, "Rota 2 tem Geodude na tabela de spawn selvagem (precisa pra GYM-01)")

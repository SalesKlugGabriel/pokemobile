## teste_fase3_tier10.gd — Teste headless do Tier 10 da expansão de mapa
## (Rock Tunnel — dungeon lateral opcional, entrada na Rota 10).
## PRIMEIRA caverna construída depois da regra de tematização de bioma do
## Gabriel (01/09): interior gerado por caminhada aleatória (não-linear de
## verdade), não retângulo+rochas-em-grade como o Mt Moon.
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase3_tier10.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 3 Tier 10 (Rock Tunnel) ===")

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
	# ---- 1. Entrada na Rota 8/10 (superfície) — moldura de rocha + patch
	# caminhável. Reorganização de 02/09: a Rota 10 (com a boca do Rock
	# Tunnel) virou a segunda metade da nova Rota 8 (Saffron → Lavender). ----
	var world_layout = MapLayouts.get_layout("world_map")
	var wtiles : Array = world_layout["tiles"]
	var r0 := MapLayouts.SAFFRON_ROW_INICIO
	var entrada_col := MapLayouts.SPINE_COL_INICIO + MapLayouts.CERULEAN_COLS + MapLayouts.ROUTE9_COLS + 23
	_assert(wtiles[r0 + 18][entrada_col] == "P", "Rota 8: entrada do Rock Tunnel é caminhável (onde fica o warp)")
	_assert(wtiles[r0 + 13][entrada_col - 3] == "R", "Rota 8: moldura de rocha ao lado da boca do Rock Tunnel existe")
	_assert(wtiles[r0 + 18][entrada_col - 3] == "P", "Rota 8: o corredor leste-oeste NUNCA é bloqueado pela moldura da caverna")

	# ---- 2. Layout interno: 36x36, determinístico (seed fixa) ----
	var layout = MapLayouts.get_layout("rock_tunnel")
	var tiles : Array = layout["tiles"]
	_assert(layout["width"] == 36 and layout["height"] == 36, "rock_tunnel tem 36x36")

	# ---- 3. Porta única ao sul ----
	_assert(tiles[35][17] == "P" and tiles[35][18] == "P", "porta única (entrada/saída) existe ao sul")
	_assert(tiles[34][17] == "D" or tiles[34][18] == "D", "logo depois da porta já é piso (caminhada começa ali)")

	# ---- 4. Determinístico: gerar de novo dá EXATAMENTE o mesmo resultado
	# (seed fixa — prova de que não é aleatório de verdade a cada load) ----
	var layout2 = MapLayouts.get_layout("rock_tunnel")
	var tiles2 : Array = layout2["tiles"]
	_assert(tiles == tiles2, "gerar o Rock Tunnel duas vezes dá exatamente a mesma caverna (seed fixa)")

	# ---- 5. Contagem de piso ("D") vs. rocha ("R") — ainda É uma CAVERNA
	# (minoria de piso), não virou uma sala aberta ----
	var piso := 0
	var rocha := 0
	var min_r := 999
	var max_r := -1
	var min_c := 999
	var max_c := -1
	for r in tiles.size():
		var row : String = tiles[r]
		for c in row.length():
			var ch := row[c]
			if ch == "D":
				piso += 1
				min_r = min(min_r, r)
				max_r = max(max_r, r)
				min_c = min(min_c, c)
				max_c = max(max_c, c)
			elif ch == "R":
				rocha += 1
	_assert(piso > 200, "caminhada aleatória escavou território real (%d tiles de piso)" % piso)
	_assert(piso < rocha, "ainda é MAIS rocha que piso — continua parecendo caverna, não sala aberta (%d piso / %d rocha)" % [piso, rocha])

	# ---- 6. Não-linear de verdade: o piso se espalha por uma boa faixa de
	# linhas E colunas (não é um corredor reto numa única direção) ----
	_assert(max_r - min_r > 15, "piso se espalha por mais de 15 linhas (não é um corredor reto na horizontal)")
	_assert(max_c - min_c > 15, "piso se espalha por mais de 15 colunas (não é um corredor reto na vertical)")

	# ---- 7. Conectividade: TODO tile de piso é alcançável a partir da porta
	# (os ramos secundários nunca ficam isolados) ----
	var visitado := {}
	var fila := [Vector2i(17, 34)]
	visitado[Vector2i(17, 34)] = true
	var direcoes : Array[Vector2i] = [Vector2i(0,-1), Vector2i(0,1), Vector2i(-1,0), Vector2i(1,0)]
	while fila.size() > 0:
		var p : Vector2i = fila.pop_back()
		for d in direcoes:
			var np : Vector2i = p + d
			if np.x < 0 or np.x >= 36 or np.y < 0 or np.y >= 36:
				continue
			if visitado.has(np):
				continue
			var ch : String = tiles[np.y][np.x]
			if ch == "D" or ch == "P":
				visitado[np] = true
				fila.append(np)
	# conta tiles de piso alcançados (menos a porta, que é "P" não "D")
	var alcancados := 0
	for k in visitado.keys():
		if tiles[k.y][k.x] == "D":
			alcancados += 1
	_assert(alcancados == piso, "TODO tile de piso é alcançável a partir da porta — nenhum ramo secundário ficou isolado (%d de %d)" % [alcancados, piso])

	# ---- 8. Cenas e warps ----
	var rt_scene := load("res://scenes/world/maps/RockTunnel.tscn") as PackedScene
	_assert(rt_scene != null, "RockTunnel.tscn carrega sem erro")

	var world_scene := load("res://scenes/world/maps/WorldMap.tscn") as PackedScene
	if world_scene:
		var inst := world_scene.instantiate()
		var warp_zones := inst.get_node_or_null("WarpZones")
		var achou_warp_rt := false
		if warp_zones:
			for w in warp_zones.get_children():
				if w.target_map.contains("RockTunnel"):
					achou_warp_rt = true
		_assert(achou_warp_rt, "WorldMap tem warp de verdade pro Rock Tunnel")
		inst.free()

	if rt_scene:
		var rt_inst := rt_scene.instantiate()
		var rt_warps := rt_inst.get_node_or_null("WarpZones")
		var achou_volta := false
		var saida_col := MapLayouts.SPINE_COL_INICIO + MapLayouts.CERULEAN_COLS + MapLayouts.ROUTE9_COLS + 23
		var saida_row := MapLayouts.SAFFRON_ROW_INICIO + 18
		if rt_warps:
			for w in rt_warps.get_children():
				if w.target_map.contains("WorldMap") and w.spawn_tile == Vector2i(saida_col, saida_row):
					achou_volta = true
		_assert(achou_volta, "Rock Tunnel tem warp de volta pra Rota 8, no mesmo tile da entrada")
		rt_inst.free()

	# ---- 9. zones.json: spawn selvagem real do Gen 1 ----
	var f := FileAccess.open("res://data/world/zones.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	var by_id := {}
	for z in data["zones"]:
		by_id[z["id"]] = z
	var especies := []
	for w in by_id["rock_tunnel"].get("wild_pokemon", []):
		especies.append(int(w.get("id", 0)))
	_assert(41 in especies and 74 in especies and 95 in especies,
		"Rock Tunnel tem Zubat/Geodude/Onix (spawn real do Gen 1)")

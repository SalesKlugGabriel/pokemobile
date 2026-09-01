## teste_fase3_tier12.gd — Teste headless do Tier 12 da expansão de mapa
## (Zona Safari — entrada por warp em Fuchsia, pedido explícito do Gabriel).
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase3_tier12.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 3 Tier 12 (Zona Safari) ===")

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
	# ---- 1. Layout interno: 44x44, cercado, portão único ----
	var layout = MapLayouts.get_layout("safari_zone")
	var tiles : Array = layout["tiles"]
	_assert(layout["width"] == 44 and layout["height"] == 44, "safari_zone tem 44x44")
	_assert(tiles[0][10] == "E", "borda norte é cerca (reserva controlada, não árvore)")
	_assert(tiles[43][10] == "E", "borda sul (fora do portão) é cerca")
	_assert(tiles[43][21] == "P", "portão único existe na borda sul (warp fica aqui)")

	# ---- 2. Lagoas de contorno orgânico existem ----
	var achou_lagoa := false
	for r in tiles.size():
		var row : String = tiles[r]
		for c in row.length():
			if row[c] == "~":
				achou_lagoa = true
	_assert(achou_lagoa, "existe pelo menos uma lagoa dentro da Zona Safari")

	# ---- 3. WorldMap: portão de Fuchsia virou warp de verdade (não é mais
	# só decoração). Reorganização de 02/09: Fuchsia fica embaixo de
	# Lavender agora. ----
	var world_layout = MapLayouts.get_layout("world_map")
	var wtiles : Array = world_layout["tiles"]
	var fc0 := MapLayouts.LAVENDER_COL_INICIO
	var fr0 := MapLayouts.FUCHSIA_ROW_INICIO
	_assert(wtiles[fr0 + 32][fc0 + 54] == "P", "Fuchsia: portão da Zona Safari é caminhável (onde fica o warp)")

	# ---- 4. Regressão: corredor leste-oeste (r16-20) continua passável nas
	# colunas do cercado da Zona Safari — a cerca não vazou pro corredor
	# principal (mesma classe de bug do Tier 10) ----
	var quebras := 0
	for c in range(fc0 + 50, fc0 + 59):
		if wtiles[fr0 + 18][c] != "P" and wtiles[fr0 + 18][c] != ".":
			quebras += 1
	_assert(quebras == 0, "corredor leste-oeste continua passável nas colunas da Zona Safari (%d quebras)" % quebras)

	# ---- 5. Cenas e warps ----
	var sz_scene := load("res://scenes/world/maps/SafariZone.tscn") as PackedScene
	_assert(sz_scene != null, "SafariZone.tscn carrega sem erro")
	if sz_scene:
		var inst := sz_scene.instantiate()
		var guarda := inst.get_node_or_null("Entities/GuardaFlorestal")
		_assert(guarda != null, "Guarda Florestal existe dentro da Zona Safari")
		var warps := inst.get_node_or_null("WarpZones")
		var achou_saida := false
		if warps:
			for w in warps.get_children():
				if w.target_map.contains("WorldMap") and w.spawn_tile == Vector2i(MapLayouts.LAVENDER_COL_INICIO + 54, MapLayouts.FUCHSIA_ROW_INICIO + 33):
					achou_saida = true
		_assert(achou_saida, "existe warp de saída pra Fuchsia, no tile certo perto do portão")
		inst.free()

	var world_scene := load("res://scenes/world/maps/WorldMap.tscn") as PackedScene
	if world_scene:
		var inst := world_scene.instantiate()
		var warp_zones := inst.get_node_or_null("WarpZones")
		var achou_entrada := false
		if warp_zones:
			for w in warp_zones.get_children():
				if w.target_map.contains("SafariZone"):
					achou_entrada = true
		_assert(achou_entrada, "WorldMap tem warp de verdade pra dentro da Zona Safari")
		inst.free()

	# ---- 6. zones.json: spawn real já estava certo, só a nota/coordenada mudou ----
	var f := FileAccess.open("res://data/world/zones.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	var by_id := {}
	for z in data["zones"]:
		by_id[z["id"]] = z
	_assert(int(by_id["safari_zone"]["tile_rect"]["w"]) == 44, "zones.json: safari_zone com coordenada local nova (44x44)")
	var achou_tauros := false
	for w in by_id["safari_zone"].get("wild_pokemon", []):
		if int(w.get("id", 0)) == 128:
			achou_tauros = true
	_assert(achou_tauros, "Zona Safari mantém o spawn real do Gen 1 (Tauros)")

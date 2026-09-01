## teste_fase3_tier19.gd — Teste headless do Tier 19 (Rota 11 → Diglett's
## Cave, segundo ramo em linhas negativas — saindo de Vermilion, não de
## Cerulean). Mesma técnica de pintura à parte do Tier 8.
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase3_tier19.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 3 Tier 19 (Rota 11 → Diglett's Cave) ===")

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

func _atlas_at(tm: TileMap, c: int, r: int) -> Vector2i:
	return tm.get_cell_atlas_coords(0, Vector2i(c, r))

func _teste_geral() -> void:
	var layout = MapLayouts.get_layout("world_map")
	_assert(layout["width"] == 940, "world_map continua com 940 de largura (Tier 19 não mexe no array principal)")

	var tileset := load("res://assets/tilesets/overworld.tres") as TileSet
	var tm := TileMap.new()
	tm.tile_set = tileset
	MapLayouts.paint(tm, "world_map")

	# ---- Seam: sair de Vermilion (r=0/1/2) pro ramo norte ----
	_assert(_atlas_at(tm, 428, 0) == MapLayouts.CHAR_MAP["P"], "seam: col 428 na row 0 é caminho (abre a Rota 11)")
	_assert(_atlas_at(tm, 428, -1) == MapLayouts.CHAR_MAP["P"], "r=-1 (já dentro da Rota 11) é caminhável")

	# ---- Corredor contínuo da Rota 11 até a boca de Diglett's Cave ----
	var quebras := 0
	for r in range(-19, 0):
		if _atlas_at(tm, 428, r) != MapLayouts.CHAR_MAP["P"]:
			quebras += 1
	_assert(quebras == 0, "corredor da Rota 11 contínuo de r=-19 a r=-1 (%d quebras)" % quebras)

	# ---- Boca de Diglett's Cave existe, com moldura de rocha na margem ----
	_assert(_atlas_at(tm, 428, -18) == MapLayouts.CHAR_MAP["P"], "boca de Diglett's Cave é caminhável (entrada do warp)")
	_assert(_atlas_at(tm, 425, -18) == MapLayouts.CHAR_MAP["R"], "margem da boca (col 425, fora do corredor) é rocha")
	_assert(_atlas_at(tm, 428, -10) == MapLayouts.CHAR_MAP["P"], "corredor além da boca (r=-10) continua caminhável")

	# ---- Não colide com o ramo de Cerulean (Tier 8), coluna bem diferente ----
	_assert(_atlas_at(tm, 428, -30) == MapLayouts.CHAR_MAP["T"], "fora do alcance da Rota 11 (r=-30, além de ROUTE11_NORTE_ROWS) é borda/vazio")
	_assert(MapLayouts.ROUTE11_NORTE_COL_INICIO != MapLayouts.RAMO_NORTE_COL_INICIO,
		"corredor da Rota 11 usa colunas diferentes do ramo de Cerulean (não colide)")

	# ---- Warps existem no WorldMap.tscn ----
	var world_scene := load("res://scenes/world/maps/WorldMap.tscn") as PackedScene
	_assert(world_scene != null, "WorldMap.tscn carrega sem erro")
	if world_scene:
		var inst := world_scene.instantiate()
		var warp_zones := inst.get_node_or_null("WarpZones")
		var achou := false
		if warp_zones:
			for w in warp_zones.get_children():
				if w.target_map.contains("DiglettsCave"):
					achou = true
		_assert(achou, "warp de entrada pra DiglettsCave.tscn existe")
		inst.free()

	# ---- Diglett's Cave: cena própria carrega e tem chão suficiente ----
	var dc_scene := load("res://scenes/world/maps/DiglettsCave.tscn") as PackedScene
	_assert(dc_scene != null, "DiglettsCave.tscn carrega sem erro")
	if dc_scene:
		var inst2 := dc_scene.instantiate()
		_assert(inst2.map_id == "digletts_cave", "map_id da cena é digletts_cave")
		var dc_layout = MapLayouts.get_layout("digletts_cave")
		var dc_tiles : Array = dc_layout["tiles"]
		var chao := 0
		for row in dc_tiles:
			chao += row.count("D") + row.count("P")
		_assert(chao > 150, "Diglett's Cave tem chão suficiente escavado (%d tiles)" % chao)
		_assert(dc_tiles[27][13] == "P" and dc_tiles[27][14] == "P", "Diglett's Cave: porta de saída existe")
		inst2.free()

	# ---- zones.json ----
	var f := FileAccess.open("res://data/world/zones.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	var by_id := {}
	for z in data["zones"]:
		by_id[z["id"]] = z
	_assert(int(by_id["route_11"]["tile_rect"]["y"]) < 0, "route_11 tem y negativo (está ao norte de Vermilion)")
	_assert(by_id["digletts_cave"].get("map_id", "") == "digletts_cave", "digletts_cave aponta pra própria cena (map_id)")

	tm.free()

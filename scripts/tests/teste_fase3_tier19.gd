## teste_fase3_tier19.gd — Teste headless do Tier 19 (Rota 11 → Diglett's
## Cave). Reescrito em 02/09 (reorganização geográfica): a espora agora sai
## a LESTE de Vermilion, dentro do array PRINCIPAL (coordenadas positivas) —
## antes saía "ao norte" em linhas negativas, só porque Vermilion não tinha
## mais nenhuma saída livre na fileira reta antiga.
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

func _teste_geral() -> void:
	var layout = MapLayouts.get_layout("world_map")
	var tiles : Array = layout["tiles"]
	_assert(layout["width"] == 465, "world_map tem 465 de largura")

	# Rota 11: cols ROUTE11_COL_INICIO..+29, rows VERMILION_ROW_INICIO..+35.
	var c0 := MapLayouts.ROUTE11_COL_INICIO
	var r0 := MapLayouts.VERMILION_ROW_INICIO

	# Corredor contínuo (vr16-20, aqui testado em vr18) de dist0 até a boca.
	var quebras := 0
	for dist in range(0, 20):
		if tiles[r0 + 18][c0 + dist] != "P":
			quebras += 1
	_assert(quebras == 0, "corredor da Rota 11 contínuo (0 a 19) (%d quebras)" % quebras)

	_assert(tiles[r0 + 18][c0 + 23] == "P", "boca de Diglett's Cave é caminhável (entrada do warp)")
	_assert(tiles[r0 + 13][c0 + 23] == "R", "moldura de rocha ao redor da boca existe")

	# Vermilion não tem parede no próprio limite leste (nenhuma cidade tem —
	# mesmo padrão de sempre) — a Rota 11 conecta direto, sem precisar de
	# brecha especial.
	var vermilion_borda_leste : String = tiles[r0 + 18][MapLayouts.SPINE_COL_INICIO + 58]
	_assert(vermilion_borda_leste != "T" and vermilion_borda_leste != "W" and vermilion_borda_leste != "R",
		"Vermilion não bloqueia o próprio limite leste (cc58 é '%s', caminhável)" % vermilion_borda_leste)

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

	var f := FileAccess.open("res://data/world/zones.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	var by_id := {}
	for z in data["zones"]:
		by_id[z["id"]] = z
	_assert(int(by_id["route_11"]["tile_rect"]["x"]) == c0, "route_11 aponta pra coordenada real (x=%d)" % c0)
	_assert(by_id["digletts_cave"].get("map_id", "") == "digletts_cave", "digletts_cave aponta pra própria cena (map_id)")

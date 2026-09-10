## teste_rota_pewter_viridian.gd — 10/09, Fase 1 (2º trecho) da
## reestruturação geográfica em escala real (docs/mundo-novo-escala.md).
## Pewter↔Viridian, 3.000 tiles = 3km. Primeira vez que o jogo tem um bioma
## de MONTANHA de verdade (rocha com elevação) + uma travessia de CAVERNA
## não-linear ligando dois lados opostos — pendência confirmada pelo Gabriel
## ao aprovar o plano (10/09).
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

const ANDAVEL := ["P", ".", "A", "F", "S", ":", "^", "D"]

func _initialize() -> void:
	print("=== Teste: Rota Pewter-Viridian + Caverna da Montanha (10/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	# ---- Geração da grade da rota ----
	var layout : Dictionary = MapLayouts.get_layout("rota_pewter_viridian")
	_assert(not layout.is_empty(), "get_layout('rota_pewter_viridian') existe")
	_assert(int(layout.get("width", 0)) == 100, "largura 100 tiles")
	_assert(int(layout.get("height", 0)) == 3000, "altura 3.000 tiles — bate com 3km = 3.000 passos")

	var tiles : Array = layout.get("tiles", [])
	_assert(tiles.size() == 3000, "a grade tem 3.000 linhas de verdade")

	# ---- Segmento 1 (Pewter até a boca norte da caverna) é andável ----
	var preso1 := -1
	for r in range(2, MapLayouts.RPV_CAVERNA_ENTRADA_R):
		var centro : int = clampi(MapLayouts._rota_pv2_centro_caminho(r), 1, 98)
		if not (tiles[r][centro] in ANDAVEL):
			preso1 = r
			break
	_assert(preso1 == -1, "segmento Pewter→boca da caverna é andável ponta a ponta (travou em r=%d)" % preso1 if preso1 >= 0 else "segmento Pewter→boca da caverna é andável ponta a ponta")

	# ---- Segmento 2 (boca sul da caverna até Viridian) é andável ----
	var preso2 := -1
	for r in range(MapLayouts.RPV_CAVERNA_SAIDA_R, 2998):
		var centro : int = clampi(MapLayouts._rota_pv2_centro_caminho(r), 1, 98)
		if not (tiles[r][centro] in ANDAVEL):
			preso2 = r
			break
	_assert(preso2 == -1, "segmento boca da caverna→Viridian é andável ponta a ponta (travou em r=%d)" % preso2 if preso2 >= 0 else "segmento boca da caverna→Viridian é andável ponta a ponta")

	# ---- A crista ENTRE as duas bocas está de verdade bloqueada por fora —
	# prova de que a caverna é obrigatória, não decoração ----
	var achou_furo := false
	for r in range(MapLayouts.RPV_CAVERNA_ENTRADA_R + 1, MapLayouts.RPV_CAVERNA_SAIDA_R):
		for c in range(1, 99):
			if tiles[r][c] in ANDAVEL:
				achou_furo = true
	_assert(not achou_furo, "a crista entre as duas bocas está 100% bloqueada por fora (sem atalho contornando a caverna)")

	# ---- Bordas nunca formam parede reta (mesma regra da Fase 1) ----
	var col_borda_r10 := -1
	var col_borda_r2500 := -1
	for c in range(0, 100):
		if not (tiles[10][c] in ["T", "N", "O", "K"]) and col_borda_r10 == -1:
			col_borda_r10 = c
		if not (tiles[2500][c] in ["T", "N", "O", "K"]) and col_borda_r2500 == -1:
			col_borda_r2500 = c
	_assert(col_borda_r10 != col_borda_r2500, "a borda oeste do caminho não fica sempre na mesma coluna (nunca é parede reta)")

	# ---- paint() desenha a rota (grande) sem erro ----
	var tilemap := TileMap.new()
	tilemap.tile_set = load("res://assets/tilesets/overworld.tres")
	MapLayouts.paint(tilemap, "rota_pewter_viridian")
	var usadas := tilemap.get_used_cells(0)
	_assert(usadas.size() > 200000, "paint() desenha a rota inteira (>200 mil tiles usados, achou %d)" % usadas.size())
	tilemap.free()

	# ---- A caverna: gera, conecta porta sul à porta norte de verdade ----
	var cave_layout : Dictionary = MapLayouts.get_layout("caverna_montanha_pv")
	_assert(not cave_layout.is_empty(), "get_layout('caverna_montanha_pv') existe")
	var ctiles : Array = cave_layout.get("tiles", [])
	var cw : int = int(cave_layout.get("width", 0))
	var ch : int = int(cave_layout.get("height", 0))
	var porta_sul := Vector2i(-1, -1)
	var porta_norte := Vector2i(-1, -1)
	for c in range(cw):
		if ctiles[ch - 1][c] == "P":
			porta_sul = Vector2i(c, ch - 1)
		if ctiles[0][c] == "P":
			porta_norte = Vector2i(c, 0)
	_assert(porta_sul.x != -1, "caverna tem porta sul (lado Pewter)")
	_assert(porta_norte.x != -1, "caverna tem porta norte (lado floresta)")

	var cave_tm := TileMap.new()
	cave_tm.tile_set = load("res://assets/tilesets/overworld.tres")
	MapLayouts.paint(cave_tm, "caverna_montanha_pv")
	_assert(AjudaMapa.caminho_a_pe(cave_tm, porta_sul, porta_norte, 200000),
		"a caverna conecta a porta sul à porta norte de verdade (travessia não-linear, não decoração)")
	cave_tm.free()

	# ---- Cenas de verdade: as duas existem, carregam, warps corretos ----
	var cena_rota : PackedScene = load("res://scenes/world/maps/RotaPewterViridian.tscn")
	_assert(cena_rota != null, "RotaPewterViridian.tscn existe e carrega")
	var inst_rota = cena_rota.instantiate()
	root.add_child(inst_rota)

	var wn = inst_rota.get_node_or_null("WarpZones/WarpNorte")
	var ws = inst_rota.get_node_or_null("WarpZones/WarpSul")
	var wce = inst_rota.get_node_or_null("WarpZones/WarpCavernaEntrada")
	var wcs = inst_rota.get_node_or_null("WarpZones/WarpCavernaSaida")
	_assert(wn != null, "WarpNorte existe na rota (volta pro world_map, lado Pewter)")
	_assert(ws != null, "WarpSul existe na rota (volta pro world_map, lado Viridian)")
	_assert(wce != null, "WarpCavernaEntrada existe (boca norte da montanha)")
	_assert(wcs != null, "WarpCavernaSaida existe (boca sul da montanha)")
	if wn:
		_assert(wn.target_map == "res://scenes/world/maps/WorldMap.tscn", "WarpNorte volta pro world_map")
	if ws:
		_assert(ws.target_map == "res://scenes/world/maps/WorldMap.tscn", "WarpSul volta pro world_map")
	if wce:
		_assert(wce.target_map == "res://scenes/world/maps/CavernaMontanhaPV.tscn", "WarpCavernaEntrada leva pra caverna")
	if wcs:
		_assert(wcs.target_map == "res://scenes/world/maps/CavernaMontanhaPV.tscn", "WarpCavernaSaida leva pra caverna")
	inst_rota.queue_free()

	var cena_caverna : PackedScene = load("res://scenes/world/maps/CavernaMontanhaPV.tscn")
	_assert(cena_caverna != null, "CavernaMontanhaPV.tscn existe e carrega")
	var inst_cav = cena_caverna.instantiate()
	root.add_child(inst_cav)
	var cs = inst_cav.get_node_or_null("WarpZones/WarpSul")
	var cn = inst_cav.get_node_or_null("WarpZones/WarpNorte")
	_assert(cs != null and cn != null, "a caverna tem as 2 portas como WarpZone")
	if cs:
		_assert(cs.target_map == "res://scenes/world/maps/RotaPewterViridian.tscn", "porta sul da caverna volta pra rota")
	if cn:
		_assert(cn.target_map == "res://scenes/world/maps/RotaPewterViridian.tscn", "porta norte da caverna volta pra rota")
	inst_cav.queue_free()

	# ---- zones.json: as 2 zonas novas existem, com map_id próprio ----
	var zj : Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/zones.json"))
	var achou_rota := false
	var achou_caverna := false
	for z in zj.get("zones", []):
		if z.get("id", "") == "rota_pewter_viridian":
			achou_rota = true
			_assert(z.get("map_id", "") == "rota_pewter_viridian", "zona da rota tem map_id próprio")
			_assert(int(z.get("tile_rect", {}).get("h", 0)) == 3000, "tile_rect da zona bate com a altura real (3.000)")
		if z.get("id", "") == "caverna_montanha_pv":
			achou_caverna = true
			_assert(z.get("map_id", "") == "caverna_montanha_pv", "zona da caverna tem map_id próprio")
	_assert(achou_rota, "zone 'rota_pewter_viridian' existe em zones.json")
	_assert(achou_caverna, "zone 'caverna_montanha_pv' existe em zones.json")

	# ---- WorldMap.tscn: os 2 warps de saída pra rota nova existem ----
	var wm_cena : PackedScene = load("res://scenes/world/maps/WorldMap.tscn")
	var wm = wm_cena.instantiate()
	root.add_child(wm)
	var saida_pewter = wm.get_node_or_null("WarpZones/WarpRotaPewterViridianNorte")
	var saida_viridian = wm.get_node_or_null("WarpZones/WarpRotaPewterViridianSul")
	_assert(saida_pewter != null, "world_map tem o warp de saída do lado de Pewter")
	_assert(saida_viridian != null, "world_map tem o warp de saída do lado de Viridian")
	if saida_pewter:
		_assert(saida_pewter.target_map == "res://scenes/world/maps/RotaPewterViridian.tscn", "warp de Pewter leva pra rota nova")
	if saida_viridian:
		_assert(saida_viridian.target_map == "res://scenes/world/maps/RotaPewterViridian.tscn", "warp de Viridian leva pra rota nova")

	# ---- Cadeia completa: Pewter anda até o warp, Viridian anda até o warp
	# (a travessia DENTRO da rota já foi provada acima — aqui só confere que
	# as duas pontas de verdade encostam na cidade) ----
	var mundo_tm := TileMap.new()
	mundo_tm.tile_set = load("res://assets/tilesets/overworld.tres")
	MapLayouts.paint(mundo_tm, "world_map")
	var origem_pewter := AjudaMapa.tile_andavel_da_zona(mundo_tm, AjudaMapa.retangulo_da_zona("pewter_city"))
	var tile_warp_pewter := Vector2i(int(saida_pewter.position.x / 128), int(saida_pewter.position.y / 128)) if saida_pewter else Vector2i(-1, -1)
	_assert(AjudaMapa.caminho_a_pe(mundo_tm, origem_pewter, tile_warp_pewter),
		"dá pra andar de dentro de Pewter até o warp da rota nova")
	var origem_viridian := AjudaMapa.tile_andavel_da_zona(mundo_tm, AjudaMapa.retangulo_da_zona("viridian_city"))
	var tile_warp_viridian := Vector2i(int(saida_viridian.position.x / 128), int(saida_viridian.position.y / 128)) if saida_viridian else Vector2i(-1, -1)
	_assert(AjudaMapa.caminho_a_pe(mundo_tm, origem_viridian, tile_warp_viridian),
		"dá pra andar de dentro de Viridian até o warp da rota nova")
	mundo_tm.free()
	wm.queue_free()

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)

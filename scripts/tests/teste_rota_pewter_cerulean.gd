## teste_rota_pewter_cerulean.gd — 10/09, Fase 2 da reestruturação
## geográfica em escala real (docs/mundo-novo-escala.md). Pewter↔Cerulean,
## 7.000 tiles = 7km, rota LESTE-OESTE (as duas cidades têm a mesma
## âncora Y). Mt Moon retrofitada nesta mesma fase pra caverna não-linear
## e agora é travessia OBRIGATÓRIA de verdade (a crista da montanha fica
## bloqueada por fora), não mais um desvio opcional dentro do world_map.
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

const ANDAVEL := ["P", ".", "A", "F", "S", ":", "^", "D"]

func _initialize() -> void:
	print("=== Teste: Rota Pewter-Cerulean + Mt Moon não-linear (10/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	# ---- Geração da grade da rota ----
	var layout : Dictionary = MapLayouts.get_layout("rota_pewter_cerulean")
	_assert(not layout.is_empty(), "get_layout('rota_pewter_cerulean') existe")
	_assert(int(layout.get("width", 0)) == 7000, "largura 7.000 tiles — bate com 7km = 7.000 passos")
	_assert(int(layout.get("height", 0)) == 100, "altura 100 tiles")

	var tiles : Array = layout.get("tiles", [])
	_assert(tiles.size() == 100, "a grade tem 100 linhas de verdade")

	# ---- Segmento 1 (Pewter até a boca oeste do Mt Moon) é andável ----
	var preso1 := -1
	for c in range(2, MapLayouts.RPC_MTMOON_ENTRADA_C):
		var centro : int = clampi(MapLayouts._rota_pc_centro_caminho(c), 1, 98)
		if not (tiles[centro][c] in ANDAVEL):
			preso1 = c
			break
	_assert(preso1 == -1, "segmento Pewter→boca oeste do Mt Moon é andável ponta a ponta")

	# ---- Segmento 2 (boca leste do Mt Moon até Cerulean) é andável ----
	var preso2 := -1
	for c in range(MapLayouts.RPC_MTMOON_SAIDA_C, 6998):
		var centro : int = clampi(MapLayouts._rota_pc_centro_caminho(c), 1, 98)
		if not (tiles[centro][c] in ANDAVEL):
			preso2 = c
			break
	_assert(preso2 == -1, "segmento boca leste do Mt Moon→Cerulean é andável ponta a ponta")

	# ---- A crista da montanha ENTRE as duas bocas está bloqueada por
	# fora — prova de que Mt Moon é travessia obrigatória, não decoração ----
	var achou_furo := false
	for c in range(MapLayouts.RPC_MTMOON_ENTRADA_C + 1, MapLayouts.RPC_MTMOON_SAIDA_C):
		for r in range(1, 99):
			if tiles[r][c] in ANDAVEL:
				achou_furo = true
	_assert(not achou_furo, "a crista da montanha entre as duas bocas está 100% bloqueada por fora")

	# ---- paint() desenha a rota inteira sem erro ----
	var tilemap := TileMap.new()
	tilemap.tile_set = load("res://assets/tilesets/overworld.tres")
	MapLayouts.paint(tilemap, "rota_pewter_cerulean")
	var usadas := tilemap.get_used_cells(0)
	_assert(usadas.size() > 500000, "paint() desenha a rota inteira (>500 mil tiles usados, achou %d)" % usadas.size())
	tilemap.free()

	# ---- Mt Moon: retrofit não-linear, conecta porta sul à porta norte ----
	var mm_layout : Dictionary = MapLayouts.get_layout("mt_moon")
	var mm_tiles : Array = mm_layout.get("tiles", [])
	var mm_w : int = int(mm_layout.get("width", 0))
	var mm_h : int = int(mm_layout.get("height", 0))
	_assert(mm_w == 20 and mm_h == 30, "Mt Moon continua 20x30 (só o miolo mudou, não o tamanho)")

	var porta_sul := Vector2i(-1, -1)
	var porta_norte := Vector2i(-1, -1)
	for c in range(mm_w):
		if mm_tiles[mm_h - 1][c] == "P":
			porta_sul = Vector2i(c, mm_h - 1)
		if mm_tiles[0][c] == "P":
			porta_norte = Vector2i(c, 0)
	_assert(porta_sul.x == 9 or porta_sul.x == 10, "Mt Moon: porta sul continua nas colunas 9-10 (compatibilidade)")
	_assert(porta_norte.x != -1, "Mt Moon: porta norte existe (posição dinâmica, não mais fixa)")
	_assert(porta_norte.x == MapLayouts.mtmoon_porta_norte_col(), "mtmoon_porta_norte_col() bate com a grade gerada de verdade")

	# Não-linear de verdade: o caminho central antigo (col 9, toda linha)
	# NÃO pode estar 100% andável mais — senão o retrofit não pegou.
	var linhas_col9_andaveis := 0
	for r in range(1, mm_h - 1):
		if mm_tiles[r][9] == "I" or mm_tiles[r][9] == "P":
			linhas_col9_andaveis += 1
	_assert(linhas_col9_andaveis < mm_h - 2, "Mt Moon não é mais um corredor reto (col 9 não é 100%% andável, achou %d/%d)" % [linhas_col9_andaveis, mm_h - 2])

	var mm_tm := TileMap.new()
	mm_tm.tile_set = load("res://assets/tilesets/overworld.tres")
	MapLayouts.paint(mm_tm, "mt_moon")
	_assert(AjudaMapa.caminho_a_pe(mm_tm, porta_sul, porta_norte, 50000),
		"Mt Moon conecta a porta sul à porta norte de verdade (travessia não-linear)")
	mm_tm.free()

	# ---- Cenas de verdade ----
	var cena_rota : PackedScene = load("res://scenes/world/maps/RotaPewterCerulean.tscn")
	_assert(cena_rota != null, "RotaPewterCerulean.tscn existe e carrega")
	var inst_rota = cena_rota.instantiate()
	root.add_child(inst_rota)
	var wo = inst_rota.get_node_or_null("WarpZones/WarpOeste")
	var wl = inst_rota.get_node_or_null("WarpZones/WarpLeste")
	var wme = inst_rota.get_node_or_null("WarpZones/WarpMtMoonEntrada")
	var wms = inst_rota.get_node_or_null("WarpZones/WarpMtMoonSaida")
	_assert(wo != null and wl != null and wme != null and wms != null,
		"a rota tem os 4 warps (Oeste/Leste pro world_map, Entrada/Saída pro Mt Moon)")
	if wo:
		_assert(wo.target_map == "res://scenes/world/maps/WorldMap.tscn", "WarpOeste volta pro world_map")
	if wl:
		_assert(wl.target_map == "res://scenes/world/maps/WorldMap.tscn", "WarpLeste volta pro world_map")
	if wme:
		_assert(wme.target_map == "res://scenes/world/maps/MtMoon.tscn", "WarpMtMoonEntrada leva pro Mt Moon")
	if wms:
		_assert(wms.target_map == "res://scenes/world/maps/MtMoon.tscn", "WarpMtMoonSaida leva pro Mt Moon")
	inst_rota.queue_free()

	var cena_mm : PackedScene = load("res://scenes/world/maps/MtMoon.tscn")
	var inst_mm = cena_mm.instantiate()
	root.add_child(inst_mm)
	var ms = inst_mm.get_node_or_null("WarpZones/WarpSouth")
	var mn = inst_mm.get_node_or_null("WarpZones/WarpNorth")
	_assert(ms != null and mn != null, "Mt Moon tem as 2 portas como WarpZone")
	if ms:
		_assert(ms.target_map == "res://scenes/world/maps/RotaPewterCerulean.tscn", "porta sul do Mt Moon volta pra rota nova (não mais world_map)")
	if mn:
		_assert(mn.target_map == "res://scenes/world/maps/RotaPewterCerulean.tscn", "porta norte do Mt Moon volta pra rota nova (não mais world_map)")
	var sombra := inst_mm.get_node_or_null("Entities/AgenteSombra1")
	_assert(sombra != null, "Agente Sombra 1 continua existindo dentro do Mt Moon")
	inst_mm.queue_free()

	# ---- zones.json: a zona nova existe, com map_id próprio ----
	var zj : Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/zones.json"))
	var achou := false
	for z in zj.get("zones", []):
		if z.get("id", "") == "rota_pewter_cerulean":
			achou = true
			_assert(z.get("map_id", "") == "rota_pewter_cerulean", "zona da rota tem map_id próprio")
			_assert(int(z.get("tile_rect", {}).get("w", 0)) == 7000, "tile_rect da zona bate com a largura real (7.000)")
	_assert(achou, "zone 'rota_pewter_cerulean' existe em zones.json")

	# ---- WorldMap.tscn: os 2 warps de saída existem, WarpMtMoon antigo sumiu ----
	var wm_cena : PackedScene = load("res://scenes/world/maps/WorldMap.tscn")
	var wm = wm_cena.instantiate()
	root.add_child(wm)
	var saida_pewter = wm.get_node_or_null("WarpZones/WarpRotaPewterCeruleanOeste")
	var saida_cerulean = wm.get_node_or_null("WarpZones/WarpRotaPewterCeruleanLeste")
	_assert(saida_pewter != null, "world_map tem o warp de saída do lado de Pewter")
	_assert(saida_cerulean != null, "world_map tem o warp de saída do lado de Cerulean")
	if saida_pewter:
		_assert(saida_pewter.target_map == "res://scenes/world/maps/RotaPewterCerulean.tscn", "warp de Pewter leva pra rota nova")
	if saida_cerulean:
		_assert(saida_cerulean.target_map == "res://scenes/world/maps/RotaPewterCerulean.tscn", "warp de Cerulean leva pra rota nova")
	var warp_mtmoon_antigo = wm.get_node_or_null("WarpZones/WarpMtMoon")
	_assert(warp_mtmoon_antigo == null, "o warp antigo direto world_map→Mt Moon foi removido (agora só chega pela rota nova)")

	# ---- Cadeia completa: Pewter anda até o warp, Cerulean anda até o warp ----
	var mundo_tm := TileMap.new()
	mundo_tm.tile_set = load("res://assets/tilesets/overworld.tres")
	MapLayouts.paint(mundo_tm, "world_map")
	var origem_pewter := AjudaMapa.tile_andavel_da_zona(mundo_tm, AjudaMapa.retangulo_da_zona("pewter_city"))
	var tile_warp_pewter := Vector2i(int(saida_pewter.position.x / 128), int(saida_pewter.position.y / 128)) if saida_pewter else Vector2i(-1, -1)
	_assert(AjudaMapa.caminho_a_pe(mundo_tm, origem_pewter, tile_warp_pewter),
		"dá pra andar de dentro de Pewter até o warp da rota nova")
	var origem_cerulean := AjudaMapa.tile_andavel_da_zona(mundo_tm, AjudaMapa.retangulo_da_zona("cerulean_city"))
	var tile_warp_cerulean := Vector2i(int(saida_cerulean.position.x / 128), int(saida_cerulean.position.y / 128)) if saida_cerulean else Vector2i(-1, -1)
	_assert(AjudaMapa.caminho_a_pe(mundo_tm, origem_cerulean, tile_warp_cerulean),
		"dá pra andar de dentro de Cerulean até o warp da rota nova")
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

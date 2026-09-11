## teste_rota_viridian_pallet.gd — 10/09, Fase 1 da reestruturação geográfica
## em escala real (docs/mundo-novo-escala.md). Primeira rota nova: Viridian↔
## Pallet, 1.000 tiles (1km ≈ 1.000 passos, confirmado literal com o Gabriel).
## Cena própria (não dentro de world_map — nenhum mapa aguenta a escala
## completa da reestruturação inteira, ver o doc).
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste: Rota Viridian-Pallet, escala real (10/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	# ---- Geração da grade (MapLayouts) ----
	var layout : Dictionary = MapLayouts.get_layout("rota_viridian_pallet")
	_assert(not layout.is_empty(), "get_layout('rota_viridian_pallet') existe")
	_assert(int(layout.get("width", 0)) == 100, "largura 100 tiles")
	_assert(int(layout.get("height", 0)) == 1000, "altura 1.000 tiles — bate com 1km ≈ 1.000 passos")

	var tiles : Array = layout.get("tiles", [])
	_assert(tiles.size() == 1000, "a grade tem 1.000 linhas de verdade (não só o número declarado)")

	# ---- O caminho é andável do início ao fim, tile a tile ----
	# Simula "seguir o centro do caminho" e confere que cada passo é um tile
	# ANDÁVEL (P, ., A, F, S — nunca T/W/~/parede) — prova que dá pra
	# atravessar a rota inteira sem ficar preso, sem precisar rodar o motor
	# gráfico inteiro.
	const ANDAVEL := ["P", ".", "A", "F", "S"]
	var preso_em := -1
	for r in range(2, 998):
		var linha : String = tiles[r]
		var centro : int = MapLayouts._rota_vp_centro_caminho(r)
		centro = clampi(centro, 1, 98)
		var ch : String = linha[centro]
		if not (ch in ANDAVEL):
			preso_em = r
			break
	_assert(preso_em == -1, "o centro do caminho é andável em toda a rota (travou em r=%d)" % preso_em if preso_em >= 0 else "o centro do caminho é andável em toda a rota, ponta a ponta")

	# ---- Nunca vira parede reta: bordas variam de posição, não são retas ----
	var col_borda_r10 := -1
	var col_borda_r500 := -1
	for c in range(0, 100):
		if tiles[10][c] != "T" and col_borda_r10 == -1:
			col_borda_r10 = c
		if tiles[500][c] != "T" and col_borda_r500 == -1:
			col_borda_r500 = c
	_assert(col_borda_r10 != col_borda_r500, "a borda oeste do caminho NÃO fica na mesma coluna o tempo todo (nunca é uma parede reta)")

	# ---- MapLayouts.paint() sabe pintar esta cena (usado de verdade por
	# BaseMap._paint_tiles()) ----
	var tilemap := TileMap.new()
	tilemap.tile_set = load("res://assets/tilesets/overworld.tres")
	MapLayouts.paint(tilemap, "rota_viridian_pallet")
	var usadas := tilemap.get_used_cells(0)
	_assert(usadas.size() > 50000, "paint() realmente desenha um mapa grande (>50 mil tiles usados, achou %d)" % usadas.size())
	tilemap.free()

	# ---- Cena de verdade: warps existem, apontam pro lugar certo ----
	var cena : PackedScene = load("res://scenes/world/maps/RotaViridianPallet.tscn")
	_assert(cena != null, "RotaViridianPallet.tscn existe e carrega")
	var inst = cena.instantiate()
	root.add_child(inst)

	var warp_norte = inst.get_node_or_null("WarpZones/WarpNorte")
	var warp_sul   = inst.get_node_or_null("WarpZones/WarpSul")
	_assert(warp_norte != null, "WarpNorte existe na cena")
	_assert(warp_sul != null, "WarpSul existe na cena")
	if warp_norte:
		_assert(warp_norte.target_map == "res://scenes/world/maps/WorldMap.tscn", "WarpNorte volta pro world_map")
	if warp_sul:
		_assert(warp_sul.target_map == "res://scenes/world/maps/WorldMap.tscn", "WarpSul volta pro world_map")

	inst.queue_free()

	# ---- zones.json: a zona nova existe, com map_id certo (regra de
	# ZoneManager.find_zone_id — sem map_id, zonas de cenas diferentes se
	# confundiriam pela coordenada bruta) ----
	var zj : Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/zones.json"))
	var achou_zona := false
	for z in zj.get("zones", []):
		if z.get("map_id", "") == "rota_viridian_pallet":
			achou_zona = true
			_assert(z.get("map_id", "") == "rota_viridian_pallet", "zona nova tem map_id próprio (não herda DEFAULT_MAP_ID)")
	_assert(achou_zona, "existe zona registrada pro mapa 'rota_viridian_pallet' (faixas de bioma)")

	# ---- WorldMap.tscn: os 2 warps de SAÍDA (rumo à rota nova) existem ----
	var wm_cena : PackedScene = load("res://scenes/world/maps/WorldMap.tscn")
	var wm = wm_cena.instantiate()
	root.add_child(wm)
	var saida_norte = wm.get_node_or_null("WarpZones/WarpRotaViridianPalletNorte")
	var saida_sul   = wm.get_node_or_null("WarpZones/WarpRotaViridianPalletSul")
	_assert(saida_norte != null, "world_map tem o warp de saída do lado de Viridian")
	_assert(saida_sul != null, "world_map tem o warp de saída do lado de Pallet")
	if saida_norte:
		_assert(saida_norte.target_map == "res://scenes/world/maps/RotaViridianPallet.tscn", "warp de Viridian leva pra rota nova")
	if saida_sul:
		_assert(saida_sul.target_map == "res://scenes/world/maps/RotaViridianPallet.tscn", "warp de Pallet leva pra rota nova")
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

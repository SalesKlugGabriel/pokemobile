## teste_no_central_saffron.gd — 10/09, Fase 3 da reestruturação
## geográfica em escala real (docs/mundo-novo-escala.md). Cerulean→Saffron
## (4km) + Saffron→Vermilion (2km) + Saffron→Celadon (4km) — Saffron é um
## cruzamento de verdade, ganha 3 saídas novas (a 4ª, pra Lavender via
## Rock Tunnel, não muda nesta fase).
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

const ANDAVEL := ["P", ".", "A", "F", "S"]

func _initialize() -> void:
	print("=== Teste: Nó central de Saffron (Cerulean/Vermilion/Celadon), 10/09 ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	_checar_rota_ns("rota_cerulean_saffron", 100, 4000, "Cerulean-Saffron")
	_checar_rota_ns("rota_saffron_vermilion", 100, 2000, "Saffron-Vermilion")
	_checar_rota_ew("rota_saffron_celadon", 4000, 100, "Saffron-Celadon")

	# ---- Cenas de verdade: as 3 existem, carregam, warps corretos ----
	_checar_cena_2warps("RotaCeruleanSaffron", "WarpNorte", "WarpSul")
	_checar_cena_2warps("RotaSaffronVermilion", "WarpNorte", "WarpSul")
	_checar_cena_2warps("RotaSaffronCeladon", "WarpOeste", "WarpLeste")

	# ---- zones.json: as 3 zonas existem, map_id próprio ----
	var zj : Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/zones.json"))
	var ids_esperados := {"rota_cerulean_saffron": false, "rota_saffron_vermilion": false, "rota_saffron_celadon": false}
	for z in zj.get("zones", []):
		var id : String = z.get("id", "")
		if ids_esperados.has(id):
			ids_esperados[id] = true
			_assert(z.get("map_id", "") == id, "zona '%s' tem map_id próprio" % id)
	for id in ids_esperados:
		_assert(ids_esperados[id], "zone '%s' existe em zones.json" % id)

	# ---- WorldMap.tscn: os 6 warps de saída existem (2 por rota) ----
	var wm_cena : PackedScene = load("res://scenes/world/maps/WorldMap.tscn")
	var wm = wm_cena.instantiate()
	root.add_child(wm)
	var nomes_e_alvos := [
		["WarpRotaCeruleanSaffronNorte", "RotaCeruleanSaffron.tscn"],
		["WarpRotaCeruleanSaffronSul", "RotaCeruleanSaffron.tscn"],
		["WarpRotaSaffronVermilionNorte", "RotaSaffronVermilion.tscn"],
		["WarpRotaSaffronVermilionSul", "RotaSaffronVermilion.tscn"],
		["WarpRotaSaffronCeladonOeste", "RotaSaffronCeladon.tscn"],
		["WarpRotaSaffronCeladonLeste", "RotaSaffronCeladon.tscn"],
	]
	for par in nomes_e_alvos:
		var w = wm.get_node_or_null("WarpZones/%s" % par[0])
		_assert(w != null, "world_map tem o warp '%s'" % par[0])
		if w:
			_assert(w.target_map.contains(par[1]), "'%s' leva pra %s" % [par[0], par[1]])

	# ---- Cadeia completa: Cerulean/Saffron/Vermilion/Celadon andam até os
	# respectivos warps (a travessia DENTRO de cada rota já foi provada
	# acima) ----
	var mundo_tm := TileMap.new()
	mundo_tm.tile_set = load("res://assets/tilesets/overworld.tres")
	MapLayouts.paint(mundo_tm, "world_map")

	var checagens := [
		["cerulean_city", "WarpRotaCeruleanSaffronNorte"],
		["saffron_city", "WarpRotaCeruleanSaffronSul"],
		["saffron_city", "WarpRotaSaffronVermilionNorte"],
		["vermilion_city", "WarpRotaSaffronVermilionSul"],
		["saffron_city", "WarpRotaSaffronCeladonLeste"],
		["celadon_city", "WarpRotaSaffronCeladonOeste"],
	]
	for chk in checagens:
		var zona : String = chk[0]
		var warp_nome : String = chk[1]
		var w = wm.get_node_or_null("WarpZones/%s" % warp_nome)
		if w == null:
			_assert(false, "warp '%s' existe (pra testar a cadeia)" % warp_nome)
			continue
		var origem := AjudaMapa.tile_andavel_da_zona(mundo_tm, AjudaMapa.retangulo_da_zona(zona))
		var tile_warp := Vector2i(int(w.position.x / 128), int(w.position.y / 128))
		_assert(AjudaMapa.caminho_a_pe(mundo_tm, origem, tile_warp),
			"dá pra andar de dentro de %s até o warp '%s'" % [zona, warp_nome])
	mundo_tm.free()
	wm.queue_free()

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	quit(1 if _fail > 0 else 0)
	return true

func _checar_rota_ns(map_id: String, W: int, H: int, nome: String) -> void:
	var layout : Dictionary = MapLayouts.get_layout(map_id)
	_assert(not layout.is_empty(), "get_layout('%s') existe" % map_id)
	_assert(int(layout.get("width", 0)) == W and int(layout.get("height", 0)) == H,
		"%s gera %dx%d" % [nome, W, H])
	var tiles : Array = layout.get("tiles", [])
	var preso := -1
	for r in range(2, H - 2):
		var achou := false
		for c in range(1, W - 1):
			if tiles[r][c] in ANDAVEL:
				achou = true
				break
		if not achou:
			preso = r
			break
	_assert(preso == -1, "%s é andável ponta a ponta (norte-sul, travou em r=%d)" % [nome, preso] if preso >= 0 else "%s é andável ponta a ponta (norte-sul)" % nome)

	var tilemap := TileMap.new()
	tilemap.tile_set = load("res://assets/tilesets/overworld.tres")
	MapLayouts.paint(tilemap, map_id)
	_assert(tilemap.get_used_cells(0).size() > (W * H) / 3, "%s: paint() desenha a rota inteira" % nome)
	tilemap.free()

func _checar_rota_ew(map_id: String, W: int, H: int, nome: String) -> void:
	var layout : Dictionary = MapLayouts.get_layout(map_id)
	_assert(not layout.is_empty(), "get_layout('%s') existe" % map_id)
	_assert(int(layout.get("width", 0)) == W and int(layout.get("height", 0)) == H,
		"%s gera %dx%d" % [nome, W, H])
	var tiles : Array = layout.get("tiles", [])
	var preso := -1
	for c in range(2, W - 2):
		var achou := false
		for r in range(1, H - 1):
			if tiles[r][c] in ANDAVEL:
				achou = true
				break
		if not achou:
			preso = c
			break
	_assert(preso == -1, "%s é andável ponta a ponta (leste-oeste)" % nome)

	var tilemap := TileMap.new()
	tilemap.tile_set = load("res://assets/tilesets/overworld.tres")
	MapLayouts.paint(tilemap, map_id)
	_assert(tilemap.get_used_cells(0).size() > (W * H) / 3, "%s: paint() desenha a rota inteira" % nome)
	tilemap.free()

func _checar_cena_2warps(nome_cena: String, warp_a: String, warp_b: String) -> void:
	var cena : PackedScene = load("res://scenes/world/maps/%s.tscn" % nome_cena)
	_assert(cena != null, "%s.tscn existe e carrega" % nome_cena)
	if cena == null:
		return
	var inst = cena.instantiate()
	root.add_child(inst)
	var wa = inst.get_node_or_null("WarpZones/%s" % warp_a)
	var wb = inst.get_node_or_null("WarpZones/%s" % warp_b)
	_assert(wa != null and wb != null, "%s tem os 2 warps (%s/%s)" % [nome_cena, warp_a, warp_b])
	if wa:
		_assert(wa.target_map == "res://scenes/world/maps/WorldMap.tscn", "%s/%s volta pro world_map" % [nome_cena, warp_a])
	if wb:
		_assert(wb.target_map == "res://scenes/world/maps/WorldMap.tscn", "%s/%s volta pro world_map" % [nome_cena, warp_b])
	inst.queue_free()

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)

## teste_rota_saffron_lavender.gd — 10/09, Fase 4 da reestruturação
## geográfica em escala real (docs/mundo-novo-escala.md). Saffron↔Lavender,
## 5.000 tiles = 5km, leste-oeste. Rock Tunnel entra como DESVIO OPCIONAL
## (porta única, já era não-linear desde que foi construída — sem
## retrofit, diferente de Mt Moon na Fase 2).
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

const ANDAVEL := ["P", ".", "A", "F", "S", "D"]

func _initialize() -> void:
	print("=== Teste: Rota Saffron-Lavender + Rock Tunnel opcional (10/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	# ---- Geração da grade ----
	var layout : Dictionary = MapLayouts.get_layout("rota_saffron_lavender")
	_assert(not layout.is_empty(), "get_layout('rota_saffron_lavender') existe")
	_assert(int(layout.get("width", 0)) == 5000, "largura 5.000 tiles — bate com 5km = 5.000 passos")
	_assert(int(layout.get("height", 0)) == 100, "altura 100 tiles")

	var tiles : Array = layout.get("tiles", [])
	_assert(tiles.size() == 100, "a grade tem 100 linhas de verdade")

	# ---- A rota é andável de ponta a ponta MESMO sem entrar em Rock
	# Tunnel — prova de que o desvio é opcional, não obrigatório ----
	var preso := -1
	for c in range(2, 4998):
		var achou := false
		for r in range(1, 99):
			if tiles[r][c] in ANDAVEL:
				achou = true
				break
		if not achou:
			preso = c
			break
	_assert(preso == -1, "a rota é andável ponta a ponta por fora (Rock Tunnel é desvio, não bloqueio)")

	# ---- paint() desenha a rota inteira ----
	var tilemap := TileMap.new()
	tilemap.tile_set = load("res://assets/tilesets/overworld.tres")
	MapLayouts.paint(tilemap, "rota_saffron_lavender")
	_assert(tilemap.get_used_cells(0).size() > 150000, "paint() desenha a rota inteira")
	tilemap.free()

	# ---- Rock Tunnel: continua exatamente como estava (não precisou de
	# retrofit — já era não-linear desde que foi construída) ----
	var rt_layout := MapLayouts.get_layout("rock_tunnel")
	_assert(int(rt_layout.get("width", 0)) == 36 and int(rt_layout.get("height", 0)) == 36,
		"Rock Tunnel continua 36x36 (não mudou)")
	var rt_tiles : Array = rt_layout.get("tiles", [])
	_assert(rt_tiles[35][17] == "P" and rt_tiles[35][18] == "P",
		"Rock Tunnel: porta única continua nas colunas 17-18 (compatibilidade)")

	# ---- Cenas de verdade ----
	var cena_rota : PackedScene = load("res://scenes/world/maps/RotaSaffronLavender.tscn")
	_assert(cena_rota != null, "RotaSaffronLavender.tscn existe e carrega")
	var inst_rota = cena_rota.instantiate()
	root.add_child(inst_rota)
	var wo = inst_rota.get_node_or_null("WarpZones/WarpOeste")
	var wl = inst_rota.get_node_or_null("WarpZones/WarpLeste")
	var wrt = inst_rota.get_node_or_null("WarpZones/WarpRockTunnel")
	_assert(wo != null and wl != null and wrt != null,
		"a rota tem os 3 warps (Oeste/Leste pro world_map, RockTunnel pro desvio)")
	if wo:
		_assert(wo.target_map == "res://scenes/world/maps/WorldMap.tscn", "WarpOeste volta pro world_map")
	if wl:
		_assert(wl.target_map == "res://scenes/world/maps/WorldMap.tscn", "WarpLeste volta pro world_map")
	if wrt:
		_assert(wrt.target_map == "res://scenes/world/maps/RockTunnel.tscn", "WarpRockTunnel leva pra Rock Tunnel")
	inst_rota.queue_free()

	var cena_rt : PackedScene = load("res://scenes/world/maps/RockTunnel.tscn")
	var inst_rt = cena_rt.instantiate()
	root.add_child(inst_rt)
	var rt_warp = inst_rt.get_node_or_null("WarpZones/WarpSouth")
	_assert(rt_warp != null, "Rock Tunnel tem a porta (WarpSouth)")
	if rt_warp:
		_assert(rt_warp.target_map == "res://scenes/world/maps/RotaSaffronLavender.tscn",
			"a porta de Rock Tunnel volta pra rota nova (não mais world_map)")
	inst_rt.queue_free()

	# ---- zones.json ----
	var zj : Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/zones.json"))
	var achou := false
	for z in zj.get("zones", []):
		if z.get("id", "") == "rota_saffron_lavender":
			achou = true
			_assert(z.get("map_id", "") == "rota_saffron_lavender", "zona da rota tem map_id próprio")
			_assert(int(z.get("tile_rect", {}).get("w", 0)) == 5000, "tile_rect bate com a largura real (5.000)")
	_assert(achou, "zone 'rota_saffron_lavender' existe em zones.json")

	# ---- WorldMap.tscn: warps de saída existem, WarpRockTunnel antigo sumiu ----
	var wm_cena : PackedScene = load("res://scenes/world/maps/WorldMap.tscn")
	var wm = wm_cena.instantiate()
	root.add_child(wm)
	var saida_saffron = wm.get_node_or_null("WarpZones/WarpRotaSaffronLavenderOeste")
	var saida_lavender = wm.get_node_or_null("WarpZones/WarpRotaSaffronLavenderLeste")
	_assert(saida_saffron != null, "world_map tem o warp de saída do lado de Saffron")
	_assert(saida_lavender != null, "world_map tem o warp de saída do lado de Lavender")
	if saida_saffron:
		_assert(saida_saffron.target_map == "res://scenes/world/maps/RotaSaffronLavender.tscn", "warp de Saffron leva pra rota nova")
	if saida_lavender:
		_assert(saida_lavender.target_map == "res://scenes/world/maps/RotaSaffronLavender.tscn", "warp de Lavender leva pra rota nova")
	var warp_rt_antigo = wm.get_node_or_null("WarpZones/WarpRockTunnel")
	_assert(warp_rt_antigo == null, "o warp antigo direto world_map→Rock Tunnel foi removido")

	# ---- Cadeia completa ----
	var mundo_tm := TileMap.new()
	mundo_tm.tile_set = load("res://assets/tilesets/overworld.tres")
	MapLayouts.paint(mundo_tm, "world_map")
	var origem_saffron := AjudaMapa.tile_andavel_da_zona(mundo_tm, AjudaMapa.retangulo_da_zona("saffron_city"))
	var tile_warp_saffron := Vector2i(int(saida_saffron.position.x / 128), int(saida_saffron.position.y / 128)) if saida_saffron else Vector2i(-1, -1)
	_assert(AjudaMapa.caminho_a_pe(mundo_tm, origem_saffron, tile_warp_saffron),
		"dá pra andar de dentro de Saffron até o warp da rota nova")
	var origem_lavender := AjudaMapa.tile_andavel_da_zona(mundo_tm, AjudaMapa.retangulo_da_zona("lavender_town"))
	var tile_warp_lavender := Vector2i(int(saida_lavender.position.x / 128), int(saida_lavender.position.y / 128)) if saida_lavender else Vector2i(-1, -1)
	_assert(AjudaMapa.caminho_a_pe(mundo_tm, origem_lavender, tile_warp_lavender),
		"dá pra andar de dentro de Lavender até o warp da rota nova")
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

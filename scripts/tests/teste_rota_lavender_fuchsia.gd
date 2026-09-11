## teste_rota_lavender_fuchsia.gd — 10/09, Fase 5 da reestruturação
## geográfica em escala real (docs/mundo-novo-escala.md). Lavender↔Fuchsia,
## 12.000 tiles = 12km, a maior jornada do mapa — 7 segmentos de bioma:
## Campo Seco → Mata Fechada → Vale do Rio → Pântano → Floresta Tropical →
## Planície Costeira → Arredores. Única rota da reestruturação cuja
## âncora bate direto com a topologia real (norte-sul), sem correção.
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

const ANDAVEL := ["P", ".", "A", "F", "S", "9", "z", "!", "(", "?", "`", "#", "~"]

func _initialize() -> void:
	print("=== Teste: Rota Lavender-Fuchsia, 7 biomas (10/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	# ---- Geração ----
	var layout : Dictionary = MapLayouts.get_layout("rota_lavender_fuchsia")
	_assert(not layout.is_empty(), "get_layout('rota_lavender_fuchsia') existe")
	_assert(int(layout.get("width", 0)) == 100, "largura 100 tiles")
	_assert(int(layout.get("height", 0)) == 12000, "altura 12.000 tiles — bate com 12km, a maior rota do mapa")

	var tiles : Array = layout.get("tiles", [])
	_assert(tiles.size() == 12000, "a grade tem 12.000 linhas de verdade")

	# ---- Andável ponta a ponta (centerline) ----
	var preso := -1
	for r in range(2, 11998):
		var centro : int = clampi(MapLayouts._rota_lf_centro_caminho(r), 1, 98)
		if not (tiles[r][centro] in ANDAVEL):
			preso = r
			break
	_assert(preso == -1, "a rota é andável ponta a ponta pelos 7 biomas")

	# ---- Cada um dos 7 biomas realmente aparece (não é decoração morta —
	# prova que os biomas reservados desde 05/09 ["9" mata fechada, "z"
	# pântano] finalmente foram pintados em algum lugar do jogo) ----
	var achou := {"9": false, "z": false, "#": false, "S": false}
	for r in range(0, 12000, 7):  # amostragem — não precisa varrer tudo
		var linha : String = tiles[r]
		for ch in achou.keys():
			if linha.find(ch) != -1:
				achou[ch] = true
	_assert(achou["9"], "o bioma Mata Fechada ('9') aparece pintado de verdade")
	_assert(achou["z"], "o bioma Pântano ('z') aparece pintado de verdade")
	_assert(achou["#"], "a ponte do Vale do Rio ('#') aparece pintada de verdade")
	_assert(achou["S"], "areia da Planície Costeira aparece pintada de verdade")

	# ---- O rio do Vale do Rio realmente CORTA o caminho (perpendicular) —
	# prova de que a ponte é necessária, não decorativa ----
	var linha_rio : String = tiles[MapLayouts.LF_RIO_CENTRO]
	var achou_agua_longe_do_centro := false
	var centro_rio := clampi(MapLayouts._rota_lf_centro_caminho(MapLayouts.LF_RIO_CENTRO), 1, 98)
	for c in range(0, 100):
		if absi(c - centro_rio) > 15 and linha_rio[c] == "~":
			achou_agua_longe_do_centro = true
	_assert(achou_agua_longe_do_centro, "o rio se estende bem além do caminho (corta a rota de verdade, não é um poço decorativo)")

	# ---- Cena de verdade + tempo de carregamento real, medido ANTES de
	# qualquer outro TileMap grande nascer neste processo (achado: criar e
	# liberar um TileMap solo de 1,2 mi de tiles logo antes contaminava a
	# medição seguinte — de ~500ms pra ~16s; não é o carregamento real da
	# cena que é lento, é o teste medindo errado. Ver docs/mundo-novo-
	# escala.md, seção de performance) ----
	var t0 := Time.get_ticks_msec()
	var cena : PackedScene = load("res://scenes/world/maps/RotaLavenderFuchsia.tscn")
	_assert(cena != null, "RotaLavenderFuchsia.tscn existe e carrega")
	var inst = cena.instantiate()
	root.add_child(inst)
	var tempo_real := Time.get_ticks_msec() - t0
	_assert(tempo_real < 5000, "carregamento real da maior rota do mapa é rápido (%dms)" % tempo_real)

	var wn = inst.get_node_or_null("WarpZones/WarpNorte")
	var ws = inst.get_node_or_null("WarpZones/WarpSul")
	_assert(wn != null and ws != null, "a rota tem os 2 warps (Norte/Sul)")
	if wn:
		_assert(wn.target_map == "res://scenes/world/maps/WorldMap.tscn", "WarpNorte volta pro world_map")
	if ws:
		_assert(ws.target_map == "res://scenes/world/maps/WorldMap.tscn", "WarpSul volta pro world_map")
	inst.queue_free()

	# ---- paint() desenha a rota inteira sem erro (depois da medição de
	# tempo, de propósito — ver comentário acima) ----
	var tilemap := TileMap.new()
	tilemap.tile_set = load("res://assets/tilesets/overworld.tres")
	MapLayouts.paint(tilemap, "rota_lavender_fuchsia")
	_assert(tilemap.get_used_cells(0).size() > 900000, "paint() desenha a rota inteira (achou %d)" % tilemap.get_used_cells(0).size())
	tilemap.queue_free()

	# ---- zones.json ----
	var zj : Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/zones.json"))
	var achou_zona := false
	for z in zj.get("zones", []):
		if z.get("map_id", "") == "rota_lavender_fuchsia":
			achou_zona = true
	_assert(achou_zona, "existe zona registrada pro mapa 'rota_lavender_fuchsia' (faixas de bioma)")

	# ---- WorldMap.tscn + cadeia completa ----
	var wm_cena : PackedScene = load("res://scenes/world/maps/WorldMap.tscn")
	var wm = wm_cena.instantiate()
	root.add_child(wm)
	var saida_lavender = wm.get_node_or_null("WarpZones/WarpRotaLavenderFuchsiaNorte")
	var saida_fuchsia = wm.get_node_or_null("WarpZones/WarpRotaLavenderFuchsiaSul")
	_assert(saida_lavender != null, "world_map tem o warp de saída do lado de Lavender")
	_assert(saida_fuchsia != null, "world_map tem o warp de saída do lado de Fuchsia")
	if saida_lavender:
		_assert(saida_lavender.target_map == "res://scenes/world/maps/RotaLavenderFuchsia.tscn", "warp de Lavender leva pra rota nova")
	if saida_fuchsia:
		_assert(saida_fuchsia.target_map == "res://scenes/world/maps/RotaLavenderFuchsia.tscn", "warp de Fuchsia leva pra rota nova")

	var mundo_tm := TileMap.new()
	mundo_tm.tile_set = load("res://assets/tilesets/overworld.tres")
	MapLayouts.paint(mundo_tm, "world_map")
	var origem_lavender := AjudaMapa.tile_andavel_da_zona(mundo_tm, AjudaMapa.retangulo_da_zona("lavender_town"))
	var tile_warp_lavender := Vector2i(int(saida_lavender.position.x / 128), int(saida_lavender.position.y / 128)) if saida_lavender else Vector2i(-1, -1)
	_assert(AjudaMapa.caminho_a_pe(mundo_tm, origem_lavender, tile_warp_lavender),
		"dá pra andar de dentro de Lavender até o warp da rota nova")
	var origem_fuchsia := AjudaMapa.tile_andavel_da_zona(mundo_tm, AjudaMapa.retangulo_da_zona("fuchsia_city"))
	var tile_warp_fuchsia := Vector2i(int(saida_fuchsia.position.x / 128), int(saida_fuchsia.position.y / 128)) if saida_fuchsia else Vector2i(-1, -1)
	_assert(AjudaMapa.caminho_a_pe(mundo_tm, origem_fuchsia, tile_warp_fuchsia),
		"dá pra andar de dentro de Fuchsia até o warp da rota nova")
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

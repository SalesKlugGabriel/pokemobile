## teste_fase3_tier14.gd — Teste headless do Tier 14 da expansão de mapa
## (Seafoam Islands — 3 ilhotas no mar aberto, SEM warp de propósito; só
## alcançável quando Surf/Fly existir. Tema frio/rochoso, diferente do
## Arquipélago Tropical). Ajustado em 02/09 (reorganização geográfica): a
## faixa de colunas do litoral de Vermilion mudou de 400-459 pra 220-279 —
## usa as constantes de MapLayouts em vez de número cravado.
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase3_tier14.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 3 Tier 14 (Seafoam Islands) ===")

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
	_assert(layout["width"] == 465 and layout["height"] == 330,
		"world_map não mudou de tamanho (Seafoam reaproveita a faixa de colunas de Vermilion)")

	var col_ini : int = MapLayouts.VERMILION_COAST_COL_INICIO
	var col_fim : int = MapLayouts.VERMILION_COAST_COL_FIM
	var row_ini : int = MapLayouts.VERMILION_COAST_ROW_INICIO + MapLayouts.COASTLINE_ROWS + MapLayouts.ARQUIPELAGO_ROWS
	var row_fim : int = row_ini + MapLayouts.SEAFOAM_ROWS - 1

	# ---- 1. As 3 ilhotas existem (centro é terra, não mar/praia) ----
	_assert(tiles[row_ini + 10][col_ini + 12] != "~" and tiles[row_ini + 10][col_ini + 12] != "S", "Ilhota 1: o centro é terreno de verdade")
	_assert(tiles[row_ini + 20][col_ini + 32] != "~" and tiles[row_ini + 20][col_ini + 32] != "S", "Ilhota 2: o centro é terreno de verdade")
	_assert(tiles[row_ini + 30][col_ini + 48] != "~" and tiles[row_ini + 30][col_ini + 48] != "S", "Ilhota 3: o centro é terreno de verdade")

	# ---- 2. Existe mar aberto entre/ao redor das ilhotas ----
	_assert(tiles[row_ini + 3][col_ini] == "~", "existe mar aberto perto da borda oeste de Seafoam")
	_assert(tiles[row_fim][col_fim] == "~", "existe mar aberto perto do canto sudeste de Seafoam")

	# ---- 3. Praia (anel pálido) ao redor de pelo menos uma ilhota ----
	var achou_praia := false
	for r in range(row_ini, row_fim + 1):
		for c in range(col_ini, col_fim + 1):
			if tiles[r][c] == "S":
				achou_praia = true
	_assert(achou_praia, "existe praia ao redor das ilhotas")

	# ---- 4. Interior rochoso/escuro existe (D/R), ZERO vegetação (T/F/G) —
	# identidade fria/rochosa, oposta ao Arquipélago Tropical ----
	var achou_rocha := false
	var achou_vegetacao := false
	for r in range(row_ini, row_fim + 1):
		for c in range(col_ini, col_fim + 1):
			var ch : String = tiles[r][c]
			if ch == "D" or ch == "R":
				achou_rocha = true
			if ch == "T" or ch == "F" or ch == "G":
				achou_vegetacao = true
	_assert(achou_rocha, "existe piso rochoso/escuro (D/R) nas ilhotas")
	_assert(not achou_vegetacao, "ZERO vegetação em Seafoam (diferente do Arquipélago Tropical, de propósito)")

	# ---- 5. Continuidade do mar: sem quebra entre o Arquipélago Tropical
	# (Tier 13) e Seafoam (Tier 14) — mesma água, só continuando ----
	_assert(tiles[row_ini - 1][col_ini + 30] == "~" or tiles[row_ini - 1][col_ini + 30] == "S", "linha de transição é praia/mar, não borda")
	_assert(tiles[row_ini + 1][col_ini + 30] != "T", "logo depois da transição já é Seafoam, não borda")

	# ---- 6. Fora da faixa de colunas de Seafoam, continua borda — não
	# vazou pro resto do mapa ----
	_assert(tiles[row_ini + 15][col_ini - 10] == "T", "fora da faixa de colunas de Seafoam continua borda")

	# ---- 7. zones.json: zona registrada com o tile_rect real, sem warp associado ----
	var f := FileAccess.open("res://data/world/zones.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	var by_id := {}
	for z in data["zones"]:
		by_id[z["id"]] = z
	_assert(by_id.has("seafoam_islands"), "zona seafoam_islands existe")
	if by_id.has("seafoam_islands"):
		var rect : Dictionary = by_id["seafoam_islands"]["tile_rect"]
		_assert(rect["x"] == col_ini and rect["y"] == row_ini and rect["w"] == 60 and rect["h"] == MapLayouts.SEAFOAM_ROWS,
			"tile_rect de seafoam_islands bate com a posição real construída no mapa")
		var achou_seel := false
		for w in by_id["seafoam_islands"].get("wild_pokemon", []):
			if int(w.get("id", 0)) == 86:
				achou_seel = true
		_assert(achou_seel, "Seafoam Islands tem Seel (spawn real do Gen 1)")

	# ---- 8. De propósito, NENHUM warp novo foi criado pra Seafoam — ainda
	# não há como chegar lá (Surf/Fly não existem) ----
	var world_scene := load("res://scenes/world/maps/WorldMap.tscn") as PackedScene
	if world_scene:
		var inst := world_scene.instantiate()
		var warp_zones := inst.get_node_or_null("WarpZones")
		var achou_warp_seafoam := false
		if warp_zones:
			for w in warp_zones.get_children():
				if w.target_map.contains("Seafoam"):
					achou_warp_seafoam = true
		_assert(not achou_warp_seafoam,
			"nenhum warp foi criado pra Seafoam (de propósito — só Surf/Fly no futuro)")
		inst.free()

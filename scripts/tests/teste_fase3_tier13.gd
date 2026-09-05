## teste_fase3_tier13.gd — Teste headless do Tier 13 da expansão de mapa
## (Arquipélago Tropical — 2 ilhas no mar aberto, SEM warp de propósito;
## só alcançável quando Surf/Fly existir). Ajustado em 02/09 (reorganização
## geográfica): a faixa de colunas do litoral de Vermilion mudou de 400-459
## pra 220-279 — usa as constantes de MapLayouts em vez de número cravado,
## pra não quebrar de novo se a geografia mudar outra vez.
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase3_tier13.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 3 Tier 13 (Arquipélago Tropical) ===")

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
	_assert(int(layout["width"]) == 465 and AjudaMapa.altura_cobre_as_zonas(int(layout["height"])),
		"world_map não mudou de tamanho (arquipélago reaproveita a faixa de colunas de Vermilion)")

	var col_ini : int = MapLayouts.VERMILION_COAST_COL_INICIO
	var col_fim : int = MapLayouts.VERMILION_COAST_COL_FIM
	var row_ini : int = MapLayouts.VERMILION_COAST_ROW_INICIO + MapLayouts.COASTLINE_ROWS
	var row_fim : int = row_ini + MapLayouts.ARQUIPELAGO_ROWS - 1

	# ---- 1. As duas ilhas existem (centro é terra, não mar/praia) ----
	_assert(tiles[row_ini + 15][col_ini + 15] != "~" and tiles[row_ini + 15][col_ini + 15] != "S", "Ilha 1: o centro é terreno de verdade")
	_assert(tiles[row_ini + 27][col_ini + 42] != "~" and tiles[row_ini + 27][col_ini + 42] != "S", "Ilha 2: o centro é terreno de verdade")

	# ---- 2. Existe mar aberto entre/ao redor das ilhas (não é um continente
	# sólido) ----
	_assert(tiles[row_ini][col_ini] == "~", "existe mar aberto perto da borda oeste do arquipélago")
	_assert(tiles[row_fim][col_fim] == "~", "existe mar aberto perto do canto sudeste do arquipélago")

	# ---- 3. Praia ao redor de pelo menos uma das ilhas ----
	var achou_praia := false
	for r in range(row_ini, row_fim + 1):
		for c in range(col_ini, col_fim + 1):
			if tiles[r][c] == "S":
				achou_praia = true
	_assert(achou_praia, "existe praia ao redor das ilhas")

	# ---- 4. Vegetação tropical densa existe (T/F/G, não só água) ----
	var achou_vegetacao := false
	for r in range(row_ini, row_fim + 1):
		for c in range(col_ini, col_fim + 1):
			var ch : String = tiles[r][c]
			if ch == "T" or ch == "F" or ch == "G":
				achou_vegetacao = true
	_assert(achou_vegetacao, "existe vegetação tropical nas ilhas")

	# ---- 5. Continuidade do mar: sem quebra entre o litoral de Vermilion
	# (Tier 9) e o arquipélago (Tier 13) — mesma "água", só continuando ----
	_assert(tiles[row_ini - 1][col_ini + 30] == "~" or tiles[row_ini - 1][col_ini + 30] == "S", "linha de transição é praia/mar, não borda")
	_assert(tiles[row_ini + 1][col_ini + 30] != "T", "logo depois da transição já é o arquipélago, não borda")

	# ---- 6. Fora da faixa de colunas do arquipélago, continua borda — não
	# vazou pro resto do mapa ----
	# NOTA (04/09): o preenchimento fora dessas colunas era "T" (árvore) e virou
	# "~" (mar) quando a costa de Pallet foi criada — a região ao sul do mapa
	# deixou de ser árvore morta e virou oceano de verdade, o que aliás põe estas
	# ilhas DENTRO do mar (alcançáveis por Surf), que era a intenção desde o
	# Tier 13. A checagem continua sendo "não vazou": o que está fora da faixa
	# tem que ser o preenchimento genérico, não conteúdo da ilha (areia/terra).
	_assert(tiles[row_ini + 10][col_ini - 10] == "~", "fora da faixa de colunas do arquipélago é preenchimento de mar, não conteúdo da ilha")

	# ---- 7. zones.json: zona registrada, spawn real do Gen 1, sem warp associado ----
	var f := FileAccess.open("res://data/world/zones.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	var by_id := {}
	for z in data["zones"]:
		by_id[z["id"]] = z
	_assert(by_id.has("arquipelago_tropical"), "zona arquipelago_tropical existe")
	if by_id.has("arquipelago_tropical"):
		var achou_exeggcute := false
		for w in by_id["arquipelago_tropical"].get("wild_pokemon", []):
			if int(w.get("id", 0)) == 102:
				achou_exeggcute = true
		_assert(achou_exeggcute, "Arquipélago Tropical tem Exeggcute (spawn real do Gen 1)")

	# ---- 8. De propósito, NENHUM warp novo foi criado pro arquipélago —
	# ainda não há como chegar lá (Surf/Fly não existem) ----
	var world_scene := load("res://scenes/world/maps/WorldMap.tscn") as PackedScene
	if world_scene:
		var inst := world_scene.instantiate()
		var warp_zones := inst.get_node_or_null("WarpZones")
		var achou_warp_arquipelago := false
		if warp_zones:
			for w in warp_zones.get_children():
				if w.target_map.contains("Arquipelago") or w.target_map.contains("Tropical"):
					achou_warp_arquipelago = true
		_assert(not achou_warp_arquipelago,
			"nenhum warp foi criado pro arquipélago (de propósito — só Surf/Fly no futuro)")
		inst.free()

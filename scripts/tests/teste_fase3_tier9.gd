## teste_fase3_tier9.gd — Teste headless do Tier 9 da expansão de mapa
## (Litoral de Vermilion — praia + mar aberto ao sul da cidade). Ajustado em
## 02/09 (reorganização geográfica): a costa agora sai do NOVO sul de
## Vermilion (VERMILION_COAST_ROW_INICIO), não mais logo depois de Pewter —
## a lógica da curva orgânica (`shore_de_vermilion`) continua idêntica.
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase3_tier9.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 3 Tier 9 (Litoral de Vermilion) ===")

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
	_assert(layout["height"] == 330, "world_map tem 330 de altura")

	var col_ini : int = MapLayouts.VERMILION_COAST_COL_INICIO
	var col_fim : int = MapLayouts.VERMILION_COAST_COL_FIM
	var row_ini : int = MapLayouts.VERMILION_COAST_ROW_INICIO

	# ---- 1. Logo no início da costa (cr=1, row_ini) a maioria é areia — a
	# curva orgânica (sin()) pode tocar exatamente shore==1 em algum ponto
	# raro, então não exigimos 100%, só a esmagadora maioria ----
	var areia_count := 0
	var total := col_fim - col_ini + 1
	for c in range(col_ini, col_fim + 1):
		if tiles[row_ini][c] == "S":
			areia_count += 1
	_assert(areia_count >= total * 0.8, "quase toda a largura logo no início da costa (row %d) é areia (%d/%d)" % [row_ini, areia_count, total])

	# ---- 2. A curva da costa é ORGÂNICA (varia por coluna), não uma linha reta ----
	var shores := []
	for vc in range(0, 60, 5):
		shores.append(MapLayouts.shore_de_vermilion(vc))
	var todos_iguais := true
	for s in shores:
		if s != shores[0]:
			todos_iguais = false
	_assert(not todos_iguais, "a linha da praia varia de coluna pra coluna (curva de erosão, não corte reto)")

	# ---- 3. Praia (areia) perto da cidade, mar aberto mais ao sul ----
	var vc_meio := 30
	var shore_meio : int = MapLayouts.shore_de_vermilion(vc_meio)
	var c_meio : int = col_ini + vc_meio
	_assert(tiles[row_ini][c_meio] == "S", "logo no início da costa (cr=1) ainda é areia")
	_assert(tiles[row_ini + shore_meio + 5][c_meio] == "~", "mar aberto (bem depois da linha de praia) é água de verdade")

	# ---- 4. Fora da faixa de colunas do litoral, comportamento de sempre
	# (borda) — o litoral não vazou pro resto do mapa ----
	# NOTA (04/09): o preenchimento fora dessas colunas era "T" (árvore) e virou
	# "~" (mar) quando a costa de Pallet foi criada — a região ao sul do mapa
	# deixou de ser árvore morta e virou oceano de verdade, o que aliás põe estas
	# ilhas DENTRO do mar (alcançáveis por Surf), que era a intenção desde o
	# Tier 13. A checagem continua sendo "não vazou": o que está fora da faixa
	# tem que ser o preenchimento genérico, não conteúdo da ilha (areia/terra).
	_assert(tiles[row_ini + 5][col_ini - 5] == "~",
		"fora da faixa de colunas de Vermilion é preenchimento de mar (litoral não vazou)")

	# ---- 5. NPC pescador existe ----
	var world_scene := load("res://scenes/world/maps/WorldMap.tscn") as PackedScene
	_assert(world_scene != null, "WorldMap.tscn carrega sem erro")
	if world_scene:
		var inst := world_scene.instantiate()
		var pescador := inst.get_node_or_null("Entities/PescadorVermilionPraia")
		_assert(pescador != null, "Pescador da praia de Vermilion existe no WorldMap")
		inst.free()

	# ---- 6. zones.json: praia e mar registrados, com nota apontando pra
	# fonte única de verdade do formato (pro mapa submarino futuro) ----
	var f := FileAccess.open("res://data/world/zones.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	var by_id := {}
	for z in data["zones"]:
		by_id[z["id"]] = z
	_assert(by_id.has("vermilion_praia"), "zona vermilion_praia existe")
	_assert(by_id.has("mar_de_vermilion"), "zona mar_de_vermilion existe")
	if by_id.has("mar_de_vermilion"):
		_assert(str(by_id["mar_de_vermilion"].get("notes","")).contains("shore_de_vermilion"),
			"mar_de_vermilion documenta a função que define seu formato (pro mapa submarino reusar)")

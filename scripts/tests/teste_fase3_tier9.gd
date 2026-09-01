## teste_fase3_tier9.gd — Teste headless do Tier 9 da expansão de mapa
## (Litoral de Vermilion — praia + mar aberto ao sul da cidade).
## Diferente do Tier 8 (ramo ao norte, linha negativa), este desvio vive no
## array PRINCIPAL — por isso volta a usar `tiles[row][col]` como os Tiers
## 1-7, sem precisar pintar um TileMap à parte.
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
	_assert(layout["width"] == 940, "world_map continua com 940 de largura (Tier 9 não mexe na largura)")
	_assert(layout["height"] == 192, "world_map continua com 192 de altura (litoral cabe dentro do que já existia)")

	# ---- 1. Seam: toda a frente de Vermilion (linhas 35-36) virou areia,
	# não mais borda de árvore ----
	var col_ini : int = MapLayouts.VERMILION_COAST_COL_INICIO
	var col_fim : int = MapLayouts.VERMILION_COAST_COL_FIM
	var seam_ok := true
	for c in range(col_ini, col_fim + 1):
		if tiles[35][c] != "S" or tiles[36][c] != "S":
			seam_ok = false
	_assert(seam_ok, "toda a orla de Vermilion (linhas 35-36) é areia, não borda")

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
	_assert(tiles[MapLayouts.PEWTER_ROWS + 1][c_meio] == "S", "logo depois da costura (cr=1) ainda é areia")
	_assert(tiles[MapLayouts.PEWTER_ROWS + shore_meio + 5][c_meio] == "~", "mar aberto (bem depois da linha de praia) é água de verdade")

	# ---- 4. Fora da faixa de colunas do litoral, comportamento de sempre
	# (Rota 2 ou borda) — o litoral não vazou pro resto do mapa ----
	_assert(tiles[MapLayouts.PEWTER_ROWS + 10][col_ini - 5] == "T",
		"fora da faixa de colunas de Vermilion, a mesma linha continua borda (litoral não vazou)")

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

## teste_beira_da_praia.gd — A costa deixou de ser uma linha reta (04/09).
##
## Do teste de gameplay: "parece uma bandeira — uma faixa verde, uma marrom e
## uma azul". O mapa já tinha praia e mar de verdade desde 03/09; faltavam os
## tiles de ENCONTRO entre os dois.
##
## Trava também a armadilha que apareceu ao construir isto: a primeira versão
## gravou os tiles de beira na linha 9 do atlas, que "parecia livre" e na
## verdade guarda o KIT DA CASA (cumeeira/beiral/cantos/paredes laterais) —
## apagou o kit inteiro. Por isso o teste confere que os dois convivem.
##
## Roda com: godot4 --headless --script res://scripts/tests/teste_beira_da_praia.gd
extends SceneTree

var _ok := 0
var _fail := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste: beira da praia (04/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	var tm := TileMap.new()
	tm.tile_set = load("res://assets/tilesets/overworld.tres") as TileSet
	MapLayouts.paint(tm, "world_map")

	var agua : Vector2i = MapLayouts.CHAR_MAP["~"]

	# ---- 1. Nenhum tile de água pura encosta em terra ----------------------
	# É esta a definição de "sem linha reta": onde houver mar tocando terra,
	# tem que haver um tile de beira no meio.
	var cruas := 0
	var beiras := 0
	for celula in tm.get_used_cells(0):
		var co := tm.get_cell_atlas_coords(0, celula)
		if co in MapLayouts.COSTA_ATLAS:
			beiras += 1
			continue
		if co != agua:
			continue
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			if MapLayouts._e_terra(tm, celula + d, agua):
				cruas += 1
				break
	_assert(beiras > 100, "a costa foi costurada de verdade (%d tiles de beira)" % beiras)
	_assert(cruas == 0, "nenhum mar encosta direto na terra — %s" % (
		"ok" if cruas == 0 else "%d tiles de corte reto" % cruas))

	# ---- 2. Beira é ÁGUA pra regra do jogo (senão o Surf para na praia) ----
	var wm := root.get_node("WorldManager")
	wm.tilemap = tm
	var achou_beira := Vector2i.ZERO
	for celula in tm.get_used_cells(0):
		if tm.get_cell_atlas_coords(0, celula) in MapLayouts.COSTA_ATLAS:
			achou_beira = celula
			break
	_assert(wm.is_water_tile(achou_beira),
		"tile de beira conta como água (Surf/pesca funcionam na primeira fileira de mar)")
	wm.tilemap = null

	# ---- 3. O kit da casa NÃO foi sobrescrito -----------------------------
	# Erro real cometido ao construir isto: a linha 9 do atlas "parecia livre"
	# e é do kit. Aqui a conferência é que as duas famílias de tile existem e
	# não dividem coordenada nenhuma.
	var coords_kit := {}
	for ch in ["q", "r", "s", "t", "u", "v", "x", "y", "a", "p"]:
		_assert(MapLayouts.CHAR_MAP.has(ch), "peça '%s' do kit da casa continua no CHAR_MAP" % ch)
		if MapLayouts.CHAR_MAP.has(ch):
			coords_kit[MapLayouts.CHAR_MAP[ch]] = ch
	var colisoes : Array[String] = []
	for co in MapLayouts.COSTA_ATLAS:
		if coords_kit.has(co):
			colisoes.append("beira %s em cima da peça '%s'" % [co, coords_kit[co]])
	_assert(colisoes.is_empty(), "beira e kit da casa ocupam slots diferentes do atlas — %s" % (
		"ok" if colisoes.is_empty() else str(colisoes)))

	# ---- 4. Todo tile de beira existe NO TILESET, não só no PNG -----------
	# 🔴 A primeira versão deste teste conferia só se a coordenada cabia dentro
	# da IMAGEM. Passou verde enquanto o jogo publicado cuspia
	# "TileSetAtlasSource has no tile at (0, 10)" no console e desenhava buraco:
	# a textura tinha crescido, mas o TileSet ainda não conhecia os tiles novos.
	# Quem manda é o TileSet — é ele que o TileMap consulta.
	var ts := tm.tile_set
	var fonte := ts.get_source(0) as TileSetAtlasSource
	var fora : Array[String] = []
	for co in MapLayouts.COSTA_ATLAS:
		if not fonte.has_tile(co):
			fora.append(str(co))
	_assert(fora.is_empty(), "todo tile de beira existe no TileSet — %s" % (
		"ok" if fora.is_empty() else str(fora)))
	# E o mesmo pra TODO char do CHAR_MAP, pela mesma razão: o furo não era do
	# tile de beira, era da conferência.
	var chars_fora : Array[String] = []
	for ch in MapLayouts.CHAR_MAP:
		if not fonte.has_tile(MapLayouts.CHAR_MAP[ch]):
			chars_fora.append("%s -> %s" % [ch, MapLayouts.CHAR_MAP[ch]])
	_assert(chars_fora.is_empty(), "todo char do CHAR_MAP existe no TileSet — %s" % (
		"ok" if chars_fora.is_empty() else str(chars_fora)))

	tm.free()
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

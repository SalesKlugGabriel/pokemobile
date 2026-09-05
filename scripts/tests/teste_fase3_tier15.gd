## teste_fase3_tier15.gd — Teste headless do Tier 15 da expansão de mapa
## (Rocket Hideout — entrada/porão em Celadon, warp de verdade porque é
## "subterrâneo", mesma exceção de Mt Moon/Rock Tunnel/Safari Zone. Só a
## sala de entrada por ora — sem Team Rocket/mecânica ainda, fica pra
## "Pokémon e estruturas", Fase 2).
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase3_tier15.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 3 Tier 15 (Rocket Hideout) ===")

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
		"world_map não mudou de tamanho (Rocket Hideout é só uma porta nova em Celadon)")

	# ---- 1. A entrada existe nos globais certos (ce24-31 dentro de Celadon —
	# reorganização de 02/09: Celadon começa em CELADON_COL_INICIO/
	# SAFFRON_ROW_INICIO agora, não mais em c=520/r global direto) ----
	var ce0 := MapLayouts.CELADON_COL_INICIO
	var r0 := MapLayouts.SAFFRON_ROW_INICIO
	_assert(tiles[r0 + 21][ce0 + 27] == "H", "telhado da entrada (linha do topo)")
	_assert(tiles[r0 + 24][ce0 + 27] == "I", "interior da entrada é chão andável")
	_assert(tiles[r0 + 28][ce0 + 27] == "P" and tiles[r0 + 28][ce0 + 28] == "P", "porta (2 tiles) no rodapé da entrada")
	# 05/09: era `== "W"`. A parede da frente dos prédios passou a alternar entre
	# lisa ("w") e com janela ("W") — antes TODA parede era janela e a fachada de
	# todo prédio do jogo era uma fileira de janelas. O que este teste quer é que
	# ali seja PAREDE, não qual desenho de parede.
	_assert(MapLayouts.e_parede(tiles[r0 + 28][ce0 + 26]), "parede ao lado da porta, fora dela")
	_assert(tiles[r0 + 29][ce0 + 27] == "P" and tiles[r0 + 30][ce0 + 27] == "P", "caminho continua 2 linhas abaixo da porta")

	# ---- 2. Não vazou pra cima do corredor leste-oeste (no_caminho, r16-20
	# continua "P" normalmente em toda a faixa de colunas de Celadon) ----
	_assert(tiles[r0 + 18][ce0 + 27] != "W" and tiles[r0 + 18][ce0 + 27] != "T" and tiles[r0 + 18][ce0 + 27] != "R",
		"faixa do corredor leste-oeste continua andável por baixo da nova porta")

	# ---- 3. Resto de Celadon (Ginásio/Centro/Mart) intacto ----
	_assert(tiles[r0 + 6][ce0 + 16] == "H", "telhado do Ginásio de Celadon intacto")
	_assert(tiles[r0 + 8][ce0 + 54] == "H", "telhado do Celadon Mart intacto")

	# ---- 4. Interior do Rocket Hideout (cena própria) ----
	var hl = MapLayouts.get_layout("rocket_hideout")
	_assert(hl["width"] == 18 and hl["height"] == 14, "Rocket Hideout é 18x14")
	var htiles : Array = hl["tiles"]
	_assert(htiles[0] == "HHHHHHHHHHHHHHHHHH", "linha 0 é telhado inteiro")
	var linha1_toda_parede := true
	for ch in htiles[1]:
		if not MapLayouts.e_parede(ch):
			linha1_toda_parede = false
	_assert(linha1_toda_parede, "linha 1 é parede inteira")
	_assert(htiles[13] == "TTTTTTTTTTTTTTTTTT", "última linha é grama (borda externa)")
	_assert(htiles[12][8] == "P" and htiles[12][9] == "P", "porta de saída na penúltima linha")
	_assert(MapLayouts.e_parede(htiles[12][0]) and MapLayouts.e_parede(htiles[12][17]), "resto da penúltima linha é parede")
	_assert(MapLayouts.e_parede(htiles[6][0]) and MapLayouts.e_parede(htiles[6][17]), "paredes laterais no meio da sala")
	_assert(htiles[6][8] == "I", "chão andável no meio da sala (nada construído ainda de propósito)")

	# ---- 5. zones.json: zona registrada como cena própria, local 0-based,
	# com nota explicando a exceção de warp ----
	var f := FileAccess.open("res://data/world/zones.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	var by_id := {}
	for z in data["zones"]:
		by_id[z["id"]] = z
	_assert(by_id.has("rocket_hideout"), "zona rocket_hideout existe")
	if by_id.has("rocket_hideout"):
		var rect : Dictionary = by_id["rocket_hideout"]["tile_rect"]
		_assert(rect["x"] == 0 and rect["y"] == 0 and rect["w"] == 18 and rect["h"] == 14,
			"tile_rect de rocket_hideout é local 0-based, batendo com a cena própria")
		var notes : String = by_id["rocket_hideout"].get("notes", "")
		_assert(notes.contains("RocketHideout.tscn"), "notes documenta a cena própria")

	# ---- 6. Warp de entrada existe de verdade no WorldMap (não só o tile) ----
	var world_scene := load("res://scenes/world/maps/WorldMap.tscn") as PackedScene
	if world_scene:
		var inst := world_scene.instantiate()
		var warp_zones := inst.get_node_or_null("WarpZones")
		var achou_entrada := false
		if warp_zones:
			for w in warp_zones.get_children():
				if w.target_map.contains("RocketHideout"):
					achou_entrada = true
					_assert(w.spawn_tile == Vector2i(8, 11),
						"warp de entrada leva pro spawn certo dentro do porão")
		_assert(achou_entrada, "existe warp de entrada de verdade pro Rocket Hideout (não só o tile)")
		inst.free()

	# ---- 7. Warp de saída existe de verdade na cena do Rocket Hideout, e
	# leva de volta pro tile certo em Celadon ----
	var hideout_scene := load("res://scenes/world/maps/RocketHideout.tscn") as PackedScene
	if hideout_scene:
		var inst2 := hideout_scene.instantiate()
		_assert(inst2.map_id == "rocket_hideout", "map_id da cena é rocket_hideout")
		var warp_zones2 := inst2.get_node_or_null("WarpZones")
		var achou_saida := false
		if warp_zones2:
			for w in warp_zones2.get_children():
				if w.target_map.contains("WorldMap"):
					achou_saida = true
					_assert(w.spawn_tile == Vector2i(MapLayouts.CELADON_COL_INICIO + 27, MapLayouts.SAFFRON_ROW_INICIO + 29),
						"warp de saída leva de volta pro tile certo em Celadon")
		_assert(achou_saida, "existe warp de saída de verdade de volta pro WorldMap")
		inst2.free()

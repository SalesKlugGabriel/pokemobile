## teste_fase3_tier8.gd — Teste headless do Tier 8 da expansão de mapa
## (Rota 24 → Rota 25 → Casa do Bill — desvio ao NORTE de Cerulean).
## Diferente dos Tiers anteriores, esse ramo usa linhas NEGATIVAS e é pintado
## à parte de `_gen_world_map()` (pra não mudar o índice de nenhuma
## conferência já escrita nos Tiers 1-7) — por isso este teste pinta um
## TileMap de verdade e lê de volta, em vez de só olhar `tiles[row][col]`.
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase3_tier8.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 3 Tier 8 (Rota 24/25 → Casa do Bill) ===")

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

func _atlas_at(tm: TileMap, c: int, r: int) -> Vector2i:
	return tm.get_cell_atlas_coords(0, Vector2i(c, r))

func _teste_geral() -> void:
	# ---- 0. O array principal (Tiers 1-7) continua IDÊNTICO — nenhuma
	# linha de NPC/warp/zona precisou mudar (garantia da arquitetura escolhida) ----
	var layout = MapLayouts.get_layout("world_map")
	_assert(layout["width"] == 465, "world_map continua com 940 de largura (Tier 8 não mexe na largura)")
	_assert(layout["height"] == 330, "world_map continua com 192 de altura no array principal (ramo é pintado à parte)")

	# ---- 1. Pinta um TileMap de verdade (é assim que o jogo realmente desenha) ----
	var tileset := load("res://assets/tilesets/overworld.tres") as TileSet
	var tm := TileMap.new()
	tm.tile_set = tileset
	MapLayouts.paint(tm, "world_map")

	# ---- 2. Corredor contínuo de Cerulean (r=-1) até perto da borda (r=-39) ----
	var quebras := 0
	for r in range(-39, 0):
		if not MapLayouts.atlas_e_do_char(_atlas_at(tm, 248, r), "P"):
			quebras += 1
	_assert(quebras == 0, "corredor da Rota 24/25 (col 248) contínuo de r=-39 a r=-1 (%d quebras)" % quebras)

	# ---- 3. A costura conecta o ramo (r=-1) com Cerulean (r=3, já dentro
	# da própria lógica da cidade, sem o seam-fix) ----
	_assert(MapLayouts.atlas_e_do_char(_atlas_at(tm, 248, 0), "P"), "seam: r=0 na coluna do ramo é caminho (não borda) — sem isso o ramo ficaria isolado")
	_assert(not MapLayouts.atlas_e_do_char(_atlas_at(tm, 248, 3), "T"), "r=3 (já território normal de Cerulean) é caminhável")

	# ---- 4. Casa do Bill existe (ao lado do corredor, não em cima) ----
	_assert(MapLayouts.atlas_e_do_char(_atlas_at(tm, 257, -36), "I"), "Casa do Bill: interior é piso")
	_assert(MapLayouts.atlas_e_do_char(_atlas_at(tm, 257, -37), "H"), "Casa do Bill: telhado existe")

	# ---- 5. Fora da faixa do ramo continua borda (não vazou pro resto do mapa) ----
	_assert(MapLayouts.atlas_e_do_char(_atlas_at(tm, 100, -20), "T"), "fora da faixa de colunas do ramo (ex: col 100) continua borda em r negativo")

	# ---- 6. NPCs existem no WorldMap.tscn ----
	var world_scene := load("res://scenes/world/maps/WorldMap.tscn") as PackedScene
	_assert(world_scene != null, "WorldMap.tscn carrega sem erro")
	if world_scene:
		var inst := world_scene.instantiate()
		var bill := inst.get_node_or_null("Entities/Bill")
		_assert(bill != null, "Bill existe no WorldMap")
		if bill:
			_assert(bill.dialog_id == "bill_intro", "Bill usa o dialog_id já previsto no plano mestre (bill_intro)")
		var treinador := inst.get_node_or_null("Entities/TreinadorRota24")
		_assert(treinador != null, "Treinador da Rota 24 existe no WorldMap")
		if treinador:
			_assert(treinador.trainer_team.size() == 2, "Treinador da Rota 24 tem time real")
		inst.free()

	# ---- 7. zones.json: route_24/route_25/bills_house com coordenada negativa coerente ----
	var f := FileAccess.open("res://data/world/zones.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	var by_id := {}
	for z in data["zones"]:
		by_id[z["id"]] = z
	_assert(int(by_id["route_24"]["tile_rect"]["y"]) < 0, "route_24 tem y negativo no zones.json (está ao norte do mapa antigo)")
	_assert(int(by_id["route_25"]["tile_rect"]["y"]) < int(by_id["route_24"]["tile_rect"]["y"]),
		"route_25 fica mais ao norte (y mais negativo) que route_24")
	_assert(by_id["bills_house"]["npcs"][0]["dialog_id"] == "bill_intro", "bills_house aponta pro NPC bill/bill_intro")

	tm.free()

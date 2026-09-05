## teste_fase3_tier17.gd — Teste headless do Tier 17 (Nugget Bridge — travessia
## de rio dentro da Rota 24, ramo negativo ao norte de Cerulean). Mesma técnica
## de pintura à parte do Tier 8 — pinta um TileMap de verdade e lê de volta.
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase3_tier17.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 3 Tier 17 (Nugget Bridge) ===")

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
	var tileset := load("res://assets/tilesets/overworld.tres") as TileSet
	var tm := TileMap.new()
	tm.tile_set = tileset
	MapLayouts.paint(tm, "world_map")

	# Dentro da faixa da ponte (r=-15..-7): corredor continua "P" (tabuleiro
	# da ponte), os dois lados viram rio "~".
	_assert(MapLayouts.atlas_e_do_char(_atlas_at(tm, 248, -10), "P"), "ponte: corredor (col 248) continua caminhável em r=-10")
	_assert(MapLayouts.atlas_e_do_char(_atlas_at(tm, 245, -10), "~"), "ponte: lado oeste (col 245) é rio em r=-10")
	_assert(MapLayouts.atlas_e_do_char(_atlas_at(tm, 251, -10), "~"), "ponte: lado leste (col 251) é rio em r=-10")

	# Corredor continua contínuo de ponta a ponta da Rota 24/25 (não quebrou
	# nada do Tier 8) — mesma conferência de sempre.
	var quebras := 0
	for r in range(-39, 0):
		if not MapLayouts.atlas_e_do_char(_atlas_at(tm, 248, r), "P"):
			quebras += 1
	_assert(quebras == 0, "corredor da Rota 24/25 continua contínuo de r=-39 a r=-1 (%d quebras)" % quebras)

	# Fora da faixa da ponte (r=-20, ainda dentro da Rota 24): os lados
	# voltam a ser terreno normal, não rio.
	_assert(not MapLayouts.atlas_e_do_char(_atlas_at(tm, 245, -20), "~"), "fora da ponte (r=-20), lado oeste NÃO é rio")

	# O TreinadorRota24 (Tier 8) já existente cai dentro da faixa da ponte —
	# é ele quem faz o papel do "treinador que bloqueia a ponte" canônico.
	var world_scene := load("res://scenes/world/maps/WorldMap.tscn") as PackedScene
	_assert(world_scene != null, "WorldMap.tscn carrega sem erro")
	if world_scene:
		var inst := world_scene.instantiate()
		var treinador := inst.get_node_or_null("Entities/TreinadorRota24")
		_assert(treinador != null, "TreinadorRota24 continua existindo")
		if treinador:
			var tile_r := int((treinador.position.y - 64) / 128)
			# 05/09: era `- NORTE_OFFSET`. A Rota 24/25 passou a ser ancorada em
			# ROTAS_NORTE_ROWS (40) e não na borda do mapa (80) — sem isso,
			# esticar o norte pra caber a Ilha Gélida movia a rota inteira. A
			# conversão de `fb` pra linha do mundo tem que usar a mesma âncora.
			_assert(tile_r >= MapLayouts.NUGGET_BRIDGE_FB_INICIO - MapLayouts.ROTAS_NORTE_ROWS
				and tile_r <= MapLayouts.NUGGET_BRIDGE_FB_FIM - MapLayouts.ROTAS_NORTE_ROWS,
				"TreinadorRota24 fica dentro da faixa da ponte (row %d)" % tile_r)
		inst.free()

	var f := FileAccess.open("res://data/world/zones.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	var by_id := {}
	for z in data["zones"]:
		by_id[z["id"]] = z
	var nb : Dictionary = by_id.get("nugget_bridge", {})
	var r : Dictionary = nb.get("tile_rect", {})
	_assert(int(r.get("y", 1)) < 0, "zones.json: nugget_bridge tem y negativo (está no ramo norte)")
	_assert(r.get("x", 0) == 244 and r.get("y", 0) == -15 and r.get("w", 0) == 9 and r.get("h", 0) == 9,
		"zones.json: nugget_bridge aponta pra coordenada real (244,-15,9,9)")

	tm.free()

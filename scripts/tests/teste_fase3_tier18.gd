## teste_fase3_tier18.gd — Teste headless do Tier 18 (Rota 22 → Victory Road
## → Indigo Plateau, ramo a OESTE de Viridian — primeiro ramo em COLUNAS
## negativas). Victory Road é cena própria (pintura à parte, mesma técnica
## do Tier 8, mas eixo trocado) — este teste pinta um TileMap de verdade e
## lê de volta.
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase3_tier18.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 3 Tier 18 (Rota 22 → Victory Road → Indigo Plateau) ===")

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
	# ---- 0. Array principal continua idêntico — ramo é pintado à parte ----
	var layout = MapLayouts.get_layout("world_map")
	_assert(layout["width"] == 465, "world_map continua com 940 de largura (Tier 18 não mexe na largura do array principal)")

	# ---- 1. Pinta um TileMap de verdade ----
	var tileset := load("res://assets/tilesets/overworld.tres") as TileSet
	var tm := TileMap.new()
	tm.tile_set = tileset
	MapLayouts.paint(tm, "world_map")

	# ---- 2. Seam: sair de Viridian (c=0/1/2, rows 100-101) pro ramo oeste ----
	_assert(_atlas_at(tm, 0, 100) == MapLayouts.CHAR_MAP["P"], "seam: c=0 na row 100 é caminho (abre o ramo oeste)")
	_assert(_atlas_at(tm, -1, 100) == MapLayouts.CHAR_MAP["P"], "c=-1 (já dentro da Rota 22) é caminhável")
	_assert(_atlas_at(tm, 0, 99) == MapLayouts.CHAR_MAP["T"], "fora das 2 linhas do seam (row 99), c=0 continua borda")

	# ---- 3. Corredor da Rota 22 contínuo até a boca de Victory Road ----
	var quebras := 0
	for c in range(-24, 0):
		if _atlas_at(tm, c, 100) != MapLayouts.CHAR_MAP["P"]:
			quebras += 1
	_assert(quebras == 0, "corredor da Rota 22 contínuo de c=-1 a c=-24 (%d quebras)" % quebras)

	# ---- 4. Victory Road: boca existe (opcional/lateral — dá pra contornar) ----
	_assert(_atlas_at(tm, -28, 100) == MapLayouts.CHAR_MAP["P"], "boca de Victory Road é caminhável (entrada do warp)")
	_assert(_atlas_at(tm, -28, 90) == MapLayouts.CHAR_MAP["R"], "fora do corredor (row 90), a montanha de Victory Road é rocha")
	_assert(_atlas_at(tm, -28, 85) != MapLayouts.CHAR_MAP["R"], "dá pra contornar a montanha por fora da caixa (row 85)")

	# ---- 5. Indigo Plateau: Liga Pokémon fechada + Centro Pokémon funcional ----
	# Liga: ip10-22 → j70-82 → c=-70..-82 (col de teste: ip16 → c=-76)
	_assert(_atlas_at(tm, -76, 88) == MapLayouts.CHAR_MAP["H"], "Indigo Plateau: telhado da Liga existe")
	_assert(_atlas_at(tm, -76, 96) == MapLayouts.CHAR_MAP["W"], "Indigo Plateau: porta da Liga é parede (fechada, bloqueada por história)")
	# Centro: ip25-37 → j85-97 → c=-85..-97 (col de teste: ip31 → c=-91)
	_assert(_atlas_at(tm, -91, 88) == MapLayouts.CHAR_MAP["H"], "Indigo Plateau: telhado do Centro Pokémon existe")
	_assert(_atlas_at(tm, -91, 92) == MapLayouts.CHAR_MAP["I"], "Indigo Plateau: interior do Centro Pokémon é piso")
	_assert(_atlas_at(tm, -91, 96) == MapLayouts.CHAR_MAP["P"], "Indigo Plateau: porta do Centro Pokémon está aberta")

	# ---- 6. Borda absoluta no fim do ramo oeste (j=OESTE_OFFSET=100, c=-100) ----
	_assert(_atlas_at(tm, -100, 100) == MapLayouts.CHAR_MAP["T"], "fim do ramo oeste (c=-100) é borda")
	# Além da borda, não tem tile nenhum pintado — mas isso é SEGURO (a
	# própria regra de walkability trata tile vazio como bloqueado, "Estratégia
	# 2" de WorldManager.is_tile_walkable), não precisa de pintura extra ali.
	_assert(_atlas_at(tm, -101, 100) == Vector2i(-1, -1), "além da borda (c=-101) não tem tile pintado (vazio = bloqueado, não é bug)")

	# ---- 7. Warps existem no WorldMap.tscn ----
	var world_scene := load("res://scenes/world/maps/WorldMap.tscn") as PackedScene
	_assert(world_scene != null, "WorldMap.tscn carrega sem erro")
	if world_scene:
		var inst := world_scene.instantiate()
		var warp_zones := inst.get_node_or_null("WarpZones")
		var achou_vr := false
		var achou_indigo_center := false
		if warp_zones:
			for w in warp_zones.get_children():
				if w.target_map.contains("VictoryRoad"):
					achou_vr = true
				if w.name == "WarpPokeCenter_Indigo":
					achou_indigo_center = true
		_assert(achou_vr, "warp de entrada pra VictoryRoad.tscn existe")
		_assert(achou_indigo_center, "warp do Centro Pokémon de Indigo Plateau existe")
		inst.free()

	# ---- 8. Victory Road: cena própria carrega e não fica isolada ----
	var vr_scene := load("res://scenes/world/maps/VictoryRoad.tscn") as PackedScene
	_assert(vr_scene != null, "VictoryRoad.tscn carrega sem erro")
	if vr_scene:
		var inst2 := vr_scene.instantiate()
		_assert(inst2.map_id == "victory_road", "map_id da cena é victory_road")
		var vr_layout = MapLayouts.get_layout("victory_road")
		var vr_tiles : Array = vr_layout["tiles"]
		var chao := 0
		for row in vr_tiles:
			chao += row.count("D") + row.count("P")
		_assert(chao > 200, "Victory Road tem chão suficiente escavado (%d tiles)" % chao)
		_assert(vr_tiles[31][15] == "P" and vr_tiles[31][16] == "P", "Victory Road: porta de saída existe")
		inst2.free()

	# ---- 9. zones.json: route_22/victory_road/indigo_plateau com coordenada real ----
	var f := FileAccess.open("res://data/world/zones.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	var by_id := {}
	for z in data["zones"]:
		by_id[z["id"]] = z
	_assert(int(by_id["route_22"]["tile_rect"]["x"]) < 0, "route_22 tem x negativo (está a oeste de Viridian)")
	_assert(by_id["victory_road"].get("map_id", "") == "victory_road", "victory_road aponta pra própria cena (map_id)")
	_assert(int(by_id["indigo_plateau"]["tile_rect"]["x"]) < int(by_id["route_22"]["tile_rect"]["x"]),
		"indigo_plateau fica mais a oeste (x mais negativo) que route_22")

	tm.free()

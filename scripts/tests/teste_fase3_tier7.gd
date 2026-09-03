## teste_fase3_tier7.gd — Teste headless do Tier 7 (Lavender Town + fachada
## da Torre Pokémon). Reescrito em 02/09 (reorganização geográfica):
## Lavender fica a LESTE de Saffron agora (Rota 8, reaproveitando o
## comprimento e a boca de Rock Tunnel que já existiam nas antigas Rota 9 e
## Rota 10), não mais numa fileira reta a leste de Saffron-antiga.
## Também trava a classe de bug achada na sessão original: Saffron ganhou o
## prédio do Centro Pokémon, mas o warp pra entrar nele foi esquecido.
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase3_tier7.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 3 Tier 7 (Lavender, a leste de Saffron) ===")

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

	var r0 := MapLayouts.SAFFRON_ROW_INICIO
	var quebras := 0
	for c in range(MapLayouts.SPINE_COL_INICIO + MapLayouts.CERULEAN_COLS, MapLayouts.LAVENDER_COL_INICIO + MapLayouts.LAVENDER_COLS):
		if tiles[r0 + 18][c] != "P" and tiles[r0 + 18][c] != "." and tiles[r0 + 18][c] != "I":
			quebras += 1
	_assert(quebras == 0, "caminho de Saffron até Lavender é contínuo (%d quebras)" % quebras)

	var lv0 := MapLayouts.LAVENDER_COL_INICIO
	_assert(tiles[r0 + 10][lv0 + 16] == "I", "Lavender: interior da Torre Pokémon (fachada) é piso")
	_assert(tiles[r0 + 4][lv0 + 16] == "H", "Lavender: telhado da Torre existe")
	_assert(tiles[r0 + 10][lv0 + 41] == "I", "Lavender: interior do Centro Pokémon é piso")

	var world_scene := load("res://scenes/world/maps/WorldMap.tscn") as PackedScene
	_assert(world_scene != null, "WorldMap.tscn carrega sem erro")
	if world_scene:
		var inst := world_scene.instantiate()
		var fuji := inst.get_node_or_null("Entities/Fuji")
		_assert(fuji != null, "Sr. Fuji existe no WorldMap")

		var warp_zones := inst.get_node_or_null("WarpZones")
		_assert(warp_zones != null, "WarpZones existe")
		var alvos_indevidos := 0
		var pokecenter_warps := 0
		if warp_zones:
			for w in warp_zones.get_children():
				if w.target_map != "" and not w.target_map.contains("PokemonCenter") \
				and not w.target_map.contains("MtMoon") and not w.target_map.contains("RockTunnel") and not w.target_map.contains("SafariZone") and not w.target_map.contains("RocketHideout") and not w.target_map.contains("VictoryRoad") and not w.target_map.contains("DiglettsCave") and not w.target_map.contains("PokemonTower") and not w.target_map.contains("SilphCo") and not w.target_map.contains("GameCorner") and not w.target_map.contains("RocketHQ") and not w.target_map.contains("PokemonMansion") and not w.target_map.contains("IndigoLeague"):
					alvos_indevidos += 1
				if w.target_map.contains("PokemonCenter"):
					pokecenter_warps += 1
		_assert(alvos_indevidos == 0,
			"nenhum warp de cidade/rota indevido sobrou (%d de sobra)" % alvos_indevidos)
		_assert(pokecenter_warps >= 9,
			"pelo menos os 9 Centros Pokémon do Tier 7 têm warp de entrada (achou %d)" % pokecenter_warps)
		inst.free()

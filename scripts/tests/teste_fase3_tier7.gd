## teste_fase3_tier7.gd — Teste headless do Tier 7 da expansão de mapa
## (Rota 10 → Lavender Town + fachada da Torre Pokémon).
## Também trava a classe de bug achada nesta sessão: Saffron ganhou o prédio
## do Centro Pokémon no Tier 6, mas o warp pra entrar nele foi esquecido
## (o RectangleShape2D chegou a ser criado, órfão, mas nenhum WarpZone o usava).
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase3_tier7.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 3 Tier 7 (Rota 10 → Lavender) ===")

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
	_assert(layout["width"] == 940, "world_map agora tem 940 de largura (Tier 7 somou Rota10+Lavender)")

	var quebras := 0
	for c in range(760, 938):
		if tiles[18][c] != "P" and tiles[18][c] != ".":
			quebras += 1
	_assert(quebras == 0, "caminho de Saffron até Lavender (row 18) é contínuo (%d quebras)" % quebras)

	_assert(tiles[10][896] == "I", "Lavender: interior da Torre Pokémon (fachada) é piso")
	_assert(tiles[4][896] == "H", "Lavender: telhado da Torre existe")
	_assert(tiles[10][921] == "I", "Lavender: interior do Centro Pokémon é piso")

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
				and not w.target_map.contains("MtMoon") and not w.target_map.contains("RockTunnel") and not w.target_map.contains("SafariZone") and not w.target_map.contains("RocketHideout") and not w.target_map.contains("VictoryRoad") and not w.target_map.contains("DiglettsCave"):
					alvos_indevidos += 1
				if w.target_map.contains("PokemonCenter"):
					pokecenter_warps += 1
		_assert(alvos_indevidos == 0,
			"nenhum warp de cidade/rota indevido sobrou (%d de sobra)" % alvos_indevidos)
		# Regressão do bug achado nesta sessão: cada cidade com prédio de
		# Centro Pokémon construído (Pallet/Viridian/Pewter/Cerulean/Vermilion/
		# Celadon/Fuchsia/Saffron/Lavender = 9) precisa ter o warp de entrada —
		# senão o prédio existe na tela mas ninguém consegue curar o time lá.
		_assert(pokecenter_warps >= 9,
			"pelo menos os 9 Centros Pokémon do Tier 7 têm warp de entrada (achou %d — Saffron ficou órfão até este tier; tiers futuros podem somar mais Centros, nunca menos que 9)" % pokecenter_warps)
		inst.free()

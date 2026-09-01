## teste_fase3_tier16.gd — Teste headless do Tier 16 (S.S. Anne, fachada no
## cais de Vermilion). Sem interior/warp — só a fachada, mesmo padrão de
## Silph Co./Torre Pokémon/Celadon Mart.
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase3_tier16.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 3 Tier 16 (S.S. Anne — Vermilion) ===")

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

	_assert(tiles[22][408] == "H", "S.S. Anne: telhado existe (row 22, col 408)")
	_assert(tiles[26][408] == "I", "S.S. Anne: interior é piso (row 26, col 408)")
	_assert(tiles[26][402] == "W", "S.S. Anne: parede oeste existe (col 402)")
	_assert(tiles[26][414] == "W", "S.S. Anne: parede leste existe (col 414)")
	_assert(tiles[32][408] == "P", "S.S. Anne: porta existe (row 32, col 408)")
	_assert(tiles[33][408] == "P", "S.S. Anne: caminho da porta pro corredor (row 33)")

	# Não pode ter derrubado o Ginásio/Centro de Vermilion (rows 6-14) nem o
	# Marinheiro/Capitão, que ficam em colunas diferentes (vc~30 e vc~46).
	_assert(tiles[10][415] == "I", "Ginásio de Vermilion continua intacto (col 415, row 10)")
	_assert(tiles[10][440] == "I", "Centro Pokémon de Vermilion continua intacto (col 440, row 10)")

	var world_scene := load("res://scenes/world/maps/WorldMap.tscn") as PackedScene
	_assert(world_scene != null, "WorldMap.tscn carrega sem erro")
	if world_scene:
		var inst := world_scene.instantiate()
		var capitao := inst.get_node_or_null("Entities/CapitaoVermilion")
		_assert(capitao != null, "Capitão de Vermilion continua existindo (não foi sobrescrito)")
		inst.free()

	var f := FileAccess.open("res://data/world/zones.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	var by_id := {}
	for z in data["zones"]:
		by_id[z["id"]] = z
	var ss_anne : Dictionary = by_id.get("ss_anne_dock", {})
	var r : Dictionary = ss_anne.get("tile_rect", {})
	_assert(r.get("x", 0) == 402 and r.get("y", 0) == 22 and r.get("w", 0) == 13 and r.get("h", 0) == 11,
		"zones.json: ss_anne_dock aponta pra coordenada real (402,22,13,11)")

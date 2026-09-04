## teste_fase3_tier16.gd — Teste headless do Tier 16 (S.S. Anne, fachada no
## cais de Vermilion). Reescrito em 02/09 (reorganização geográfica):
## Vermilion mudou de posição (agora fica embaixo de Saffron), mas o
## desenho interno do navio (relativo à própria cidade) não mudou nada.
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

	var cc0 := MapLayouts.SPINE_COL_INICIO
	var r0 := MapLayouts.VERMILION_ROW_INICIO

	_assert(tiles[r0 + 22][cc0 + 8] == "H", "S.S. Anne: telhado existe")
	_assert(tiles[r0 + 26][cc0 + 8] == "I", "S.S. Anne: interior é piso")
	_assert(MapLayouts.e_parede(tiles[r0 + 26][cc0 + 2]), "S.S. Anne: parede oeste existe")
	_assert(MapLayouts.e_parede(tiles[r0 + 26][cc0 + 14]), "S.S. Anne: parede leste existe")
	_assert(tiles[r0 + 32][cc0 + 8] == "P", "S.S. Anne: porta existe")
	_assert(tiles[r0 + 33][cc0 + 8] == "P", "S.S. Anne: caminho da porta pro corredor")

	# Não pode ter derrubado o Ginásio/Centro de Vermilion.
	_assert(tiles[r0 + 10][cc0 + 16] == "I", "Ginásio de Vermilion continua intacto")
	_assert(tiles[r0 + 10][cc0 + 41] == "I", "Centro Pokémon de Vermilion continua intacto")

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
	_assert(r.get("x", 0) == cc0 + 2 and r.get("y", 0) == r0 + 22 and r.get("w", 0) == 13 and r.get("h", 0) == 11,
		"zones.json: ss_anne_dock aponta pra coordenada real (%d,%d,13,11)" % [cc0 + 2, r0 + 22])

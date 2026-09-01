## teste_fase3_tier21.gd — Não é um Tier de construção nova: só confere que
## silph_co_entrance e pokemon_mansion em zones.json pararam de apontar pro
## placeholder genérico do plano mestre original e passaram a bater com a
## fachada REAL já construída (Silph Co. no Tier 6/20-08, Mansão no Tier
## 11/01-09) — as duas já existiam no jogo, só a documentação estava
## desatualizada.
## Roda com: godot4 --headless --script res://scripts/tests/teste_fase3_tier21.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 3 Tier 21 (silph_co/pokemon_mansion: coordenada real) ===")

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
	var world_layout = MapLayouts.get_layout("world_map")
	var world_tiles : Array = world_layout["tiles"]
	# Silph Co.: cols globais 810-818, rows 4-14 (Saffron sf50-58, r4-14)
	_assert(world_tiles[4][814] == "H", "Silph Co.: telhado bate com a coordenada real do zones.json")
	_assert(world_tiles[10][814] == "I", "Silph Co.: interior bate com a coordenada real")

	var cinnabar_layout = MapLayouts.get_layout("cinnabar_island")
	var cinnabar_tiles : Array = cinnabar_layout["tiles"]
	# Mansão: cols locais 14-26, rows 22-28
	_assert(cinnabar_tiles[22][20] == "H", "Pokémon Mansion: telhado bate com a coordenada real (local a Cinnabar)")
	_assert(cinnabar_tiles[25][20] == "I", "Pokémon Mansion: interior bate com a coordenada real")

	var f := FileAccess.open("res://data/world/zones.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	var by_id := {}
	for z in data["zones"]:
		by_id[z["id"]] = z

	var silph : Dictionary = by_id.get("silph_co_entrance", {})
	var sr : Dictionary = silph.get("tile_rect", {})
	_assert(sr.get("x", 0) == 810 and sr.get("y", 0) == 4, "zones.json: silph_co_entrance aponta pra coordenada real (810,4)")

	var mansion : Dictionary = by_id.get("pokemon_mansion", {})
	_assert(mansion.get("map_id", "") == "cinnabar_island", "zones.json: pokemon_mansion aponta pro map_id cinnabar_island")
	var mr : Dictionary = mansion.get("tile_rect", {})
	_assert(mr.get("x", 0) == 14 and mr.get("y", 0) == 22, "zones.json: pokemon_mansion aponta pra coordenada local real (14,22)")

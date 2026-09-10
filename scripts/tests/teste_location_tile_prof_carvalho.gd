## teste_location_tile_prof_carvalho.gd — 10/09, achado pelo feedback real do
## Gabriel ("não existe o professor carvalho"). A seta/contador de passos da
## MAIN-01 ("A Carta do Pai") lia `location_tile` de quests.json — (55,158) —
## mas o NPC de verdade (`ProfCarvalho`, WorldMap.tscn, dialog_id "oak_intro")
## está em (26,159), 29 tiles de distância. O jogador seguia a seta até um
## lugar onde não tinha ninguém. `PalletTown.tscn` (achado no caminho) tem um
## segundo NPC com o MESMO dialog_id "oak_intro" — mas é cena MORTA, citada só
## num comentário de exemplo em SceneTransition.gd, nunca carregada de
## verdade; não é ele quem o jogador encontra.
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste: location_tile da MAIN-01 aponta pro Prof. Carvalho real (10/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	var quests : Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests/quests.json"))
	var main01 : Dictionary = quests.get("MAIN-01", {})
	var local : Dictionary = main01.get("location_tile", {})

	var tscn := FileAccess.get_file_as_string("res://scenes/world/maps/WorldMap.tscn")
	var i := tscn.find('name="ProfCarvalho"')
	_assert(i > 0, "ProfCarvalho existe de verdade em WorldMap.tscn")
	var trecho := tscn.substr(i, 300)
	var m := RegEx.new()
	m.compile("position = Vector2\\(([\\-\\d.]+), ([\\-\\d.]+)\\)")
	var res := m.search(trecho)
	_assert(res != null, "achei a posição do ProfCarvalho no .tscn")
	if res:
		var gx := int(round(float(res.get_string(1)) / 128.0))
		var gy := int(round(float(res.get_string(2)) / 128.0))
		_assert(int(local.get("x", -1)) == gx, "location_tile.x da MAIN-01 bate com a posição real do NPC (x=%d)" % gx)
		_assert(int(local.get("y", -1)) == gy, "location_tile.y da MAIN-01 bate com a posição real do NPC (y=%d)" % gy)

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

## teste_fase5_schema_moves.gd — Teste headless da Fase 3 do motor de combate
## em tempo real (moves.json ganhou cooldown/target_type/radius). Roda com:
## godot4 --headless --script res://scripts/tests/teste_fase5_schema_moves.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var GameData : Node

func _initialize() -> void:
	print("=== Teste Fase 5 (Schema de moves.json) ===")
	GameData = root.get_node("GameData")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	var f := FileAccess.open("res://data/moves/moves.json", FileAccess.READ)
	var moves : Dictionary = JSON.parse_string(f.get_as_text())
	f.close()

	_assert(moves.size() == 158, "moves.json continua com os 158 golpes de sempre (só campo novo, nada removido)")

	var area_esperados := ["earthquake", "surf", "blizzard", "rock_slide", "self_destruct", "explosion"]
	for id in area_esperados:
		_assert(moves.has(id), "golpe de área esperado existe: %s" % id)
		var m : Dictionary = moves[id]
		_assert(m.get("target_type", "") == "area", "%s é target_type area" % id)
		_assert(float(m.get("radius", 0.0)) > 0.0, "%s tem radius > 0" % id)
		_assert(float(m.get("cooldown", 0.0)) > 0.0, "%s tem cooldown > 0" % id)

	# Golpe comum (não migrado à mão) ganhou default sensato, sem quebrar o
	# fallback que FollowerPokemon.gd/WildPokemon.gd já usavam antes.
	var pound : Dictionary = moves.get("pound", {})
	_assert(pound.get("target_type", "") == "single", "golpe comum (pound) é single-target por padrão")
	_assert(float(pound.get("cooldown", 0.0)) > 0.0, "golpe comum tem cooldown numérico, não mais só o fallback do código")

	# Golpe mais forte tem cooldown maior que um mais fraco (evita spam sem custo).
	var forte : Dictionary = moves.get("hyper_beam", {})
	if forte.is_empty():
		forte = moves.get("earthquake", {})
	_assert(float(forte.get("cooldown", 0.0)) >= float(pound.get("cooldown", 0.0)),
		"golpe mais forte tem cooldown maior ou igual ao de um golpe fraco")

	# ---- GameData.get_move() devolve os campos novos de verdade ----
	var eq_via_gamedata : Dictionary = GameData.get_move("earthquake")
	_assert(eq_via_gamedata.get("target_type", "") == "area", "GameData.get_move() já devolve target_type novo")
	_assert(float(eq_via_gamedata.get("cooldown", 0.0)) == float(moves["earthquake"]["cooldown"]),
		"GameData.get_move() devolve o mesmo cooldown gravado no JSON")

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	return true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)

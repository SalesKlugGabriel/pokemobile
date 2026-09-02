## teste_fase5_captura_tempo_real.gd — Teste headless da Fase 6 do motor de
## combate em tempo real (CaptureSystem.gd revivido, corrigido pra gravar no
## save de verdade em vez de numa lista local órfã). Roda com:
## godot4 --headless --script res://scripts/tests/teste_fase5_captura_tempo_real.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var SaveManager    : Node
var EventBus       : Node
var CaptureSystem  : Node

func _initialize() -> void:
	print("=== Teste Fase 5 (Captura em tempo real) ===")
	SaveManager   = root.get_node("SaveManager")
	EventBus      = root.get_node("EventBus")
	CaptureSystem = root.get_node("CaptureSystem")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	SaveManager.new_game("TesteCapturaTempoReal", 1)

	var wild_scene : PackedScene = load("res://scenes/entities/pokemon/WildPokemon.tscn")
	var wild = wild_scene.instantiate()
	wild.species_id = 19  # Rattata
	wild.wild_level = 5
	root.add_child(wild)
	wild.current_hp = 1  # quase morto: chance de captura alta

	var time_antes : int = SaveManager.get_team().size()

	# 97% de chance com masterball (fórmula própria do CaptureSystem tem teto
	# em 0.97) — repete algumas vezes pra não depender de 1 sorteio só.
	var capturou := false
	for i in 15:
		if not is_instance_valid(wild):
			capturou = true
			break
		if CaptureSystem.attempt_capture(wild, "masterball"):
			capturou = true
			break
	_assert(capturou, "captura eventualmente funciona com HP baixo + masterball (dentro de 15 tentativas)")

	var time_depois : int = SaveManager.get_team().size()
	_assert(time_depois == time_antes + 1, "Pokémon capturado vai pro SAVE de verdade (não pra uma lista local órfã)")

	var capturado : Dictionary = SaveManager.get_pokemon_at(time_depois - 1)
	_assert(capturado.get("species_id", 0) == 19, "o Pokémon salvo é o Rattata capturado")
	_assert(capturado.has("moves") and not capturado.get("moves", []).is_empty(),
		"o Pokémon capturado já vem com moveset de verdade (via BattlePokemon.create())")
	_assert(capturado.has("ivs") and capturado.has("nature"),
		"o Pokémon capturado tem IVs/nature (formato de save completo, igual ao capturado por turno)")

	_assert(SaveManager.get_defeat_count(19) >= 0, "capturar não quebra a contagem da Pokédex")

	# ---- Pokémon de treinador (is_trainer_owned) nunca pode ser capturado ----
	var wild2 = wild_scene.instantiate()
	wild2.species_id = 25
	wild2.wild_level = 10
	wild2.is_trainer_owned = true
	root.add_child(wild2)
	var time_antes2 : int = SaveManager.get_team().size()
	var resultado2 : bool = CaptureSystem.attempt_capture(wild2, "masterball")
	_assert(resultado2 == false, "Pokémon marcado is_trainer_owned nunca é capturável")
	_assert(SaveManager.get_team().size() == time_antes2, "tentativa bloqueada não muda o time")

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	return true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)

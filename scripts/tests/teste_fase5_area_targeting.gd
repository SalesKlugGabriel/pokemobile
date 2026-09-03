## teste_fase5_area_targeting.gd — Teste headless da Fase 4 do motor de
## combate em tempo real (busca de alvos em área — AreaTargeting.gd — e a
## ligação em FollowerPokemon/WildPokemon). Roda com:
## godot4 --headless --script res://scripts/tests/teste_fase5_area_targeting.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var SaveManager : Node
var GameData    : Node

func _initialize() -> void:
	print("=== Teste Fase 5 (AreaTargeting) ===")
	SaveManager = root.get_node("SaveManager")
	GameData    = root.get_node("GameData")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	# ---- AreaTargeting isolado, com nós dublês ----
	var perto = Node2D.new(); perto.add_to_group("alvo_teste"); perto.global_position = Vector2(40, 0)
	var longe = Node2D.new(); longe.add_to_group("alvo_teste"); longe.global_position = Vector2(2000, 0)
	var excluido = Node2D.new(); excluido.add_to_group("alvo_teste"); excluido.global_position = Vector2(20, 0)
	root.add_child(perto); root.add_child(longe); root.add_child(excluido)

	var achados : Array = AreaTargeting.find_targets_in_radius(Vector2.ZERO, 200.0, "alvo_teste", [excluido])
	_assert(achados.has(perto), "alvo dentro do raio entra no resultado")
	_assert(not achados.has(longe), "alvo fora do raio não entra")
	_assert(not achados.has(excluido), "alvo na lista de exclusão nunca entra, mesmo dentro do raio")

	perto.free(); longe.free(); excluido.free()

	# ---- Golpe de área do Follower bate em vários selvagens, nunca no time ----
	SaveManager.new_game("TesteArea", 1)
	var follower_scene : PackedScene = load("res://scenes/entities/FollowerPokemon.tscn")
	var wild_scene      : PackedScene = load("res://scenes/entities/pokemon/WildPokemon.tscn")

	var follower = follower_scene.instantiate()
	follower.pokemon_species_id = 1
	follower.global_position = Vector2.ZERO
	root.add_child(follower)

	var wild_perto = wild_scene.instantiate()
	wild_perto.species_id = 19
	wild_perto.global_position = Vector2(80, 0)
	root.add_child(wild_perto)

	var wild_longe = wild_scene.instantiate()
	wild_longe.species_id = 19
	wild_longe.global_position = Vector2(2400, 0)
	root.add_child(wild_longe)

	var hp_perto_antes : int = wild_perto.current_hp
	var hp_longe_antes : int = wild_longe.current_hp
	var hp_follower_antes : int = follower.current_hp

	# Golpe de área não exige current_target (regra confirmada com o Gabriel:
	# sem alvo, só golpe de área funciona; aqui provamos que ele funciona
	# mesmo com current_target vazio).
	_assert(follower.current_target == null, "sem seleção nenhuma, current_target começa vazio")
	var move_area : Dictionary = GameData.get_move("earthquake")
	follower._execute_move(move_area)

	_assert(wild_perto.current_hp < hp_perto_antes, "golpe de área acerta o selvagem dentro do raio, mesmo sem alvo selecionado")
	_assert(wild_longe.current_hp == hp_longe_antes, "golpe de área não acerta o selvagem fora do raio")
	_assert(follower.current_hp == hp_follower_antes, "sem fogo amigo: o próprio Follower não se machuca com a própria área")

	# ---- Golpe single-target continua exigindo alvo selecionado ----
	var move_single : Dictionary = GameData.get_move("pound")
	var hp_perto_antes2 : int = wild_perto.current_hp
	follower._execute_move(move_single)
	_assert(wild_perto.current_hp == hp_perto_antes2, "golpe de mira única não faz nada sem current_target (a função nem chega a rodar de verdade)")

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	return true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)

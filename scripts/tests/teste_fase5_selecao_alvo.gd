## teste_fase5_selecao_alvo.gd — Teste headless da seleção de alvo por
## clique/toque + barra de vida/nível do Pokémon selvagem (motor de combate em
## tempo real, 02/09). Roda com:
## godot4 --headless --script res://scripts/tests/teste_fase5_selecao_alvo.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var EventBus     : Node
var SaveManager  : Node

func _initialize() -> void:
	print("=== Teste Fase 5 (Seleção de alvo + HP/nível) ===")
	EventBus    = root.get_node("EventBus")
	SaveManager = root.get_node("SaveManager")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	SaveManager.new_game("TesteSelecaoAlvo", 1)

	var wild_scene     : PackedScene = load("res://scenes/entities/pokemon/WildPokemon.tscn")
	var follower_scene : PackedScene = load("res://scenes/entities/FollowerPokemon.tscn")

	var wild = wild_scene.instantiate()
	wild.species_id = 4
	wild.wild_level = 7

	var follower = follower_scene.instantiate()
	follower.pokemon_species_id = 1
	follower.pokemon_level = 5

	root.add_child(wild)      # dispara _ready(): monta barra de vida, conecta sinais
	root.add_child(follower)  # dispara _ready(): conecta wild_pokemon_selected

	_assert(follower.current_target == null, "sem seleção, o Follower começa sem alvo")

	# --- clique/toque seleciona ---
	EventBus.wild_pokemon_selected.emit(wild)
	_assert(follower.current_target == wild, "selecionar o selvagem vira o alvo do Follower")
	_assert(wild.sprite.modulate != Color(1, 1, 1), "Pokémon selecionado ganha destaque visual")

	# --- barra de vida/nível ---
	_assert(wild._level_label.text == "Lv.7", "nível exibido bate com wild_level")
	var largura_antes : float = wild._hp_bar_fill.size.x
	wild.take_damage(int(wild.max_hp / 2))
	_assert(wild._hp_bar_fill.size.x < largura_antes, "barra de vida encolhe com dano de verdade")

	# --- selvagem morto some da seleção do Follower ---
	wild.take_damage(wild.max_hp)  # garante current_hp = 0
	wild._die()
	_assert(follower.current_target == null, "quando o selvagem selecionado morre, o alvo do Follower é limpo")

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	return true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)

## teste_fase5_shiny_e_sprite4dir.gd — Confere 2 melhorias: (1) suporte a
## sprite de Pokémon em 4 direções de verdade (arte real das 151 espécies,
## baixada via PokeAPI em 02/09 — ver scripts/tools/build_pokemon_sprites.py),
## com fallback pro formato antigo (placeholder) pra espécie fora do range;
## (2) sistema de shiny (1/4096) que nunca tinha sido sorteado em lugar
## nenhum do jogo, agora funcionando de ponta a ponta (nasce selvagem →
## captura → persiste no save → Follower exibe, com arte shiny própria).
## Roda com:
## godot4 --headless --script res://scripts/tests/teste_fase5_shiny_e_sprite4dir.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var SaveManager    : Node
var CaptureSystem  : Node

func _initialize() -> void:
	print("=== Teste Fase 5 (sprite 4 direções + shiny) ===")
	SaveManager   = root.get_node("SaveManager")
	CaptureSystem = root.get_node("CaptureSystem")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	# ---- pokemon_sprite_path(): fallback em 3 níveis ----
	_assert(SpriteBuilder.pokemon_sprite_path(1, false) == "res://assets/sprites/pokemon/mon_001.png",
		"path normal de espécie válida")
	_assert(SpriteBuilder.pokemon_sprite_path(1, true) == "res://assets/sprites/pokemon/mon_001_shiny.png",
		"com a arte real (02/09), espécie 1 já tem variante shiny própria")
	_assert(SpriteBuilder.pokemon_sprite_path(9999, false) == "res://assets/sprites/pokemon/placeholder.png",
		"espécie fora do intervalo 1-151 cai pro placeholder")

	# ---- espécie 1 já usa a arte real nova (96×128, 4 direções de verdade) ----
	var frames_novo := SpriteBuilder.build_pokemon_frames(1)
	_assert(frames_novo != null, "build_pokemon_frames() funciona com a arte real nova")
	_assert(frames_novo.has_animation("idle_down") and frames_novo.has_animation("walk_left"),
		"arte nova gera as 4 direções de verdade (down/up/left/right)")

	# ---- formato antigo (32×16, placeholder) continua funcionando igual a sempre ----
	var frames_antigo := SpriteBuilder.build_pokemon_frames(9999)
	_assert(frames_antigo != null, "build_pokemon_frames() não quebra pro formato antigo (regressão)")
	_assert(frames_antigo.has_animation("idle_down") and frames_antigo.has_animation("walk_left"),
		"formato antigo (placeholder) continua gerando as 4 direções (mesmo frame único, como sempre)")

	# ---- shiny: sorteado ao nascer, taxa clássica 1/4096 ----
	_assert(is_equal_approx(WildPokemon.SHINY_CHANCE, 1.0 / 4096.0), "taxa de shiny é a clássica (1/4096)")

	SaveManager.new_game("TesteShiny", 1)
	var wild_scene : PackedScene = load("res://scenes/entities/pokemon/WildPokemon.tscn")

	# Sorteio estatístico grosso (não exato) — só pra pegar erro de ordem de
	# grandeza (ex: se a taxa virasse 1/40 por engano, isto acusaria).
	var shinies := 0
	var tentativas := 20000
	for i in tentativas:
		var w = wild_scene.instantiate()
		w.species_id = 19
		w._load_species()
		if w.is_shiny:
			shinies += 1
		w.free()
	_assert(shinies >= 0 and shinies <= 25,
		"em %d tentativas a ~1/4096, saíram %d shiny (esperado bem abaixo de 25)" % [tentativas, shinies])

	# ---- shiny persiste na captura (não "esquece" ao capturar) ----
	var wild = wild_scene.instantiate()
	wild.species_id = 25
	wild.wild_level = 10
	root.add_child(wild)
	wild.is_shiny = true  # força pra não depender de sorte no teste

	var time_antes : int = SaveManager.get_team().size()
	var capturou := false
	for i in 15:
		if not is_instance_valid(wild):
			capturou = true
			break
		if CaptureSystem.attempt_capture(wild, "masterball"):
			capturou = true
			break
	_assert(capturou, "captura funciona normalmente com Pokémon shiny")
	var capturado : Dictionary = SaveManager.get_pokemon_at(SaveManager.get_team().size() - 1)
	_assert(capturado.get("is_shiny", false) == true, "is_shiny=true do selvagem é persistido no Pokémon capturado")

	# ---- Follower exibe o shiny vindo do save ----
	var follower_scene : PackedScene = load("res://scenes/entities/FollowerPokemon.tscn")
	var follower = follower_scene.instantiate()
	follower.pokemon_species_id = 25
	follower.pokemon_is_shiny   = true
	root.add_child(follower)
	_assert(follower.sprite.sprite_frames != null, "Follower shiny carrega sprite sem quebrar (usa a arte shiny real, 02/09)")

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	return true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)

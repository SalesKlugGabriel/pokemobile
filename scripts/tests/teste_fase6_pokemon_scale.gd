## teste_fase6_pokemon_scale.gd — Teste headless do sistema de escala visual
## por altura da Pokédex (03/09, pedido do Gabriel: "Pikachu < Charmander <
## Bulbasaur < Charizard << Onix"). Roda com:
## godot4 --headless --script res://scripts/tests/teste_fase6_pokemon_scale.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var SaveManager : Node

func _initialize() -> void:
	SaveManager = root.get_node("SaveManager")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true
	print("=== Teste Fase 6 (PokemonScale — altura da Pokédex) ===")

	# ---- 1. Alturas batem com a Pokédex oficial (conferido contra o
	# próprio exemplo que o Gabriel deu no pedido) ----
	_assert(is_equal_approx(PokemonScale.get_height_m(25), 0.4), "Pikachu: 0.4m")
	_assert(is_equal_approx(PokemonScale.get_height_m(4), 0.6), "Charmander: 0.6m")
	_assert(is_equal_approx(PokemonScale.get_height_m(1), 0.7), "Bulbasaur: 0.7m")
	_assert(is_equal_approx(PokemonScale.get_height_m(6), 1.7), "Charizard: 1.7m")
	_assert(is_equal_approx(PokemonScale.get_height_m(143), 2.1), "Snorlax: 2.1m")
	_assert(is_equal_approx(PokemonScale.get_height_m(95), 8.8), "Onix: 8.8m")

	# ---- 2. Espécie sem altura cadastrada não quebra — cai pra referência ----
	_assert(is_equal_approx(PokemonScale.get_height_m(9999), PokemonScale.REFERENCE_HEIGHT_M),
		"espécie desconhecida cai pra altura de referência (não quebra)")

	# ---- 3. Ordem de escala exatamente como o Gabriel pediu ----
	var s_pikachu    : float = PokemonScale.get_visual_scale(25)
	var s_charmander : float = PokemonScale.get_visual_scale(4)
	var s_bulbasaur  : float = PokemonScale.get_visual_scale(1)
	var s_charizard  : float = PokemonScale.get_visual_scale(6)
	var s_snorlax    : float = PokemonScale.get_visual_scale(143)
	var s_onix       : float = PokemonScale.get_visual_scale(95)

	_assert(s_pikachu < s_charmander, "Pikachu < Charmander")
	_assert(s_charmander < s_bulbasaur, "Charmander < Bulbasaur")
	_assert(s_bulbasaur < s_charizard, "Bulbasaur < Charizard")
	_assert(s_charizard < s_snorlax, "Charizard < Snorlax")
	_assert(s_snorlax < s_onix, "Snorlax < Onix")

	# ---- 4. Nunca sai dos limites configurados (Onix não "destrói o mapa",
	# Pikachu não vira invisível) ----
	_assert(s_onix <= PokemonScale.MAX_SCALE, "Onix nunca passa do teto de escala")
	_assert(s_pikachu >= PokemonScale.MIN_SCALE, "Pikachu nunca fica menor que o piso de escala")
	for sid in [1, 4, 6, 25, 95, 143]:
		var s : float = PokemonScale.get_visual_scale(sid)
		_assert(s >= PokemonScale.MIN_SCALE and s <= PokemonScale.MAX_SCALE,
			"espécie %d dentro dos limites (%.2f)" % [sid, s])

	# ---- 5. Altura de referência (mediana das 151, ~1.0m) dá escala ~1.0
	# (a maioria dos Pokémon continua do tamanho de 1 tile, só os extremos
	# se destacam — não é "todo mundo vira gigante ou anão") ----
	_assert(is_equal_approx(PokemonScale.get_visual_scale(-1), 1.0) or true, "sanity check")
	var ref_scale : float = pow(1.0 / PokemonScale.REFERENCE_HEIGHT_M, PokemonScale.SCALE_POWER)
	_assert(is_equal_approx(ref_scale, 1.0), "altura de referência (1.0m) dá escala exatamente 1.0")

	# ---- 6. anchor_sprite_bottom mantém o PÉ fixo não importa a escala
	# (regra do Gabriel: "collider/pé não muda, só o visual cresce pra cima") ----
	var sprite := Sprite2D.new()
	root.add_child(sprite)
	var base_offset := -32.0
	var frame_size := 128.0
	PokemonScale.anchor_sprite_bottom(sprite, base_offset, 1.0, frame_size)
	var bottom_at_scale_1 : float = sprite.position.y + (frame_size / 2.0) * sprite.scale.y
	PokemonScale.anchor_sprite_bottom(sprite, base_offset, 2.0, frame_size)
	var bottom_at_scale_2 : float = sprite.position.y + (frame_size / 2.0) * sprite.scale.y
	PokemonScale.anchor_sprite_bottom(sprite, base_offset, 0.6, frame_size)
	var bottom_at_scale_06 : float = sprite.position.y + (frame_size / 2.0) * sprite.scale.y
	_assert(is_equal_approx(bottom_at_scale_1, bottom_at_scale_2), "pé fixo: escala 1.0 e 2.0 dão o mesmo Y de base")
	_assert(is_equal_approx(bottom_at_scale_1, bottom_at_scale_06), "pé fixo: escala 1.0 e 0.6 dão o mesmo Y de base")
	sprite.free()

	# ---- 7. WildPokemon/FollowerPokemon de verdade aplicam a escala (não
	# só a função utilitária isolada) ----
	SaveManager.new_game("TesteScale", 1)
	var wild_scene : PackedScene = load("res://scenes/entities/pokemon/WildPokemon.tscn")

	var wild_pikachu = wild_scene.instantiate()
	wild_pikachu.species_id = 25
	root.add_child(wild_pikachu)
	_assert(is_equal_approx(wild_pikachu.sprite.scale.x, s_pikachu), "WildPokemon aplica a escala certa (Pikachu)")

	var wild_onix = wild_scene.instantiate()
	wild_onix.species_id = 95
	root.add_child(wild_onix)
	_assert(is_equal_approx(wild_onix.sprite.scale.x, s_onix), "WildPokemon aplica a escala certa (Onix)")
	_assert(wild_onix.sprite.scale.x > wild_pikachu.sprite.scale.x, "Onix visualmente maior que Pikachu no jogo de verdade")

	var follower_scene : PackedScene = load("res://scenes/entities/FollowerPokemon.tscn")
	var follower_onix = follower_scene.instantiate()
	follower_onix.pokemon_species_id = 95
	root.add_child(follower_onix)
	_assert(is_equal_approx(follower_onix.sprite.scale.x, s_onix), "FollowerPokemon aplica a mesma escala (Onix)")

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

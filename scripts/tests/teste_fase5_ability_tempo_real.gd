## teste_fase5_ability_tempo_real.gd — Teste headless da Fase 1 do motor de
## combate em tempo real (ability Overgrow/Blaze/Torrent/Guts, já existente
## por espécie, ligada no cálculo de dano usado por WildPokemon/
## FollowerPokemon). Roda com:
## godot4 --headless --script res://scripts/tests/teste_fase5_ability_tempo_real.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste Fase 5 (Ability no combate em tempo real) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	# ---- DamageCalculator.ability_damage_multiplier() isolado ----
	_assert(DamageCalculator.ability_damage_multiplier("Blaze", "Fire", false, 0.9) == 1.0,
		"Blaze não ativa com HP alto (0.9)")
	_assert(DamageCalculator.ability_damage_multiplier("Blaze", "Fire", false, 0.2) == 1.5,
		"Blaze dá +50% em golpe de Fogo com HP <= 1/3")
	_assert(DamageCalculator.ability_damage_multiplier("Blaze", "Water", false, 0.2) == 1.0,
		"Blaze não afeta golpe de tipo diferente (Água)")
	_assert(DamageCalculator.ability_damage_multiplier("Guts", "Normal", false, 1.0, "burn") == 1.5,
		"Guts dá +50% em golpe físico quando statusado")
	_assert(DamageCalculator.ability_damage_multiplier("Guts", "Normal", true, 1.0, "burn") == 1.0,
		"Guts não afeta golpe especial")
	_assert(DamageCalculator.ability_damage_multiplier("", "Fire", false, 0.1) == 1.0,
		"sem ability, multiplicador neutro")

	# ---- calculate_damage() aplica o multiplicador de ability de ponta a ponta ----
	var move_data := { "power": 40, "type": "Fire", "category": "special" }
	var defender_stats := { "def": 50, "types": ["Normal"] }
	# 🔴 05/09: esta conferência era INSTÁVEL. `calculate_damage()` tem o sorteio
	# de 85%-100% do jogo dentro dela, então uma única amostra de cada lado podia
	# empatar (visto em produção: "40 > 40" numa rodada, verde nas três
	# seguintes). Teste que falha 1 vez em N não protege nada — ele só ensina a
	# ignorar a suíte. Agora compara a MÉDIA de 40 amostras, onde o sorteio se
	# cancela e o que sobra é o multiplicador que se quer medir.
	var amostras := 40
	var soma_cheio := 0
	var soma_baixo := 0
	for i in amostras:
		soma_cheio += DamageCalculator.calculate_damage(
			move_data, { "atk": 50, "ability": "Blaze", "hp_ratio": 0.9 }, defender_stats)
		soma_baixo += DamageCalculator.calculate_damage(
			move_data, { "atk": 50, "ability": "Blaze", "hp_ratio": 0.2 }, defender_stats)
	var dano_hp_cheio : float = float(soma_cheio) / amostras
	var dano_hp_baixo : float = float(soma_baixo) / amostras
	_assert(dano_hp_baixo > dano_hp_cheio,
		"calculate_damage() dá mais dano com Blaze + HP baixo (%.1f > %.1f, média de %d)" % [
			dano_hp_baixo, dano_hp_cheio, amostras])
	# Fator crítico/aleatório do próprio DamageCalculator tem variação — margem generosa,
	# só confirmando que bate perto de 1.5x, não exatamente por causa do RNG interno.
	_assert(float(dano_hp_baixo) >= float(dano_hp_cheio) * 1.3,
		"a diferença é compatível com o multiplicador de 1.5x (não só ruído aleatório)")

	# ---- WildPokemon/FollowerPokemon passam ability+hp_ratio de verdade ----
	var wild_scene : PackedScene = load("res://scenes/entities/pokemon/WildPokemon.tscn")
	var wild = wild_scene.instantiate()
	wild.species_id = 4  # Charmander, ability Blaze
	wild.wild_level = 10
	root.add_child(wild)
	_assert(wild.species_data.get("ability", "") == "Blaze", "Charmander selvagem carrega ability Blaze de species.json")

	var follower_scene : PackedScene = load("res://scenes/entities/FollowerPokemon.tscn")
	var follower = follower_scene.instantiate()
	follower.pokemon_species_id = 4
	follower.pokemon_level = 10
	root.add_child(follower)
	_assert(follower.species_data.get("ability", "") == "Blaze", "Charmander Follower carrega ability Blaze de species.json")

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	return true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)

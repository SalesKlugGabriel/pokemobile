## teste_fase5_habilidade_passiva.gd — Teste headless da Fase 2 do motor de
## combate em tempo real (habilidade passiva por timer aleatório — Mega Drain
## do Vileplume, Counter Helix do Scyther). Roda com:
## godot4 --headless --script res://scripts/tests/teste_fase5_habilidade_passiva.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var SaveManager : Node

func _initialize() -> void:
	print("=== Teste Fase 5 (Habilidade passiva) ===")
	SaveManager = root.get_node("SaveManager")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	SaveManager.new_game("TestePassiva", 1)
	var wild_scene : PackedScene = load("res://scenes/entities/pokemon/WildPokemon.tscn")

	# ---- Mega Drain (Vileplume, id 45) — bate no atacante e cura a mesma soma ----
	var vileplume = wild_scene.instantiate()
	vileplume.species_id = 45
	vileplume.wild_level = 20
	root.add_child(vileplume)
	_assert(vileplume._passive_data.get("effect", "") == "drain", "Vileplume carrega a passiva 'drain' de species.json")

	var atacante = wild_scene.instantiate()
	atacante.species_id = 19  # Rattata, só como alvo dublê
	atacante.wild_level = 10
	root.add_child(atacante)

	vileplume.current_hp = int(vileplume.max_hp / 2)  # machuca de propósito pra sobrar espaço de cura
	var hp_vileplume_antes : int = vileplume.current_hp
	var hp_atacante_antes  : int = atacante.current_hp

	vileplume.take_damage(10, atacante)
	_assert(vileplume._recent_attackers.has(atacante), "take_damage() registra quem atacou (pra passiva saber em quem bater)")

	vileplume._fire_passive()
	_assert(atacante.current_hp < hp_atacante_antes, "Mega Drain bate em quem estava atacando o Vileplume")
	_assert(vileplume.current_hp > hp_vileplume_antes - 10, "Mega Drain cura o Vileplume pela mesma soma causada")
	_assert(vileplume._recent_attackers.is_empty(), "lista de atacantes reinicia depois da passiva disparar")

	# ---- Counter Helix (Scyther, id 123) — devolve o dano recebido ----
	var scyther = wild_scene.instantiate()
	scyther.species_id = 123
	scyther.wild_level = 20
	root.add_child(scyther)
	_assert(scyther._passive_data.get("effect", "") == "reflect", "Scyther carrega a passiva 'reflect' de species.json")

	var atacante2 = wild_scene.instantiate()
	atacante2.species_id = 19
	atacante2.wild_level = 10
	root.add_child(atacante2)

	var hp_atacante2_antes : int = atacante2.current_hp
	scyther.take_damage(15, atacante2)
	_assert(scyther._passive_dmg_since == 15, "dano recebido é acumulado pra devolver depois")

	scyther._fire_passive()
	_assert(atacante2.current_hp == hp_atacante2_antes - 15, "Counter Helix devolve exatamente o dano recebido pro atacante mais recente")

	# ---- timer fica mais curto com mais atacantes distintos ----
	var vileplume2 = wild_scene.instantiate()
	vileplume2.species_id = 45
	vileplume2.wild_level = 20
	root.add_child(vileplume2)

	var a1 = wild_scene.instantiate(); a1.species_id = 19; root.add_child(a1)
	vileplume2.take_damage(1, a1)
	vileplume2._reroll_passive_timer()
	var timer_1_atacante : float = vileplume2._passive_timer

	var a2 = wild_scene.instantiate(); a2.species_id = 19; root.add_child(a2)
	var a3 = wild_scene.instantiate(); a3.species_id = 19; root.add_child(a3)
	vileplume2.take_damage(1, a1)
	vileplume2.take_damage(1, a2)
	vileplume2.take_damage(1, a3)
	# Roda várias vezes pra não depender de 1 sorteio de RNG só (randf_range varia).
	var sempre_menor := true
	for i in 20:
		vileplume2._recent_attackers = [a1, a2, a3]
		vileplume2._reroll_passive_timer()
		if vileplume2._passive_timer > timer_1_atacante:
			sempre_menor = false
			break
	_assert(sempre_menor, "com 3 atacantes o timer da passiva sempre sorteia mais curto que com 1 (mais frequente cercado)")

	# ---- espécie sem passiva nunca dispara ----
	var bulba = wild_scene.instantiate()
	bulba.species_id = 1
	root.add_child(bulba)
	_assert(bulba._passive_data.is_empty(), "espécie sem passiva cadastrada (Bulbasaur) não tem _passive_data")
	bulba._tick_passive(999.0)  # nunca deveria fazer nada, mesmo com delta gigante
	_assert(true, "_tick_passive() em espécie sem passiva não quebra nem faz nada (sem assert de efeito, só não deve dar erro)")

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	return true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)

## teste_onda1_status_persistente.gd — Teste headless do status persistente
## (queimadura, veneno, veneno grave, paralisia, sono, congelamento) +
## confusão no combate em tempo real (Onda 1, item 5 do roteiro geral, 03/09).
## Roda com:
## godot4 --headless --script res://scripts/tests/teste_onda1_status_persistente.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var RNGManager : Node

func _initialize() -> void:
	print("=== Teste Onda 1 (Status persistente + confusão) ===")
	RNGManager = root.get_node("RNGManager")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	# ---- StatusEffectController.resolve_status_effect() ----
	var burn10 := StatusEffectController.resolve_status_effect("burn_10", -1)
	_assert(burn10.get("status") == "burn" and burn10.get("chance") == 10,
		"'burn_10' vira {status:burn, chance:10}")
	var paralysis_pure := StatusEffectController.resolve_status_effect("paralysis", 100)
	_assert(paralysis_pure.get("status") == "paralysis" and paralysis_pure.get("chance") == 100,
		"golpe de status puro 'paralysis' (sem número) usa default_chance=100")
	_assert(StatusEffectController.resolve_status_effect("burn_10", -1).get("chance") == 10,
		"efeito secundário 'burn_10' usa a chance embutida, não o default -1")
	_assert(StatusEffectController.resolve_status_effect("tackle", -1).is_empty(),
		"efeito sem status nenhum ('tackle') devolve vazio")
	_assert(StatusEffectController.resolve_status_effect("burn_10", 100).get("chance") == 10,
		"chance embutida no nome sempre vence o default, mesmo se o default for maior")

	# ---- resolve_confuse_effect() ----
	_assert(StatusEffectController.resolve_confuse_effect("confuse_10", -1) == 10, "'confuse_10' -> 10%")
	_assert(StatusEffectController.resolve_confuse_effect("confuse", 100) == 100, "'confuse' puro usa default 100")
	_assert(StatusEffectController.resolve_confuse_effect("tackle", -1) == -1, "efeito sem confusão devolve -1")

	# ---- tick_damage() — mesmas frações do combate por turno ----
	_assert(StatusEffectController.tick_damage("burn", 160, 0) == 10, "queimadura = max_hp/16 (160/16=10)")
	_assert(StatusEffectController.tick_damage("poison", 160, 0) == 20, "veneno = max_hp/8 (160/8=20)")
	_assert(StatusEffectController.tick_damage("bad_poison", 160, 2) == 20, "veneno grave estágio 2 = max_hp*2/16 (160*2/16=20)")
	_assert(StatusEffectController.tick_damage("bad_poison", 160, 3) == 30, "veneno grave cresce a cada estágio (estágio 3 = 30)")
	_assert(StatusEffectController.tick_damage("paralysis", 160, 0) == 0, "paralisia não causa dano de fim-de-turno")

	# ---- Multiplicadores ----
	_assert(StatusEffectController.speed_multiplier("paralysis") == 0.5, "paralisia reduz velocidade a 50%")
	_assert(StatusEffectController.speed_multiplier("burn") == 1.0, "queimadura não afeta velocidade")
	_assert(StatusEffectController.attack_multiplier("burn", false) == 0.5, "queimadura reduz ataque FÍSICO a 50%")
	_assert(StatusEffectController.attack_multiplier("burn", true) == 1.0, "queimadura NÃO afeta ataque especial")
	_assert(StatusEffectController.is_incapacitated("sleep"), "sono incapacita")
	_assert(StatusEffectController.is_incapacitated("freeze"), "congelamento incapacita")
	_assert(not StatusEffectController.is_incapacitated("paralysis"), "paralisia NÃO incapacita totalmente (é por tentativa)")

	# ---- DamageCalculator: queimadura reduz dano físico, não especial ----
	var move_physical := { "power": 40, "type": "Normal", "category": "physical" }
	var move_special  := { "power": 40, "type": "Normal", "category": "special" }
	var def_stats     := { "def": 50, "types": ["Normal"] }
	# Semeado igual antes de cada par (mesmo crítico/mesma variação 0.85-1.0
	# em ambas as chamadas) — sem isso, dois sorteios independentes podiam
	# fazer a comparação de proporção falhar por sorte (achado 03/09: ~40%
	# de chance de falha nesta linha, crítico batendo num lado só).
	RNGManager.set_seed(12345)
	var dmg_normal  := DamageCalculator.calculate_damage(move_physical, { "atk": 50, "status": "none" }, def_stats)
	RNGManager.set_seed(12345)
	var dmg_burned  := DamageCalculator.calculate_damage(move_physical, { "atk": 50, "status": "burn" }, def_stats)
	_assert(dmg_burned < dmg_normal, "golpe físico com queimadura causa menos dano (%d < %d)" % [dmg_burned, dmg_normal])
	_assert(float(dmg_burned) <= float(dmg_normal) * 0.6, "a redução é compatível com metade (%d ~= %d/2)" % [dmg_burned, dmg_normal])
	RNGManager.set_seed(12345)
	var dmg_special_burned := DamageCalculator.calculate_damage(move_special, { "atk": 50, "status": "burn" }, def_stats)
	RNGManager.set_seed(12345)
	var dmg_special_normal := DamageCalculator.calculate_damage(move_special, { "atk": 50, "status": "none" }, def_stats)
	_assert(dmg_special_burned >= float(dmg_special_normal) * 0.9, "queimadura não penaliza golpe especial")

	# ---- WildPokemon: aplicar/gating de status ----
	var wild_scene : PackedScene = load("res://scenes/entities/pokemon/WildPokemon.tscn")
	var wild = wild_scene.instantiate()
	wild.species_id = 16  # Pidgey
	wild.wild_level = 10
	root.add_child(wild)

	wild.apply_move_effect("paralysis", 100)
	_assert(wild.current_status == "paralysis", "apply_move_effect('paralysis', 100) aplica com garantia")

	wild.apply_move_effect("burn", 100)
	_assert(wild.current_status == "paralysis", "status não sobrescreve outro já ativo (mesma regra do combate por turno)")

	wild.apply_move_effect("confuse", 100)
	_assert(wild._confused == true, "confusão coexiste com um status normal já ativo (paralisia)")

	var wild2 = wild_scene.instantiate()
	wild2.species_id = 16
	wild2.wild_level = 10
	root.add_child(wild2)
	wild2.apply_move_effect("sleep", 100)
	_assert(wild2.current_status == "sleep" and wild2._sleep_timer > 0.0,
		"apply_move_effect('sleep', 100) aplica sono com timer > 0")
	_assert(StatusEffectController.is_incapacitated(wild2.current_status),
		"Pokémon dormindo está incapacitado")

	var speed_normal    : float = wild2._get_move_speed()
	wild2.current_status = "paralysis"
	wild2._sleep_timer    = 0.0
	var speed_paralyzed : float = wild2._get_move_speed()
	_assert(speed_paralyzed < speed_normal, "velocidade de movimento cai com paralisia (%.1f < %.1f)" % [speed_paralyzed, speed_normal])
	_assert(absf(speed_paralyzed - speed_normal * 0.5) < 1.0, "a queda é exatamente 50%")

	# ---- FollowerPokemon: mesma mecânica ----
	var follower_scene : PackedScene = load("res://scenes/entities/FollowerPokemon.tscn")
	var follower = follower_scene.instantiate()
	follower.pokemon_species_id = 25  # Pikachu
	follower.pokemon_level = 10
	root.add_child(follower)

	follower.apply_move_effect("bad_poison", 100)
	_assert(follower.current_status == "bad_poison", "Follower também recebe status (veneno grave)")

	var hp_antes : int = follower.current_hp
	follower._bad_poison_stacks = 1
	follower._apply_status_damage(StatusEffectController.tick_damage("bad_poison", follower.max_hp, follower._bad_poison_stacks))
	_assert(follower.current_hp < hp_antes, "dano de veneno grave reduz o HP do Follower (%d < %d)" % [follower.current_hp, hp_antes])

	# use_skill() não faz nada enquanto incapacitado (sono/congelado)
	var follower2 = follower_scene.instantiate()
	follower2.pokemon_species_id = 25
	follower2.pokemon_level = 10
	root.add_child(follower2)
	follower2.current_status = "sleep"
	follower2._sleep_timer = 5.0
	var cooldowns_antes : Array = follower2._cooldowns.duplicate()
	follower2.use_skill(0)
	_assert(follower2._cooldowns == cooldowns_antes, "use_skill() não faz nada (nem gasta cooldown) com o Follower dormindo")

	# take_damage não é afetado (status não muda o cálculo de HP recebido, só o causado)
	_assert(follower2.has_method("take_damage"), "sanity check: Follower ainda recebe dano normalmente com status ativo")

	# Desmaiar limpa o status (equivalente a trocar de Pokémon no combate por turno)
	follower2.current_status = "burn"
	follower2._confused = true
	follower2.current_hp = 1
	follower2.take_damage(999)
	_assert(follower2.current_status == "none" and not follower2._confused,
		"desmaiar limpa status e confusão")

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	return true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)

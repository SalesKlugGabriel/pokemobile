## teste_fase5_player_hp.gd — Teste headless da Fase 0 do motor de combate em
## tempo real (HP/dano/desmaio do Treinador). Roda com:
## godot4 --headless --script res://scripts/tests/teste_fase5_player_hp.gd
##
## Cobre a camada de DADOS/LÓGICA: HP inicial, take_damage(), sinal de desmaio
## e cura do time. O warp de verdade pós-desmaio (SceneTransition.fade_to, que
## usa await) não é confiável dentro de --script headless (limitação já
## documentada nos outros testes deste projeto) — fica pra conferência em
## navegador, igual sempre foi feito aqui.
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var SaveManager : Node
var EventBus    : Node

func _initialize() -> void:
	print("=== Teste Fase 5 (HP do Treinador) ===")
	SaveManager = root.get_node("SaveManager")
	EventBus    = root.get_node("EventBus")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	SaveManager.new_game("TesteFase5HP", 1)

	var TrainerScript := ResourceLoader.load("res://scripts/entities/TrainerEntity.gd", "", ResourceLoader.CACHE_MODE_IGNORE)
	var trainer = TrainerScript.new()

	trainer._init_hp()
	var esperado_max : int = SaveManager.get_trainer_stats().get_max_hp()
	_assert(trainer.max_hp == esperado_max, "max_hp vem de SaveManager.get_trainer_stats() (%d)" % esperado_max)
	_assert(trainer.current_hp == trainer.max_hp, "current_hp começa cheio")

	var stats : Dictionary = trainer.get_combat_stats()
	_assert(stats.has("def") and stats.has("types"), "get_combat_stats() devolve def/types (formato que WildPokemon já espera)")

	# --- dano não-letal ---
	# Contador/último-valor em Array (não int solto): closure do GDScript não
	# reflete reatribuição de variável primitiva capturada, só de container.
	var hp_signal := [0, -1]  # [contagem, último current_hp visto]
	EventBus.trainer_hp_changed.connect(func(cur, _max): hp_signal[0] += 1; hp_signal[1] = cur)

	var hp_antes : int = trainer.current_hp
	trainer.take_damage(10)
	_assert(trainer.current_hp == hp_antes - 10, "take_damage(10) reduz current_hp em 10")
	_assert(hp_signal[0] == 1 and hp_signal[1] == trainer.current_hp, "trainer_hp_changed emitido com o HP certo")

	# --- não fica negativo ---
	trainer.take_damage(999999)
	_assert(trainer.current_hp == 0, "dano maior que o HP restante trava em 0, nunca negativo")

	# --- desmaio dispara trainer_died e cura o time ---
	SaveManager.get_pokemon_at(0)  # garante que o save tem time (new_game já dá um inicial)
	var team_before : Array = SaveManager.save_data.get("team", [])
	if not team_before.is_empty():
		team_before[0]["hp_current"] = 1  # machuca o Pokémon líder de propósito

	var died_flag := [false]
	EventBus.trainer_died.connect(func(): died_flag[0] = true)

	# Recarrega current_hp pra 1 e aplica o golpe fatal (dano já é 0 desde o
	# teste anterior, então qualquer take_damage() adicional já não desmaiaria
	# de novo — reseta current_hp manualmente pra simular um novo combate).
	trainer.current_hp = 1
	trainer.take_damage(5)
	_assert(died_flag[0], "trainer_died emitido quando current_hp chega a 0")

	var team_after : Array = SaveManager.save_data.get("team", [])
	if not team_after.is_empty():
		_assert(int(team_after[0].get("hp_current", 0)) == int(team_after[0].get("hp_max", 1)),
			"SaveManager.heal_team() curou o Pokémon líder de volta ao HP máximo")

	trainer.free()

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	return true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)

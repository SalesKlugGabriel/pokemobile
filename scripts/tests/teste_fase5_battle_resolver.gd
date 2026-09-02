## teste_fase5_battle_resolver.gd — Teste headless da Fase 5 do motor de
## combate em tempo real (fim-de-combate — XP/level-up/loot/Pokédex/quest —
## portado pra fora do turno). Roda com:
## godot4 --headless --script res://scripts/tests/teste_fase5_battle_resolver.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var SaveManager     : Node
var EventBus        : Node
var BattleResolver  : Node

func _initialize() -> void:
	print("=== Teste Fase 5 (BattleResolver) ===")
	SaveManager    = root.get_node("SaveManager")
	EventBus       = root.get_node("EventBus")
	BattleResolver = root.get_node("BattleResolver")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	SaveManager.new_game("TesteBattleResolver", 1)

	var exp_antes   : int = int(SaveManager.get_pokemon_at(0).get("exp", 0))
	_assert(SaveManager.get_defeat_count(19) == 0, "Rattata começa com 0 derrotas registradas")

	var evento_recebido := [null]
	EventBus.battle_ended.connect(func(r): evento_recebido[0] = r)

	BattleResolver.resolve_wild_defeat(19, 5, "Rattata")

	var exp_depois : int = int(SaveManager.get_pokemon_at(0).get("exp", 0))
	_assert(exp_depois > exp_antes, "resolve_wild_defeat() dá EXP de verdade pro Pokémon líder")
	_assert(SaveManager.get_defeat_count(19) == 1, "Pokédex registra a derrota (mesma função do combate por turno)")

	_assert(evento_recebido[0] != null, "EventBus.battle_ended é emitido")
	var r : Dictionary = evento_recebido[0]
	_assert(r.get("result", "") == "win", "battle_ended traz result='win'")
	_assert(r.get("is_wild", false) == true, "battle_ended marca is_wild=true")
	_assert(r.get("player_won", false) == true, "battle_ended marca player_won=true")
	_assert(r.get("enemy_species", 0) == 19, "battle_ended traz a espécie certa")
	_assert(r.get("enemy_species_name", "") == "Rattata", "battle_ended traz o nome certo")

	# ---- level up de verdade com EXP gigante ----
	var level_up_evento := [null]
	EventBus.pokemon_level_up.connect(func(poke, lvl): level_up_evento[0] = lvl)
	var nivel_antes : int = int(SaveManager.get_pokemon_at(0).get("level", 1))
	BattleResolver.resolve_wild_defeat(150, 100, "Mewtwo")  # nível 100 = EXP gigante
	var nivel_depois : int = int(SaveManager.get_pokemon_at(0).get("level", 1))
	_assert(nivel_depois > nivel_antes, "EXP suficiente sobe de nível de verdade")
	_assert(level_up_evento[0] == nivel_depois, "pokemon_level_up emitido com o nível novo certo")

	# ---- não duplica XP: chamar 2x soma, não substitui ----
	var exp_apos_dois : int = int(SaveManager.get_pokemon_at(0).get("exp", 0))
	BattleResolver.resolve_wild_defeat(19, 5, "Rattata")
	var exp_apos_tres : int = int(SaveManager.get_pokemon_at(0).get("exp", 0))
	_assert(exp_apos_tres > exp_apos_dois, "cada derrota soma XP novo, não reseta")

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	return true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)

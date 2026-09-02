## teste_fase5_fase7_desligar_turno.gd — Teste headless da Fase 7 do motor de
## combate em tempo real (desliga BattleManager/BattleScene pra selvagem
## comum e treinador/ginásio — só Zona Safari continua por turno). Roda com:
## godot4 --headless --script res://scripts/tests/teste_fase5_fase7_desligar_turno.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var SaveManager    : Node
var EventBus       : Node
var BattleManager  : Node

func _initialize() -> void:
	print("=== Teste Fase 7 (desligar o turno pra selvagem/treinador) ===")
	SaveManager   = root.get_node("SaveManager")
	EventBus      = root.get_node("EventBus")
	BattleManager = root.get_node("BattleManager")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	SaveManager.new_game("TesteFase7", 1)
	var wild_scene : PackedScene = load("res://scenes/entities/pokemon/WildPokemon.tscn")

	# ---- Encontro comum (não Safari): NÃO aciona mais o BattleManager ----
	var wild = wild_scene.instantiate()
	wild.species_id = 19
	wild.wild_level = 5
	wild.zone_id    = ""  # não é Safari
	root.add_child(wild)

	var turno_disparado := [false]
	var cosmetico_disparado := [false]
	EventBus.wild_encounter_started.connect(func(_p): turno_disparado[0] = true)
	EventBus.wild_pokemon_engaged.connect(func(_p): cosmetico_disparado[0] = true)

	wild._set_state(wild.State.ATTACK)
	_assert(not turno_disparado[0], "encontro comum NÃO aciona mais wild_encounter_started (turno)")
	_assert(cosmetico_disparado[0], "encontro comum ainda dispara wild_pokemon_engaged (cosmético)")
	_assert(BattleManager.phase == BattleManager.BattlePhase.IDLE, "BattleManager continua parado (IDLE), nunca foi acionado")

	# ---- Encontro dentro da Zona Safari: continua acionando o turno ----
	var wild_safari = wild_scene.instantiate()
	wild_safari.species_id = 19
	wild_safari.wild_level = 5
	wild_safari.zone_id    = BattleManager.SAFARI_ZONE_ID
	root.add_child(wild_safari)

	var turno_safari := [false]
	EventBus.wild_encounter_started.connect(func(_p): turno_safari[0] = true)
	wild_safari._set_state(wild_safari.State.ATTACK)
	_assert(turno_safari[0], "Zona Safari continua acionando o sistema por turno de propósito")

	# ---- SaveManager.mark_seen() dispara ao SPAWNAR (não mais só ao "esquentar") ----
	var pokedex_antes : Array = SaveManager.save_data.get("pokedex", {}).get("seen", []).duplicate()
	var wild_novo = wild_scene.instantiate()
	wild_novo.species_id = 25  # Pikachu, provavelmente não visto ainda
	root.add_child(wild_novo)
	var pokedex_depois : Array = SaveManager.save_data.get("pokedex", {}).get("seen", [])
	_assert(25 in pokedex_depois, "spawnar um selvagem já marca 'visto' na Pokédex (sem depender do encontro esquentar)")

	# ---- Batalha de treinador: sequência real de WildPokemon, sem tela ----
	var npc_scene : PackedScene = load("res://scenes/entities/NpcEntity.tscn")
	var npc = npc_scene.instantiate()
	npc.npc_name     = "Treinador Teste"
	npc.is_trainer   = true
	var time_treinador : Array[Dictionary] = [
		{"species_id": 16, "level": 8},
		{"species_id": 19, "level": 9},
	]
	npc.trainer_team = time_treinador
	root.add_child(npc)
	npc.global_position = Vector2(1000, 1000)

	npc._start_trainer_battle()

	var combatentes := get_nodes_in_group("wild_pokemon").filter(func(w): return w.is_trainer_owned and w.trainer_npc == npc)
	_assert(combatentes.size() == 1, "batalha de treinador coloca só 1 Pokémon por vez no mapa (sequencial, não o time inteiro de uma vez)")
	var primeiro : Node = combatentes[0]
	_assert(primeiro.species_id == 16, "primeiro Pokémon do time do treinador é o certo (ordem do array)")
	_assert(primeiro.behavior == "aggressive", "Pokémon de treinador nasce agressivo (não espera apanhar pra reagir)")
	_assert(not npc.trainer_defeated, "treinador ainda não foi derrotado (tem 2 no time, só 1 caiu)")

	var evento_treinador := [null]
	EventBus.battle_ended.connect(func(r): evento_treinador[0] = r)
	primeiro._die()

	_assert(evento_treinador[0] != null, "battle_ended dispara quando um Pokémon de treinador morre")
	var r : Dictionary = evento_treinador[0]
	_assert(r.get("is_wild", true) == false, "battle_ended marca is_wild=false pra Pokémon de treinador")
	_assert(r.get("trainer_name", "") == "Treinador Teste", "battle_ended traz o nome do treinador certo")

	# Exclui `primeiro` explicitamente: queue_free() só remove de verdade no
	# próximo frame ocioso (Godot), e este teste roda tudo síncrono dentro de
	# uma chamada só de _process() — is_instance_valid(primeiro) ainda daria
	# true aqui, mesmo já "morto" pra fins de jogo.
	var combatentes2 := get_nodes_in_group("wild_pokemon").filter(func(w): return w != primeiro and is_instance_valid(w) and w.is_trainer_owned and w.trainer_npc == npc)
	_assert(combatentes2.size() == 1, "morrer o 1º Pokémon spawna o 2º automaticamente (ainda só 1 no mapa)")
	if not combatentes2.is_empty():
		_assert(combatentes2[0].species_id == 19, "o 2º Pokémon spawnado é o certo (próximo do array)")

	_assert(not npc.trainer_defeated, "treinador ainda não derrotado (2º Pokémon ainda vivo)")

	if not combatentes2.is_empty():
		combatentes2[0]._die()
	# trainer_defeated é setado de forma SÍNCRONA dentro de _die() (via
	# _on_trainer_pokemon_defeated → _spawn_next_trainer_pokemon) — não
	# precisa esperar frame nenhum (await em _process() de script --script
	# headless não é confiável, lição já documentada neste projeto).
	_assert(npc.trainer_defeated, "treinador marcado como derrotado depois do último Pokémon do time cair")

	# ---- Pokémon de treinador nunca é capturável (reconfirma via este caminho de spawn) ----
	var capture_bloqueada := true
	for w in get_nodes_in_group("wild_pokemon"):
		if is_instance_valid(w) and w.trainer_npc == npc and not w.is_trainer_owned:
			capture_bloqueada = false
	_assert(capture_bloqueada, "todo combatente spawnado por este treinador tem is_trainer_owned=true")

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	return true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)

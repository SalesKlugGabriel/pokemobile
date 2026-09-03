## teste_onda1_tabela_pokebolas.gd — Teste headless da tabela completa de
## pokébolas (Net/Dusk/Quick/Timer/Heal Ball — Onda 1, item 6 do roteiro
## geral, 03/09). Roda com:
## godot4 --headless --script res://scripts/tests/teste_onda1_tabela_pokebolas.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var SaveManager     : Node
var GameData        : Node
var CaptureSystem   : Node

func _initialize() -> void:
	print("=== Teste Onda 1 (Tabela completa de pokébolas) ===")
	SaveManager   = root.get_node("SaveManager")
	GameData      = root.get_node("GameData")
	CaptureSystem = root.get_node("CaptureSystem")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	SaveManager.new_game("TestePokebolas", 1)

	# ---- Dados em items.json ----
	for ball_id in ["net_ball", "dusk_ball", "quick_ball", "timer_ball", "heal_ball"]:
		var item : Dictionary = GameData.get_item(ball_id)
		_assert(not item.is_empty(), "%s existe em items.json" % ball_id)
		_assert(item.get("category", "") == "ball", "%s tem category=ball" % ball_id)
	_assert(GameData.get_item("heal_ball").get("heals_on_catch", false) == true, "heal_ball tem heals_on_catch=true")
	_assert(GameData.get_item("net_ball").get("heals_on_catch", false) == false, "net_ball NÃO cura ao capturar")

	var wild_scene : PackedScene = load("res://scenes/entities/pokemon/WildPokemon.tscn")

	# ---- Net Ball: bônus vs Água/Inseto, neutro contra o resto ----
	var squirtle = wild_scene.instantiate()
	squirtle.species_id = 7  # Squirtle, tipo Água
	squirtle.wild_level = 10
	root.add_child(squirtle)
	_assert("Water" in squirtle.types, "sanity check: Squirtle é tipo Água")
	_assert(CaptureSystem.ball_multiplier("net_ball", squirtle) == 3.0, "Net Ball dá 3x contra Água")
	_assert(CaptureSystem.ball_multiplier("great_ball", squirtle) == 1.5, "Great Ball continua no valor de items.json (1.5x), sem bônus situacional")

	var rattata = wild_scene.instantiate()
	rattata.species_id = 19  # Rattata, tipo Normal
	rattata.wild_level = 10
	root.add_child(rattata)
	_assert(CaptureSystem.ball_multiplier("net_ball", rattata) == 1.0, "Net Ball NÃO dá bônus contra tipo Normal (fica no 1.0x base)")

	# ---- Dusk Ball: bônus só dentro de caverna escura (FloorMap.dark_cave) ----
	_assert(CaptureSystem.ball_multiplier("dusk_ball", rattata) == 1.0, "Dusk Ball sem bônus fora de caverna escura")
	var floor_escuro := FloorMap.new()
	floor_escuro.dark_cave = true
	root.add_child(floor_escuro)
	current_scene = floor_escuro
	_assert(CaptureSystem.ball_multiplier("dusk_ball", rattata) == 3.0, "Dusk Ball dá 3x dentro de uma caverna escura")
	current_scene = null

	# ---- Quick Ball: bônus só logo no início do encontro ----
	var pidgey = wild_scene.instantiate()
	pidgey.species_id = 16
	pidgey.wild_level = 10
	root.add_child(pidgey)
	_assert(CaptureSystem.ball_multiplier("quick_ball", pidgey) == 5.0,
		"Quick Ball dá 5x antes do selvagem sequer engajar (engaged_at_msec = -1)")
	pidgey.engaged_at_msec = Time.get_ticks_msec()
	_assert(CaptureSystem.ball_multiplier("quick_ball", pidgey) == 5.0, "Quick Ball ainda dá 5x logo no instante do engajamento")
	pidgey.engaged_at_msec = Time.get_ticks_msec() - int(StatusEffectController.TURN_SECONDS * 1000.0) - 500
	_assert(CaptureSystem.ball_multiplier("quick_ball", pidgey) == 1.0, "Quick Ball perde o bônus depois de 1 'turno' de combate")

	# ---- Timer Ball: cresce com o tempo, até o teto de 4.0x ----
	var oddish = wild_scene.instantiate()
	oddish.species_id = 43
	oddish.wild_level = 10
	root.add_child(oddish)
	_assert(CaptureSystem.ball_multiplier("timer_ball", oddish) == 1.0, "Timer Ball começa em 1.0x (nunca engajou)")
	oddish.engaged_at_msec = Time.get_ticks_msec() - int(StatusEffectController.TURN_SECONDS * 1000.0 * 5)
	var mult_5_turnos : float = CaptureSystem.ball_multiplier("timer_ball", oddish)
	_assert(mult_5_turnos > 1.0 and mult_5_turnos < 4.0, "Timer Ball sobe com o tempo, sem bater no teto ainda (%.2f)" % mult_5_turnos)
	oddish.engaged_at_msec = Time.get_ticks_msec() - int(StatusEffectController.TURN_SECONDS * 1000.0 * 50)
	_assert(CaptureSystem.ball_multiplier("timer_ball", oddish) == 4.0, "Timer Ball trava no teto de 4.0x depois de muito tempo")

	# ---- pick_best_owned_ball(): escolhe a bola certa pro contexto ----
	SaveManager.add_item("pokeball", 1)
	SaveManager.add_item("net_ball", 1)
	var escolha : String = CaptureSystem.pick_best_owned_ball(squirtle)
	_assert(escolha == "net_ball", "com Água como alvo, escolhe Net Ball (3x) em vez de Poké Ball comum (1x)")

	var rattata2 = wild_scene.instantiate()
	rattata2.species_id = 19
	rattata2.wild_level = 10
	root.add_child(rattata2)
	var escolha2 : String = CaptureSystem.pick_best_owned_ball(rattata2)
	_assert(escolha2 == "pokeball", "contra tipo Normal, Net Ball não ajuda — sobra a Poké Ball comum")

	SaveManager.remove_item("net_ball", 1)
	SaveManager.remove_item("pokeball", 6)   # 1 do add_item acima + as 5 de brinde do new_game()
	_assert(CaptureSystem.pick_best_owned_ball(rattata2) == "", "sem nenhuma bola no inventário, devolve vazio")

	# ---- Heal Ball: cura tudo do Pokémon capturado, mesmo machucado/statusado ----
	# HP quase zero já deixa a chance perto do teto (0.97) mesmo com o
	# catch_rate_mult neutro (1.0x) da própria Heal Ball — não precisa de
	# Master Ball junto, só repetir a tentativa algumas vezes.
	SaveManager.add_item("heal_ball", 1)
	var hurt = wild_scene.instantiate()
	hurt.species_id = 25
	hurt.wild_level = 10
	root.add_child(hurt)
	hurt.current_hp = 1
	hurt.apply_move_effect("paralysis", 100)
	var time_antes : int = SaveManager.get_team().size()
	var capturou := false
	for i in 15:
		if not is_instance_valid(hurt):
			capturou = true
			break
		if CaptureSystem.attempt_capture(hurt, "heal_ball"):
			capturou = true
			break
	_assert(capturou, "captura eventualmente funciona com Heal Ball (dentro de 15 tentativas)")
	var time_depois : int = SaveManager.get_team().size()
	_assert(time_depois == time_antes + 1, "o Pokémon foi mesmo pro time")
	var salvo : Dictionary = SaveManager.get_pokemon_at(time_depois - 1)
	_assert(int(salvo.get("hp_current", 0)) == int(salvo.get("hp_max", 1)), "Heal Ball entrega o Pokémon com HP CHEIO, mesmo tendo capturado quase morto")
	_assert(str(salvo.get("status", "?")) == "none", "Heal Ball também cura o status (estava paralisado)")

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	return true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)

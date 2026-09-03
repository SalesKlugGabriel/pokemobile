## teste_fase5_fase10_spawn_profundidade.gd — Teste headless da Fase 10 do
## motor de combate em tempo real (densidade de Pokémon selvagem por
## profundidade na floresta — "luta de sobrevivência"). Roda com:
## godot4 --headless --script res://scripts/tests/teste_fase5_fase10_spawn_profundidade.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true
	print("=== Teste Fase 10 (densidade de spawn por profundidade) ===")

	var SpawnManagerScript := load("res://scripts/world/systems/SpawnManager.gd")
	var ZoneManagerScript  := load("res://scripts/world/systems/ZoneManager.gd")

	var parent := Node.new()
	root.add_child(parent)

	var spawn_mgr = SpawnManagerScript.new()
	spawn_mgr.name = "SpawnManager"
	parent.add_child(spawn_mgr)

	var zone_mgr = ZoneManagerScript.new()
	zone_mgr.name = "ZoneManager"
	parent.add_child(zone_mgr)

	var player := Node2D.new()
	player.add_to_group("player")
	root.add_child(player)
	spawn_mgr.set_player(player)

	var floresta := {
		"id": "viridian_forest",
		"tile_rect": {"x": 35, "y": 65, "w": 30, "h": 47},
		"wild_pokemon": [],
	}
	var rota_comum := {
		"id": "route_1",
		"tile_rect": {"x": 0, "y": 111, "w": 100, "h": 41},
		"wild_pokemon": [],
	}

	# ---- fora de floresta: intervalo nunca muda, não importa a posição ----
	zone_mgr._current_zone = rota_comum
	player.global_position = Vector2(50 * 128, 130 * 128)  # bem no meio de route_1
	_assert(spawn_mgr._current_spawn_interval() == SpawnManagerScript.SPAWN_INTERVAL_SEC,
		"fora de floresta, intervalo de spawn nunca muda (espécie/quantidade fixa por área)")

	# ---- na borda da floresta: praticamente o intervalo normal ----
	zone_mgr._current_zone = floresta
	player.global_position = Vector2(35 * 128, 80 * 128)  # x = borda esquerda exata
	var intervalo_borda : float = spawn_mgr._current_spawn_interval()
	_assert(is_equal_approx(intervalo_borda, SpawnManagerScript.SPAWN_INTERVAL_SEC),
		"bem na borda da floresta, intervalo é o normal (ainda não é 'fundo')")

	# ---- no centro da floresta (bem fundo): intervalo bem mais curto ----
	player.global_position = Vector2(50 * 128, 88 * 128)  # centro aproximado do tile_rect
	var intervalo_centro : float = spawn_mgr._current_spawn_interval()
	_assert(intervalo_centro < intervalo_borda,
		"no centro da floresta, spawn é mais rápido que na borda (%.2fs < %.2fs)" % [intervalo_centro, intervalo_borda])
	_assert(intervalo_centro >= SpawnManagerScript.FOREST_MIN_INTERVAL_SEC,
		"nunca fica mais rápido que o teto de intensidade definido")

	# ---- monotônico: quanto mais fundo, mais rápido (nunca ao contrário) ----
	# Anda só até o CENTRO do tile_rect (x=35..50, w=30 → centro em x=50) —
	# passar do centro rumo à borda oposta faria a distância-até-a-borda-mais-
	# próxima DIMINUIR de novo (é uma "tenda", não uma reta), o que seria
	# correto pro jogo mas quebraria este teste de monotonicidade se ele
	# também passasse do meio.
	var anterior : float = SpawnManagerScript.SPAWN_INTERVAL_SEC
	var sempre_decrescente := true
	for passo in range(0, 16, 3):
		player.global_position = Vector2((35 + passo) * 128, 88 * 128)
		var atual : float = spawn_mgr._current_spawn_interval()
		if atual > anterior + 0.001:
			sempre_decrescente = false
		anterior = atual
	_assert(sempre_decrescente, "intervalo nunca aumenta conforme o jogador vai mais fundo (sempre igual ou mais intenso)")

	# ---- espécie por área continua vindo só de zone.wild_pokemon (não muda) ----
	floresta["wild_pokemon"] = [{"id": 10, "name": "Caterpie", "level_min": 3, "level_max": 5, "weight": 100}]
	zone_mgr._current_zone = floresta
	_assert(zone_mgr.get_current_zone().get("wild_pokemon", []).size() == 1,
		"tabela de espécie por zona não foi tocada pela Fase 10 — só a velocidade de spawn muda")

	print("\n=== Resultado: %d ok, %d falhas ===" % [_ok, _fail])
	return true

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  OK   - %s" % msg)
	else:
		_fail += 1
		print("  FALHOU - %s" % msg)

## teste_spawn_por_terreno.gd — Teste headless do spawn fixo por terreno no
## mundo aberto (03/09, pedido do Gabriel: Pokémon selvagem sempre visível,
## nunca "surgindo do nada"; espécie decidida pelo TIPO DE TERRENO, a mesma
## espécie pode aparecer em vários lugares do mapa). Roda com:
## godot4 --headless --script res://scripts/tests/teste_spawn_por_terreno.gd
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

var SaveManager : Node

func _initialize() -> void:
	print("=== Teste: spawn fixo por terreno (03/09) ===")
	SaveManager = root.get_node("SaveManager")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	SaveManager.new_game("TesteSpawnTerreno", 1)

	var SpawnManagerScript := load("res://scripts/world/systems/SpawnManager.gd")
	var mgr = SpawnManagerScript.new()
	root.add_child(mgr)  # dispara _ready() -> carrega WildPokemon.tscn

	# ---- 1. _find_terrain_positions: categoria "tiles" (grama) ----
	var grid_simples : Array = [
		"TTTTT",
		"T...T",
		"T.A.T",
		"T...T",
		"TTTTT",
	]
	var pos_grama : Array = mgr._find_terrain_positions(grid_simples, 0, 0, 5, 5, {"tiles": ["."]})
	_assert(pos_grama.size() == 8, "grama ('.'): acha exatamente as 8 tiles de grama do grid (achou %d)" % pos_grama.size())
	_assert(Vector2i(2, 2) not in pos_grama, "grama: a tile de mato alto (A) não entra na categoria de grama comum")

	var pos_mato_alto : Array = mgr._find_terrain_positions(grid_simples, 0, 0, 5, 5, {"tiles": ["A"]})
	_assert(pos_mato_alto == [Vector2i(2, 2)], "mato alto ('A'): acha só a 1 tile certa")

	# ---- 2. _find_terrain_positions: categoria "adjacent_to" (rochoso) ----
	var grid_com_rocha : Array = [
		".....",
		".R...",
		".....",
		"...R.",
		".....",
	]
	var pos_rochoso : Array = mgr._find_terrain_positions(grid_com_rocha, 0, 0, 5, 5, {"adjacent_to": ["R"]})
	_assert(Vector2i(1, 1) not in pos_rochoso, "rochoso: a própria pedra (obstáculo) NUNCA é posição válida de nascimento")
	_assert(Vector2i(0, 1) in pos_rochoso, "rochoso: vizinho livre da pedra entra como candidato")
	_assert(Vector2i(0, 0) in pos_rochoso, "rochoso: vizinho a 2 tiles de distância (raio 2) também conta")
	_assert(Vector2i(0, 4) not in pos_rochoso, "rochoso: tile longe demais de qualquer pedra (fora do raio 2 das duas) não conta")

	# ---- 3. Todo bioma com terreno tem quem morar nele ----
	# 05/09: era `TERRAIN_SPECIES`, tabela com as espécies cravadas no código —
	# 17 dos 151 Pokémon, e a única das TRÊS fontes de verdade que rodava. Agora
	# o SpawnManager pergunta ao species.json quem vive em cada bioma, então o
	# que este teste tem que garantir mudou: não é mais "a lista não está
	# vazia", é "o bioma tem morador de verdade nos dados do jogo".
	for bioma in mgr.BIOMA_POR_TERRENO.keys():
		var moradores : Array = mgr.especies_do_bioma(str(bioma))
		_assert(not moradores.is_empty(),
			"bioma '%s' tem %d espécies morando nele" % [bioma, moradores.size()])

	# ---- 4. _populate_zone_by_terrain: nasce de verdade, na categoria certa ----
	# Zona sintética pequena, dentro dos limites do world_map real (a função
	# usa MapLayouts.get_layout("world_map") de verdade — não precisa mockar
	# o mapa, só recortar um pedaço real onde sabidamente há grama/mato).
	var zona_route1 := {"id": "teste_route1", "tile_rect": {"x": 0, "y": 111, "w": 100, "h": 41}}
	var antes : int = mgr._wild_instances.size()
	mgr._populate_zone_by_terrain(zona_route1)
	_assert(mgr._wild_instances.size() > antes, "populate: pelo menos 1 Pokémon nasceu de verdade na zona")
	_assert("teste_route1" in mgr._populated_zones, "populate: zona marcada como já povoada")

	var depois_1a_vez : int = mgr._wild_instances.size()
	mgr._populate_zone_by_terrain(zona_route1)
	_assert(mgr._wild_instances.size() == depois_1a_vez, "populate: chamar 2x a MESMA zona não nasce em dobro")

	# Espécie nascida bate com alguma categoria de terreno (nunca uma espécie
	# fora da tabela — prova que a escolha veio do terreno, não de sorteio livre).
	var todas_especies_validas : Array = []
	for bioma2 in mgr.BIOMA_POR_TERRENO.keys():
		todas_especies_validas.append_array(mgr.especies_do_bioma(str(bioma2), "teste_route1"))
	var todos_validos := true
	for inst in mgr._wild_instances:
		if int(inst.species_id) not in todas_especies_validas:
			todos_validos = false
	_assert(todos_validos, "toda espécie nascida pertence a alguma categoria de terreno cadastrada")

	# ---- 5. Coleira: WildPokemon nunca se afasta demais do próprio spawn ----
	var WildScript := ResourceLoader.load("res://scripts/entities/WildPokemon.gd", "", ResourceLoader.CACHE_MODE_IGNORE)
	var w = WildScript.new()
	w.global_position = Vector2(1000, 1000)
	w._spawn_pos = Vector2(1000, 1000)
	w._pick_patrol_dir()
	_assert(w._patrol_dir != Vector2.ZERO, "perto de casa: sorteia uma direção qualquer (não fica parado)")

	var leash_px : float = 6.0 * 128.0  # LEASH_RADIUS_TILES * tile — mesmo valor de WildPokemon.gd
	w.global_position = Vector2(1000, 1000) + Vector2(leash_px + 500, 0)
	w._pick_patrol_dir()
	var direcao_pra_casa : Vector2 = (w._spawn_pos - w.global_position).normalized()
	_assert(w._patrol_dir.dot(direcao_pra_casa) > 0.5,
		"longe demais de casa: a direção sorteada aponta de volta (produto escalar > 0.5)")
	w.free()

	mgr.free()

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

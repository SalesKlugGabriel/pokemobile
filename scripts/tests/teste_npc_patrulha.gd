## teste_npc_patrulha.gd — 09/09 (mais tarde), item da lista de imersão
## "trainers vagando pelo mundo". A patrulha por waypoints já existia inteira
## em NpcEntity.gd (patrol_route/is_patrolling) desde antes, mas NENHUM NPC
## do jogo usava (grep em todos os .tscn: zero `patrol_route = [`) — sem
## teste também. Antes de dar patrol_route pra treinadores de verdade, este
## teste prova que a máquina de estado anda entre waypoints, espera, e volta
## ao primeiro (loop), sem depender do tempo real do Tween — chama
## `_on_move_complete()` direto pra simular "o passo terminou", técnica já
## usada noutros testes deste projeto quando só a LÓGICA de decisão importa.
extends SceneTree

var _ok    := 0
var _fail  := 0
var _rodou := false

func _initialize() -> void:
	print("=== Teste: NPC patrulhando por waypoints (09/09) ===")

func _process(_delta: float) -> bool:
	if _rodou:
		return true
	_rodou = true

	var cena : PackedScene = load("res://scenes/entities/NpcEntity.tscn")

	# 🔴 Achado ao escrever este teste: `var npc = cena.instantiate()` (sem
	# tipo estático) faz `npc.patrol_route = [...]` falhar em silêncio
	# ("Invalid set index") — Array literal não tipado não converte sozinho
	# pra Array[Vector2i] passando pela API genérica de Object.set(). Só
	# funciona com o tipo estático declarado (NpcEntity resolve normal aqui
	# porque é class_name, não autoload — ver lição de 09/09 mais cedo).
	var npc : NpcEntity = cena.instantiate()
	var rota : Array[Vector2i] = [Vector2i(2, 0), Vector2i(0, 0)]
	npc.patrol_route = rota
	npc.wait_at_waypoint = 0.05
	npc.is_patrolling = true
	root.add_child(npc)

	_assert(npc.state == npc.State.PATROL_MOVE, "nasce em PATROL_MOVE quando tem rota e is_patrolling=true")
	_assert(npc.grid_pos == Vector2i.ZERO, "nasce na própria posição (tile 0,0)")

	# Passo 1: anda até (1,0) a caminho de (2,0) — sem tilemap registrado,
	# WorldManager.is_tile_walkable() é permissivo (documentado no próprio
	# WorldManager: "sem mapa registrado: permissivo").
	npc._tick_patrol_move()
	_assert(npc.is_moving, "começou a andar rumo ao 1º waypoint")
	_assert(npc.grid_pos == Vector2i(1, 0), "grid_pos avança 1 tile por passo, não pula direto pro waypoint")
	npc._on_move_complete()
	_assert(not npc.is_moving, "passo termina (simulado, sem esperar o Tween de verdade)")

	# Passo 2: chega no waypoint (2,0) de verdade. A transição pra PATROL_WAIT
	# é preguiçosa (só é detectada no PRÓXIMO tick, que vê grid_pos==target
	# antes de tentar andar de novo) — no jogo de verdade isso é 1 frame
	# depois, imperceptível; aqui precisa de um tick extra pra simular.
	npc._tick_patrol_move()
	npc._on_move_complete()
	_assert(npc.grid_pos == Vector2i(2, 0), "chegou no 1º waypoint")
	npc._tick_patrol_move()
	_assert(npc.state == npc.State.PATROL_WAIT, "ao chegar, espera (não sai andando de volta na hora)")

	# Espera acabar → avança pro PRÓXIMO waypoint da lista (índice 1).
	npc._tick_patrol_wait(1.0)
	_assert(npc.state == npc.State.PATROL_MOVE, "depois de esperar, volta a andar")

	# Volta os 2 tiles até (0,0) — o waypoint seguinte da rota.
	npc._tick_patrol_move(); npc._on_move_complete()
	npc._tick_patrol_move(); npc._on_move_complete()
	_assert(npc.grid_pos == Vector2i(0, 0), "andou de volta pro 2º waypoint (0,0)")
	npc._tick_patrol_move()
	_assert(npc.state == npc.State.PATROL_WAIT, "espera de novo ao chegar")

	# Fecha o loop: depois do último waypoint da lista, volta pro PRIMEIRO.
	npc._tick_patrol_wait(1.0)
	npc._tick_patrol_move(); npc._on_move_complete()
	_assert(npc.grid_pos == Vector2i(1, 0), "reinicia o loop rumo ao 1º waypoint de novo (não para no final da lista)")

	# Falar com o NPC no meio da patrulha pausa em DIALOG (herda comportamento
	# de sempre) e, ao terminar, retoma a patrulha em vez de ficar parado —
	# achado que teria sido regressão fácil de introduzir sem este teste.
	npc._set_state(npc.State.IDLE)  # estado inicial neutro pra não depender do timing acima
	npc.start_dialog(null)
	_assert(npc.state == npc.State.DIALOG, "conversar interrompe a patrulha")
	npc._on_dialog_ended()
	_assert(npc.state == npc.State.PATROL_MOVE, "depois do diálogo, retoma a patrulha (não fica parado pra sempre)")

	# Sem rota (o padrão de hoje pra quem não é treinador de rota): fica parado.
	var parado : NpcEntity = cena.instantiate()
	var rota_vazia : Array[Vector2i] = []
	parado.patrol_route = rota_vazia
	root.add_child(parado)
	_assert(parado.state == parado.State.IDLE, "sem patrol_route, continua parado — comportamento de hoje intacto")

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

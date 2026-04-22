## ChunkStreamManager.gd — Carrega/descarrega chunks 32×32 baseado na posição do player.
## Kanto = ~16×12 chunks = 192 total. Apenas ~25 ficam em memória por vez.
extends Node

# ──────────────────────────────────────────────────────────────────────────────
# Constantes
# ──────────────────────────────────────────────────────────────────────────────
const CHUNK_SIZE      : int = 32   # tiles por chunk (largura e altura)
const LOAD_RADIUS     : int = 5    # chunks ao redor do player para carregar
const UNLOAD_RADIUS   : int = 8    # chunks além deste raio são descarregados

# Dimensões do mundo Kanto em chunks
const WORLD_CHUNKS_X  : int = 16
const WORLD_CHUNKS_Y  : int = 12

# ──────────────────────────────────────────────────────────────────────────────
# Estado
# ──────────────────────────────────────────────────────────────────────────────
## Chunks ativos: chave = Vector2i(chunk_x, chunk_y), valor = dados do chunk
var active_chunks : Dictionary = {}

## Chunk em que o player estava no último frame (evita reprocessar desnecessário)
var _last_player_chunk : Vector2i = Vector2i(-999, -999)

## Referência ao player (injetada pelo KantoWorld ou WorldManager)
var _player : Node2D = null

# ──────────────────────────────────────────────────────────────────────────────
# Sinais
# ──────────────────────────────────────────────────────────────────────────────
signal chunk_loaded(coord: Vector2i)
signal chunk_unloaded(coord: Vector2i)

# ──────────────────────────────────────────────────────────────────────────────
# Ciclo de vida
# ──────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	set_process(true)

func _process(_delta: float) -> void:
	if not _player:
		_player = _find_player()
		if not _player:
			return

	var tile_pos  : Vector2i = _world_to_tile(_player.global_position)
	var chunk_pos : Vector2i = world_pos_to_chunk(tile_pos)

	# Só recalcula se o chunk mudou
	if chunk_pos == _last_player_chunk:
		return

	_last_player_chunk = chunk_pos
	_update_chunks(chunk_pos)

# ──────────────────────────────────────────────────────────────────────────────
# API pública
# ──────────────────────────────────────────────────────────────────────────────
## Converte posição em tile para coordenada de chunk.
func world_pos_to_chunk(tile_pos: Vector2i) -> Vector2i:
	return Vector2i(
		tile_pos.x / CHUNK_SIZE,
		tile_pos.y / CHUNK_SIZE
	)

## Injeta referência ao player externamente.
func set_player(p: Node2D) -> void:
	_player = p

## Retorna se um chunk está ativo em memória.
func is_chunk_active(coord: Vector2i) -> bool:
	return active_chunks.has(coord)

## Retorna o rect em tiles de um chunk.
func get_chunk_rect(coord: Vector2i) -> Rect2i:
	return Rect2i(
		coord.x * CHUNK_SIZE,
		coord.y * CHUNK_SIZE,
		CHUNK_SIZE,
		CHUNK_SIZE
	)

# ──────────────────────────────────────────────────────────────────────────────
# Lógica interna
# ──────────────────────────────────────────────────────────────────────────────
## Determina quais chunks devem estar ativos e carrega/descarrega conforme necessário.
func _update_chunks(center: Vector2i) -> void:
	# Conjunto de chunks que devem ficar ativos
	var desired : Dictionary = {}
	for dy in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var coord := Vector2i(center.x + dx, center.y + dy)
			# Garante que está dentro dos limites do mapa
			if _is_valid_chunk(coord):
				desired[coord] = true

	# Carrega novos chunks
	for coord in desired:
		if not active_chunks.has(coord):
			_load_chunk(coord)

	# Descarrega chunks muito distantes
	var to_unload : Array = []
	for coord in active_chunks:
		var dist : int = _chebyshev_distance(coord, center)
		if dist > UNLOAD_RADIUS:
			to_unload.append(coord)

	for coord in to_unload:
		_unload_chunk(coord)

## Carrega dados de um chunk na memória.
func _load_chunk(coord: Vector2i) -> void:
	var chunk_data : Dictionary = {
		"coord"     : coord,
		"rect"      : get_chunk_rect(coord),
		"loaded_at" : Time.get_ticks_msec()
	}
	active_chunks[coord] = chunk_data
	chunk_loaded.emit(coord)

## Descarrega um chunk da memória.
func _unload_chunk(coord: Vector2i) -> void:
	if not active_chunks.has(coord):
		return
	active_chunks.erase(coord)
	chunk_unloaded.emit(coord)

## Verifica se coordenada de chunk está dentro do mundo Kanto.
func _is_valid_chunk(coord: Vector2i) -> bool:
	return (
		coord.x >= 0 and coord.x < WORLD_CHUNKS_X and
		coord.y >= 0 and coord.y < WORLD_CHUNKS_Y
	)

## Distância de Chebyshev (máximo entre abs(dx) e abs(dy)).
func _chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

## Converte posição global (pixels) para posição em tile (assumindo tile 16×16).
func _world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x) / 16, int(world_pos.y) / 16)

## Tenta encontrar o player na cena via WorldManager ou grupo.
func _find_player() -> Node2D:
	# Tenta via WorldManager (autoload)
	if Engine.has_singleton("WorldManager"):
		var wm = Engine.get_singleton("WorldManager")
		if wm and wm.player:
			return wm.player
	# Fallback: grupo "player"
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null

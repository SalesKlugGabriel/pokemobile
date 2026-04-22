## BaseEntity.gd — CharacterBody2D base para Trainer, NPC e Pokémon selvagem.
## Gerencia: movimento tile-a-tile, sprite direcionado, interação por colisão, estado FSM.
## Nunca instanciar diretamente — use subclasses (TrainerEntity, PokemonEntity, NpcEntity).
class_name BaseEntity
extends CharacterBody2D

# --- Constantes ---
const TILE_SIZE      : int   = 16     # pixels por tile
const MOVE_DURATION  : float = 0.18   # segundos para cruzar 1 tile (caminhada)
const RUN_DURATION   : float = 0.09   # segundos para cruzar 1 tile (corrida)

# --- Direções ---
enum Direction { DOWN = 0, LEFT = 1, RIGHT = 2, UP = 3 }

# --- Estado do movimento ---
var facing      : Direction = Direction.DOWN
var is_moving   : bool      = false
var is_running  : bool      = false

# --- Posição no grid (em tiles) ---
var grid_pos    : Vector2i  = Vector2i.ZERO

# --- Componentes ---
@onready var sprite    : AnimatedSprite2D = $Sprite
@onready var collision : CollisionShape2D = $CollisionShape2D

# --- Sinal emitido quando o movimento termina ---
signal move_finished
signal interaction_triggered(entity: BaseEntity)

# ──────────────────────────────────────────────────────────────────────────────
# Inicialização
# ──────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_sync_position_to_grid()
	_update_sprite_facing()
	_on_ready()

## Hook para subclasses sem necessidade de chamar super
func _on_ready() -> void:
	pass

# ──────────────────────────────────────────────────────────────────────────────
# Movimento tile-a-tile
# ──────────────────────────────────────────────────────────────────────────────

## Tenta mover a entidade 1 tile na direção dada.
## Retorna true se o movimento foi iniciado.
func try_move(dir: Direction) -> bool:
	if is_moving:
		return false
	facing = dir
	_update_sprite_facing()

	var target_grid := grid_pos + _dir_to_vec(dir)
	if not _can_move_to(target_grid):
		# Ficou parado mas mudou de direção — anima idle
		_play_anim("idle")
		return false

	grid_pos = target_grid
	is_moving = true
	_play_anim("walk")

	var target_world := _grid_to_world(grid_pos)
	var duration     := RUN_DURATION if is_running else MOVE_DURATION
	var tween        := create_tween()
	tween.tween_property(self, "position", target_world, duration)
	tween.tween_callback(_on_move_complete)
	return true

func _on_move_complete() -> void:
	is_moving = false
	_play_anim("idle")
	move_finished.emit()
	_on_tile_entered(grid_pos)

## Hook chamado toda vez que a entidade chega a um novo tile
func _on_tile_entered(_tile: Vector2i) -> void:
	pass

# ──────────────────────────────────────────────────────────────────────────────
# Verificação de colisão no grid
# ──────────────────────────────────────────────────────────────────────────────

func _can_move_to(target: Vector2i) -> bool:
	# Posição mundo do centro do tile alvo
	var world_target := _grid_to_world(target)
	# Checar via move_and_collide em vez de raycasting para simplificar
	# — subclasses podem sobrescrever com verificação no TileMap
	return _is_tile_walkable(target)

## Consulta o WorldManager para verificar walkability do tile.
## Permissivo se WorldManager ainda não tiver tilemap registrado.
func _is_tile_walkable(tile: Vector2i) -> bool:
	return WorldManager.is_tile_walkable(tile)

# ──────────────────────────────────────────────────────────────────────────────
# Interação
# ──────────────────────────────────────────────────────────────────────────────

## Chama interação com a entidade à frente
func interact() -> void:
	var target_tile := grid_pos + _dir_to_vec(facing)
	var entity      := _find_entity_at(target_tile)
	if entity:
		interaction_triggered.emit(entity)
		_on_interact_with(entity)

func _on_interact_with(_entity: BaseEntity) -> void:
	pass

func _find_entity_at(tile: Vector2i) -> BaseEntity:
	var world_pos := _grid_to_world(tile)
	# Usa overlap para detectar entidades no tile alvo
	var space     := get_world_2d().direct_space_state
	var params    := PhysicsPointQueryParameters2D.new()
	params.position      = world_pos
	params.collision_mask = collision_layer
	params.exclude        = [get_rid()]
	var results := space.intersect_point(params, 4)
	for r in results:
		var body = r.get("collider")
		if body is BaseEntity:
			return body
	return null

# ──────────────────────────────────────────────────────────────────────────────
# Animações
# ──────────────────────────────────────────────────────────────────────────────

func _update_sprite_facing() -> void:
	if not sprite:
		return
	match facing:
		Direction.DOWN:  sprite.flip_h = false; _play_anim("idle_down")
		Direction.UP:    sprite.flip_h = false; _play_anim("idle_up")
		Direction.LEFT:  sprite.flip_h = false; _play_anim("idle_left")
		Direction.RIGHT: sprite.flip_h = false; _play_anim("idle_right")

func _play_anim(anim: String) -> void:
	if not sprite or not sprite.sprite_frames:
		return
	var dir_suffix := _dir_suffix()
	var full_name  := anim + "_" + dir_suffix if sprite.sprite_frames.has_animation(anim + "_" + dir_suffix) else anim
	if sprite.animation != full_name:
		sprite.play(full_name)

func _dir_suffix() -> String:
	match facing:
		Direction.DOWN:  return "down"
		Direction.UP:    return "up"
		Direction.LEFT:  return "left"
		Direction.RIGHT: return "right"
	return "down"

# ──────────────────────────────────────────────────────────────────────────────
# Utilitários de grid
# ──────────────────────────────────────────────────────────────────────────────

func _dir_to_vec(dir: Direction) -> Vector2i:
	match dir:
		Direction.DOWN:  return Vector2i(0, 1)
		Direction.UP:    return Vector2i(0, -1)
		Direction.LEFT:  return Vector2i(-1, 0)
		Direction.RIGHT: return Vector2i(1, 0)
	return Vector2i.ZERO

func _grid_to_world(tile: Vector2i) -> Vector2:
	return Vector2(tile) * TILE_SIZE + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)

func _world_to_grid(world: Vector2) -> Vector2i:
	return Vector2i(world / TILE_SIZE)

func _sync_position_to_grid() -> void:
	grid_pos = _world_to_grid(position)
	position  = _grid_to_world(grid_pos)

# ──────────────────────────────────────────────────────────────────────────────
# Utilitários públicos
# ──────────────────────────────────────────────────────────────────────────────

func set_grid_position(tile: Vector2i) -> void:
	grid_pos = tile
	position  = _grid_to_world(tile)

func face_toward(target_tile: Vector2i) -> void:
	var delta := target_tile - grid_pos
	if abs(delta.x) >= abs(delta.y):
		facing = Direction.RIGHT if delta.x > 0 else Direction.LEFT
	else:
		facing = Direction.DOWN if delta.y > 0 else Direction.UP
	_update_sprite_facing()

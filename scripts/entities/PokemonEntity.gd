## PokemonEntity.gd — Pokémon selvagem no overworld.
## FSM: IDLE → WANDER → FLEE → CHASE
## Quando o jogador entra na zona de detecção: CHASE → inicia batalha.
## Quando o jogador corre/escapa: FLEE por alguns tiles depois volta a WANDER.
class_name PokemonEntity
extends BaseEntity

# ──────────────────────────────────────────────────────────────────────────────
# Configuração via Inspector (ou código ao spawnar)
# ──────────────────────────────────────────────────────────────────────────────
@export var species_id   : int   = 1        # ID em species.json
@export var level        : int   = 5
@export var is_shiny     : bool  = false

@export var wander_radius : int   = 3       # tiles de raio a partir do spawn
@export var sight_range   : int   = 4       # tiles de visão para CHASE
@export var flee_range    : int   = 5       # tiles de visão para FLEE (medo do jogador)
@export var wander_interval : float = 2.5   # segundos entre passos de WANDER

# ──────────────────────────────────────────────────────────────────────────────
# FSM
# ──────────────────────────────────────────────────────────────────────────────
enum State { IDLE, WANDER, FLEE, CHASE, BATTLE }

var state         : State     = State.IDLE
var spawn_tile    : Vector2i  = Vector2i.ZERO
var _wander_timer : float     = 0.0
var _flee_steps   : int       = 0

# Referência ao jogador (injetada pelo WorldManager ou buscada no grupo)
var player        : BaseEntity = null

# Dados carregados do GameData
var species_data  : Dictionary = {}

# ──────────────────────────────────────────────────────────────────────────────
# Inicialização
# ──────────────────────────────────────────────────────────────────────────────
func _on_ready() -> void:
	add_to_group("pokemon_entities")
	spawn_tile   = grid_pos
	species_data = GameData.get_species(species_id)
	_wander_timer = randf_range(0.5, wander_interval)
	_load_sprites()
	_set_state(State.WANDER)

func _load_sprites() -> void:
	if sprite and not sprite.sprite_frames:
		sprite.sprite_frames = SpriteBuilder.build_pokemon_frames(species_id)
		sprite.play("idle")
		sprite.scale = Vector2(2.0, 2.0)

# ──────────────────────────────────────────────────────────────────────────────
# Loop principal
# ──────────────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if state == State.BATTLE:
		return

	_detect_player()

	match state:
		State.IDLE:
			_tick_idle(delta)
		State.WANDER:
			_tick_wander(delta)
		State.FLEE:
			_tick_flee(delta)
		State.CHASE:
			_tick_chase(delta)

# ──────────────────────────────────────────────────────────────────────────────
# Detecção do jogador
# ──────────────────────────────────────────────────────────────────────────────
func _detect_player() -> void:
	if not player:
		_find_player()
	if not player:
		return

	var dist := _tile_distance(grid_pos, player.grid_pos)

	match state:
		State.IDLE, State.WANDER:
			if dist <= sight_range:
				_set_state(State.CHASE)
		State.CHASE:
			if dist > sight_range + 2:
				_set_state(State.WANDER)
			elif _is_adjacent(grid_pos, player.grid_pos):
				_trigger_battle()
		State.FLEE:
			pass  # flee se resolve pelos passos

func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

# ──────────────────────────────────────────────────────────────────────────────
# Estados
# ──────────────────────────────────────────────────────────────────────────────
func _tick_idle(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_set_state(State.WANDER)

func _tick_wander(delta: float) -> void:
	if is_moving:
		return
	_wander_timer -= delta
	if _wander_timer > 0.0:
		return
	_wander_timer = randf_range(wander_interval * 0.6, wander_interval * 1.4)

	# Escolhe direção aleatória que mantém dentro do raio do spawn
	var dirs := [Direction.UP, Direction.DOWN, Direction.LEFT, Direction.RIGHT]
	RNGManager.shuffle(dirs)
	for d in dirs:
		var next := grid_pos + _dir_to_vec(d)
		if _within_spawn_radius(next):
			try_move(d)
			break

func _tick_flee(delta: float) -> void:
	if is_moving or _flee_steps <= 0:
		if _flee_steps <= 0:
			_set_state(State.WANDER)
		return
	if not player:
		_set_state(State.WANDER)
		return

	# Move no sentido oposto ao jogador
	var away := _direction_away_from(player.grid_pos)
	if away != null and try_move(away):
		_flee_steps -= 1

func _tick_chase(delta: float) -> void:
	if is_moving or not player:
		return
	var toward := _direction_toward(player.grid_pos)
	if toward != null:
		try_move(toward)

# ──────────────────────────────────────────────────────────────────────────────
# Transições
# ──────────────────────────────────────────────────────────────────────────────
func _set_state(new_state: State) -> void:
	state = new_state
	match new_state:
		State.IDLE:
			_wander_timer = randf_range(1.0, 3.0)
			_play_anim("idle")
		State.WANDER:
			_wander_timer = randf_range(0.3, wander_interval)
		State.FLEE:
			_flee_steps   = flee_range
			is_running    = true
		State.CHASE:
			is_running    = true
		State.BATTLE:
			is_running    = false

func start_flee() -> void:
	_set_state(State.FLEE)

func _trigger_battle() -> void:
	_set_state(State.BATTLE)
	EventBus.wild_encounter_started.emit(self)

# ──────────────────────────────────────────────────────────────────────────────
# Getters de dados
# ──────────────────────────────────────────────────────────────────────────────
func get_species_name() -> String:
	return species_data.get("name", "???")

func get_base_stats() -> Dictionary:
	return species_data.get("base_stats", {})

# ──────────────────────────────────────────────────────────────────────────────
# Utilitários internos
# ──────────────────────────────────────────────────────────────────────────────
func _within_spawn_radius(tile: Vector2i) -> bool:
	return _tile_distance(tile, spawn_tile) <= wander_radius

func _tile_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)  # Manhattan

func _is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return _tile_distance(a, b) == 1

func _direction_toward(target: Vector2i) -> Direction:
	var delta := target - grid_pos
	if abs(delta.x) >= abs(delta.y):
		return Direction.RIGHT if delta.x > 0 else Direction.LEFT
	else:
		return Direction.DOWN if delta.y > 0 else Direction.UP

func _direction_away_from(target: Vector2i) -> Direction:
	var toward := _direction_toward(target)
	match toward:
		Direction.UP:    return Direction.DOWN
		Direction.DOWN:  return Direction.UP
		Direction.LEFT:  return Direction.RIGHT
		Direction.RIGHT: return Direction.LEFT
	return Direction.DOWN

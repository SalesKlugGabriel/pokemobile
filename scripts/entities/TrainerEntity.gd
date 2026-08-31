## TrainerEntity.gd — Entidade controlada pelo jogador.
## Movimento contínuo por pixel (move_and_slide), velocidade base 180 px/s.
## Mantém grid_pos para ZoneManager e emite player_tile_entered por tile.
class_name TrainerEntity
extends CharacterBody2D

# ──────────────────────────────────────────────────────────────────────────────
# Constantes
# ──────────────────────────────────────────────────────────────────────────────
const TILE_SIZE    : int   = 16
const WALK_SPEED   : float = 180.0
const RUN_SPEED    : float = 360.0
const INTERACT_REACH : float = 20.0   # px na direção do facing para interação

const FOLLOWER_SCENE : PackedScene = preload("res://scenes/entities/FollowerPokemon.tscn")

# ──────────────────────────────────────────────────────────────────────────────
# Nodes
# ──────────────────────────────────────────────────────────────────────────────
@onready var sprite : AnimatedSprite2D = $Sprite

# ──────────────────────────────────────────────────────────────────────────────
# Estado
# ──────────────────────────────────────────────────────────────────────────────
var grid_pos        : Vector2i = Vector2i.ZERO
var _last_grid_pos  : Vector2i = Vector2i(-9999, -9999)
var facing          : Vector2  = Vector2.DOWN
var is_running      : bool     = false
var _input_locked   : bool     = false

# Follower Pokémon (FollowerPokemon.gd — pixel-based)
var follower : Node2D = null

# Trail de posições para o follower (pixel + direção)
var _trail          : Array[Dictionary] = []
const TRAIL_MAX     : int = 120   # ~2/3 s a 60fps de buffer

# ──────────────────────────────────────────────────────────────────────────────
# Sinal de interação
# ──────────────────────────────────────────────────────────────────────────────
signal interaction_triggered(entity: Node)

# ──────────────────────────────────────────────────────────────────────────────
# Inicialização
# ──────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("player")
	EventBus.dialog_started.connect(_on_dialog_started)
	EventBus.dialog_ended.connect(_on_dialog_ended)
	EventBus.dialogue_ended.connect(_on_dialog_ended)
	EventBus.battle_started.connect(_on_battle_started)
	EventBus.battle_ended.connect(_on_battle_ended)
	_load_sprites()
	grid_pos       = _world_to_grid(position)
	_last_grid_pos = grid_pos
	call_deferred("_spawn_follower")

func _load_sprites() -> void:
	if sprite and not sprite.sprite_frames:
		sprite.sprite_frames = SpriteBuilder.build_entity_frames(
			"res://assets/sprites/player/player.png"
		)
		sprite.play("idle_down")

## Coloca o Pokémon líder da equipe pra andar atrás do jogador no mapa.
## Não aparece se a equipe está vazia ou se o líder desmaiou (hp_current <= 0).
func _spawn_follower() -> void:
	if not SaveManager.has_save():
		return
	var lead : Dictionary = SaveManager.get_pokemon_at(0)
	if lead.is_empty():
		return
	if int(lead.get("hp_current", 0)) <= 0:
		return

	var f : Node2D = FOLLOWER_SCENE.instantiate()
	f.pokemon_species_id = int(lead.get("species_id", 1))
	f.pokemon_level      = int(lead.get("level", 5))
	get_parent().add_child(f)
	f.global_position = global_position
	f.set_trainer(self)
	set_follower(f)

# ──────────────────────────────────────────────────────────────────────────────
# Física / Movimento
# ──────────────────────────────────────────────────────────────────────────────
func _physics_process(_delta: float) -> void:
	if _input_locked:
		velocity = Vector2.ZERO
		_update_idle_anim()
		return

	var dir := _read_direction()
	is_running = Input.is_action_pressed("run")

	if dir != Vector2.ZERO:
		facing   = dir
		var speed := RUN_SPEED if is_running else WALK_SPEED
		velocity = dir * speed
		_play_walk_anim()
	else:
		velocity = Vector2.ZERO
		_update_idle_anim()

	move_and_slide()
	_record_trail()
	_check_tile_change()

	if Input.is_action_just_pressed("interact"):
		_try_interact()

func _read_direction() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_action_pressed("move_up"):    v.y -= 1
	if Input.is_action_pressed("move_down"):  v.y += 1
	if Input.is_action_pressed("move_left"):  v.x -= 1
	if Input.is_action_pressed("move_right"): v.x += 1
	return v.normalized()

# ──────────────────────────────────────────────────────────────────────────────
# Detecção de mudança de tile
# ──────────────────────────────────────────────────────────────────────────────
func _check_tile_change() -> void:
	grid_pos = _world_to_grid(position)
	if grid_pos != _last_grid_pos:
		_last_grid_pos = grid_pos
		EventBus.player_tile_entered.emit(grid_pos)

# ──────────────────────────────────────────────────────────────────────────────
# Trail para FollowerPokemon
# ──────────────────────────────────────────────────────────────────────────────
func _record_trail() -> void:
	_trail.append({ "pos": position, "facing": facing })
	if _trail.size() > TRAIL_MAX:
		_trail.pop_front()
	_update_follower()

func _update_follower() -> void:
	if not follower or not follower.has_method("set_target_position"):
		return
	# Pega a posição a FollowerPokemon.FOLLOW_DISTANCE px atrás no histórico — mesma constante
	# usada pelo follower pra manter repouso, senão os dois número dessincronizam e a
	# distância real de caminhada volta a ficar menor que o repouso.
	var follow_frames : int = int(FollowerPokemon.FOLLOW_DISTANCE / (WALK_SPEED / 60.0))
	follow_frames = clampi(follow_frames, 1, _trail.size())
	var entry := _trail[_trail.size() - follow_frames]
	follower.set_target_position(entry["pos"])

# ──────────────────────────────────────────────────────────────────────────────
# Follower management
# ──────────────────────────────────────────────────────────────────────────────
func set_follower(f: Node2D) -> void:
	follower = f
	_trail.clear()

func clear_follower() -> void:
	follower = null

# ──────────────────────────────────────────────────────────────────────────────
# Interação
# ──────────────────────────────────────────────────────────────────────────────
func _try_interact() -> void:
	var query_pos := position + facing * INTERACT_REACH
	var space := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position         = query_pos
	params.collision_mask   = 4   # layer NPC/Pokémon
	params.exclude          = [get_rid()]
	var hits := space.intersect_point(params, 4)
	for hit in hits:
		var col = hit.get("collider")
		if col and col != self:
			interaction_triggered.emit(col)
			return

# ──────────────────────────────────────────────────────────────────────────────
# Animação
# ──────────────────────────────────────────────────────────────────────────────
func _play_walk_anim() -> void:
	if not sprite or not sprite.sprite_frames:
		return
	var suffix := _facing_suffix()
	var anim   := "walk_" + suffix
	if not sprite.sprite_frames.has_animation(anim):
		anim = "walk"
	if sprite.animation != anim:
		sprite.play(anim)

func _update_idle_anim() -> void:
	if not sprite or not sprite.sprite_frames:
		return
	var anim := "idle_" + _facing_suffix()
	if not sprite.sprite_frames.has_animation(anim):
		anim = "idle"
	if sprite.animation != anim:
		sprite.play(anim)

func _facing_suffix() -> String:
	if abs(facing.x) >= abs(facing.y):
		return "right" if facing.x > 0 else "left"
	return "down" if facing.y > 0 else "up"

# ──────────────────────────────────────────────────────────────────────────────
# API pública de posição
# ──────────────────────────────────────────────────────────────────────────────
func set_grid_position(tile: Vector2i) -> void:
	grid_pos       = tile
	_last_grid_pos = tile
	position       = _grid_to_world(tile)

func _grid_to_world(tile: Vector2i) -> Vector2:
	return Vector2(tile) * TILE_SIZE + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)

func _world_to_grid(world: Vector2) -> Vector2i:
	return Vector2i(int(world.x) / TILE_SIZE, int(world.y) / TILE_SIZE)

# ──────────────────────────────────────────────────────────────────────────────
# Lock de input via EventBus
# ──────────────────────────────────────────────────────────────────────────────
func lock_input() -> void:
	_input_locked = true

func unlock_input() -> void:
	_input_locked = false

func _on_dialog_started(_npc) -> void:
	lock_input()

func _on_dialog_ended() -> void:
	unlock_input()

func _on_battle_started() -> void:
	lock_input()

func _on_battle_ended(_result) -> void:
	unlock_input()

# ──────────────────────────────────────────────────────────────────────────────
# Compatibilidade com WorldManager (move_finished signal)
# ──────────────────────────────────────────────────────────────────────────────
signal move_finished()

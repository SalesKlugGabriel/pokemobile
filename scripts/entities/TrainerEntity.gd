## TrainerEntity.gd — Entidade controlada pelo jogador.
## Movimento tile-a-tile (estilo Poketibia): herda de BaseEntity e usa o mesmo
## try_move()/WorldManager.is_tile_walkable() que já bloqueia NPCs em árvore/parede/água —
## antes o jogador tinha seu próprio movimento contínuo em pixel, sem checar o mapa,
## por isso atravessava tudo. Segurar uma tecla agora "empurra" um tile por vez.
class_name TrainerEntity
extends BaseEntity

# ──────────────────────────────────────────────────────────────────────────────
# Constantes
# ──────────────────────────────────────────────────────────────────────────────
const FOLLOWER_SCENE : PackedScene = preload("res://scenes/entities/FollowerPokemon.tscn")

# ──────────────────────────────────────────────────────────────────────────────
# Estado
# ──────────────────────────────────────────────────────────────────────────────
var _input_locked   : bool     = false

# Follower Pokémon (FollowerPokemon.gd — continua em pixel, persegue um rastro)
var follower : Node2D = null

# Trail de posições para o follower (pixel + direção)
var _trail          : Array[Dictionary] = []
const TRAIL_MAX     : int = 120   # ~2s a 60fps de buffer

# ──────────────────────────────────────────────────────────────────────────────
# Inicialização
# ──────────────────────────────────────────────────────────────────────────────
func _on_ready() -> void:
	add_to_group("player")
	EventBus.dialog_started.connect(_on_dialog_started)
	EventBus.dialog_ended.connect(_on_dialog_ended)
	EventBus.dialogue_ended.connect(_on_dialog_ended)
	EventBus.battle_started.connect(_on_battle_started)
	EventBus.battle_ended.connect(_on_battle_ended)
	_load_sprites()
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
# Movimento (tile-a-tile, herdado de BaseEntity.try_move)
# ──────────────────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	_record_trail()

	if _input_locked:
		return

	var dir := _read_direction()
	if dir != -1:
		is_running = Input.is_action_pressed("run")
		try_move(dir)

	if Input.is_action_just_pressed("interact"):
		interact()

## Prioridade fixa quando mais de uma tecla está pressionada (sem diagonal —
## o grid e os sprites do jogo são só 4 direções, igual Poketibia clássico).
func _read_direction() -> int:
	if Input.is_action_pressed("move_down"):  return Direction.DOWN
	if Input.is_action_pressed("move_up"):    return Direction.UP
	if Input.is_action_pressed("move_left"):  return Direction.LEFT
	if Input.is_action_pressed("move_right"): return Direction.RIGHT
	return -1

func _on_tile_entered(tile: Vector2i) -> void:
	EventBus.player_tile_entered.emit(tile)

## Usado pelo FollowerPokemon como direção de repouso quando ainda não há rastro.
func get_facing_vector() -> Vector2:
	return _dir_to_vec(facing)

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
	# Velocidade efetiva do tween de tile: TILE_SIZE px em MOVE_DURATION (ou RUN_DURATION) s.
	var duration : float = RUN_DURATION if is_running else MOVE_DURATION
	var speed_px_s : float = TILE_SIZE / duration
	var follow_frames : int = int(FollowerPokemon.FOLLOW_DISTANCE / (speed_px_s / 60.0))
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

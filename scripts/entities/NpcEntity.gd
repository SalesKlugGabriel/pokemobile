## NpcEntity.gd — NPC com rota de patrulha e trigger de diálogo.
## Suporta: patrulha por lista de waypoints, idle fixo, face ao interagir.
class_name NpcEntity
extends BaseEntity

# ──────────────────────────────────────────────────────────────────────────────
# Configuração via Inspector
# ──────────────────────────────────────────────────────────────────────────────

## Nome exibido na caixa de diálogo (vazio = sem label de nome)
@export var npc_name       : String = ""

## ID do diálogo em dialogs.json (Sprint 3)
@export var dialog_id      : String = ""

## Se true, cura o time completo ao encerrar o diálogo (Enfermeira Joy)
@export var heal_on_dialog_end : bool = false

## Se true, inicia batalha de treinador após o diálogo
@export var is_trainer     : bool = false

## Time do treinador: Array de {species_id, level}. Usado quando is_trainer=true.
@export var trainer_team   : Array[Dictionary] = []

## Se true, já foi derrotado (não ataca de novo)
var trainer_defeated       : bool = false

## Lista de tiles de waypoint para patrulha.
## Vazio = NPC fica parado no spawn.
@export var patrol_route   : Array[Vector2i] = []

## Intervalo de espera ao chegar em cada waypoint
@export var wait_at_waypoint : float = 1.5

## Velocidade de patrulha (usa MOVE_DURATION do BaseEntity)
@export var is_patrolling  : bool = true

# ──────────────────────────────────────────────────────────────────────────────
# Estado interno
# ──────────────────────────────────────────────────────────────────────────────
enum State { IDLE, PATROL_MOVE, PATROL_WAIT, DIALOG }

var state             : State = State.IDLE
var _patrol_index     : int   = 0
var _wait_timer       : float = 0.0
var _interacted_by    : TrainerEntity = null

# ──────────────────────────────────────────────────────────────────────────────
# Inicialização
# ──────────────────────────────────────────────────────────────────────────────
func _on_ready() -> void:
	add_to_group("npc_entities")
	EventBus.dialog_ended.connect(_on_dialog_ended)
	_load_sprites()

	if patrol_route.is_empty() or not is_patrolling:
		_set_state(State.IDLE)
	else:
		_set_state(State.PATROL_MOVE)

func _load_sprites() -> void:
	if not sprite or sprite.sprite_frames:
		return
	# Prof. Carvalho tem sprite próprio; Enfermeira Joy também
	var tex_path : String
	match npc_name:
		"Prof. Carvalho":
			tex_path = "res://assets/sprites/npc/npc_oak.png"
		"Enfermeira Joy":
			tex_path = "res://assets/sprites/npc/npc_nurse.png"
		_:
			tex_path = "res://assets/sprites/npc/npc_default.png"
	sprite.sprite_frames = SpriteBuilder.build_entity_frames(tex_path)
	sprite.play("idle_down")

# ──────────────────────────────────────────────────────────────────────────────
# Loop principal
# ──────────────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	match state:
		State.PATROL_MOVE:
			_tick_patrol_move()
		State.PATROL_WAIT:
			_tick_patrol_wait(delta)
		State.IDLE, State.DIALOG:
			pass

# ──────────────────────────────────────────────────────────────────────────────
# Patrulha
# ──────────────────────────────────────────────────────────────────────────────
func _tick_patrol_move() -> void:
	if is_moving or patrol_route.is_empty():
		return

	var target := patrol_route[_patrol_index]
	if grid_pos == target:
		_set_state(State.PATROL_WAIT)
		return

	var dir : Variant = _direction_toward(target)
	if dir != null:
		try_move(dir)

func _tick_patrol_wait(delta: float) -> void:
	_wait_timer -= delta
	if _wait_timer <= 0.0:
		_patrol_index = (_patrol_index + 1) % patrol_route.size()
		_set_state(State.PATROL_MOVE)

func _set_state(new_state: State) -> void:
	state = new_state
	match new_state:
		State.IDLE:
			_play_anim("idle")
		State.PATROL_MOVE:
			pass  # animação gerenciada pelo try_move
		State.PATROL_WAIT:
			_wait_timer = wait_at_waypoint
			_play_anim("idle")
		State.DIALOG:
			_play_anim("idle")

# ──────────────────────────────────────────────────────────────────────────────
# Interação (chamada pelo BaseEntity via interact())
# ──────────────────────────────────────────────────────────────────────────────
func _on_interact_with(_entity: BaseEntity) -> void:
	pass  # NPC não inicia interação — aguarda ser interagido

## Chamado quando o jogador aperta interagir estando adjacente a este NPC.
## O TrainerEntity chama interact() que emite interaction_triggered(self) →
## WorldManager conecta ao método abaixo.
func start_dialog(initiator: TrainerEntity) -> void:
	if state == State.DIALOG:
		return
	_interacted_by = initiator
	_set_state(State.DIALOG)

	# Vira para o jogador
	if initiator:
		face_toward(initiator.grid_pos)

	EventBus.dialog_started.emit(self)
	EventBus.npc_dialog_requested.emit(self, dialog_id)

func _on_dialog_ended() -> void:
	if state != State.DIALOG:
		return
	if heal_on_dialog_end:
		SaveManager.heal_team()
		AudioManager.play_sfx("heal")
		EventBus.pokemon_center_visited.emit(WorldManager.current_map_id)
	# Inicia batalha de treinador após o diálogo (se não foi derrotado ainda)
	if is_trainer and not trainer_defeated and not trainer_team.is_empty():
		BattleManager.start_trainer_battle(self)
		_interacted_by = null
		return  # permanece em estado DIALOG até a batalha terminar
	_interacted_by = null
	if patrol_route.is_empty() or not is_patrolling:
		_set_state(State.IDLE)
	else:
		_set_state(State.PATROL_MOVE)

# ──────────────────────────────────────────────────────────────────────────────
# Utilitários internos
# ──────────────────────────────────────────────────────────────────────────────
func _direction_toward(target: Vector2i) -> Variant:
	var delta := target - grid_pos
	if delta == Vector2i.ZERO:
		return null
	if abs(delta.x) >= abs(delta.y):
		return Direction.RIGHT if delta.x > 0 else Direction.LEFT
	else:
		return Direction.DOWN if delta.y > 0 else Direction.UP

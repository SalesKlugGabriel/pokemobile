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

## Se true, abre a Loja (comprar/vender) ao encerrar o diálogo (vendedor)
@export var opens_shop_on_dialog_end : bool = false

## Item dado de presente (1x só) ao fim do diálogo — vazio = não dá nada.
## Só dá se o jogador ainda não tem o item (evita repetir infinito conversando
## de novo; funciona pra item único tipo vara de pescar, não pra consumível).
@export var gift_item_id   : String = ""
@export var gift_quantity  : int    = 1

## ID de quest pra iniciar ao encerrar o diálogo (QuestManager.start_quest) —
## vazio = não inicia nada. start_quest() já ignora sozinho se a quest já
## estiver ativa/completa, então é seguro conversar de novo.
@export var starts_quest_id : String = ""

## Viagem condicionada a quest (Capitão do barco pra Cinnabar, 01/09) —
## vazio = NPC não leva a lugar nenhum. Se preenchido, exige essa quest
## completa (QuestManager.is_quest_complete) pra realmente viajar; antes
## disso usa o `dialog_id` normal, depois usa "<dialog_id>_liberado".
@export var requires_quest_for_travel : String = ""
@export var travel_target_map  : String   = ""
@export var travel_spawn_tile  : Vector2i = Vector2i.ZERO

## Se true, inicia batalha de treinador após o diálogo
@export var is_trainer     : bool = false

## Time do treinador: Array de {species_id, level}. Usado quando is_trainer=true.
@export var trainer_team   : Array[Dictionary] = []

## Se true, já foi derrotado (não ataca de novo)
var trainer_defeated       : bool = false

## Índice do próximo Pokémon do time a entrar em combate (Fase 7 do motor de
## combate em tempo real, 02/09) — batalha de treinador agora é uma
## SEQUÊNCIA de WildPokemon reais no mapa (is_trainer_owned=true), um de
## cada vez, igual jogo clássico, em vez de abrir BattleManager/BattleScene.
var _trainer_team_idx      : int  = 0
const TRAINER_POKEMON_SCENE : PackedScene = preload("res://scenes/entities/pokemon/WildPokemon.tscn")

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
	# Migração tile128 (03/09): arte reamostrada pra 128px nativos (igual ao
	# tile), não precisa mais da escala 2x que compensava a arte de 16px.
	sprite.scale = Vector2(1.0, 1.0)
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
	EventBus.npc_dialog_requested.emit(self, _effective_dialog_id())

## A Enfermeira Joy reage ao estado real do time: fala diferente se ninguém
## precisa de cura (evita a mesma fala "vou restaurar seus Pokémon" quando o
## time já está 100%). Um NPC com presente já dado também troca de fala
## (evita repetir "tome uma vara" pra sempre). Os outros usam o dialog_id fixo.
func _effective_dialog_id() -> String:
	if heal_on_dialog_end and dialog_id == "nurse_joy":
		for poke in SaveManager.get_team():
			if int(poke.get("hp_current", 1)) < int(poke.get("hp_max", 1)):
				return "nurse_joy"
		return "nurse_joy_healthy"
	if not gift_item_id.is_empty() and SaveManager.has_item(gift_item_id, 1):
		return dialog_id + "_depois"
	if not requires_quest_for_travel.is_empty() and QuestManager.is_quest_complete(requires_quest_for_travel):
		return dialog_id + "_liberado"
	return dialog_id

func _on_dialog_ended() -> void:
	if state != State.DIALOG:
		return
	if heal_on_dialog_end:
		SaveManager.heal_team()
		AudioManager.play_sfx("heal")
		EventBus.pokemon_center_visited.emit(WorldManager.current_map_id)
	if opens_shop_on_dialog_end:
		var pause_menu := get_tree().get_first_node_in_group("pause_menu")
		if pause_menu and pause_menu.has_method("open_shop_externally"):
			pause_menu.open_shop_externally()
	if not gift_item_id.is_empty() and not SaveManager.has_item(gift_item_id, 1):
		SaveManager.add_item(gift_item_id, gift_quantity)
		AudioManager.play_sfx("item_get")
	if not starts_quest_id.is_empty():
		QuestManager.start_quest(starts_quest_id)
	# Viagem (barco etc.) — só acontece se a quest exigida já estiver completa;
	# antes disso o diálogo normal já deixou claro que ainda não dá.
	if not requires_quest_for_travel.is_empty() and travel_target_map != "" \
	and QuestManager.is_quest_complete(requires_quest_for_travel):
		WorldManager.warp_to(travel_target_map, travel_spawn_tile)
		_interacted_by = null
		_set_state(State.IDLE)
		return
	# Inicia batalha de treinador após o diálogo (se não foi derrotado ainda)
	if is_trainer and not trainer_defeated and not trainer_team.is_empty():
		_start_trainer_battle()
		_interacted_by = null
		return  # permanece em estado DIALOG até o time inteiro ser derrotado
	_interacted_by = null
	if patrol_route.is_empty() or not is_patrolling:
		_set_state(State.IDLE)
	else:
		_set_state(State.PATROL_MOVE)

# ──────────────────────────────────────────────────────────────────────────────
# Batalha de treinador em tempo real (Fase 7, 02/09)
# ──────────────────────────────────────────────────────────────────────────────
func _start_trainer_battle() -> void:
	_trainer_team_idx = 0
	_spawn_next_trainer_pokemon()

## Coloca o próximo Pokémon do time do treinador no mapa como um WildPokemon
## de verdade (is_trainer_owned=true — mesma classe do selvagem comum, reusa
## toda a infraestrutura de combate/seleção/HP já pronta). Quando acaba o
## time, marca derrotado e volta a andar normal (mesmo efeito que
## BattleManager._return_to_world() já fazia pro caminho por turno).
func _spawn_next_trainer_pokemon() -> void:
	if _trainer_team_idx >= trainer_team.size():
		trainer_defeated = true
		_interacted_by = null
		if patrol_route.is_empty() or not is_patrolling:
			_set_state(State.IDLE)
		else:
			_set_state(State.PATROL_MOVE)
		return

	var entry : Dictionary = trainer_team[_trainer_team_idx]
	_trainer_team_idx += 1

	var poke : Node = TRAINER_POKEMON_SCENE.instantiate()
	poke.species_id       = int(entry.get("species_id", 16))
	poke.wild_level       = int(entry.get("level", 5))
	poke.is_trainer_owned = true
	poke.trainer_npc      = self
	# "neutral" (padrão de WildPokemon) só reage se atacado primeiro — um
	# treinador não pode ficar esperando o jogador tomar a iniciativa.
	poke.behavior         = "aggressive"
	get_parent().add_child(poke)
	poke.global_position = global_position + Vector2(0, -TILE_SIZE)

## Chamado por WildPokemon._die() quando o Pokémon atual deste treinador morre.
func _on_trainer_pokemon_defeated() -> void:
	_spawn_next_trainer_pokemon()

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

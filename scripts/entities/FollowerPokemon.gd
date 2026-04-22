## FollowerPokemon.gd — Pokémon Bodyguard que segue o Treinador e executa combate.
## Posicionamento: entre o Treinador e o WildPokémon mais próximo.
## Skills 1-4 ativadas por input; cada skill tem cooldown individual.
## Estende CharacterBody2D (movimento contínuo em px, não tile-a-tile).
class_name FollowerPokemon
extends CharacterBody2D

# ──────────────────────────────────────────────────────────────────────────────
# Exports
# ──────────────────────────────────────────────────────────────────────────────

@export var pokemon_species_id : int = 4
@export var pokemon_level      : int = 5

# ──────────────────────────────────────────────────────────────────────────────
# Constantes
# ──────────────────────────────────────────────────────────────────────────────

const FOLLOW_DISTANCE   : float = 24.0   # px — distância de repouso atrás do Treinador
const BODYGUARD_OFFSET  : float = 20.0   # px — distância do Treinador em direção ao inimigo
const MOVE_SPEED_BASE   : float = 120.0

# ──────────────────────────────────────────────────────────────────────────────
# Referências de cena
# ──────────────────────────────────────────────────────────────────────────────

@onready var sprite        : AnimatedSprite2D = $Sprite
@onready var hitbox        : Area2D           = $HitBox
@onready var hurtbox       : Area2D           = $HurtBox
@onready var skill_timers  : Array[Timer]     = []    # populado em _ready

# ──────────────────────────────────────────────────────────────────────────────
# Estado em tempo de execução
# ──────────────────────────────────────────────────────────────────────────────

## Dados calculados da espécie
var species_data   : Dictionary = {}
var current_hp     : int = 0
var max_hp         : int = 0
var atk_stat       : int = 0
var def_stat       : int = 0
var speed_stat     : int = 0

## Slots de move (4 IDs de string consultados do GameData)
var move_slots     : Array[String] = ["", "", "", ""]

## Cooldowns individuais restantes em segundos
var _cooldowns     : Array[float]  = [0.0, 0.0, 0.0, 0.0]

## Referência ao Treinador e ao inimigo mais próximo (injetadas externamente)
var trainer        : Node2D = null
var current_target : Node2D = null

var _is_fainted    : bool   = false

# ──────────────────────────────────────────────────────────────────────────────
# Inicialização
# ──────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("follower_pokemon")
	_load_species_data()
	_load_move_slots()
	EventBus.follower_changed.emit(_build_pokemon_data())

func _load_species_data() -> void:
	species_data = GameData.get_species(pokemon_species_id)
	if species_data.is_empty():
		push_warning("[FollowerPokemon] Espécie %d não encontrada." % pokemon_species_id)
		return

	var base : Dictionary = species_data.get("base_stats", {})
	max_hp      = DamageCalculator.calculate_hp(base.get("hp", 45),   pokemon_level)
	atk_stat    = DamageCalculator.calculate_stat(base.get("atk", 45),  pokemon_level)
	def_stat    = DamageCalculator.calculate_stat(base.get("def", 45),  pokemon_level)
	speed_stat  = DamageCalculator.calculate_stat(base.get("spd", 45),  pokemon_level)
	current_hp  = max_hp
	EventBus.follower_hp_changed.emit(current_hp, max_hp)

func _load_move_slots() -> void:
	var learnable : Array = GameData.get_learnable_moves(pokemon_species_id, pokemon_level)
	# Usa os últimos 4 moves aprendíveis (os mais recentes)
	var start := max(0, learnable.size() - 4)
	for i in range(start, learnable.size()):
		var entry : Dictionary = learnable[i]
		move_slots[i - start] = entry.get("move", "")

# ──────────────────────────────────────────────────────────────────────────────
# Loop principal
# ──────────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _is_fainted:
		return
	_tick_cooldowns(delta)
	_handle_skill_input()

func _physics_process(delta: float) -> void:
	if _is_fainted or not trainer:
		return
	_update_position(delta)

func _tick_cooldowns(delta: float) -> void:
	for i in 4:
		if _cooldowns[i] > 0.0:
			_cooldowns[i] = max(0.0, _cooldowns[i] - delta)
			var move_data := GameData.get_move(move_slots[i])
			var total_cd  : float = move_data.get("cooldown", 2.0)
			var progress  : float = 1.0 - (_cooldowns[i] / total_cd) if total_cd > 0.0 else 1.0
			EventBus.follower_skill_cooldown_updated.emit(i, progress)

# ──────────────────────────────────────────────────────────────────────────────
# Input de skills
# ──────────────────────────────────────────────────────────────────────────────

func _handle_skill_input() -> void:
	for i in 4:
		var action := "skill_%d" % (i + 1)
		if Input.is_action_just_pressed(action):
			use_skill(i)

## Executa a skill do slot indicado (0-3). Chamável externamente também.
func use_skill(slot: int) -> void:
	if slot < 0 or slot >= 4:
		return
	if move_slots[slot].is_empty():
		return
	if _cooldowns[slot] > 0.0:
		return
	if not current_target:
		return

	var move_data : Dictionary = GameData.get_move(move_slots[slot])
	if move_data.is_empty():
		return

	# Aplica redução de cooldown pela velocidade
	var base_cd    : float = move_data.get("cooldown", 2.0)
	var spd_reduc  : float = speed_stat / 500.0
	_cooldowns[slot] = max(0.2, base_cd * (1.0 - spd_reduc))

	EventBus.follower_skill_used.emit(slot, move_slots[slot])
	_execute_move(move_data)

func _execute_move(move_data: Dictionary) -> void:
	if not current_target:
		return
	# Projétil ou dano direto dependendo do alcance do move
	var is_ranged : bool = move_data.get("ranged", false)
	if is_ranged:
		_spawn_projectile(move_data)
	else:
		_apply_damage_direct(move_data)

func _apply_damage_direct(move_data: Dictionary) -> void:
	if not current_target.has_method("take_damage"):
		return
	var attacker_stats := { "atk": atk_stat, "level": pokemon_level }
	var defender_stats : Dictionary = {}
	if current_target.has_method("get_combat_stats"):
		defender_stats = current_target.get_combat_stats()
	var damage := DamageCalculator.calculate_damage(move_data, attacker_stats, defender_stats)
	current_target.take_damage(damage, self)

func _spawn_projectile(move_data: Dictionary) -> void:
	# O ProjectileBase é instanciado pela cena — aqui apenas notificamos
	# via sinal para que o SpawnManager crie o projétil no mundo
	var dir := (current_target.global_position - global_position).normalized()
	EventBus.follower_skill_used.emit(-1, move_data.get("id", ""))
	# Fallback: aplica direto se não há suporte a projétil
	_apply_damage_direct(move_data)

# ──────────────────────────────────────────────────────────────────────────────
# Posicionamento Bodyguard
# ──────────────────────────────────────────────────────────────────────────────

func _update_position(delta: float) -> void:
	var target_pos := _calculate_target_position()
	var diff       := target_pos - global_position
	var move_speed : float = MOVE_SPEED_BASE + (speed_stat * 0.8)

	if diff.length() > 2.0:
		velocity = diff.normalized() * min(diff.length() / delta, move_speed)
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func _calculate_target_position() -> Vector2:
	if not trainer:
		return global_position

	# Sem inimigo: fica atrás do Treinador
	if not current_target:
		return _position_behind_trainer()

	# Com inimigo: posiciona entre Treinador e inimigo
	var to_enemy : Vector2 = (current_target.global_position - trainer.global_position)
	if to_enemy.length() < 0.1:
		return _position_behind_trainer()

	return trainer.global_position + to_enemy.normalized() * BODYGUARD_OFFSET

func _position_behind_trainer() -> Vector2:
	# Usa a direção oposta ao facing do Treinador (aproximado: abaixo do Treinador)
	if trainer.has_method("get_facing_vector"):
		var fv : Vector2 = trainer.get_facing_vector()
		return trainer.global_position - fv * FOLLOW_DISTANCE
	return trainer.global_position + Vector2(0, FOLLOW_DISTANCE)

# ──────────────────────────────────────────────────────────────────────────────
# Receber dano
# ──────────────────────────────────────────────────────────────────────────────

func take_damage(amount: int, attacker: Node = null) -> void:
	if _is_fainted:
		return
	current_hp = max(0, current_hp - amount)
	EventBus.follower_hp_changed.emit(current_hp, max_hp)
	EventBus.damage_dealt.emit(self, amount, false)

	if current_hp <= 0:
		_faint()

func _faint() -> void:
	_is_fainted = true
	velocity    = Vector2.ZERO
	EventBus.follower_fainted.emit(_build_pokemon_data())
	if sprite:
		sprite.modulate = Color(0.4, 0.4, 0.4, 0.6)

# ──────────────────────────────────────────────────────────────────────────────
# API pública
# ──────────────────────────────────────────────────────────────────────────────

func set_trainer(t: Node2D) -> void:
	trainer = t

func set_target(t: Node2D) -> void:
	current_target = t

func is_fainted() -> bool:
	return _is_fainted

func get_combat_stats() -> Dictionary:
	return { "atk": atk_stat, "def": def_stat, "spd": speed_stat, "level": pokemon_level }

func _build_pokemon_data() -> Dictionary:
	return {
		"species_id": pokemon_species_id,
		"level":      pokemon_level,
		"hp":         current_hp,
		"max_hp":     max_hp,
		"moves":      move_slots.duplicate(),
	}

## WildPokemon.gd — Pokémon selvagem com FSM preditiva para combate Action RPG.
## Estados: PATROL → CHASE → ATTACK → DEAD
## Comportamentos: "aggressive" / "neutral" / "flee"
class_name WildPokemon
extends CharacterBody2D

# ──────────────────────────────────────────────────────────────────────────────
# Exports
# ──────────────────────────────────────────────────────────────────────────────

@export var species_id : int    = 1
@export var wild_level : int    = 5
@export var behavior   : String = "neutral"   # "aggressive" | "neutral" | "flee"
@export var is_alpha   : bool   = false
## ID da zona onde nasceu (data/world/zones.json) — setado pelo SpawnManager.
## Usado pelo BattleManager pra saber se é uma batalha de Zona Safari
## ("" pros spawns sem zona conhecida, ex: pesca via spawn_specific).
@export var zone_id    : String = ""

## Alias para compatibilidade com BattleManager (espera .level)
var level : int:
	get: return wild_level

# ──────────────────────────────────────────────────────────────────────────────
# Constantes do spec
# ──────────────────────────────────────────────────────────────────────────────

const WILD_DETECT_RADIUS : float = 120.0
const WILD_ATTACK_RADIUS : float = 48.0
const ALPHA_HP_MULT      : float = 5.0
const ALPHA_ATK_MULT     : float = 3.0
const ALPHA_DEF_MULT     : float = 2.5
const ALPHA_SPD_MULT     : float = 1.5

const PATROL_INTERVAL_MIN : float = 2.0
const PATROL_INTERVAL_MAX : float = 4.0
const BASE_MOVE_SPEED     : float = 80.0

# ──────────────────────────────────────────────────────────────────────────────
# FSM
# ──────────────────────────────────────────────────────────────────────────────

enum State { PATROL, CHASE, ATTACK, DEAD }

var state : State = State.PATROL

# ──────────────────────────────────────────────────────────────────────────────
# Componentes de cena
# ──────────────────────────────────────────────────────────────────────────────

@onready var sprite   : AnimatedSprite2D = $Sprite
@onready var hurtbox  : Area2D           = $HurtBox
@onready var hitbox   : Area2D           = $HitBox

# ──────────────────────────────────────────────────────────────────────────────
# Stats em tempo de execução
# ──────────────────────────────────────────────────────────────────────────────

var species_data  : Dictionary = {}
var current_hp    : int   = 0
var max_hp        : int   = 0
var atk_stat      : int   = 0
var def_stat      : int   = 0
var speed_stat    : int   = 0
var catch_rate    : int   = 45   # fallback
var types         : Array = []

## Move padrão desta espécie (primeiro do learnset ou fallback)
var default_move  : Dictionary = {}
var _attack_cd    : float = 0.0

# ──────────────────────────────────────────────────────────────────────────────
# Patrol
# ──────────────────────────────────────────────────────────────────────────────

var _patrol_dir      : Vector2 = Vector2.ZERO
var _patrol_timer    : float   = 0.0
var _spawn_pos       : Vector2 = Vector2.ZERO

# ──────────────────────────────────────────────────────────────────────────────
# Alvo
# ──────────────────────────────────────────────────────────────────────────────

## Alvo principal: Follower ativo ou Treinador
var target : Node2D = null

# ──────────────────────────────────────────────────────────────────────────────
# Inicialização
# ──────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("wild_pokemon")
	_spawn_pos = global_position
	_load_species()
	_load_sprite()
	_pick_patrol_dir()
	EventBus.wild_pokemon_spawned.emit(self)

## Chamado pelo SpawnManager (ANTES de entrar na árvore, então antes do _ready
## rodar) pra definir espécie/nível/comportamento de acordo com a tabela da
## zona. Achado: esse método não existia — SpawnManager já tentava chamar
## "initialize" (`if instance.has_method("initialize")`), mas como não achava
## o método, todo Pokémon selvagem nascia com os valores padrão do Inspector
## (Bulbasaur nível 5), ignorando o que a zona sorteou (Pidgey/Rattata/etc).
func initialize(new_species_id: int, new_level: int, new_behavior: String = "aggressive", new_zone_id: String = "") -> void:
	species_id = new_species_id
	wild_level  = new_level
	behavior    = new_behavior
	zone_id     = new_zone_id

## Achado (mesma causa do Pokémon companheiro): sem isto, o Pokémon selvagem
## nunca tinha sprite nenhum — existia, se movia e reagia, mas era 100%
## invisível no mapa. A escala 2x evita o outro problema já visto: a região
## do spritesheet é só 16×16, quase invisível do lado do jogador.
func _load_sprite() -> void:
	if sprite and not sprite.sprite_frames:
		sprite.sprite_frames = SpriteBuilder.build_pokemon_frames(species_id)
		sprite.play("idle")
		sprite.scale = Vector2(2.0, 2.0)

func _load_species() -> void:
	species_data = GameData.get_species(species_id)
	if species_data.is_empty():
		push_warning("[WildPokemon] Espécie %d não encontrada." % species_id)
		return

	var base : Dictionary = species_data.get("base_stats", {})
	types      = species_data.get("types", ["Normal"])
	catch_rate = species_data.get("catch_rate", 45)

	# Chaves corrigidas (Fase 1 do Diário) — mesmo bug do FollowerPokemon.gd:
	# "atk"/"def"/"spd" não existem em species.json, caía sempre no padrão 45.
	max_hp     = DamageCalculator.calculate_hp(base.get("hp", 45),      wild_level)
	atk_stat   = DamageCalculator.calculate_stat(base.get("attack", 45), wild_level)
	def_stat   = DamageCalculator.calculate_stat(base.get("defense", 45), wild_level)
	speed_stat = DamageCalculator.calculate_stat(base.get("speed", 45),  wild_level)

	if is_alpha:
		max_hp    = int(max_hp  * ALPHA_HP_MULT)
		atk_stat  = int(atk_stat * ALPHA_ATK_MULT)
		def_stat  = int(def_stat * ALPHA_DEF_MULT)
		speed_stat = int(speed_stat * ALPHA_SPD_MULT)

	current_hp = max_hp

	# Move padrão: primeiro move aprendível
	var learnable : Array = GameData.get_learnable_moves(species_id, wild_level)
	if not learnable.is_empty():
		default_move = GameData.get_move(learnable[0].get("move", ""))

# ──────────────────────────────────────────────────────────────────────────────
# Loop principal
# ──────────────────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_find_target()
	_attack_cd = max(0.0, _attack_cd - delta)

	match state:
		State.PATROL: _tick_patrol(delta)
		State.CHASE:  _tick_chase()
		State.ATTACK: _tick_attack()

func _find_target() -> void:
	# Prioridade: Follower ativo → Treinador
	var followers := get_tree().get_nodes_in_group("follower_pokemon")
	for f in followers:
		if f.has_method("is_fainted") and not f.is_fainted():
			target = f
			return

	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target = players[0]
	else:
		target = null

# ──────────────────────────────────────────────────────────────────────────────
# PATROL
# ──────────────────────────────────────────────────────────────────────────────

func _tick_patrol(delta: float) -> void:
	_patrol_timer -= delta
	if _patrol_timer <= 0.0:
		_pick_patrol_dir()

	# Detecção de player
	if target:
		var dist : float = global_position.distance_to(target.global_position)
		if dist <= WILD_DETECT_RADIUS:
			match behavior:
				"aggressive": _set_state(State.CHASE)
				"neutral":    pass  # só ataca se atacado
				"flee":       _flee_from_target()
			return

	var move_speed := _get_move_speed()
	velocity = _patrol_dir * move_speed
	move_and_slide()

func _pick_patrol_dir() -> void:
	_patrol_timer = RNGManager.randf_range(PATROL_INTERVAL_MIN, PATROL_INTERVAL_MAX)
	var angle     := RNGManager.randf_range(0.0, TAU)
	_patrol_dir   = Vector2(cos(angle), sin(angle))

func _flee_from_target() -> void:
	if not target:
		return
	var away := (global_position - target.global_position).normalized()
	velocity  = away * _get_move_speed() * 1.5
	move_and_slide()

# ──────────────────────────────────────────────────────────────────────────────
# CHASE
# ──────────────────────────────────────────────────────────────────────────────

func _tick_chase() -> void:
	if not target:
		_set_state(State.PATROL)
		return

	var dist : float = global_position.distance_to(target.global_position)
	if dist > WILD_DETECT_RADIUS + 20.0:
		_set_state(State.PATROL)
		return
	if dist <= WILD_ATTACK_RADIUS:
		_set_state(State.ATTACK)
		return

	var dir  := (target.global_position - global_position).normalized()
	velocity  = dir * _get_move_speed()
	move_and_slide()

# ──────────────────────────────────────────────────────────────────────────────
# ATTACK
# ──────────────────────────────────────────────────────────────────────────────

func _tick_attack() -> void:
	velocity = Vector2.ZERO

	if not target:
		_set_state(State.PATROL)
		return

	var dist : float = global_position.distance_to(target.global_position)
	if dist > WILD_ATTACK_RADIUS + 8.0:
		_set_state(State.CHASE)
		return

	if _attack_cd <= 0.0:
		_perform_attack()

func _perform_attack() -> void:
	var base_cd : float = default_move.get("cooldown", 2.0)
	var spd_reduc : float = speed_stat / 500.0
	_attack_cd = max(0.3, base_cd * (1.0 - spd_reduc))

	if target and target.has_method("take_damage"):
		var attacker_stats := { "atk": atk_stat, "level": wild_level }
		var defender_stats : Dictionary = {}
		if target.has_method("get_combat_stats"):
			defender_stats = target.get_combat_stats()
		var damage := DamageCalculator.calculate_damage(default_move, attacker_stats, defender_stats)
		target.take_damage(damage, self)

# ──────────────────────────────────────────────────────────────────────────────
# Receber dano
# ──────────────────────────────────────────────────────────────────────────────

func take_damage(amount: int, attacker: Node = null) -> void:
	if state == State.DEAD:
		return
	current_hp = max(0, current_hp - amount)
	EventBus.damage_dealt.emit(self, amount, false)

	# "neutral" entra em combate quando atacado
	if behavior == "neutral" and state == State.PATROL:
		_set_state(State.CHASE)

	if current_hp <= 0:
		_die()

func _die() -> void:
	_set_state(State.DEAD)
	velocity = Vector2.ZERO
	var loot := _roll_loot()
	EventBus.wild_pokemon_died.emit(self, loot)
	EventBus.wild_pokemon_fainted.emit(self)
	queue_free()

func _roll_loot() -> Array:
	var luck_pts : int = 0
	# Tenta obter sorte do Treinador se disponível
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty() and players[0].has_method("get_luck_points"):
		luck_pts = players[0].get_luck_points()

	var chance_drop : float = min(0.15 + (wild_level / 200.0) + (luck_pts * 0.02), 0.85)
	if not RNGManager.chance(chance_drop):
		return []

	var item_pool : Array = species_data.get("drops", [])
	if item_pool.is_empty():
		return []
	return [RNGManager.pick(item_pool)]

# ──────────────────────────────────────────────────────────────────────────────
# API pública
# ──────────────────────────────────────────────────────────────────────────────

func get_combat_stats() -> Dictionary:
	return { "def": def_stat, "types": types, "level": wild_level }

func get_hp_ratio() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)

func get_catch_rate() -> int:
	return catch_rate

# ──────────────────────────────────────────────────────────────────────────────
# Transições de estado
# ──────────────────────────────────────────────────────────────────────────────

var _encounter_triggered : bool = false   # evita emissão repetida por encontro

func _set_state(new_state: State) -> void:
	var prev := state
	state = new_state
	# Quando entra em ATTACK pela primeira vez (vindo de outro estado),
	# emite wild_encounter_started para acionar o BattleManager (sistema turn-based).
	if new_state == State.ATTACK and prev != State.ATTACK and not _encounter_triggered:
		_encounter_triggered = true
		EventBus.wild_encounter_started.emit(self)
	# Reset do flag quando sai do ATTACK (ex: para PATROL/DEAD)
	if prev == State.ATTACK and new_state != State.ATTACK:
		_encounter_triggered = false

func _get_move_speed() -> float:
	return BASE_MOVE_SPEED + (speed_stat * 0.8)

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

const WILD_DETECT_RADIUS : float = 240.0
const WILD_ATTACK_RADIUS : float = 96.0
const ALPHA_HP_MULT      : float = 5.0
const ALPHA_ATK_MULT     : float = 3.0
const ALPHA_DEF_MULT     : float = 2.5
const ALPHA_SPD_MULT     : float = 1.5

const PATROL_INTERVAL_MIN : float = 2.0
const PATROL_INTERVAL_MAX : float = 4.0
const BASE_MOVE_SPEED     : float = 160.0

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
	_build_health_bar()
	if hurtbox:
		hurtbox.input_event.connect(_on_hurtbox_input_event)
	EventBus.wild_pokemon_selected.connect(_on_wild_pokemon_selected)
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
		sprite.scale = Vector2(4.0, 4.0)

# ──────────────────────────────────────────────────────────────────────────────
# Seleção de alvo + HP/nível visível (motor de combate em tempo real, 02/09)
# ──────────────────────────────────────────────────────────────────────────────
# Achado ao construir isto: sem alvo selecionado, os golpes de mira única do
# Follower nunca tinham quem atacar (current_target nunca era setado por
# ninguém) — clicar/tocar no Pokémon é como o Gabriel pediu pra escolher.
var _hp_bar_bg     : ColorRect
var _hp_bar_fill   : ColorRect
var _level_label   : Label
const HP_BAR_WIDTH  : float = 40.0
const HP_BAR_HEIGHT : float = 5.0
const HP_BAR_Y      : float = -40.0

func _build_health_bar() -> void:
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color = Color(0.1, 0.1, 0.1, 0.8)
	_hp_bar_bg.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	_hp_bar_bg.position = Vector2(-HP_BAR_WIDTH / 2.0, HP_BAR_Y)
	add_child(_hp_bar_bg)

	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.color = Color(0.2, 0.85, 0.2)
	_hp_bar_fill.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	_hp_bar_bg.add_child(_hp_bar_fill)

	_level_label = Label.new()
	_level_label.text = "Lv.%d" % wild_level
	_level_label.add_theme_font_size_override("font_size", 10)
	_level_label.position = Vector2(-HP_BAR_WIDTH / 2.0, HP_BAR_Y - 14.0)
	add_child(_level_label)

	_update_health_bar()

func _update_health_bar() -> void:
	if not _hp_bar_fill or max_hp <= 0:
		return
	var ratio : float = clampf(float(current_hp) / float(max_hp), 0.0, 1.0)
	_hp_bar_fill.size.x = HP_BAR_WIDTH * ratio
	# Verde -> amarelo -> vermelho, igual convenção clássica de barra de vida.
	if ratio > 0.5:
		_hp_bar_fill.color = Color(0.2, 0.85, 0.2)
	elif ratio > 0.2:
		_hp_bar_fill.color = Color(0.9, 0.8, 0.1)
	else:
		_hp_bar_fill.color = Color(0.85, 0.2, 0.2)

func _on_hurtbox_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if state == State.DEAD:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		EventBus.wild_pokemon_selected.emit(self)
	elif event is InputEventScreenTouch and event.pressed:
		EventBus.wild_pokemon_selected.emit(self)

## Todo Pokémon selvagem escuta a própria seleção pra saber se é ELE o
## escolhido (sem gerente central) — só acende o destaque em si mesmo.
func _on_wild_pokemon_selected(pokemon: Node) -> void:
	if not sprite:
		return
	sprite.modulate = Color(1.5, 1.5, 0.7) if pokemon == self else Color(1, 1, 1)

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

	_passive_data = species_data.get("passive", {})
	if not _passive_data.is_empty():
		_reroll_passive_timer()

# ──────────────────────────────────────────────────────────────────────────────
# Habilidade passiva (Fase 2 do motor de combate em tempo real, 02/09) — pedido
# do Gabriel com 2 exemplos concretos: Mega Drain do Vileplume (bate nos que
# estão atacando e cura a mesma soma) e Counter Helix do Scyther (devolve o
# dano recebido pro atacante mais recente). Dispara sozinha, num timer
# aleatório que fica MAIS FREQUENTE quanto mais atacantes distintos bateram
# desde o último disparo (Gabriel: "mais frequente quando cercado") — não é
# convenção de nenhum jogo real pesquisado (Tibia/PokeXGames), é design nosso.
# ──────────────────────────────────────────────────────────────────────────────
var _passive_data      : Dictionary = {}
var _passive_timer     : float      = 0.0
var _recent_attackers  : Array      = []
var _passive_dmg_since : int        = 0

func _reroll_passive_timer() -> void:
	var n  : int   = maxi(1, _recent_attackers.size())
	var lo : float = _passive_data.get("interval_min", 8.0)
	var hi : float = _passive_data.get("interval_max", 16.0)
	_passive_timer = RNGManager.randf_range(lo, hi) / float(n)
	_recent_attackers.clear()
	_passive_dmg_since = 0

func _tick_passive(delta: float) -> void:
	if _passive_data.is_empty():
		return
	_passive_timer -= delta
	if _passive_timer <= 0.0:
		_fire_passive()

func _fire_passive() -> void:
	match _passive_data.get("effect", ""):
		"drain":   _fire_passive_drain()
		"reflect": _fire_passive_reflect()
	_reroll_passive_timer()

func _fire_passive_drain() -> void:
	if _recent_attackers.is_empty():
		return
	var move_data      : Dictionary = GameData.get_move(_passive_data.get("move_id", ""))
	var attacker_stats := _attacker_stats()
	var total_dealt := 0
	for a in _recent_attackers:
		if is_instance_valid(a) and a.has_method("take_damage"):
			var defender_stats : Dictionary = a.get_combat_stats() if a.has_method("get_combat_stats") else {}
			var dmg : int = DamageCalculator.calculate_damage(move_data, attacker_stats, defender_stats)
			a.take_damage(dmg, self)
			total_dealt += dmg
	if total_dealt > 0:
		current_hp = mini(max_hp, current_hp + total_dealt)
		_update_health_bar()

func _fire_passive_reflect() -> void:
	if _recent_attackers.is_empty() or _passive_dmg_since <= 0:
		return
	var alvo = _recent_attackers[_recent_attackers.size() - 1]  # atacante mais recente
	if is_instance_valid(alvo) and alvo.has_method("take_damage"):
		alvo.take_damage(_passive_dmg_since, self)

# ──────────────────────────────────────────────────────────────────────────────
# Loop principal
# ──────────────────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_find_target()
	_attack_cd = max(0.0, _attack_cd - delta)
	_tick_passive(delta)

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
	if dist > WILD_DETECT_RADIUS + 40.0:
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
	if dist > WILD_ATTACK_RADIUS + 16.0:
		_set_state(State.CHASE)
		return

	if _attack_cd <= 0.0:
		_perform_attack()

func _perform_attack() -> void:
	var base_cd : float = default_move.get("cooldown", 2.0)
	var spd_reduc : float = speed_stat / 500.0
	_attack_cd = max(0.3, base_cd * (1.0 - spd_reduc))

	if default_move.get("target_type", "single") == "area":
		_apply_damage_area(default_move)
		return

	if target and target.has_method("take_damage"):
		var attacker_stats := _attacker_stats()
		var defender_stats : Dictionary = {}
		if target.has_method("get_combat_stats"):
			defender_stats = target.get_combat_stats()
		var damage := DamageCalculator.calculate_damage(default_move, attacker_stats, defender_stats)
		target.take_damage(damage, self)

## Mesmo formato de attacker_stats usado no ataque direto, na área e na
## passiva — centralizado aqui pra não divergir.
func _attacker_stats() -> Dictionary:
	return {
		"atk": atk_stat, "level": wild_level,
		"ability": species_data.get("ability", ""), "hp_ratio": get_hp_ratio(),
	}

## Golpe de área: bate em Follower + Treinador (os únicos alvos válidos de um
## selvagem) dentro do raio, a partir da própria posição — não depende de
## `target` travado, diferente do ataque single-target.
func _apply_damage_area(move_data: Dictionary) -> void:
	var radius : float = move_data.get("radius", 0.0)
	var alvos  : Array  = AreaTargeting.find_targets_in_radius(global_position, radius, ["follower_pokemon", "player"])
	var attacker_stats := _attacker_stats()
	for alvo in alvos:
		if not alvo.has_method("take_damage"):
			continue
		var defender_stats : Dictionary = alvo.get_combat_stats() if alvo.has_method("get_combat_stats") else {}
		var dmg : int = DamageCalculator.calculate_damage(move_data, attacker_stats, defender_stats)
		alvo.take_damage(dmg, self)

# ──────────────────────────────────────────────────────────────────────────────
# Receber dano
# ──────────────────────────────────────────────────────────────────────────────

func take_damage(amount: int, attacker: Node = null) -> void:
	if state == State.DEAD:
		return
	current_hp = max(0, current_hp - amount)
	EventBus.damage_dealt.emit(self, amount, false)
	EventBus.wild_pokemon_hp_changed.emit(self, current_hp, max_hp)
	if attacker and not _recent_attackers.has(attacker):
		_recent_attackers.append(attacker)
	_passive_dmg_since += amount
	_update_health_bar()

	# "neutral" entra em combate quando atacado
	if behavior == "neutral" and state == State.PATROL:
		_set_state(State.CHASE)

	if current_hp <= 0:
		_die()

func _die() -> void:
	_set_state(State.DEAD)
	velocity = Vector2.ZERO
	# Fase 5 do motor de combate em tempo real (02/09): XP/level-up/loot/
	# Pokédex/sinal de quest agora vêm de BattleResolver — mesma fórmula que
	# o combate por turno já usava (BattleManager._end_battle()), não mais a
	# fórmula própria de _roll_loot() (aposentada: usava species_data.drops,
	# uma tabela paralela e desconectada da de LootTable, que já dava bônus
	# de sorte do Treinador).
	BattleResolver.resolve_wild_defeat(species_id, wild_level, species_data.get("name", ""))
	EventBus.wild_pokemon_died.emit(self, [])
	EventBus.wild_pokemon_fainted.emit(self)
	queue_free()

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

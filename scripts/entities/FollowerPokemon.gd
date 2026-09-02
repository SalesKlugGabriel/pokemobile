## FollowerPokemon.gd — Pokémon Bodyguard que segue o Treinador e executa combate.
## Posicionamento: entre o Treinador e o WildPokémon mais próximo.
## Skills 1-4 ativadas por input; cada skill tem cooldown individual.
## Estende CharacterBody2D (movimento contínuo em px, não tile-a-tile).
class_name FollowerPokemon
extends CharacterBody2D

# ──────────────────────────────────────────────────────────────────────────────
# Exports
# ──────────────────────────────────────────────────────────────────────────────

@export var pokemon_species_id : int  = 4
@export var pokemon_level      : int  = 5
## Vem do save (poke.is_shiny) — não é sorteado aqui, o Follower só EXIBE o
## resultado que já foi decidido quando o Pokémon nasceu selvagem/foi
## capturado (ver WildPokemon._load_species() e CaptureSystem).
@export var pokemon_is_shiny   : bool = false

# ──────────────────────────────────────────────────────────────────────────────
# Constantes
# ──────────────────────────────────────────────────────────────────────────────

const FOLLOW_DISTANCE   : float = 64.0   # px — distância de repouso atrás do Treinador (2 tiles de 32px, pra não sobrepor o sprite)
const BODYGUARD_OFFSET  : float = 40.0   # px — distância do Treinador em direção ao inimigo
const MOVE_SPEED_BASE   : float = 240.0

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
	_load_sprite()
	EventBus.follower_changed.emit(_build_pokemon_data())
	# Motor de combate em tempo real (02/09): use_skill() já exigia
	# current_target pra funcionar, só que nada nunca setava esse valor —
	# clicar/tocar no Pokémon selvagem (WildPokemon._on_hurtbox_input_event)
	# agora é como o Gabriel pediu pra escolher em quem atacar.
	EventBus.wild_pokemon_selected.connect(_on_wild_pokemon_selected)
	EventBus.wild_pokemon_died.connect(_on_wild_pokemon_died)
	EventBus.wild_pokemon_fainted.connect(_on_wild_pokemon_fainted)

func _on_wild_pokemon_selected(pokemon: Node) -> void:
	current_target = pokemon

func _on_wild_pokemon_died(pokemon: Node, _loot: Array) -> void:
	if current_target == pokemon:
		current_target = null

func _on_wild_pokemon_fainted(pokemon: Node) -> void:
	if current_target == pokemon:
		current_target = null

func _load_sprite() -> void:
	if sprite and not sprite.sprite_frames:
		sprite.sprite_frames = SpriteBuilder.build_pokemon_frames(pokemon_species_id, pokemon_is_shiny)
		sprite.play("idle")
		# Sprites de Pokémon usam a mesma região 16×16 do jogador, mas ficam quase
		# vazios dentro desse quadro — sem isto, o Pokémon fica praticamente
		# invisível do lado do Treinador (achado: "sprite" existe e é desenhado,
		# só é minúsculo demais pra notar a olho nu).
		sprite.scale = Vector2(4.0, 4.0)

func _load_species_data() -> void:
	species_data = GameData.get_species(pokemon_species_id)
	if species_data.is_empty():
		push_warning("[FollowerPokemon] Espécie %d não encontrada." % pokemon_species_id)
		return

	# Chaves corrigidas (Fase 1 do Diário) — eram "atk"/"def"/"spd", que não
	# existem em species.json (as chaves reais são attack/defense/speed);
	# sempre caía no valor-padrão 45, igual pra qualquer espécie.
	var base : Dictionary = species_data.get("base_stats", {})
	max_hp      = DamageCalculator.calculate_hp(base.get("hp", 45),      pokemon_level)
	atk_stat    = DamageCalculator.calculate_stat(base.get("attack", 45), pokemon_level)
	def_stat    = DamageCalculator.calculate_stat(base.get("defense", 45), pokemon_level)
	speed_stat  = DamageCalculator.calculate_stat(base.get("speed", 45),  pokemon_level)
	current_hp  = max_hp
	EventBus.follower_hp_changed.emit(current_hp, max_hp)
	_passive_data = species_data.get("passive", {})
	if not _passive_data.is_empty():
		_reroll_passive_timer()

# ──────────────────────────────────────────────────────────────────────────────
# Habilidade passiva — mesma mecânica de WildPokemon.gd (Fase 2, ver comentário
# lá pro contexto completo). Duplicada aqui de propósito, não por descuido: os
# dois lados (selvagem e Follower) precisam da mesma passiva, mas cada um já
# tem seu próprio estado (species_data/current_hp/atk_stat próprios) — dividir
# isso numa classe à parte custaria mais que as ~40 linhas repetidas.
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
	var nome : String = move_data.get("name", "")
	var attacker_stats := _attacker_stats()
	var total_dealt := 0
	for a in _recent_attackers:
		if is_instance_valid(a) and a.has_method("take_damage"):
			var defender_stats : Dictionary = a.get_combat_stats() if a.has_method("get_combat_stats") else {}
			var dmg : int = DamageCalculator.calculate_damage(move_data, attacker_stats, defender_stats)
			a.take_damage(dmg, self)
			total_dealt += dmg
			FloatingText.show_text(get_tree().current_scene, a.global_position + Vector2(0, -46), "%s -%d" % [nome, dmg], Color(0.6, 1.0, 0.4))
	if total_dealt > 0:
		current_hp = mini(max_hp, current_hp + total_dealt)
		EventBus.follower_hp_changed.emit(current_hp, max_hp)
		FloatingText.show_text(get_tree().current_scene, global_position + Vector2(0, -46), "+%d" % total_dealt, Color(0.4, 1.0, 0.4))

func _fire_passive_reflect() -> void:
	if _recent_attackers.is_empty() or _passive_dmg_since <= 0:
		return
	var alvo = _recent_attackers[_recent_attackers.size() - 1]
	if is_instance_valid(alvo) and alvo.has_method("take_damage"):
		alvo.take_damage(_passive_dmg_since, self)
		FloatingText.show_text(get_tree().current_scene, alvo.global_position + Vector2(0, -46), "Reflexo! -%d" % _passive_dmg_since, Color(0.8, 0.6, 1.0))

func _load_move_slots() -> void:
	var learnable : Array = GameData.get_learnable_moves(pokemon_species_id, pokemon_level)
	# Usa os últimos 4 moves aprendíveis (os mais recentes)
	var start : int = maxi(0, learnable.size() - 4)
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
	if _is_fainted:
		return
	_update_position(delta)
	_tick_passive(delta)

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

	var move_data : Dictionary = GameData.get_move(move_slots[slot])
	if move_data.is_empty():
		return

	# Golpe de área não depende de alvo selecionado (bate em quem estiver no
	# raio); golpe de mira única/corpo-a-corpo exige um alvo escolhido por
	# clique/toque (WildPokemon._on_hurtbox_input_event) — sem isso, nem o
	# ataque melee funciona (regra confirmada com o Gabriel, 02/09).
	var is_area : bool = move_data.get("target_type", "single") == "area"
	if not is_area and not current_target:
		return

	# Aplica redução de cooldown pela velocidade
	var base_cd    : float = move_data.get("cooldown", 2.0)
	var spd_reduc  : float = speed_stat / 500.0
	_cooldowns[slot] = max(0.2, base_cd * (1.0 - spd_reduc))

	EventBus.follower_skill_used.emit(slot, move_slots[slot])
	_execute_move(move_data)

func _execute_move(move_data: Dictionary) -> void:
	if move_data.get("target_type", "single") == "area":
		_apply_damage_area(move_data)
		return
	if not current_target:
		return
	# Projétil ou dano direto dependendo do alcance do move
	var is_ranged : bool = move_data.get("ranged", false)
	if is_ranged:
		_spawn_projectile(move_data)
	else:
		_apply_damage_direct(move_data)

## Mesmo formato de attacker_stats usado em 3 lugares deste arquivo (dano
## direto, área e a passiva) — centralizado aqui pra não divergir os 3.
func _attacker_stats() -> Dictionary:
	return {
		"atk": atk_stat, "level": pokemon_level,
		"ability": species_data.get("ability", ""),
		"hp_ratio": float(current_hp) / float(max_hp) if max_hp > 0 else 1.0,
	}

## Golpe de área: bate em todo `wild_pokemon` no raio, nunca no próprio time
## (sem fogo amigo, decisão confirmada com o Gabriel) — não depende de
## current_target, mira a partir da própria posição do Follower.
func _apply_damage_area(move_data: Dictionary) -> void:
	var radius : float = move_data.get("radius", 0.0)
	var alvos : Array = AreaTargeting.find_targets_in_radius(global_position, radius, "wild_pokemon")
	var attacker_stats := _attacker_stats()
	var nome : String = move_data.get("name", "")
	for alvo in alvos:
		if not alvo.has_method("take_damage"):
			continue
		var defender_stats : Dictionary = alvo.get_combat_stats() if alvo.has_method("get_combat_stats") else {}
		var dmg : int = DamageCalculator.calculate_damage(move_data, attacker_stats, defender_stats)
		alvo.take_damage(dmg, self)
		FloatingText.show_text(get_tree().current_scene, alvo.global_position + Vector2(0, -46), "%s -%d" % [nome, dmg], Color(1.0, 0.6, 0.2))

func _apply_damage_direct(move_data: Dictionary) -> void:
	if not current_target.has_method("take_damage"):
		return
	var attacker_stats := _attacker_stats()
	var defender_stats : Dictionary = {}
	if current_target.has_method("get_combat_stats"):
		defender_stats = current_target.get_combat_stats()
	var damage := DamageCalculator.calculate_damage(move_data, attacker_stats, defender_stats)
	current_target.take_damage(damage, self)
	FloatingText.show_text(get_tree().current_scene, current_target.global_position + Vector2(0, -46), "%s -%d" % [move_data.get("name", ""), damage], Color(1.0, 0.9, 0.3))

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

	if diff.length() > 4.0:
		velocity = diff.normalized() * min(diff.length() / delta, move_speed)
		_play_anim("walk")
	else:
		velocity = Vector2.ZERO
		_play_anim("idle")

	move_and_slide()

func _calculate_target_position() -> Vector2:
	# Com inimigo em combate: posiciona entre Treinador e inimigo
	if current_target and trainer:
		var to_enemy : Vector2 = (current_target.global_position - trainer.global_position)
		if to_enemy.length() >= 0.1:
			return trainer.global_position + to_enemy.normalized() * BODYGUARD_OFFSET

	# Fora de combate: sempre 1 quadro atrás do Treinador, no sentido oposto
	# de pra onde ele está olhando — nunca na diagonal, pra nunca sobrepor.
	if trainer:
		return _position_behind_trainer()

	return global_position

func _play_anim(base: String) -> void:
	if not sprite or not sprite.sprite_frames:
		return
	if sprite.animation != base and sprite.sprite_frames.has_animation(base):
		sprite.play(base)

## Sempre no quadro cardeal OPOSTO a pra onde o Treinador está olhando —
## Norte→fica ao Sul, Oeste→fica a Leste, etc. (correção pedida pelo Gabriel,
## 02/09: nunca diagonal, nunca sobrepor). Antes disso o Pokémon perseguia um
## "rastro" de posições passadas do Treinador (removido) — parecia mais
## natural em linha reta, mas podia ficar temporariamente fora do eixo
## cardeal numa curva, sobrepondo o sprite (que é desenhado 2x maior, ver
## _load_sprite, pra não ficar minúsculo do lado do Treinador).
func _position_behind_trainer() -> Vector2:
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
	if attacker and not _recent_attackers.has(attacker):
		_recent_attackers.append(attacker)
	_passive_dmg_since += amount

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

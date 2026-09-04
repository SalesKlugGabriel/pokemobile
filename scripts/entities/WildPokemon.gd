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
## Pokémon de treinador nunca pode ser capturado (ver CaptureSystem.
## attempt_capture()) — hoje todo WildPokemon é selvagem por definição, mas
## o campo já existe pronto pra quando a Fase 7 trouxer combatente de
## treinador usando esta mesma classe.
@export var is_trainer_owned : bool = false
## Setado junto com is_trainer_owned — a quem avisar (spawnar o próximo da
## equipe / marcar derrotado) quando este morrer (Fase 7, 02/09).
var trainer_npc : Node = null

## Alias para compatibilidade com BattleManager (espera .level)
var level : int:
	get: return wild_level

# ──────────────────────────────────────────────────────────────────────────────
# Constantes do spec
# ──────────────────────────────────────────────────────────────────────────────

const WILD_DETECT_RADIUS : float = 960.0  # migração tile128 (03/09): era 240 pro tile de 32px
const WILD_ATTACK_RADIUS : float = 384.0  # migração tile128 (03/09): era 96 pro tile de 32px
const ALPHA_HP_MULT      : float = 5.0
const ALPHA_ATK_MULT     : float = 3.0
const ALPHA_DEF_MULT     : float = 2.5
const ALPHA_SPD_MULT     : float = 1.5

const PATROL_INTERVAL_MIN : float = 2.0
const PATROL_INTERVAL_MAX : float = 4.0
const BASE_MOVE_SPEED     : float = 640.0  # migração tile128 (03/09): era 160 pro tile de 32px

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
# Status persistente (Onda 1, item 5 do roteiro geral, 03/09) — ver
# StatusEffectController.gd pras regras/frações, todas reaproveitadas do
# combate por turno já validado (BattlePokemon.gd).
# ──────────────────────────────────────────────────────────────────────────────
var current_status      : String = "none"   # "none"/"burn"/"poison"/"bad_poison"/"paralysis"/"sleep"/"freeze"
var _status_tick_timer  : float  = 0.0      # até o próximo dano de queima/veneno ou checagem de degelo
var _sleep_timer        : float  = 0.0      # segundos restantes de sono
var _bad_poison_stacks  : int    = 0
var _confused           : bool   = false
var _confuse_timer      : float  = 0.0

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
	# Achado ao fazer a Fase 7: o combate por turno marcava "visto" na Pokédex
	# só quando o encontro esquentava (BattleManager._on_wild_encounter_started).
	# Sem essa emissão pra encontro comum, isso pararia de acontecer — marcar
	# aqui em vez disso (assim que o Pokémon aparece no mapa) é pelo menos tão
	# correto quanto, e cobre selvagem e Pokémon de treinador igual.
	SaveManager.mark_seen(species_id)
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

## Base Y do Sprite (do .tscn, escala 1.0) — usada por PokemonScale pra
## manter o PÉ do Pokémon fixo no chão não importa o tamanho (03/09).
const SPRITE_BASE_OFFSET_Y : float = -32.0

## Escala visual por espécie (03/09, pedido do Gabriel: "Pikachu < Charmander
## < Bulbasaur < Charizard << Onix", baseado na altura oficial da Pokédex —
## ver PokemonScale.gd pra fórmula e limites). Sem isto, TODO Pokémon
## ocupava exatamente 1 tile, não importa a espécie ("Pikachu=32px,
## Charizard=32px, Onix=32px" — exatamente o que ele NÃO queria).
func _load_sprite() -> void:
	if sprite and not sprite.sprite_frames:
		sprite.sprite_frames = SpriteBuilder.build_pokemon_frames(species_id, is_shiny)
		sprite.play("idle")
		var vscale := PokemonScale.get_visual_scale(species_id)
		PokemonScale.anchor_sprite_bottom(sprite, SPRITE_BASE_OFFSET_Y, vscale)
		_add_ground_shadow(vscale)

## Sombra no chão, proporcional ao tamanho do Pokémon (03/09) — mesma
## técnica de TrainerEntity._add_visibility_shadow() (degradê radial em
## código, sem precisar de arte nova). Fica NO CHÃO sempre — diferente do
## sprite (que cresce pra cima com a escala), a sombra só fica um pouco
## maior/menor, nunca sai do lugar onde o Pokémon pisa.
func _add_ground_shadow(vscale: float) -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.55))
	grad.add_point(0.7, Color(0, 0, 0, 0.35))
	grad.set_color(grad.get_point_count() - 1, Color(0, 0, 0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = maxi(20, roundi(130.0 * vscale))
	tex.height = maxi(10, roundi(65.0 * vscale))

	var shadow := Sprite2D.new()
	shadow.texture = tex
	shadow.position = Vector2(0, 24)
	shadow.z_index = 0
	add_child(shadow)
	move_child(shadow, 0)

# ──────────────────────────────────────────────────────────────────────────────
# Seleção de alvo + HP/nível visível (motor de combate em tempo real, 02/09)
# ──────────────────────────────────────────────────────────────────────────────
# Achado ao construir isto: sem alvo selecionado, os golpes de mira única do
# Follower nunca tinham quem atacar (current_target nunca era setado por
# ninguém) — clicar/tocar no Pokémon é como o Gabriel pediu pra escolher.
var _hp_bar_bg     : ColorRect
var _hp_bar_fill   : ColorRect
var _level_label   : Label
var _status_label  : Label
const HP_BAR_WIDTH  : float = 160.0  # migração tile128 (03/09): era 40
const HP_BAR_HEIGHT : float = 20.0   # migração tile128 (03/09): era 5
const HP_BAR_Y      : float = -160.0  # migração tile128 (03/09): era -40

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
	_level_label.position = Vector2(-HP_BAR_WIDTH / 2.0, HP_BAR_Y - 56.0)
	add_child(_level_label)

	# Status persistente (03/09) — abreviação (BRN/PSN/PAR/SLP/FRZ), igual
	# convenção clássica de HUD de batalha. Vazio = sem status, label some.
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_status_label.position = Vector2(HP_BAR_WIDTH / 2.0 - 36.0, HP_BAR_Y - 56.0)
	add_child(_status_label)

	_update_health_bar()

func _update_status_label() -> void:
	if not _status_label:
		return
	var label := StatusEffectController.status_label(current_status)
	if _confused and label == "":
		label = "CNF"
	elif _confused:
		label += "/CNF"
	_status_label.text = label

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

## 1/4096, taxa clássica de shiny — achado ao mexer nisso (sessão anterior):
## o jogo já tinha o CAMPO "is_shiny" no save (BattlePokemon.gd) desde
## antes, mas nunca em lugar nenhum ele era de fato sorteado. Revisão de
## lore (03/09): mesmo sorteado, shiny não tinha NENHUM propósito
## jogável — cosmético puro, sem gancho de gameplay pra "caçar shiny" valer
## a pena de verdade. O Pokéradar/Pokéradar Avançado (itens que já existiam
## em quests.json como recompensa, mas nunca tinham definição nem efeito)
## agora fazem exatamente isso: possuir um deles aumenta a chance de
## verdade, enquanto durar a posse do item — sem precisar de mecanismo de
## "combo"/chain como o jogo real, mantendo simples.
const SHINY_CHANCE                    : float = 1.0 / 4096.0
const SHINY_CHANCE_POKERADAR          : float = 1.0 / 512.0
const SHINY_CHANCE_POKERADAR_AVANCADO : float = 1.0 / 256.0
var is_shiny : bool = false

func _load_species() -> void:
	species_data = GameData.get_species(species_id)
	if species_data.is_empty():
		push_warning("[WildPokemon] Espécie %d não encontrada." % species_id)
		return
	is_shiny = RNGManager.chance(_shiny_chance_efetiva())

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

func _shiny_chance_efetiva() -> float:
	if SaveManager.has_item("pokeradar_advanced", 1):
		return SHINY_CHANCE_POKERADAR_AVANCADO
	if SaveManager.has_item("pokeradar", 1):
		return SHINY_CHANCE_POKERADAR
	return SHINY_CHANCE

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
	var nome : String = move_data.get("name", "")
	var attacker_stats := _attacker_stats()
	var total_dealt := 0
	for a in _recent_attackers:
		if is_instance_valid(a) and a.has_method("take_damage"):
			var defender_stats : Dictionary = a.get_combat_stats() if a.has_method("get_combat_stats") else {}
			var dmg : int = DamageCalculator.calculate_damage(move_data, attacker_stats, defender_stats)
			a.take_damage(dmg, self)
			total_dealt += dmg
			FloatingText.show_text(get_tree().current_scene, a.global_position + Vector2(0, -184), "%s -%d" % [nome, dmg], Color(0.6, 1.0, 0.4))
	if total_dealt > 0:
		current_hp = mini(max_hp, current_hp + total_dealt)
		_update_health_bar()
		FloatingText.show_text(get_tree().current_scene, global_position + Vector2(0, -184), "+%d" % total_dealt, Color(0.4, 1.0, 0.4))

func _fire_passive_reflect() -> void:
	if _recent_attackers.is_empty() or _passive_dmg_since <= 0:
		return
	var alvo = _recent_attackers[_recent_attackers.size() - 1]  # atacante mais recente
	if is_instance_valid(alvo) and alvo.has_method("take_damage"):
		alvo.take_damage(_passive_dmg_since, self)
		FloatingText.show_text(get_tree().current_scene, alvo.global_position + Vector2(0, -184), "Reflexo! -%d" % _passive_dmg_since, Color(0.8, 0.6, 1.0))

# ──────────────────────────────────────────────────────────────────────────────
# Loop principal
# ──────────────────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_find_target()
	_attack_cd = max(0.0, _attack_cd - delta)
	_tick_passive(delta)
	_tick_status(delta)

	# Sono/congelado: incapaz de agir, nem persegue nem ataca nem foge —
	# fica parado até acordar/degelar (StatusEffectController.is_incapacitated).
	if StatusEffectController.is_incapacitated(current_status):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	match state:
		State.PATROL: _tick_patrol(delta)
		State.CHASE:  _tick_chase()
		State.ATTACK: _tick_attack()

# ──────────────────────────────────────────────────────────────────────────────
# Status persistente (Onda 1, item 5, 03/09) — ver StatusEffectController.gd
# ──────────────────────────────────────────────────────────────────────────────

func _tick_status(delta: float) -> void:
	if _confused:
		_confuse_timer -= delta
		if _confuse_timer <= 0.0:
			_confused = false
			_update_status_label()

	match current_status:
		"sleep":
			_sleep_timer -= delta
			if _sleep_timer <= 0.0:
				current_status = "none"
				_update_status_label()
			return  # sono não tem dano de fim-de-turno, só a checagem acima
		"none":
			return

	_status_tick_timer -= delta
	if _status_tick_timer > 0.0:
		return
	_status_tick_timer = StatusEffectController.TURN_SECONDS

	match current_status:
		"freeze":
			if StatusEffectController.should_thaw():
				current_status = "none"
				_update_status_label()
		"burn", "poison":
			_apply_status_damage(StatusEffectController.tick_damage(current_status, max_hp, 0))
		"bad_poison":
			_bad_poison_stacks += 1
			_apply_status_damage(StatusEffectController.tick_damage(current_status, max_hp, _bad_poison_stacks))

func _apply_status_damage(dmg: int) -> void:
	if dmg <= 0 or state == State.DEAD:
		return
	current_hp = max(0, current_hp - dmg)
	EventBus.wild_pokemon_hp_changed.emit(self, current_hp, max_hp)
	_update_health_bar()
	FloatingText.show_text(get_tree().current_scene, global_position + Vector2(0, -184),
		"%s -%d" % [StatusEffectController.status_label(current_status), dmg], Color(0.8, 0.5, 1.0))
	if current_hp <= 0:
		_die()

## Chamado por StatusEffectController.try_apply() quando ESTE Pokémon é o
## alvo de um golpe com efeito de status/confusão — nunca chamado direto por
## fora (a chance/checagem já foi resolvida lá).
func apply_move_effect(effect: String, default_chance: int) -> void:
	if state == State.DEAD:
		return
	var confuse_chance := StatusEffectController.resolve_confuse_effect(effect, default_chance)
	if confuse_chance > 0 and not _confused and RNGManager.chance(confuse_chance / 100.0):
		_confused      = true
		_confuse_timer = StatusEffectController.roll_confuse_duration()
		FloatingText.show_text(get_tree().current_scene, global_position + Vector2(0, -184), "Confuso!", Color(0.9, 0.5, 0.9))
		_update_status_label()

	var resolved := StatusEffectController.resolve_status_effect(effect, default_chance)
	if resolved.is_empty() or current_status != "none":
		return
	if not RNGManager.chance(int(resolved["chance"]) / 100.0):
		return
	current_status     = resolved["status"]
	_bad_poison_stacks = 0
	if current_status == "sleep":
		_sleep_timer = StatusEffectController.roll_sleep_duration()
	_status_tick_timer = StatusEffectController.TURN_SECONDS
	FloatingText.show_text(get_tree().current_scene, global_position + Vector2(0, -184),
		StatusEffectController.status_label(current_status) + "!", Color(1.0, 0.85, 0.3))
	_update_status_label()

## Confusão: chance de bater em si mesmo em vez de agir (mesma fórmula de
## BattleManager._confusion_self_damage — golpe físico potência 40, sem
## STAB/tipo, contra a própria defesa).
func _hit_self_confused() -> void:
	var dmg : float = (2.0 * wild_level / 5.0 + 2.0) * 40.0 * float(atk_stat) / float(max(1, def_stat)) / 50.0 + 2.0
	_apply_status_damage(maxi(1, roundi(dmg)))
	FloatingText.show_text(get_tree().current_scene, global_position + Vector2(0, -220), "Confuso!", Color(0.9, 0.5, 0.9))

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

	# Paralisia: chance por TENTATIVA de falhar o golpe inteiro (mesma regra
	# de BattlePokemon.can_move() — 25%, StatusEffectController.03/09).
	if current_status == "paralysis" and StatusEffectController.should_paralysis_fail():
		FloatingText.show_text(get_tree().current_scene, global_position + Vector2(0, -184), "Paralisado!", Color(1.0, 0.85, 0.3))
		return
	# Confusão: chance de acertar a si mesmo em vez de agir (mesma ordem do
	# combate por turno — checa paralisia primeiro, confusão depois).
	if _confused and StatusEffectController.should_confuse_self_hit():
		_hit_self_confused()
		return

	if default_move.get("target_type", "single") == "area":
		_apply_damage_area(default_move)
		return

	if target and target.has_method("take_damage"):
		var attacker_stats := _attacker_stats()
		var defender_stats : Dictionary = {}
		if target.has_method("get_combat_stats"):
			defender_stats = target.get_combat_stats()
		# Golpe puro de status (ex: Thunder Wave, power=0) não causa dano
		# nenhum — só o efeito, aplicado abaixo via StatusEffectController.
		if default_move.get("category", "physical") != "status":
			var damage := DamageCalculator.calculate_damage(default_move, attacker_stats, defender_stats)
			target.take_damage(damage, self)
			FloatingText.show_text(get_tree().current_scene, target.global_position + Vector2(0, -184), "%s -%d" % [default_move.get("name", ""), damage], Color(1.0, 0.4, 0.4))
		StatusEffectController.try_apply(target, default_move)

## Mesmo formato de attacker_stats usado no ataque direto, na área e na
## passiva — centralizado aqui pra não divergir. "status" (03/09): usado por
## DamageCalculator pro bônus de Guts e pra halving de queima em golpe físico.
func _attacker_stats() -> Dictionary:
	return {
		"atk": atk_stat, "level": wild_level,
		"ability": species_data.get("ability", ""), "hp_ratio": get_hp_ratio(),
		"status": current_status,
	}

## Golpe de área: bate em Follower + Treinador (os únicos alvos válidos de um
## selvagem) dentro do raio, a partir da própria posição — não depende de
## `target` travado, diferente do ataque single-target.
func _apply_damage_area(move_data: Dictionary) -> void:
	var radius : float = move_data.get("radius", 0.0)
	var alvos  : Array  = AreaTargeting.find_targets_in_radius(global_position, radius, ["follower_pokemon", "player"])
	var attacker_stats := _attacker_stats()
	var nome : String = move_data.get("name", "")
	var is_status_move : bool = move_data.get("category", "physical") == "status"
	for alvo in alvos:
		if not alvo.has_method("take_damage"):
			continue
		if not is_status_move:
			var defender_stats : Dictionary = alvo.get_combat_stats() if alvo.has_method("get_combat_stats") else {}
			var dmg : int = DamageCalculator.calculate_damage(move_data, attacker_stats, defender_stats)
			alvo.take_damage(dmg, self)
			FloatingText.show_text(get_tree().current_scene, alvo.global_position + Vector2(0, -184), "%s -%d" % [nome, dmg], Color(1.0, 0.4, 0.4))
		StatusEffectController.try_apply(alvo, move_data)

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
	# Fase 5/7 do motor de combate em tempo real (02/09): XP/level-up/loot/
	# Pokédex/sinal de quest vêm de BattleResolver — mesma fórmula que o
	# combate por turno já usava. Pokémon de treinador não dá loot nem conta
	# na Pokédex (não é selvagem) e avisa o NPC dono pra mandar o próximo da
	# equipe (ou marcar derrotado, se era o último).
	if is_trainer_owned:
		BattleResolver.resolve_trainer_pokemon_defeat(species_id, wild_level, species_data.get("name", ""), trainer_npc)
		if trainer_npc and trainer_npc.has_method("_on_trainer_pokemon_defeated"):
			trainer_npc._on_trainer_pokemon_defeated()
	else:
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

## Timestamp (Time.get_ticks_msec) de quando o encontro atual começou — -1 =
## nunca engajou ainda (ou o encontro anterior já terminou). Usado só pela
## Bola Rápida/Bola Tempo (CaptureSystem.gd, Onda 1 item 6, 03/09) pra saber
## "há quanto tempo estamos nisso", sem inventar um sistema de turno próprio.
var engaged_at_msec : int = -1

func _set_state(new_state: State) -> void:
	var prev := state
	state = new_state
	# Fase 7 do motor de combate em tempo real (02/09): quando entra em ATTACK
	# pela primeira vez, o combate já acontece sozinho no mapa (hitbox/hurtbox/
	# take_damage, sem trocar de tela) — NÃO aciona mais o BattleManager, exceto
	# na Zona Safari, que continua por turno de propósito (isca/pedra/bolas
	# limitadas são uma mecânica só dela, ainda não portada pro tempo real).
	# wild_pokemon_engaged é só cosmético (câmera/SFX), pra QUALQUER encontro.
	if new_state == State.ATTACK and prev != State.ATTACK and not _encounter_triggered:
		_encounter_triggered = true
		engaged_at_msec = Time.get_ticks_msec()
		EventBus.wild_pokemon_engaged.emit(self)
		if zone_id == BattleManager.SAFARI_ZONE_ID:
			EventBus.wild_encounter_started.emit(self)
	# Reset do flag quando sai do ATTACK (ex: para PATROL/DEAD)
	if prev == State.ATTACK and new_state != State.ATTACK:
		_encounter_triggered = false
		engaged_at_msec = -1

func _get_move_speed() -> float:
	var speed := BASE_MOVE_SPEED + (speed_stat * 0.8)
	return speed * StatusEffectController.speed_multiplier(current_status)

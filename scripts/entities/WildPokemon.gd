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

## 🔴 11/09: estas constantes viraram a régua central (`CombatBalance`) — o
## raio de detecção agora depende da PERSONALIDADE do bicho e o alcance de
## ataque depende do GOLPE dele, não de um número igual pra todo mundo. Os
## nomes seguem aqui porque cena e teste antigos leem daqui.
const WILD_DETECT_RADIUS : float = CombatBalance.AGGRO_RADIUS_TILES * CombatBalance.TILE_PX
const WILD_ATTACK_RADIUS : float = 384.0  # só como piso, ver _alcance_de_ataque()
const ALPHA_HP_MULT      : float = CombatBalance.ALPHA_HP_MULT
const ALPHA_ATK_MULT     : float = CombatBalance.ALPHA_ATK_MULT
const ALPHA_DEF_MULT     : float = CombatBalance.ALPHA_DEF_MULT
const ALPHA_SPD_MULT     : float = CombatBalance.ALPHA_SPD_MULT

const PATROL_INTERVAL_MIN : float = 2.0
const PATROL_INTERVAL_MAX : float = 4.0
const BASE_MOVE_SPEED     : float = 640.0  # migração tile128 (03/09): era 160 pro tile de 32px

# ──────────────────────────────────────────────────────────────────────────────
# FSM
# ──────────────────────────────────────────────────────────────────────────────

## 🔴 11/09: dois estados novos. RETORNAR é a coleira (item 26) — antes um
## selvagem em CHASE perseguia até o fim do mapa, porque a coleira só existia
## na patrulha. FUGIR é a personalidade FUGITIVO e o "correr quando está quase
## morrendo" (item 24), que antes só acontecia dentro do PATROL.
enum State { PATROL, CHASE, ATTACK, DEAD, RETORNAR, FUGIR }

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
## 🔴 11/09: os dois stats especiais. Existiam em species.json desde sempre e
## nunca chegavam ao combate — todo Pokémon especial atacava com o físico.
var spa_stat      : int   = 0
var spd_stat      : int   = 0
var speed_stat    : int   = 0
## Nature sorteada no nascimento: +10% num stat, -10% em outro. O selvagem já
## nascia com uma dentro do BattlePokemon (usado só na captura); agora ela
## vale na LUTA também, e é a mesma que vai pro save se ele for capturado.
var nature        : String = ""
var ivs           : Dictionary = {}
## Personalidade normalizada (as 7 do item 24). `behavior` continua guardando
## o rótulo cru que veio do dado.
var personalidade : String = ComportamentoSelvagem.DEFENSIVO
var catch_rate    : int   = 45   # fallback
var types         : Array = []

## Move padrão desta espécie (primeiro do learnset ou fallback)
## 🔴 11/09: o selvagem tinha UM golpe — `default_move`, sempre o PRIMEIRO
## aprendível da espécie, que é quase sempre o Tackle/Scratch de nível 1. Um
## Alakazam selvagem de nível 50 atacava com o golpe de nível 1. Agora tem
## até 4, cada um com sua recarga, e escolhe qual usar pela distância.
var golpes        : Array = []              ## até 4 Dictionary de moves.json
var recargas      : Array = [0.0, 0.0, 0.0, 0.0]
var default_move  : Dictionary = {}         ## o primeiro de `golpes` — compatibilidade
var _attack_cd    : float = 0.0             ## trava global entre golpes (anti-metralhadora)

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

## Y da barra de vida: logo ACIMA da cabeça, calculado a partir da escala da
## espécie. Antes era HP_BAR_Y fixo (-160), calibrado quando todo Pokémon
## preenchia o frame inteiro — com escala por espécie e pé alinhado, a barra
## ficava boiando bem longe dos pequenos (visto em jogo, 04/09).
func _y_da_barra() -> float:
	var escala : float = PokemonScale.get_visual_scale(species_id)
	return PokemonScale.topo_do_corpo(SPRITE_BASE_OFFSET_Y, escala) - 14.0

## Largura da barra acompanha o TAMANHO do Pokémon (04/09). Era fixa em 160px —
## mais larga que um tile inteiro. Num Slowpoke pequeno a barra passava dos dois
## lados do bicho e, com o jogador ao lado, ia parar visualmente sobre a cabeça
## do TREINADOR: no teste em tela parecia a vida do jogador, não a do selvagem.
func _largura_da_barra() -> float:
	var escala : float = PokemonScale.get_visual_scale(species_id)
	return clampf(96.0 * escala, 64.0, 160.0)

func _build_health_bar() -> void:
	var larg := _largura_da_barra()
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color = Color(0.1, 0.1, 0.1, 0.8)
	_hp_bar_bg.size = Vector2(larg, HP_BAR_HEIGHT)
	_hp_bar_bg.position = Vector2(-larg / 2.0, _y_da_barra())
	add_child(_hp_bar_bg)

	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.color = Color(0.2, 0.85, 0.2)
	_hp_bar_fill.size = Vector2(larg, HP_BAR_HEIGHT)
	_hp_bar_bg.add_child(_hp_bar_fill)

	# Nome + nível: sem o NOME, a criança via "Lv.6" e não sabia de quem era.
	_level_label = Label.new()
	_level_label.text = _texto_do_rotulo()
	_level_label.add_theme_font_size_override("font_size", 12)
	_level_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_level_label.add_theme_constant_override("outline_size", 4)
	# centralizado sobre o BICHO, não ancorado na ponta esquerda da barra
	_level_label.size = Vector2(larg * 2.0, 18)
	_level_label.position = Vector2(-larg, _y_da_barra() - 30.0)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_level_label)

	# Status persistente (03/09) — abreviação (BRN/PSN/PAR/SLP/FRZ), igual
	# convenção clássica de HUD de batalha. Vazio = sem status, label some.
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_status_label.position = Vector2(_largura_da_barra() / 2.0 - 36.0, _y_da_barra() - 48.0)
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

## Nome, nível e vida atual/máxima (item 22 do pedido). A vida SÓ aparece
## depois do primeiro dano — antes disso "Beedrill Nv.28" é o que interessa, e
## um "84/84" em cada bicho da tela vira poluição.
func _texto_do_rotulo() -> String:
	var cabeca := "%s  Nv.%d" % [_nome_da_especie(), wild_level]
	if max_hp > 0 and current_hp < max_hp:
		return "%s   %d/%d" % [cabeca, current_hp, max_hp]
	return cabeca

func _update_health_bar() -> void:
	if _level_label:
		_level_label.text = _texto_do_rotulo()
	if not _hp_bar_fill or max_hp <= 0:
		return
	var ratio : float = clampf(float(current_hp) / float(max_hp), 0.0, 1.0)
	_hp_bar_fill.size.x = _largura_da_barra() * ratio
	# Verde -> amarelo -> vermelho, igual convenção clássica de barra de vida.
	if ratio > 0.5:
		_hp_bar_fill.color = Color(0.2, 0.85, 0.2)
	elif ratio > 0.2:
		_hp_bar_fill.color = Color(0.9, 0.8, 0.1)
	else:
		_hp_bar_fill.color = Color(0.85, 0.2, 0.2)

func _on_hurtbox_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var clicou : bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not clicou:
		return
	# Corpo desmaiado (09/09, pedido do Gabriel: "clique na Pokébola escolhida
	# e um clique no Pokémon atordoado como alvo") — sinal PRÓPRIO, nunca
	# wild_pokemon_selected: aquele é pra mirar combate, e não faz sentido
	# "engajar" um corpo já caído.
	if state == State.DEAD:
		if esta_desmaiado():
			EventBus.corpo_desmaiado_clicado.emit(self)
		return
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

	# 🔴 11/09: os SEIS stats, com nature e IV sorteados — a mesma fórmula do
	# Pokémon do jogador e do save (`StatsDePokemon`). Antes eram três stats
	# por uma fórmula própria, e o HP do selvagem não batia com o do menu.
	nature = GameData.roll_random_nature()
	ivs = StatsDePokemon.sortear_ivs()
	var stats : Dictionary = StatsDePokemon.conjunto(base, wild_level, nature, ivs)
	max_hp     = int(stats["hp"])
	atk_stat   = int(stats["atk"])
	def_stat   = int(stats["def"])
	spa_stat   = int(stats["spa"])
	spd_stat   = int(stats["spd"])
	speed_stat = int(stats["spe"])

	# Personalidade: o rótulo da espécie, a não ser que a zona/spawn tenha
	# mandado outro (aí `behavior` já veio preenchido pelo initialize).
	var rotulo : String = behavior if not behavior.is_empty() else str(species_data.get("behavior", "neutral"))
	personalidade = ComportamentoSelvagem.normalizar(rotulo)

	if is_alpha:
		max_hp     = int(max_hp    * ALPHA_HP_MULT)
		atk_stat   = int(atk_stat  * ALPHA_ATK_MULT)
		def_stat   = int(def_stat  * ALPHA_DEF_MULT)
		spa_stat   = int(spa_stat  * ALPHA_ATK_MULT)
		spd_stat   = int(spd_stat  * ALPHA_DEF_MULT)
		speed_stat = int(speed_stat * ALPHA_SPD_MULT)

	current_hp = max_hp
	_montar_golpes()

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
			FloatingText.show_text(get_tree().current_scene, a.global_position + Vector2(0, -184), nome, Color(0.6, 1.0, 0.4))
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
		FloatingText.show_text(get_tree().current_scene, alvo.global_position + Vector2(0, -184), "Reflexo!", Color(0.8, 0.6, 1.0))

# ──────────────────────────────────────────────────────────────────────────────
# Loop principal
# ──────────────────────────────────────────────────────────────────────────────

## Move respeitando os tiles bloqueados (árvore/parede/água), usando a MESMA
## fonte de verdade do jogador (WorldManager.is_tile_walkable). Antes de 04/09
## estas entidades chamavam move_and_slide() cru e atravessavam tudo — o
## TileSet não tem camada de física, então não havia nada segurando.
## PE_OFFSET: a origem do nó fica acima do chão; o contato com o solo (e a
## sombra) está +24px abaixo, e é ESSE ponto que decide em qual tile a
## entidade está.
const PE_OFFSET : Vector2 = Vector2(0, 24)

# ──────────────────────────────────────────────────────────────────────────────
# Empurrão (knockback) — ver Empurrao.gd
# ──────────────────────────────────────────────────────────────────────────────
## Estado puro, sem timer e sem nó novo: o `_physics_process` que já roda
## consome isto. Enquanto `_empurrao_restante > 0`, o movimento normal cede a
## vez pro empurrão.
var _empurrao_restante : float = 0.0
var _empurrao_direcao  : Vector2 = Vector2.ZERO
var _empurrao_veloc    : float = 0.0

func receber_empurrao(direcao: Vector2, distancia_px: float) -> void:
	if distancia_px <= 0.0 or direcao.length_squared() <= 0.0:
		return
	_empurrao_direcao  = direcao.normalized()
	_empurrao_restante = Empurrao.DURACAO_SEG
	_empurrao_veloc    = distancia_px / Empurrao.DURACAO_SEG

## true enquanto estiver sendo empurrado — e já move o corpo neste quadro.
## O movimento usa o MESMO caminho de sempre (`_mover_com_colisao`), então
## parede, pedra, água e limite de mapa param o empurrão exatamente como param
## um passo normal. Nada atravessa nada.
func _consumiu_empurrao(delta: float) -> bool:
	if _empurrao_restante <= 0.0:
		return false
	_empurrao_restante -= delta
	velocity = _empurrao_direcao * _empurrao_veloc
	_mover_com_colisao()
	return true

func _mover_com_colisao() -> void:
	velocity = WorldManager.filtrar_velocidade(global_position + PE_OFFSET, velocity)
	move_and_slide()

## 🔴 11/09 (item 41: separar lógica de combate do quadro visual). Procurar
## alvo e decidir o que fazer NÃO precisa acontecer 60 vezes por segundo — com
## o teto de 60 selvagens ativos isso eram 3.600 buscas de alvo por segundo, e
## cada busca varre dois grupos inteiros da árvore. Agora a DECISÃO roda a cada
## COMBAT_TICK_SEC (0,2s) e o MOVIMENTO continua a 60 FPS, que é o que o olho
## vê. O jogador não percebe a diferença; o processador percebe.
var _relogio_de_combate : float = 0.0

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_attack_cd = max(0.0, _attack_cd - delta)
	for i in recargas.size():
		recargas[i] = max(0.0, float(recargas[i]) - delta)
	_tick_passive(delta)
	_tick_status(delta)

	# Empurrão tem prioridade sobre andar: quem levou um Tornado vai pra trás,
	# não continua marchando pra frente no mesmo quadro.
	if _consumiu_empurrao(delta):
		return

	_relogio_de_combate -= delta
	if _relogio_de_combate <= 0.0:
		_relogio_de_combate = CombatBalance.COMBAT_TICK_SEC
		_find_target()
		_decidir()

	# Sono/congelado: incapaz de agir, nem persegue nem ataca nem foge —
	# fica parado até acordar/degelar (StatusEffectController.is_incapacitated).
	if StatusEffectController.is_incapacitated(current_status):
		velocity = Vector2.ZERO
		_mover_com_colisao()
		return

	match state:
		State.PATROL:   _tick_patrol(delta)
		State.CHASE:    _tick_chase()
		State.ATTACK:   _tick_attack()
		State.RETORNAR: _tick_retornar(delta)
		State.FUGIR:    _tick_fugir()

## O cérebro, uma vez a cada tick de combate. Só TROCA DE ESTADO — quem anda e
## quem bate são os `_tick_*`. Ordem de prioridade, de cima pra baixo:
## coleira → fuga → briga → paz.
func _decidir() -> void:
	if state == State.DEAD:
		return

	# 1. Estourou a coleira? Volta pra casa, e não tem conversa (item 26).
	var longe_de_casa : float = global_position.distance_to(_spawn_pos)
	if state in [State.CHASE, State.ATTACK] \
			and longe_de_casa > ComportamentoSelvagem.raio_de_coleira(personalidade):
		_set_state(State.RETORNAR)
		return
	if state == State.RETORNAR:
		if longe_de_casa <= CombatBalance.TILE_PX * 1.5:
			_set_state(State.PATROL)
		return

	# 2. Machucado demais (ou fugitivo por natureza)? Corre.
	if state in [State.CHASE, State.ATTACK] \
			and ComportamentoSelvagem.deve_fugir(personalidade, get_hp_ratio()):
		_set_state(State.FUGIR)
		return
	if state == State.FUGIR:
		if target == null or global_position.distance_to(target.global_position) \
				> ComportamentoSelvagem.raio_de_aggro(personalidade) * 2.0:
			_set_state(State.RETORNAR)
		return

	if target == null:
		if state != State.PATROL:
			_set_state(State.PATROL)
		return

	var dist : float = global_position.distance_to(target.global_position)

	# 3. Em paz: percebe o jogador?
	if state == State.PATROL:
		if not ComportamentoSelvagem.comeca_briga(personalidade):
			if ComportamentoSelvagem.foge_sempre(personalidade) \
					and dist <= ComportamentoSelvagem.raio_de_aggro(personalidade):
				_set_state(State.FUGIR)
			return
		if dist <= ComportamentoSelvagem.raio_de_aggro(personalidade):
			_entrar_em_briga(0)
		return

	# 4. Já brigando: perto o bastante pra bater, ou tem que correr atrás?
	var alcance : float = _alcance_de_ataque()
	if state == State.CHASE and dist <= alcance:
		_set_state(State.ATTACK)
	elif state == State.ATTACK and dist > alcance * 1.15:
		# A folga de 15% evita o bicho ficar piscando entre CHASE e ATTACK
		# quando o jogador anda exatamente na borda do alcance.
		_set_state(State.CHASE)

## Até onde eu consigo bater: o alcance do meu golpe mais longo. Antes era uma
## constante igual pra todo mundo, então um Onix corpo a corpo e um Alakazam
## de feixe paravam à mesma distância do jogador.
func _alcance_de_ataque() -> float:
	return maxf(ComportamentoSelvagem.alcance_util(golpes), CombatBalance.TILE_PX * 1.2)

## Entra em briga — e, se for bicho de bando, GRITA (item 25).
##
## `saltos` é o que impede a corrente do item 27: quem entrou por conta
## própria grita com saltos=0; quem foi CHAMADO entra com saltos=1 e não
## chama mais ninguém. Sem isso, um Beedrill acorda o mapa inteiro.
func _entrar_em_briga(saltos: int) -> void:
	_set_state(State.CHASE)
	if saltos > 0 or not ComportamentoSelvagem.chama_o_bando(personalidade):
		return
	var vizinhos : Array = ComportamentoSelvagem.quem_ouve_o_grito(
		self, get_tree().get_nodes_in_group("wild_pokemon"), species_id, saltos)
	for v in vizinhos:
		if v.has_method("responder_ao_grito"):
			v.responder_ao_grito(self, saltos + 1)

## Chamado por um companheiro de bando. Só responde quem está em paz — quem já
## está brigando ou fugindo tem problema próprio.
func responder_ao_grito(quem_gritou: Node2D, saltos: int) -> void:
	if state != State.PATROL or quem_gritou == null:
		return
	_find_target()
	if target == null:
		return
	# Chega com atraso: o bando ataca em ONDA, não em bloco (ver a medição em
	# CombatBalance.ATRASO_DO_BANDO_MIN).
	_attack_cd = maxf(_attack_cd, RNGManager.randf_range(
		CombatBalance.ATRASO_DO_BANDO_MIN, CombatBalance.ATRASO_DO_BANDO_MAX))
	_entrar_em_briga(saltos)

## Volta pra casa e se cura no caminho (item 26: "pode recuperar HP"). É o que
## faz valer a pena fugir de um bicho forte em vez de morrer — e o que impede
## o jogador de sangrar um alpha em 10 idas e voltas.
func _tick_retornar(delta: float) -> void:
	var para_casa : Vector2 = (_spawn_pos - global_position)
	if para_casa.length() <= CombatBalance.TILE_PX * 1.5:
		velocity = Vector2.ZERO
		_mover_com_colisao()
		return
	velocity = para_casa.normalized() * _get_move_speed()
	_mover_com_colisao()

	if current_hp < max_hp:
		_regen_acumulado += float(max_hp) * CombatBalance.REGEN_NA_COLEIRA_POR_SEG * delta
		if _regen_acumulado >= 1.0:
			var ganho : int = int(_regen_acumulado)
			_regen_acumulado -= float(ganho)
			current_hp = mini(max_hp, current_hp + ganho)
			EventBus.wild_pokemon_hp_changed.emit(self, current_hp, max_hp)
			_update_health_bar()

var _regen_acumulado : float = 0.0

## Corre na direção oposta ao alvo, mais rápido que o normal.
func _tick_fugir() -> void:
	if target == null:
		velocity = Vector2.ZERO
		_mover_com_colisao()
		return
	var longe := (global_position - target.global_position).normalized()
	velocity = longe * _get_move_speed() * 1.5
	_mover_com_colisao()

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

## 🔴 Fase 2: era "o primeiro Follower vivo que eu achar na lista" — a ordem
## da árvore de cena decidia a briga. Agora cada candidato recebe uma nota
## (distância, se me bateu, vida, invasão de território, Pokémon antes do
## treinador) e o maior ganha. Ver `ComportamentoSelvagem.nota_do_alvo`.
func _find_target() -> void:
	var candidatos : Array = []

	for f in get_tree().get_nodes_in_group("follower_pokemon"):
		if not (f is Node2D) or not is_instance_valid(f):
			continue
		if f.has_method("is_fainted") and f.is_fainted():
			continue
		candidatos.append(_ficha_de_alvo(f, false))

	for pl in get_tree().get_nodes_in_group("player"):
		if not (pl is Node2D) or not is_instance_valid(pl):
			continue
		candidatos.append(_ficha_de_alvo(pl, true))

	if candidatos.is_empty():
		target = null
		return
	target = ComportamentoSelvagem.escolher_alvo(
		candidatos, personalidade, global_position, _spawn_pos)

## O que a nota precisa saber sobre um candidato a alvo.
func _ficha_de_alvo(no: Node2D, e_treinador: bool) -> Dictionary:
	var fracao : float = 1.0
	if no.has_method("get_hp_ratio"):
		fracao = float(no.get_hp_ratio())
	elif no.has_method("get_combat_stats"):
		var cs : Dictionary = no.get_combat_stats()
		var mx : int = int(cs.get("max_hp", 0))
		if mx > 0:
			fracao = float(cs.get("hp", mx)) / float(mx)
	return {
		"no": no,
		"distancia": global_position.distance_to(no.global_position),
		"me_atacou": no in _recent_attackers,
		"fracao_vida": fracao,
		"e_treinador": e_treinador,
	}

# ──────────────────────────────────────────────────────────────────────────────
# PATROL
# ──────────────────────────────────────────────────────────────────────────────

func _tick_patrol(delta: float) -> void:
	_patrol_timer -= delta
	if _patrol_timer <= 0.0:
		_pick_patrol_dir()

	# 🔴 11/09: a DECISÃO de perseguir/fugir saiu daqui e foi pro `_decidir()`,
	# que roda no tick de combate e conhece as 7 personalidades. Aqui ficou só
	# o passeio — que é movimento, e movimento continua a 60 FPS.
	var move_speed := _get_move_speed()
	velocity = _patrol_dir * move_speed
	_mover_com_colisao()

## Coleira (03/09, spawn fixo por terreno): sem isso, um passeio 100%
## aleatório pode, com tempo suficiente, sair da própria área de terreno
## (um Oddish saindo da grama pro meio da estrada). Fora do raio, a direção
## sorteada vira "de volta pra casa" (com uma variação, pra não parecer um
## trilho reto) em vez de mais uma direção qualquer.
const LEASH_RADIUS_TILES : float = CombatBalance.PATROL_LEASH_TILES

func _pick_patrol_dir() -> void:
	_patrol_timer = RNGManager.randf_range(PATROL_INTERVAL_MIN, PATROL_INTERVAL_MAX)
	var leash_px : float = LEASH_RADIUS_TILES * 128.0
	if _spawn_pos != Vector2.ZERO and global_position.distance_to(_spawn_pos) > leash_px:
		var para_casa := (_spawn_pos - global_position).normalized()
		_patrol_dir = para_casa.rotated(RNGManager.randf_range(-0.6, 0.6))
	else:
		var angle := RNGManager.randf_range(0.0, TAU)
		_patrol_dir = Vector2(cos(angle), sin(angle))

func _flee_from_target() -> void:
	if not target:
		return
	var away := (global_position - target.global_position).normalized()
	velocity  = away * _get_move_speed() * 1.5
	_mover_com_colisao()

# ──────────────────────────────────────────────────────────────────────────────
# CHASE
# ──────────────────────────────────────────────────────────────────────────────

## Só corre atrás. Quando parar de correr e começar a bater é decisão do
## `_decidir()` — aqui não se troca mais de estado, pra não existirem dois
## lugares decidindo a mesma coisa com réguas diferentes.
func _tick_chase() -> void:
	if not target:
		velocity = Vector2.ZERO
		_mover_com_colisao()
		return
	var dir := (target.global_position - global_position).normalized()
	velocity = dir * _get_move_speed()
	_mover_com_colisao()

# ──────────────────────────────────────────────────────────────────────────────
# ATTACK
# ──────────────────────────────────────────────────────────────────────────────

func _tick_attack() -> void:
	velocity = Vector2.ZERO
	_mover_com_colisao()
	if not target:
		return
	if _attack_cd <= 0.0:
		_perform_attack()

## 🔴 11/09: escolhe QUAL golpe usar. Antes existia um só (`default_move`,
## sempre o de nível 1 da espécie) e o selvagem batia sempre a mesma coisa.
## A escolha é deliberadamente legível (item 29: previsibilidade > esperteza):
## entre os golpes prontos que alcançam o alvo, usa o mais forte.
func _perform_attack() -> void:
	if golpes.is_empty() or target == null:
		return
	var dist : float = global_position.distance_to(target.global_position)
	var slot : int = ComportamentoSelvagem.escolher_golpe(golpes, recargas, dist, _contexto_de_briga())
	if slot < 0:
		return   # nada pronto ou nada alcança — o `_decidir()` aproxima no próximo tick
	var move : Dictionary = golpes[slot]

	var recarga : float = CombatBalance.recarga(float(move.get("cooldown", 2.0)), speed_stat)
	recargas[slot] = recarga
	# Trava global curta entre golpes: sem ela, um bicho com 4 golpes prontos
	# dispara os 4 no mesmo quadro e mata sem o jogador ver nada acontecer.
	_attack_cd = maxf(CombatBalance.MIN_COOLDOWN_SEC, recarga * 0.5)
	_usar_golpe(move)

## `golpe` em vez de `default_move`: o parâmetro estava com o MESMO nome da
## variável de membro, o que é um convite a erro de leitura.
func _usar_golpe(golpe: Dictionary) -> void:

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

	# Tempo de conjuração: a janela em que o jogador vê o golpe vindo e pode
	# sair de perto (item 19). Golpe rápido tem cast 0 e sai na hora.
	var cast : float = float(golpe.get("cast_time", 0.0))
	if cast > 0.0:
		await get_tree().create_timer(cast).timeout
		if not is_instance_valid(self) or state == State.DEAD:
			return

	if golpe.get("target_type", "single") == "area":
		_apply_damage_area(golpe)
		return

	# O alvo saiu do alcance durante a conjuração? O golpe falha.
	if target and not FormaDeArea.no_alcance(global_position, target, golpe):
		return

	if target and target.has_method("take_damage"):
		var attacker_stats := _attacker_stats()
		var defender_stats : Dictionary = {}
		if target.has_method("get_combat_stats"):
			defender_stats = target.get_combat_stats()
		# Golpe puro de status (ex: Thunder Wave, power=0) não causa dano
		# nenhum — só o efeito, aplicado abaixo via StatusEffectController.
		if not StatusEffectController.acertou(golpe):
			FloatingText.show_text(get_tree().current_scene, global_position + Vector2(0, -184),
				"Errou!", Color(0.8, 0.8, 0.85))
			return
		var mult_tipo : float = DamageCalculator.get_type_multiplier(
			str(golpe.get("type", "Normal")), defender_stats.get("types", ["Normal"]))
		if golpe.get("category", "physical") != "status":
			var damage := DamageCalculator.calculate_damage(golpe, attacker_stats, defender_stats)
			target.take_damage(damage, self)
			FloatingText.show_text(get_tree().current_scene, global_position + Vector2(0, -184), str(golpe.get("name", "")), Color(1.0, 0.4, 0.4))
		Empurrao.aplicar(target, global_position, golpe)
		StatusEffectController.try_apply(target, golpe, mult_tipo)

## O que a escolha de golpe precisa saber da situação: contra que tipos estou,
## quão machucado está o alvo, quão machucado estou eu, e quantos alvos há
## agrupados (é isso que faz golpe de área valer a pena só quando vale).
func _contexto_de_briga() -> Dictionary:
	var tipos_do_alvo : Array = []
	var vida_do_alvo : float = 1.0
	if target and is_instance_valid(target):
		if target.has_method("get_combat_stats"):
			var cs : Dictionary = target.get_combat_stats()
			tipos_do_alvo = cs.get("types", [])
			var mx : int = int(cs.get("max_hp", 0))
			if mx > 0:
				vida_do_alvo = float(cs.get("hp", mx)) / float(mx)
	var agrupados : int = 0
	var raio : float = CombatBalance.TILE_PX * 3.0
	for grupo in ["follower_pokemon", "player"]:
		for n in get_tree().get_nodes_in_group(grupo):
			if n is Node2D and global_position.distance_to(n.global_position) <= raio:
				agrupados += 1
	return {
		"tipos_do_alvo": tipos_do_alvo,
		"fracao_vida_alvo": vida_do_alvo,
		"minha_fracao_vida": get_hp_ratio(),
		"alvos_agrupados": maxi(agrupados, 1),
	}

## Mesmo formato de attacker_stats usado no ataque direto, na área e na
## passiva — centralizado aqui pra não divergir. "status" (03/09): usado por
## DamageCalculator pro bônus de Guts e pra halving de queima em golpe físico.
func _attacker_stats() -> Dictionary:
	return {
		"atk": atk_stat, "spa": spa_stat, "level": wild_level,
		"types": types,
		"ability": species_data.get("ability", ""), "hp_ratio": get_hp_ratio(),
		"status": current_status,
	}

## Golpe de área: bate em Follower + Treinador (os únicos alvos válidos de um
## selvagem) dentro do raio, a partir da própria posição — não depende de
## `target` travado, diferente do ataque single-target.
func _apply_damage_area(move_data: Dictionary) -> void:
	var radius : float = move_data.get("radius", 0.0)
	var nome : String = move_data.get("name", "")
	var cena := get_tree().current_scene

	# Telegraph (05/09): o golpe passa a AVISAR antes de cair. O dano só sai
	# depois da janela, e mira quem está dentro do círculo NAQUELE momento —
	# quem saiu a tempo escapa. Sem isso, área é dano do nada, impossível de
	# evitar; com isso, vira decisão do jogador.
	var centro := global_position
	TelegraphDeArea.disparar(cena, centro, radius, TelegraphDeArea.cor_do_tipo(move_data.get("type", "normal")), self)
	FloatingText.show_text(cena, global_position + Vector2(0, -184), nome + "!", Color(1.0, 0.6, 0.3))
	await get_tree().create_timer(TelegraphDeArea.ATE_O_DANO).timeout
	if not is_instance_valid(self) or state == State.DEAD:
		return

	var mira : Vector2 = Vector2.RIGHT
	if target and is_instance_valid(target):
		var d : Vector2 = target.global_position - centro
		if d.length_squared() > 0.0:
			mira = d.normalized()
	var alvos : Array = FormaDeArea.alvos(centro, mira, move_data,
		["follower_pokemon", "player"], [self])
	var attacker_stats := _attacker_stats()
	var is_status_move : bool = move_data.get("category", "physical") == "status"
	for alvo in alvos:
		if not alvo.has_method("take_damage"):
			continue
		var defender_stats : Dictionary = alvo.get_combat_stats() if alvo.has_method("get_combat_stats") else {}
		if not StatusEffectController.acertou(move_data):
			continue
		var mult_tipo : float = DamageCalculator.get_type_multiplier(
			str(move_data.get("type", "Normal")), defender_stats.get("types", ["Normal"]))
		if not is_status_move:
			var dmg : int = DamageCalculator.calculate_damage(move_data, attacker_stats, defender_stats)
			alvo.take_damage(dmg, self)
		Empurrao.aplicar(alvo, centro, move_data)
		StatusEffectController.try_apply(alvo, move_data, mult_tipo)

# ──────────────────────────────────────────────────────────────────────────────
# Receber dano
# ──────────────────────────────────────────────────────────────────────────────

func take_damage(amount: int, attacker: Node = null) -> void:
	if state == State.DEAD:
		return
	current_hp = max(0, current_hp - amount)
	EventBus.damage_dealt.emit(self, amount, false, attacker)
	EventBus.wild_pokemon_hp_changed.emit(self, current_hp, max_hp)
	if attacker and not _recent_attackers.has(attacker):
		_recent_attackers.append(attacker)
	_passive_dmg_since += amount
	_update_health_bar()

	# Apanhou: qualquer personalidade reage — até o passivo, que reage FUGINDO.
	# Antes só o rótulo "neutral" reagia, então um "flee" apanhando ficava
	# parado apanhando.
	if state == State.PATROL:
		_find_target()
		if target != null:
			if ComportamentoSelvagem.deve_fugir(personalidade, get_hp_ratio()):
				_set_state(State.FUGIR)
			else:
				_entrar_em_briga(0)

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
		# Vencer o chefe paga a recompensa (MT exclusiva, contagem de limpezas)
		# — vitória é vitória. O que NÃO acontece mais aqui é gastar a chance da
		# partida: com a regra nova, derrotar é o caminho ATÉ a captura, não o
		# oposto dela. A chance só se perde se o corpo expirar sem a Pokébola
		# (ver _process, mais abaixo).
		if get_node_or_null("ChefeLendario") != null:
			RecompensasDeCovil.ao_vencer_chefe(species_id)
	EventBus.wild_pokemon_died.emit(self, [])
	EventBus.wild_pokemon_fainted.emit(self)
	# 06/09 — REGRA NOVA DO GABRIEL, vale no jogo inteiro: derrotar não faz o
	# Pokémon sumir. Ele DESMAIA e fica caído no chão, e é só aí que a Pokébola
	# funciona. Capturar deixou de ser "acertar uma bola num bicho correndo" e
	# virou o prêmio de ter vencido a luta.
	#
	# Pokémon de treinador é a exceção: aquele não é selvagem, não se captura, e
	# some como sempre — deixar o corpo dele no chão só atrapalharia a fila da
	# equipe do NPC.
	if is_trainer_owned:
		queue_free()
	else:
		_ficar_desmaiado()

# ──────────────────────────────────────────────────────────────────────────────
# Desmaiado — a janela em que a captura acontece (06/09)
# ──────────────────────────────────────────────────────────────────────────────
## Quanto tempo o corpo fica no chão antes de o Pokémon se recuperar e ir
## embora. Curto o bastante pra a decisão pesar (qual bola? tenho bola?), longo
## o bastante pra dar pra chegar perto e tentar mais de uma vez.
const SEGUNDOS_DESMAIADO : float = 25.0

var _desmaiado : bool = false
var _desmaiado_ate_msec : int = 0

func esta_desmaiado() -> bool:
	return _desmaiado

func _ficar_desmaiado() -> void:
	_desmaiado = true
	_desmaiado_ate_msec = Time.get_ticks_msec() + int(SEGUNDOS_DESMAIADO * 1000.0)
	velocity = Vector2.ZERO
	set_physics_process(false)
	# Não bate mais e não apanha mais: está fora de combate. A HurtBox continua
	# clicável de propósito — é nela que o jogador mira a Pokébola.
	if hitbox:
		hitbox.set_deferred("monitoring", false)
	# Sem arte nova: deitar o sprite e apagar a cor é a leitura universal de
	# "nocauteado", e funciona pros 151 de uma vez.
	if sprite:
		sprite.rotation = -PI / 2.0
		sprite.modulate = Color(0.65, 0.65, 0.72, 1.0)
		sprite.stop()
	if _hp_bar_bg:
		_hp_bar_bg.visible = false
	EventBus.wild_pokemon_desmaiado.emit(self)
	_avisar_captura()

func _avisar_captura() -> void:
	var cena := get_tree().current_scene if get_tree() else null
	if cena == null:
		return
	FloatingText.show_text(cena, global_position + Vector2(0, -160),
		"Desmaiado! Jogue uma Pokébola", Color(1.0, 0.95, 0.5))

## O corpo tem prazo. Rodado pelo _process (não pelo _physics_process, que foi
## desligado ao desmaiar).
func _process(_delta: float) -> void:
	if not _desmaiado:
		return
	if Time.get_ticks_msec() < _desmaiado_ate_msec:
		return
	# Acordou e foi embora. Um lendário que escapa assim gasta a chance da
	# partida — é aqui que "nasce uma vez só" passa a valer, e não mais na
	# derrota (derrotar agora é o caminho PARA capturar, não o oposto dela).
	if get_node_or_null("ChefeLendario") != null:
		NinhoLendario.marcar_derrotado(species_id)
	var cena := get_tree().current_scene if get_tree() else null
	if cena != null:
		FloatingText.show_text(cena, global_position + Vector2(0, -160),
			"%s se recuperou e fugiu!" % str(species_data.get("name", "")), Color(0.8, 0.8, 0.9))
	queue_free()

# ──────────────────────────────────────────────────────────────────────────────
# API pública
# ──────────────────────────────────────────────────────────────────────────────

## O que um atacante precisa saber sobre mim. Ganhou defesa especial, vida e
## nível: a fórmula nova usa SP_DEF em golpe especial e a vida máxima pro teto
## que impede hit-kill.
func get_combat_stats() -> Dictionary:
	return {
		"def": def_stat, "spd": spd_stat, "spe": speed_stat,
		"types": types, "level": wild_level,
		"max_hp": max_hp, "hp": current_hp,
	}

## Monta o repertório do selvagem.
##
## 🔴 Fase 2 (item 14): um selvagem comum NÃO é um mini-jogador. Ele carrega
## **até 3** golpes; um Alpha carrega 4. O jogador é quem tem o repertório
## grande (4 a 8, conforme evolução e nível — ver `KitDeCombate`), e é isso
## que faz o time dele valer mais que a soma dos stats.
##
## Antes da Fase 1 era UM golpe só, sempre o primeiro aprendível da espécie
## (quase sempre o Tackle de nível 1); na Fase 1 virou 4 pra todo mundo, o que
## era generoso demais do lado errado da mesa.
func _montar_golpes() -> void:
	var teto : int = KitDeCombate.SLOTS_SELVAGEM_ALPHA if is_alpha \
		else KitDeCombate.SLOTS_SELVAGEM_COMUM
	var ids : Array = KitDeCombate.montar(
		species_id, wild_level,
		GameData.get_learnable_moves(species_id, wild_level),
		GameData.moves, types, GameData.species, teto)

	golpes = []
	for mid in ids:
		var dados : Dictionary = GameData.get_move(str(mid))
		if not dados.is_empty():
			golpes.append(dados)

	recargas = []
	for i in maxi(golpes.size(), 1):
		recargas.append(0.0)

	default_move = golpes[0] if not golpes.is_empty() else {}

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
	# pela primeira vez, o combate acontece sozinho no mapa (hitbox/hurtbox/
	# take_damage, sem trocar de tela).
	#
	# 06/09 — pedido do Gabriel: *"não quero esse modo de batalha em nenhum
	# lugar do jogo"*, e logo depois: *"Safari também vai ser combate puro"*. O
	# motor por turno foi APAGADO do projeto e a Zona Safari deixou de ter regra
	# própria — lá se luta como em qualquer outro lugar. Não existe mais sinal
	# nenhum que troque de tela pra lutar.
	# wild_pokemon_engaged é só cosmético (câmera/SFX), pra QUALQUER encontro.
	if new_state == State.ATTACK and prev != State.ATTACK and not _encounter_triggered:
		_encounter_triggered = true
		engaged_at_msec = Time.get_ticks_msec()
		EventBus.wild_pokemon_engaged.emit(self)
	# Reset do flag quando sai do ATTACK (ex: para PATROL/DEAD)
	if prev == State.ATTACK and new_state != State.ATTACK:
		_encounter_triggered = false
		engaged_at_msec = -1

func _get_move_speed() -> float:
	var speed := BASE_MOVE_SPEED + (speed_stat * 0.8)
	return speed * StatusEffectController.speed_multiplier(current_status)

## Nome da espécie pro rótulo acima da barra de vida.
func _nome_da_especie() -> String:
	var dados : Dictionary = GameData.get_species(species_id)
	return str(dados.get("name", "?"))

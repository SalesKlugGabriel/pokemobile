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

# Follower Pokémon (FollowerPokemon.gd — continua em pixel; calcula sozinho a
# própria posição de repouso a partir de trainer.global_position/facing, ver
# FollowerPokemon._position_behind_trainer()).
var follower : Node2D = null

# ──────────────────────────────────────────────────────────────────────────────
# Mecânicas de movimentação (02/09) — 4 marchas, da mais lenta pra mais
# rápida: Andar (MOVE_DURATION/Surfar) < Bicicleta (RUN_DURATION, herdada de
# BaseEntity) < Montaria (MOUNT_DURATION) < Voar (FLY_DURATION, a mais
# rápida do jogo, pedido explícito do Gabriel). Nenhuma delas empilha —
# _get_move_duration() escolhe só a marcha mais rápida disponível no momento.
#
# is_surfing/is_flying são DERIVADOS do tile onde o jogador está (não um
# liga/desliga manual): sobe sozinho ao entrar na água (se puder) e desce
# sozinho ao voltar pra terra. Quando o time dá pra Surfar E Voar ao mesmo
# tempo, Voar ganha (mais rápido) — ver _on_tile_entered.
# is_mounted é o análogo em TERRA: ativa junto com "run" se o time tiver um
# dos Pokémon de montaria (Tauros/Dodrio/Rhyhorn/etc.), mais rápido que a
# Bicicleta — não pode as duas ligadas juntas.
# ──────────────────────────────────────────────────────────────────────────────
var is_surfing : bool = false
var is_flying  : bool = false
var is_mounted : bool = false

var _last_mode : String = "walk"

const MOUNT_DURATION : float = 0.07   # Montaria — mais rápida que a Bicicleta (0.09)
const FLY_DURATION   : float = 0.05   # Voar — a marcha mais rápida do jogo

## Pokémon de montaria (Gabriel, 02/09: "tauros, dodrio, rhyhorn, arcanine,
## ponyta, rapidash, etc") — não é golpe, é só ter o bicho no time. Sem tipo
## em comum entre eles (Normal/Voador/Terra-Pedra/Fogo), por isso é uma
## lista de espécie mesmo, não uma checagem de tipo como Surfar/Voar.
## Rhydon (112) incluído por simetria: se a pré-evolução Rhyhorn monta, a
## evolução também monta.
const MOUNT_SPECIES : Array[int] = [
	128,  # Tauros
	85,   # Dodrio
	111,  # Rhyhorn
	112,  # Rhydon
	59,   # Arcanine
	77,   # Ponyta
	78,   # Rapidash
]

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
	_init_hp()
	call_deferred("_spawn_follower")

## Sprite muda de aparência por marcha (02/09, pedido do Gabriel) — só a
## Bicicleta tem arte pronta por ora (Montaria/Surf/Voar ficam pro próximo
## lote de imagens, a lógica de marcha já funciona igual, só não muda a
## cara ainda). Bike é 256×256 (o dobro do normal, 128×128) — sprite maior
## com a MESMA caixa de colisão pequena (docs/customizacao-personagem.md já
## previa isso), por isso sprite.position.y compensa na troca (ver
## _apply_sprite_mode) senão o personagem "afunda" visualmente no chão.
const BIKE_TEXTURE_PATH : String = "res://assets/sprites/player/player_bike.png"
## Pedido do Gabriel (03/09): "personagem e NPCs podem ter 2 tiles de
## altura por 1 de largura" — player.png agora é 128×256 por quadro (corpo
## humano de verdade, não mais um quadrado achatado). O pé fica ~32px
## abaixo da origem da entidade (mesma proporção "pé um pouco abaixo do
## centro" que já existia antes da migração, só recalculada pro quadro
## mais alto) — ver conta em NORMAL_SPRITE_Y.
const NORMAL_SPRITE_Y : float = -60.0  # migração 2-tiles-altura (03/09): era -32
const BIKE_SPRITE_Y   : float = -96.0  # bike continua 256×256 (quadrado) — sem arte nova ainda

var _frames_normal : SpriteFrames
var _frames_bike    : SpriteFrames
var _sprite_mode    : String = "normal"

func _load_sprites() -> void:
	if sprite and not sprite.sprite_frames:
		_frames_normal = SpriteBuilder.build_entity_frames(
			"res://assets/sprites/player/player.png", 128, 256
		)
		if ResourceLoader.exists(BIKE_TEXTURE_PATH):
			_frames_bike = SpriteBuilder.build_entity_frames(BIKE_TEXTURE_PATH, 256)
		sprite.sprite_frames = _frames_normal
		# Migração tile128 (03/09): player.png/player_bike.png foram
		# reamostradas pra 128px/256px nativos (o tamanho final, igual ao
		# tile) — escala fica em 1.0, sem precisar mais do "2x na marra"
		# que compensava a arte antiga de 16px.
		sprite.scale = Vector2(1.0, 1.0)
		sprite.play("idle_down")
		_add_visibility_shadow()

## Melhoria de visibilidade (02/09, pedido do Gabriel) — o Treinador não
## tinha NENHUM contraste com o chão embaixo dele; num mapa com grama/
## caminho/água de cores parecidas, o personagem se perdia visualmente.
## Sombra oval simples, sem precisar de arte nova (só um degradê radial
## construído em código) — resolve a visibilidade sem depender da cota da
## ferramenta de imagem, que hoje está travada.
func _add_visibility_shadow() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.65))
	grad.add_point(0.7, Color(0, 0, 0, 0.45))
	grad.set_color(grad.get_point_count() - 1, Color(0, 0, 0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 160   # migração tile128 (03/09): era 40
	tex.height = 80   # migração tile128 (03/09): era 20

	var shadow := Sprite2D.new()
	shadow.texture = tex
	shadow.position = Vector2(0, 28)  # migração tile128 (03/09): era (0, 7)
	shadow.z_index = 0
	add_child(shadow)
	move_child(shadow, 0)

## Troca a folha de sprites quando a marcha muda pra uma que tem arte
## própria (só "bike" por ora) e volta pro normal nas outras. Reaplica a
## animação atual (mesmo nome em toda folha — idle_<dir>/walk_<dir>) pra
## não perder o frame/direção que já estava tocando.
func _apply_sprite_mode(mode: String) -> void:
	var want_bike := mode == "bike" and _frames_bike != null
	var new_mode := "bike" if want_bike else "normal"
	if new_mode == _sprite_mode:
		return
	_sprite_mode = new_mode
	if new_mode == "bike":
		sprite.sprite_frames = _frames_bike
		sprite.position.y = BIKE_SPRITE_Y
	else:
		sprite.sprite_frames = _frames_normal
		sprite.position.y = NORMAL_SPRITE_Y
	var anim := sprite.animation
	if sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)

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
	f.pokemon_is_shiny   = bool(lead.get("is_shiny", false))
	get_parent().add_child(f)
	f.global_position = global_position
	f.set_trainer(self)
	set_follower(f)

# ──────────────────────────────────────────────────────────────────────────────
# Movimento (tile-a-tile, herdado de BaseEntity.try_move)
# ──────────────────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if _input_locked:
		return

	var dir := _read_direction()
	if dir != -1:
		# Corrida só existe pra quem já ganhou a Bicicleta (UTIL-03) — antes
		# disso a ação "run" (Shift/BtnB) já existia ligada no input map, mas
		# sem checar posse do item, dava +100% de velocidade de graça pra
		# qualquer um, sem precisar da quest. Nunca pedala/monta na água —
		# lá quem manda é Surfar/Voar (is_surfing/is_flying), calculado à
		# parte em _on_tile_entered().
		var segurando_corrida := Input.is_action_pressed("run") and not is_surfing and not is_flying
		is_mounted = segurando_corrida and SaveManager.team_has_any_species(MOUNT_SPECIES)
		is_running = segurando_corrida and not is_mounted and SaveManager.has_item("bicycle", 1)
		try_move(dir)

	if Input.is_action_just_pressed("interact"):
		if not interact():
			_try_fish()

	if Input.is_action_just_pressed("pokeball"):
		_try_throw_pokeball()

	_emit_mode_if_changed()

## Mesma prioridade de _get_move_duration() (a marcha mais rápida disponível
## vence) — só que aqui é só pra AVISAR a HUD, não decide velocidade nenhuma.
## Emite só quando muda de verdade (não a cada frame), senão o EventBus
## dispararia 60x/segundo à toa.
func _emit_mode_if_changed() -> void:
	var mode := "walk"
	if is_flying:        mode = "fly"
	elif is_surfing:      mode = "surf"
	elif is_mounted:      mode = "mount"
	elif is_running:      mode = "bike"
	if mode != _last_mode:
		_last_mode = mode
		_apply_sprite_mode(mode)
		EventBus.movement_mode_changed.emit(mode)

## Prioridade fixa quando mais de uma tecla está pressionada (sem diagonal —
## o grid e os sprites do jogo são só 4 direções, igual Poketibia clássico).
func _read_direction() -> int:
	if Input.is_action_pressed("move_down"):  return Direction.DOWN
	if Input.is_action_pressed("move_up"):    return Direction.UP
	if Input.is_action_pressed("move_left"):  return Direction.LEFT
	if Input.is_action_pressed("move_right"): return Direction.RIGHT
	return -1

## Só o jogador entra na água — sobrescreve a checagem herdada de BaseEntity
## (que bloqueia água pra todo mundo, NPC incluso, de propósito). Permite o
## tile se o time tiver Surfar (Pokémon de tipo Água) OU Voar (Pokémon de
## tipo Voador) — quem não tem nenhum dos dois esbarra na água igual numa
## parede, sem mensagem extra (mesmo padrão silencioso já usado pra árvore/
## rocha no resto do jogo).
func _is_tile_walkable(tile: Vector2i) -> bool:
	if WorldManager.is_water_tile(tile):
		return _pode_voar() or _pode_surfar()
	return super._is_tile_walkable(tile)

func _on_tile_entered(tile: Vector2i) -> void:
	# is_surfing/is_flying são derivados do tile atual (não um botão liga/
	# desliga): sobem na água sozinhos ao entrar (só chega até aqui se
	# _is_tile_walkable já deixou), descem sozinhos ao voltar pra terra —
	# igual ao Surfar/Voar clássicos. Se o time dá pros dois ao mesmo tempo,
	# Voar ganha (é a marcha mais rápida do jogo).
	var na_agua := WorldManager.is_water_tile(tile)
	is_flying  = na_agua and _pode_voar()
	is_surfing = na_agua and not is_flying and _pode_surfar()
	EventBus.player_tile_entered.emit(tile)

func _pode_surfar() -> bool:
	return SaveManager.team_has_move_of_type("surf", "Water")

func _pode_voar() -> bool:
	return SaveManager.team_has_move_of_type("fly", "Flying")

## Escolhe a marcha mais rápida disponível no momento — sobrescreve o hook
## de BaseEntity (que só tem Andar/Correr). Nenhuma marcha empilha com outra.
func _get_move_duration() -> float:
	if is_flying:  return FLY_DURATION
	if is_mounted: return MOUNT_DURATION
	if is_running: return RUN_DURATION   # Bicicleta
	return MOVE_DURATION                 # Andar (e Surfar, mesma velocidade)

## Usado pelo FollowerPokemon pra saber em qual quadro cardeal (nunca diagonal)
## ficar de repouso — sempre o oposto de pra onde o Treinador está olhando.
func get_facing_vector() -> Vector2:
	return _dir_to_vec(facing)

# ──────────────────────────────────────────────────────────────────────────────
# Pesca (Fase 2 do Diário) — só tenta quando "interagir" não achou ninguém
# na frente (chamado do _process acima).
# ──────────────────────────────────────────────────────────────────────────────
const ROD_PRIORITY := ["super_rod", "good_rod", "old_rod"]  # melhor vara primeiro

func _try_fish() -> void:
	var target_tile := grid_pos + _dir_to_vec(facing)
	if not WorldManager.is_water_tile(target_tile):
		return

	var rod_id := ""
	for candidate in ROD_PRIORITY:
		if SaveManager.has_item(candidate, 1):
			rod_id = candidate
			break
	if rod_id.is_empty():
		_show_system_message("fishing_no_rod")
		return

	AudioManager.play_sfx("fishing_cast")
	var rod_effect : String = GameData.get_item(rod_id).get("effect", "fish_common")
	var catch_data := FishingSystem.new().attempt(rod_effect)
	if catch_data.is_empty():
		_show_system_message("fishing_no_bite")
		return

	var spawn_mgr := get_tree().get_first_node_in_group("spawn_manager")
	if not spawn_mgr or not spawn_mgr.has_method("spawn_specific"):
		return
	var caught_pos := _grid_to_world(target_tile)
	var wild_instance : Node = spawn_mgr.spawn_specific(
		catch_data["species_id"], catch_data["level"], caught_pos
	)
	# Motor de combate em tempo real (Fase 7, 02/09): antes emitia
	# wild_encounter_started direto pra forçar a batalha por turno assim que
	# fisgava — agora só força o Pokémon a já nascer "hostil" (ATTACK), o
	# resto (hitbox/hurtbox/HP) já é o mesmo combate em tempo real de sempre.
	if wild_instance and wild_instance.has_method("_set_state"):
		wild_instance.behavior = "aggressive"
		wild_instance._set_state(WildPokemon.State.ATTACK)

## Mensagem de sistema sem NPC (ex: "nada mordeu") — usa o mesmo DialogBox
## (com npc=null, ver DialogBox.gd) e trava/destrava input igual um diálogo
## de verdade, senão dava pra sair andando com a caixa ainda aberta na tela.
func _show_system_message(dialog_id: String) -> void:
	EventBus.dialog_started.emit(null)
	EventBus.npc_dialog_requested.emit(null, dialog_id)

# ──────────────────────────────────────────────────────────────────────────────
# Captura em tempo real (Fase 6 do motor de combate, 02/09) — CaptureSystem.gd
# já existia pronto (arremesso em arco, cálculo de chance), só nunca tinha
# sido ligado a uma tecla. A ação "pokeball" (Espaço) já existia no mapa de
# input, também nunca usada até agora.
# ──────────────────────────────────────────────────────────────────────────────
const BALL_PRIORITY := ["masterball", "ultraball", "superball", "pokeball"]  # melhor bola primeiro

func _try_throw_pokeball() -> void:
	var ball_id := ""
	for candidate in BALL_PRIORITY:
		if SaveManager.has_item(candidate, 1):
			ball_id = candidate
			break
	if ball_id.is_empty():
		_show_system_message("no_pokeball")
		return

	var alvo := _find_nearest_wild_pokemon()
	if not alvo:
		_show_system_message("no_wild_nearby")
		return

	SaveManager.remove_item(ball_id, 1)
	CaptureSystem.throw_pokeball(alvo, ball_id)

## Só permite arremesso dentro de alcance curto (2 tiles) — evita capturar
## um selvagem do outro lado da tela sem nem chegar perto dele.
func _find_nearest_wild_pokemon() -> Node2D:
	var candidatos := get_tree().get_nodes_in_group("wild_pokemon")
	var melhor      : Node2D = null
	var melhor_dist : float  = INF
	for c in candidatos:
		var d : float = global_position.distance_to(c.global_position)
		if d < melhor_dist:
			melhor_dist = d
			melhor = c
	if melhor and melhor_dist <= TILE_SIZE * 2.0:
		return melhor
	return null

# ──────────────────────────────────────────────────────────────────────────────
# HP / combate em tempo real (motor novo, 02/09) — o Treinador só é alvo de
# ataque quando não tem Pokémon ativo: WildPokemon._find_target() já prioriza
# o Follower e só mira o Treinador se ele estiver ausente/desmaiado, e
# WildPokemon._perform_attack() já guarda com has_method("take_damage") antes
# de bater — os dois já existiam, só nunca faziam nada porque o Treinador não
# tinha esse método. Vira funcional só de existir aqui, sem tocar WildPokemon.
# ──────────────────────────────────────────────────────────────────────────────
var current_hp : int = 0
var max_hp      : int = 0

func _init_hp() -> void:
	max_hp     = SaveManager.get_trainer_stats().get_max_hp()
	current_hp = max_hp
	EventBus.trainer_hp_changed.emit(current_hp, max_hp)

## Mesmo formato que WildPokemon/FollowerPokemon já esperam de um alvo
## (get_combat_stats() opcional, checado com has_method antes de chamar).
## Treinador não tem tipo elemental nem defesa própria de Pokémon — usa um
## valor fixo neutro (mesmo default já usado como fallback em
## DamageCalculator.calculate_damage(), "def": 50) até existir uma fórmula
## própria de defesa do Treinador.
func get_combat_stats() -> Dictionary:
	return { "def": 50, "types": [] }

func take_damage(amount: int, _attacker: Node = null) -> void:
	if current_hp <= 0:
		return
	current_hp = max(0, current_hp - amount)
	EventBus.trainer_hp_changed.emit(current_hp, max_hp)
	EventBus.damage_dealt.emit(self, amount, false)
	if current_hp <= 0:
		_faint()

## Convenção clássica de Pokémon: desmaia, cura o time, volta pro último
## Centro Pokémon visitado (WorldManager já rastreia isso pra outro fluxo —
## warp_to_remembered_return() — sem perda permanente de item/progresso.
func _faint() -> void:
	EventBus.trainer_died.emit()
	SaveManager.heal_team()
	WorldManager.warp_to_remembered_return()

# ──────────────────────────────────────────────────────────────────────────────
# Follower management
# ──────────────────────────────────────────────────────────────────────────────
func set_follower(f: Node2D) -> void:
	follower = f

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

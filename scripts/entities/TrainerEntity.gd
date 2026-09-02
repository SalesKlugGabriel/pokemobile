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

## Usado pelo FollowerPokemon como direção de repouso quando ainda não há rastro.
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
	if wild_instance:
		EventBus.wild_encounter_started.emit(wild_instance)

## Mensagem de sistema sem NPC (ex: "nada mordeu") — usa o mesmo DialogBox
## (com npc=null, ver DialogBox.gd) e trava/destrava input igual um diálogo
## de verdade, senão dava pra sair andando com a caixa ainda aberta na tela.
func _show_system_message(dialog_id: String) -> void:
	EventBus.dialog_started.emit(null)
	EventBus.npc_dialog_requested.emit(null, dialog_id)

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
	# Velocidade efetiva do tween de tile: TILE_SIZE px na marcha atual (_get_move_duration,
	# a mesma que try_move usa de verdade) — antes de Montaria/Voar existirem, só tinha
	# Andar/Bicicleta; agora precisa da mesma escolha de marcha, senão o seguidor
	# dessincroniza (fica pra trás ou colado demais) nas marchas novas.
	var duration : float = _get_move_duration()
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

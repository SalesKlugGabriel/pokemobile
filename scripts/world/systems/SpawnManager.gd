## SpawnManager.gd — Gerencia spawn de WildPokémons no overworld.
## Respeita MAX_WILD_INSTANCES, SPAWN_RADIUS_TILES e DESPAWN_RADIUS_TILES.
## Usa ZoneManager para obter tabela de spawn e RNGManager para sorteio por weight.
extends Node

# ──────────────────────────────────────────────────────────────────────────────
# Constantes
# ──────────────────────────────────────────────────────────────────────────────
const MAX_WILD_INSTANCES    : int   = 60
# Achado: 200/280 tiles fazia sentido pra um mundo contínuo gigante (Kanto
# inteiro) que nunca chegou a ser construído. O world_map real hoje tem só
# 100×120 tiles — um raio de 200 sorteava posição quase sempre fora do mapa
# ou longe demais da tela pra o Gabriel algum dia ver o Pokémon selvagem.
const SPAWN_RADIUS_TILES    : int   = 20
const DESPAWN_RADIUS_TILES  : int   = 35
const SPAWN_INTERVAL_SEC    : float = 3.0   # tempo entre tentativas de spawn
const TILE_SIZE             : int   = 128   # pixels por tile (migração tile128, 03/09)

const WILD_POKEMON_SCENE : String = "res://scenes/entities/pokemon/WildPokemon.tscn"

# ──────────────────────────────────────────────────────────────────────────────
# Estado
# ──────────────────────────────────────────────────────────────────────────────
var _wild_instances : Array   = []       # lista de WildPokemon ativos
var _spawn_timer    : float   = 0.0
var _player         : Node2D  = null
var _spawn_parent   : Node    = null     # onde instanciar na árvore

var _wild_scene : PackedScene = null

# ──────────────────────────────────────────────────────────────────────────────
# Ciclo de vida
# ──────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("spawn_manager")
	_wild_scene = load(WILD_POKEMON_SCENE) as PackedScene
	if not _wild_scene:
		push_warning("SpawnManager: WildPokemon.tscn não encontrado em %s" % WILD_POKEMON_SCENE)
	# Usa o próprio nó como pai de instâncias por padrão
	_spawn_parent = self
	set_process(true)

func _process(delta: float) -> void:
	if not _player:
		_player = _find_player()
		if not _player:
			return

	_despawn_distant()

	_spawn_timer += delta
	if _spawn_timer >= _current_spawn_interval():
		_spawn_timer = 0.0
		_try_spawn()

# ──────────────────────────────────────────────────────────────────────────────
# Densidade por profundidade na floresta (Fase 10 do motor de combate em
# tempo real, 02/09) — pedido do Gabriel: espécie por área continua fixa
# (tabela de zones.json não muda em nada), só a VELOCIDADE de spawn aumenta
# quanto mais fundo o jogador entra — "vira uma luta de sobrevivência".
# "Fundo" = mais longe de qualquer borda do tile_rect que a zona já tem em
# zones.json (não precisou campo novo). Só zonas com "forest" no id — não é
# convenção de nenhum jogo pesquisado, é design nosso, seguindo a descrição
# do próprio Gabriel. MAX_WILD_INSTANCES continua sendo o teto de segurança
# absoluto (nunca mais que isso no mapa inteiro, protege performance).
# ──────────────────────────────────────────────────────────────────────────────
const FOREST_MAX_DEPTH_TILES  : float = 20.0   # a partir daqui já conta como "o mais fundo"
const FOREST_MIN_INTERVAL_SEC : float = 0.6    # intervalo no fundo da floresta (teto de intensidade)

func _current_spawn_interval() -> float:
	var zone_manager := _get_zone_manager()
	if not zone_manager:
		return SPAWN_INTERVAL_SEC
	var zone : Dictionary = zone_manager.get_current_zone()
	if zone.is_empty():
		return SPAWN_INTERVAL_SEC
	var zone_id : String = str(zone.get("id", "")).to_lower()
	if not zone_id.contains("forest"):
		return SPAWN_INTERVAL_SEC
	var ratio : float = clampf(_forest_depth_tiles(zone) / FOREST_MAX_DEPTH_TILES, 0.0, 1.0)
	return lerpf(SPAWN_INTERVAL_SEC, FOREST_MIN_INTERVAL_SEC, ratio)

## Distância (em tiles) até a borda mais próxima do tile_rect da zona —
## 0 = na borda/fora, cresce conforme o jogador entra mais no meio dela.
func _forest_depth_tiles(zone: Dictionary) -> float:
	var rect : Dictionary = zone.get("tile_rect", {})
	if rect.is_empty() or not _player:
		return 0.0
	var px : float = _player.global_position.x / float(TILE_SIZE)
	var py : float = _player.global_position.y / float(TILE_SIZE)
	var x0 : float = rect.get("x", 0)
	var y0 : float = rect.get("y", 0)
	var w  : float = rect.get("w", 0)
	var h  : float = rect.get("h", 0)
	var dist_to_edge : float = min(min(px - x0, (x0 + w) - px), min(py - y0, (y0 + h) - py))
	return max(0.0, dist_to_edge)

# ──────────────────────────────────────────────────────────────────────────────
# API pública
# ──────────────────────────────────────────────────────────────────────────────
## Define nó pai para instâncias (chamado pelo KantoWorld).
func set_spawn_parent(parent: Node) -> void:
	_spawn_parent = parent

## Define player manualmente.
func set_player(p: Node2D) -> void:
	_player = p

## Retorna quantidade de instâncias ativas.
func get_active_count() -> int:
	return _wild_instances.size()

# ──────────────────────────────────────────────────────────────────────────────
# Lógica de spawn
# ──────────────────────────────────────────────────────────────────────────────
func _try_spawn() -> void:
	if _wild_instances.size() >= MAX_WILD_INSTANCES:
		return
	if not _wild_scene:
		return

	# Obtém zona atual via ZoneManager (autoload ou nó na árvore)
	var zone_manager := _get_zone_manager()
	if not zone_manager:
		return

	var zone : Dictionary = zone_manager.get_current_zone()
	if zone.is_empty():
		return

	var table : Array = zone.get("wild_pokemon", [])
	if table.is_empty():
		return

	# Sorteia pokémon por weight
	var chosen := _weighted_pick(table)
	if chosen.is_empty():
		return

	# Sorteia posição ao redor do player dentro do raio
	var spawn_pos := _random_spawn_pos()
	if spawn_pos == Vector2.ZERO:
		return

	_spawn_pokemon(chosen, spawn_pos, str(zone.get("id", "")))

func _spawn_pokemon(entry: Dictionary, pos: Vector2, zone_id: String = "") -> void:
	var instance := _wild_scene.instantiate()
	if not instance:
		return

	instance.global_position = pos

	# Injeta dados no WildPokemon se ele tiver método de inicialização
	var level : int = RNGManager.randi_range(
		entry.get("level_min", 1),
		entry.get("level_max", 5)
	)
	if instance.has_method("initialize"):
		instance.initialize(entry.get("id", 1), level, entry.get("behavior", "aggressive"), zone_id)

	_spawn_parent.add_child(instance)
	_wild_instances.append(instance)
	EventBus.wild_pokemon_spawned.emit(instance)

## Cria um WildPokemon específico (espécie/nível já escolhidos por fora) numa
## posição exata — usado pela pesca (Fase 2 do Diário): o peixe fisgado não
## "persegue" o jogador como um spawn normal, a mordida já é o encontro.
## Retorna a instância (quem chamou decide o que fazer com ela, ex: emitir
## wild_encounter_started na hora, sem esperar o WildPokemon perceber o player).
func spawn_specific(species_id: int, level: int, pos: Vector2) -> Node:
	var instance := _wild_scene.instantiate()
	if not instance:
		return null
	instance.global_position = pos
	if instance.has_method("initialize"):
		instance.initialize(species_id, level, "neutral")
	_spawn_parent.add_child(instance)
	_wild_instances.append(instance)
	return instance

## Sorteia posição aleatória dentro de SPAWN_RADIUS_TILES ao redor do player,
## garantindo que não seja na mesma tile do player.
func _random_spawn_pos() -> Vector2:
	if not _player:
		return Vector2.ZERO

	var center   : Vector2 = _player.global_position
	var radius_px : float  = SPAWN_RADIUS_TILES * TILE_SIZE
	var min_dist  : float  = TILE_SIZE * 5  # mínimo 5 tiles de distância

	for _attempt in range(20):
		var angle : float  = RNGManager.randf() * TAU
		var dist  : float  = RNGManager.randf_range(min_dist, radius_px)
		var pos   : Vector2 = center + Vector2(cos(angle), sin(angle)) * dist
		return pos

	return Vector2.ZERO

# ──────────────────────────────────────────────────────────────────────────────
# Lógica de despawn
# ──────────────────────────────────────────────────────────────────────────────
func _despawn_distant() -> void:
	if not _player:
		return

	var despawn_px : float = DESPAWN_RADIUS_TILES * TILE_SIZE
	var to_remove  : Array = []

	for inst in _wild_instances:
		if not is_instance_valid(inst):
			to_remove.append(inst)
			continue
		var dist : float = _player.global_position.distance_to(inst.global_position)
		if dist > despawn_px:
			to_remove.append(inst)

	for inst in to_remove:
		_wild_instances.erase(inst)
		if is_instance_valid(inst):
			inst.queue_free()

# ──────────────────────────────────────────────────────────────────────────────
# Utilitários
# ──────────────────────────────────────────────────────────────────────────────
## Sorteio por peso: entry deve ter campo "weight" (int).
func _weighted_pick(table: Array) -> Dictionary:
	var total : int = 0
	for entry in table:
		total += entry.get("weight", 1)

	if total <= 0:
		return {}

	var roll : int = RNGManager.randi_range(0, total - 1)
	var acc  : int = 0
	for entry in table:
		acc += entry.get("weight", 1)
		if roll < acc:
			return entry

	return table[table.size() - 1]

func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null

func _get_zone_manager() -> Node:
	# Tenta encontrar ZoneManager como irmão na árvore
	var parent := get_parent()
	if parent:
		for child in parent.get_children():
			if child.name == "ZoneManager":
				return child
	return null

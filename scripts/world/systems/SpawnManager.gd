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
const TILE_SIZE             : int   = 16    # pixels por tile

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
	if _spawn_timer >= SPAWN_INTERVAL_SEC:
		_spawn_timer = 0.0
		_try_spawn()

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

	_spawn_pokemon(chosen, spawn_pos)

func _spawn_pokemon(entry: Dictionary, pos: Vector2) -> void:
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
		instance.initialize(entry.get("id", 1), level)

	_spawn_parent.add_child(instance)
	_wild_instances.append(instance)
	EventBus.wild_pokemon_spawned.emit(instance)

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

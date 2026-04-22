## PokemonSpawner.gd — Spawna Pokémons selvagens no mapa baseado em spawns.json.
## Coloque este nó como filho da cena de mapa.
## Configure biome_id via Inspector para selecionar a tabela de spawn correta.
class_name PokemonSpawner
extends Node2D

# ──────────────────────────────────────────────────────────────────────────────
# Configuração
# ──────────────────────────────────────────────────────────────────────────────
@export var biome_id        : String = "plains"
@export var max_spawns      : int    = 8
@export var spawn_radius    : int    = 20    # tiles ao redor do centro da área
@export var respawn_interval: float  = 15.0  # segundos entre checagens de respawn

## Cena base de PokemonEntity
const POKEMON_SCENE := preload("res://scenes/entities/PokemonEntity.tscn")

# ──────────────────────────────────────────────────────────────────────────────
# Estado interno
# ──────────────────────────────────────────────────────────────────────────────
var _spawn_table  : Array[Dictionary] = []
var _active       : Array[PokemonEntity] = []
var _respawn_timer: float = 0.0
var _spawn_center : Vector2i = Vector2i.ZERO

# ──────────────────────────────────────────────────────────────────────────────
# Inicialização
# ──────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_spawn_center = WorldManager.tilemap.local_to_map(global_position) if WorldManager.tilemap else Vector2i.ZERO
	_load_spawn_table()
	_spawn_batch()

func _load_spawn_table() -> void:
	var table : Array = GameData.get_biome_spawns(biome_id)
	if table.is_empty():
		push_warning("PokemonSpawner: biome '%s' não encontrado em spawns.json" % biome_id)
		return
	_spawn_table.assign(table)

# ──────────────────────────────────────────────────────────────────────────────
# Loop
# ──────────────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_respawn_timer -= delta
	if _respawn_timer <= 0.0:
		_respawn_timer = respawn_interval
		_cleanup_dead()
		_spawn_batch()

func _cleanup_dead() -> void:
	_active = _active.filter(func(p): return is_instance_valid(p) and p.state != PokemonEntity.State.BATTLE)

# ──────────────────────────────────────────────────────────────────────────────
# Spawn
# ──────────────────────────────────────────────────────────────────────────────
func _spawn_batch() -> void:
	if _spawn_table.is_empty():
		return
	var needed := max_spawns - _active.size()
	for i in needed:
		_spawn_one()

func _spawn_one() -> void:
	var tile := _pick_free_tile()
	if tile == Vector2i(-9999, -9999):
		return  # nenhum tile livre encontrado

	var entry     := _pick_from_table()
	if entry.is_empty():
		return

	var pokemon   : PokemonEntity = POKEMON_SCENE.instantiate()
	pokemon.species_id = entry.get("species_id", 1)
	pokemon.level      = RNGManager.randi_range(entry.get("min_level", 3), entry.get("max_level", 5))
	pokemon.is_shiny   = RNGManager.chance(0.002)  # 1/500 global
	pokemon.set_grid_position(tile)

	add_child(pokemon)
	_active.append(pokemon)

func _pick_from_table() -> Dictionary:
	if _spawn_table.is_empty():
		return {}
	# Peso por encounter_rate
	var total_weight := 0.0
	for entry in _spawn_table:
		total_weight += float(entry.get("weight", 10))
	var roll := RNGManager.randf_range(0.0, total_weight)
	var acc  := 0.0
	for entry in _spawn_table:
		acc += float(entry.get("weight", 10))
		if roll <= acc:
			return entry
	return _spawn_table[-1]

func _pick_free_tile() -> Vector2i:
	for _attempt in 20:
		var offset := Vector2i(
			RNGManager.randi_range(-spawn_radius, spawn_radius),
			RNGManager.randi_range(-spawn_radius, spawn_radius)
		)
		var tile := _spawn_center + offset
		if WorldManager.is_tile_walkable(tile) and _no_entity_at(tile):
			return tile
	return Vector2i(-9999, -9999)

func _no_entity_at(tile: Vector2i) -> bool:
	for p in _active:
		if is_instance_valid(p) and p.grid_pos == tile:
			return false
	var player_nodes := get_tree().get_nodes_in_group("player")
	for p in player_nodes:
		if p is BaseEntity and p.grid_pos == tile:
			return false
	return true

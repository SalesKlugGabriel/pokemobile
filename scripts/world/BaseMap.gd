## BaseMap.gd — Script base para todas as cenas de mapa.
## Herdar este script em cada mapa. Registra TileMap e Player no WorldManager.
## Pinta tiles automaticamente via MapLayouts e ajusta Camera2D limits.
class_name BaseMap
extends Node2D

## ID único do mapa (ex: "pallet_town", "route_1")
@export var map_id : String = "unknown_map"

@onready var tilemap : TileMap       = $TileMap
@onready var player  : TrainerEntity = $Entities/Player

func _ready() -> void:
	_paint_tiles()
	_apply_camera_limits()
	WorldManager.register_map(map_id, tilemap, player)
	WorldManager.apply_pending_spawn()
	EventBus.map_changed.emit("", map_id)
	_setup_world_systems()

func _setup_world_systems() -> void:
	if not player:
		return
	var wild_container := get_node_or_null("Entities/WildPokemons")
	var npc_container  := get_node_or_null("Entities/NPCs")

	var spawn_mgr := get_node_or_null("SpawnManager")
	if spawn_mgr:
		if spawn_mgr.has_method("set_player"):
			spawn_mgr.set_player(player)
		if wild_container and spawn_mgr.has_method("set_spawn_parent"):
			spawn_mgr.set_spawn_parent(wild_container)

	var npc_mgr := get_node_or_null("NPCManager")
	if npc_mgr:
		if npc_mgr.has_method("set_player"):
			npc_mgr.set_player(player)
		if npc_container and npc_mgr.has_method("set_spawn_parent"):
			npc_mgr.set_spawn_parent(npc_container)

func _exit_tree() -> void:
	WorldManager.unregister_map()

# ──────────────────────────────────────────────────────────────────────────────
# Polimento visual
# ──────────────────────────────────────────────────────────────────────────────

func _paint_tiles() -> void:
	if not tilemap:
		return
	MapLayouts.paint(tilemap, map_id)

func _apply_camera_limits() -> void:
	var cam : Camera2D = _find_camera()
	if not cam:
		return
	var bounds := MapLayouts.get_pixel_bounds(map_id)
	cam.limit_left   = bounds.position.x
	cam.limit_top    = bounds.position.y
	cam.limit_right  = bounds.position.x + bounds.size.x
	cam.limit_bottom = bounds.position.y + bounds.size.y

func _find_camera() -> Camera2D:
	if player:
		for child in player.get_children():
			if child is Camera2D:
				return child
	return null

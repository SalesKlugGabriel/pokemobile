## KantoWorldInit.gd — Script de inicialização da cena KantoWorld.
## Conecta os sistemas de mundo ao Player e containers corretos após _ready().
extends Node2D

func _ready() -> void:
	var player         := $Entities/Player
	var wild_container := $Entities/WildPokemons
	var spawn_manager  := $SpawnManager as Node
	var npc_manager    := $NPCManager as Node

	# Injeta player e container de instâncias no SpawnManager
	if spawn_manager and spawn_manager.has_method("set_player"):
		spawn_manager.set_player(player)
	if spawn_manager and spawn_manager.has_method("set_spawn_parent"):
		spawn_manager.set_spawn_parent(wild_container)

	# Injeta player no NPCManager se disponível
	if npc_manager and npc_manager.has_method("set_player"):
		npc_manager.set_player(player)

	# Registra o mapa world_map no WorldManager
	# Obtém o primeiro TileMapLayer (compatível com Godot 4.2 multi-layer)
	var tilemap : TileMap = null
	for child in get_children():
		if child is TileMap:
			tilemap = child
			break
	if tilemap and player:
		WorldManager.register_map("world_map", tilemap, player)

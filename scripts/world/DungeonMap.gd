## DungeonMap.gd — Script base para KantoDungeons.tscn.
## Localiza o player na árvore e aplica o pending_spawn do WorldManager.
extends Node2D

func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		# Registra player no WorldManager sem tilemap (dungeons usam physics direto)
		WorldManager.player = player
	WorldManager.apply_pending_spawn()

## DungeonPortal.gd — DEPRECATED. Não usar.
## Substituído por WarpZone.gd para entradas de dungeon (estilo Tibia).
## Mantido apenas para evitar erros de referência em cenas antigas.
## TODO: remover DungeonPortal.tscn e KantoDungeons.tscn — substituídos por
##       cenas individuais em scenes/world/dungeons/ com WarpZone.
extends Area2D

func _ready() -> void:
	push_warning("DungeonPortal: DEPRECATED — usar WarpZone para entradas de dungeon")
	queue_free()

## PortalManager.gd — Gerencia apenas portais de REGIÃO (Kanto → Johto, etc.).
## Dungeons não usam PortalManager — usam WarpZone diretamente (estilo Tibia).
## Colocar este nó na WorldMap.tscn ou KantoWorld.tscn.
extends Node

signal region_enter_blocked(region_id: String, message: String)

var _is_transitioning : bool = false

func enter_region(target_region_id: String) -> void:
	if _is_transitioning:
		return
	var region_manager := _get_region_manager()
	if not region_manager:
		push_warning("PortalManager: RegionManager não encontrado")
		return
	if not region_manager.is_region_unlocked(target_region_id):
		var msg : String = region_manager.get_coming_soon_message(target_region_id)
		region_enter_blocked.emit(target_region_id, msg)
		return
	_is_transitioning = true
	# Warp para posição de entrada da região (a ser definida por regions.json)
	WorldManager.warp_to("res://scenes/world/maps/WorldMap.tscn", Vector2i(50, 5))
	_is_transitioning = false

func _get_region_manager() -> Node:
	var parent := get_parent()
	if parent:
		for child in parent.get_children():
			if child.name == "RegionManager":
				return child
	return get_tree().get_first_node_in_group("region_manager")

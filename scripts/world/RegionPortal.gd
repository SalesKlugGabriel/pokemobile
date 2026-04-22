## RegionPortal.gd — Area2D reutilizável para portais de região.
## Quando player entra: verifica unlock via PortalManager.
## Se desbloqueada: entra na região. Se bloqueada: exibe popup Coming Soon.
extends Area2D

# ──────────────────────────────────────────────────────────────────────────────
# Exports
# ──────────────────────────────────────────────────────────────────────────────
@export var target_region_id  : String = ""
@export var portal_label      : String = ""   # nome exibido no popup se necessário

# ──────────────────────────────────────────────────────────────────────────────
# Ciclo de vida
# ──────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	body_entered.connect(_on_body_entered)

# ──────────────────────────────────────────────────────────────────────────────
# Callbacks
# ──────────────────────────────────────────────────────────────────────────────
func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if target_region_id.is_empty():
		push_warning("RegionPortal: target_region_id não definido")
		return

	var portal_manager := _get_portal_manager()
	if portal_manager:
		portal_manager.enter_region(target_region_id)
	else:
		push_warning("RegionPortal: PortalManager não encontrado na cena")

# ──────────────────────────────────────────────────────────────────────────────
# Utilitários
# ──────────────────────────────────────────────────────────────────────────────
func _get_portal_manager() -> Node:
	# Busca PortalManager como filho da cena raiz do mundo
	var root := get_tree().current_scene
	if root:
		for child in root.get_children():
			if child.name == "PortalManager":
				return child
	return null

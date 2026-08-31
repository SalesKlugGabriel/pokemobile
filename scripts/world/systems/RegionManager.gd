## RegionManager.gd — Gerencia regiões do mundo (kanto, johto, etc.).
## Carrega data/world/regions.json. Controla unlock e mensagens Coming Soon.
extends Node

# ──────────────────────────────────────────────────────────────────────────────
# Constantes
# ──────────────────────────────────────────────────────────────────────────────
const REGIONS_JSON_PATH : String = "res://data/world/regions.json"

# ──────────────────────────────────────────────────────────────────────────────
# Estado
# ──────────────────────────────────────────────────────────────────────────────
var _regions       : Array      = []
var _regions_by_id : Dictionary = {}
var _active_region : Dictionary = {}

# ──────────────────────────────────────────────────────────────────────────────
# Sinais
# ──────────────────────────────────────────────────────────────────────────────
signal region_changed(region_id: String)

# ──────────────────────────────────────────────────────────────────────────────
# Ciclo de vida
# ──────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_load_regions()
	# Define kanto como região inicial
	_active_region = _regions_by_id.get("kanto", {})
	# Atualiza região ativa quando a zona mudar
	EventBus.zone_changed.connect(_on_zone_changed)

# ──────────────────────────────────────────────────────────────────────────────
# API pública
# ──────────────────────────────────────────────────────────────────────────────
## Retorna os dados da região ativa no momento.
func get_active_region() -> Dictionary:
	return _active_region

## Verifica se uma região está desbloqueada.
func is_region_unlocked(region_id: String) -> bool:
	var region := get_region(region_id)
	if region.is_empty():
		return false
	return region.get("unlocked", false)

## Retorna dados de uma região pelo ID.
func get_region(region_id: String) -> Dictionary:
	return _regions_by_id.get(region_id, {})

## Retorna mensagem Coming Soon de uma região.
func get_coming_soon_message(region_id: String) -> String:
	var region := get_region(region_id)
	return region.get("coming_soon_message", "Esta região ainda não está disponível.")

## Retorna todas as regiões (para WorldMapUI).
func get_all_regions() -> Array:
	return _regions

## Desbloqueia uma região programaticamente (ex: via quest ou save).
func unlock_region(region_id: String) -> void:
	if _regions_by_id.has(region_id):
		_regions_by_id[region_id]["unlocked"] = true
		_regions_by_id[region_id]["coming_soon"] = false

# ──────────────────────────────────────────────────────────────────────────────
# Lógica interna
# ──────────────────────────────────────────────────────────────────────────────
func _load_regions() -> void:
	if not FileAccess.file_exists(REGIONS_JSON_PATH):
		push_warning("RegionManager: regions.json não encontrado em %s" % REGIONS_JSON_PATH)
		return

	var f := FileAccess.open(REGIONS_JSON_PATH, FileAccess.READ)
	if not f:
		push_error("RegionManager: falha ao abrir regions.json")
		return

	var json := JSON.new()
	var err  := json.parse(f.get_as_text())
	f.close()

	if err != OK:
		push_error("RegionManager: erro ao parsear regions.json — linha %d" % json.get_error_line())
		return

	var data = json.get_data()
	if not data is Dictionary or not data.has("regions"):
		push_error("RegionManager: formato inválido em regions.json")
		return

	_regions = data["regions"]
	_regions_by_id.clear()
	for region in _regions:
		_regions_by_id[region["id"]] = region

func _on_zone_changed(zone_id: String) -> void:
	# Determina a região da zona via ZoneManager
	var zone_manager := _get_zone_manager()
	if not zone_manager:
		return

	var zone : Dictionary = zone_manager.get_zone_by_id(zone_id)
	if zone.is_empty():
		return

	var region_id : String = zone.get("region", "")
	if region_id.is_empty():
		return

	var new_region : Dictionary = _regions_by_id.get(region_id, {})
	if new_region.is_empty():
		return

	var prev_id : String = _active_region.get("id", "")
	if region_id != prev_id:
		_active_region = new_region
		region_changed.emit(region_id)

func _get_zone_manager() -> Node:
	var parent := get_parent()
	if parent:
		for child in parent.get_children():
			if child.name == "ZoneManager":
				return child
	return null

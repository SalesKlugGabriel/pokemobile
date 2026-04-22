## ZoneManager.gd — Detecta zona atual do player baseado em posição no tilemap.
## Carrega data/world/zones.json. Emite EventBus.zone_changed ao mudar de zona.
extends Node

# ──────────────────────────────────────────────────────────────────────────────
# Estado
# ──────────────────────────────────────────────────────────────────────────────
var _zones          : Array      = []       # lista de dicionários de zonas
var _current_zone   : Dictionary = {}       # zona atual do player
var _zones_by_id    : Dictionary = {}       # índice rápido id → dados

const ZONES_JSON_PATH : String = "res://data/world/zones.json"

# ──────────────────────────────────────────────────────────────────────────────
# Ciclo de vida
# ──────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_load_zones()
	EventBus.player_tile_entered.connect(_on_player_tile_entered)

# ──────────────────────────────────────────────────────────────────────────────
# API pública
# ──────────────────────────────────────────────────────────────────────────────
## Retorna os dados da zona atual do player.
func get_current_zone() -> Dictionary:
	return _current_zone

## Retorna dados de uma zona pelo ID; Dictionary vazio se não encontrada.
func get_zone_by_id(zone_id: String) -> Dictionary:
	return _zones_by_id.get(zone_id, {})

## Retorna a lista completa de zonas.
func get_all_zones() -> Array:
	return _zones

## Retorna o ID da zona para uma posição em tile, ou "" se fora de todas as zonas.
func get_zone_id_at(tile_pos: Vector2i) -> String:
	for zone in _zones:
		if _tile_in_zone(tile_pos, zone):
			return zone["id"]
	return ""

# ──────────────────────────────────────────────────────────────────────────────
# Lógica interna
# ──────────────────────────────────────────────────────────────────────────────
func _load_zones() -> void:
	if not FileAccess.file_exists(ZONES_JSON_PATH):
		push_warning("ZoneManager: zones.json não encontrado em %s" % ZONES_JSON_PATH)
		return

	var f := FileAccess.open(ZONES_JSON_PATH, FileAccess.READ)
	if not f:
		push_error("ZoneManager: falha ao abrir zones.json")
		return

	var json := JSON.new()
	var err  := json.parse(f.get_as_text())
	f.close()

	if err != OK:
		push_error("ZoneManager: erro ao parsear zones.json — linha %d" % json.get_error_line())
		return

	var data = json.get_data()
	if not data is Dictionary or not data.has("zones"):
		push_error("ZoneManager: formato inválido em zones.json")
		return

	_zones = data["zones"]
	_zones_by_id.clear()
	for zone in _zones:
		_zones_by_id[zone["id"]] = zone

## Chamado quando o player muda de tile.
func _on_player_tile_entered(tile: Vector2i) -> void:
	var new_zone_id := get_zone_id_at(tile)

	# Sem mudança
	if not _current_zone.is_empty() and _current_zone.get("id", "") == new_zone_id:
		return

	var prev_id := _current_zone.get("id", "")
	_current_zone = _zones_by_id.get(new_zone_id, {})

	if new_zone_id != prev_id:
		EventBus.zone_changed.emit(new_zone_id)

## Verifica se tile_pos está dentro do rect de uma zona.
func _tile_in_zone(tile_pos: Vector2i, zone: Dictionary) -> bool:
	var r = zone.get("tile_rect", {})
	if r.is_empty():
		return false
	var rx : int = r.get("x", 0)
	var ry : int = r.get("y", 0)
	var rw : int = r.get("w", 0)
	var rh : int = r.get("h", 0)
	return (
		tile_pos.x >= rx and tile_pos.x < rx + rw and
		tile_pos.y >= ry and tile_pos.y < ry + rh
	)

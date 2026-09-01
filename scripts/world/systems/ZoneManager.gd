## ZoneManager.gd — Detecta zona atual do player baseado em posição no tilemap.
## Carrega data/world/zones.json. Emite EventBus.zone_changed ao mudar de zona.
## Instanciado uma vez POR CENA (filho direto de cada BaseMap, não é autoload) —
## por isso precisa saber em qual mapa está (ver DEFAULT_MAP_ID abaixo), já que
## zones.json é compartilhado por todas as cenas.
extends Node

# ──────────────────────────────────────────────────────────────────────────────
# Estado
# ──────────────────────────────────────────────────────────────────────────────
var _zones          : Array      = []       # lista de dicionários de zonas
var _current_zone   : Dictionary = {}       # zona atual do player
var _zones_by_id    : Dictionary = {}       # índice rápido id → dados
var _map_id         : String     = DEFAULT_MAP_ID  # mapa/cena a que ESTA instância pertence

const ZONES_JSON_PATH : String = "res://data/world/zones.json"

## Mapa/cena padrão: o mundo aberto compartilhado (WorldMap.tscn, BaseMap.map_id
## = "world_map"). Zonas sem "map_id" próprio em zones.json pertencem a ele.
const DEFAULT_MAP_ID : String = "world_map"

# ──────────────────────────────────────────────────────────────────────────────
# Ciclo de vida
# ──────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	var base_map := get_parent()
	if base_map and "map_id" in base_map:
		_map_id = base_map.map_id
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

## Retorna o ID da zona para uma posição em tile (dentro do mapa/cena desta
## instância), ou "" se fora de todas as zonas.
func get_zone_id_at(tile_pos: Vector2i) -> String:
	return find_zone_id(tile_pos, _zones, _map_id)

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

	var prev_id : String = _current_zone.get("id", "")
	_current_zone = _zones_by_id.get(new_zone_id, {})

	if new_zone_id != prev_id:
		EventBus.zone_changed.emit(new_zone_id)

## Acha o ID da zona pra uma posição em tile, restrito às zonas do map_id dado
## (zona sem "map_id" próprio pertence ao DEFAULT_MAP_ID). Estático de propósito
## (sem depender de instância) pra ser testável direto por script headless.
## Corrige o risco sistêmico registrado em 01/09: cenas próprias (Mt Moon, Rock
## Tunnel, Safari Zone, Rocket Hideout, Cinnabar Island) têm tile_rect que se
## sobrepõem entre si em números brutos porque todas começam perto de (0,0) na
## própria cena — sem o filtro por map_id, a primeira zona da lista que batesse
## a coordenada bruta "vencia" (era sempre Mt Moon, por vir primeiro no JSON).
static func find_zone_id(tile_pos: Vector2i, zones: Array, map_id: String) -> String:
	for zone in zones:
		var zone_map_id : String = zone.get("map_id", DEFAULT_MAP_ID)
		if zone_map_id != map_id:
			continue
		if _zone_contains(tile_pos, zone):
			return zone["id"]
	return ""

static func _zone_contains(tile_pos: Vector2i, zone: Dictionary) -> bool:
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

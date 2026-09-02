## WorldManager.gd — Autoload que gerencia o mapa ativo.
## Responsabilidades:
##   - Referência ao TileMap do mapa atual
##   - Verificação de walkability por tile (usado por BaseEntity._is_tile_walkable)
##   - Referência ao jogador ativo
##   - Transições de mapa (warp)
##   - Conexão de sinais entre entidades (NPC interaction → DialogManager)
extends Node

# ──────────────────────────────────────────────────────────────────────────────
# Referências ao mapa ativo (injetadas pela cena de mapa ao entrar na árvore)
# ──────────────────────────────────────────────────────────────────────────────
var tilemap        : Node            = null   # TileMap ou null (KantoWorld usa TileMapLayer)
var player         : TrainerEntity   = null
var current_map_id : String          = ""

## Layer do TileMap que representa colisão (0 = primeira layer)
const COLLISION_LAYER_INDEX : int = 0
## Custom data layer name para indicar tile bloqueado
const BLOCKED_DATA_KEY      : String = "blocked"
## Coordenada do tile de água no atlas (ver MapLayouts.CHAR_MAP "~") — usado
## pra pesca (Fase 2 do Diário) saber se o jogador está de frente pra água.
const WATER_ATLAS_COORDS    : Vector2i = Vector2i(1, 1)

# ──────────────────────────────────────────────────────────────────────────────
# Inicialização
# ──────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	EventBus.wild_pokemon_engaged.connect(_on_wild_encounter_started)
	EventBus.zone_changed.connect(_on_zone_changed)

func _on_zone_changed(zone_id: String) -> void:
	if _zone_bgm_map.is_empty():
		_load_zone_bgm_map()
	var bgm : String = _zone_bgm_map.get(zone_id, "")
	if bgm != "":
		AudioManager.play_bgm(bgm)

# ──────────────────────────────────────────────────────────────────────────────
# Registro de mapa (chamado pela cena de mapa em _ready)
# ──────────────────────────────────────────────────────────────────────────────
## Mapa zone_id → bgm carregado de zones.json
var _zone_bgm_map : Dictionary = {}

func _load_zone_bgm_map() -> void:
	var path := "res://data/world/zones.json"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		f.close()
		return
	f.close()
	var data = json.get_data()
	if data is Dictionary and data.has("zones"):
		for zone in data["zones"]:
			if zone.has("id") and zone.has("bgm"):
				_zone_bgm_map[zone["id"]] = zone["bgm"]

func register_map(map_id: String, tm: Node, p: TrainerEntity) -> void:
	current_map_id = map_id
	tilemap        = tm
	player         = p

	if _zone_bgm_map.is_empty():
		_load_zone_bgm_map()

	# Mapas fora do world_map tocavam sempre "pokemon_center" fixo, mesmo
	# não sendo o Centro Pokémon (achado ao expandir o mapa pra novas
	# cidades) — agora busca o bgm de verdade em zones.json pelo map_id,
	# só cai no antigo padrão se não achar (mantém o Centro Pokémon igual).
	if current_map_id != "world_map":
		AudioManager.play_bgm(_zone_bgm_map.get(current_map_id, "pokemon_center"))

	# Conecta sinais de interação de todas as entidades
	_connect_entity_signals()

func unregister_map() -> void:
	tilemap        = null
	player         = null
	current_map_id = ""

# ──────────────────────────────────────────────────────────────────────────────
# Walkability (consultado por BaseEntity._is_tile_walkable)
# ──────────────────────────────────────────────────────────────────────────────

## Retorna true se o tile pode ser percorrido.
## Estratégia 1: custom data layer "blocked" = true → bloqueado
## Estratégia 2: tile vazio na layer 0 → bloqueado (bordas do mapa)
## Estratégia 3: tile com physics layer ativo → bloqueado
func is_tile_walkable(tile: Vector2i) -> bool:
	if not tilemap:
		return true  # sem mapa registrado: permissivo (physics trata colisão)

	# Suporte a TileMap (API antiga) e TileMapLayer (Godot 4.2+)
	if tilemap is TileMap:
		return _tile_walkable_tilemap(tilemap as TileMap, tile)
	# TileMapLayer: usa API de layer única
	if tilemap.has_method("get_cell_tile_data"):
		var td : TileData = tilemap.call("get_cell_tile_data", tile)
		if td == null:
			return false
		if td.get_custom_data(BLOCKED_DATA_KEY):
			return false
		return td.get_collision_polygons_count(0) == 0
	return true

func _tile_walkable_tilemap(tm: TileMap, tile: Vector2i) -> bool:
	for layer_idx in tm.get_layers_count():
		var td : TileData = tm.get_cell_tile_data(layer_idx, tile)
		if td == null:
			continue
		if td.get_custom_data(BLOCKED_DATA_KEY):
			return false
		if td.get_collision_polygons_count(0) > 0:
			return false
	var has_any := false
	for layer_idx in tm.get_layers_count():
		if tm.get_cell_source_id(layer_idx, tile) != -1:
			has_any = true
			break
	return has_any

## Retorna true se o tile é água (atlas coords == WATER_ATLAS_COORDS) —
## usado pra pesca: só dá pra pescar de frente pra um tile assim.
func is_water_tile(tile: Vector2i) -> bool:
	if not tilemap or not (tilemap is TileMap):
		return false
	var tm := tilemap as TileMap
	for layer_idx in tm.get_layers_count():
		if tm.get_cell_atlas_coords(layer_idx, tile) == WATER_ATLAS_COORDS:
			return true
	return false

# ──────────────────────────────────────────────────────────────────────────────
# Conexão de sinais de entidades
# ──────────────────────────────────────────────────────────────────────────────
var _last_zone : String = ""

func _connect_entity_signals() -> void:
	if not player:
		return
	if player.has_signal("interaction_triggered"):
		if not player.interaction_triggered.is_connected(_on_player_interaction):
			player.interaction_triggered.connect(_on_player_interaction)
	if player.has_signal("move_finished"):
		if not player.move_finished.is_connected(_on_player_moved):
			player.move_finished.connect(_on_player_moved)

func _on_player_moved() -> void:
	pass  # Zone detection delegada ao ZoneManager via EventBus.player_tile_entered

func _on_player_interaction(entity: Node) -> void:
	if entity is NpcEntity:
		entity.start_dialog(player)

# ──────────────────────────────────────────────────────────────────────────────
# Encontrar entidades no tile
# ──────────────────────────────────────────────────────────────────────────────
func get_entities_at(tile: Vector2i) -> Array[BaseEntity]:
	var result : Array[BaseEntity] = []
	for group in ["player", "npc_entities", "pokemon_entities"]:
		for node in get_tree().get_nodes_in_group(group):
			if node is BaseEntity and node.grid_pos == tile:
				result.append(node)
	return result

# ──────────────────────────────────────────────────────────────────────────────
# Warp / transição de mapa
# ──────────────────────────────────────────────────────────────────────────────
func warp_to(map_scene_path: String, spawn_tile: Vector2i) -> void:
	if player:
		player.lock_input()
	# Guarda tile de spawn para usar após carregar a cena
	_pending_spawn_tile = spawn_tile
	SceneTransition.fade_to(map_scene_path)

# ──────────────────────────────────────────────────────────────────────────────
# Retorno do Centro Pokémon (Fase 3 do Diário)
# ──────────────────────────────────────────────────────────────────────────────
# Achado: a saída do PokemonCenter.tscn (compartilhado por todas as cidades)
# sempre voltava pro MESMO lugar fixo (perto de Pallet) — quem entrasse pela
# porta de Viridian saía teleportado em Pallet. Nunca dava pra notar antes
# porque só existiam 2 entradas e ambas levavam ao mesmo lugar por coincidência
# de teste. Agora cada entrada guarda de onde veio, e a saída usa isso.
var _pc_return_map  : String    = "res://scenes/world/maps/WorldMap.tscn"
var _pc_return_tile : Vector2i  = Vector2i(76, 91)

func remember_pokemon_center_return(map_scene_path: String, tile: Vector2i) -> void:
	_pc_return_map  = map_scene_path
	_pc_return_tile = tile

func warp_to_remembered_return() -> void:
	warp_to(_pc_return_map, _pc_return_tile)

var _pending_spawn_tile : Vector2i = Vector2i.ZERO

func apply_pending_spawn() -> void:
	if player and _pending_spawn_tile != Vector2i.ZERO:
		player.set_grid_position(_pending_spawn_tile)
		_pending_spawn_tile = Vector2i.ZERO
		player.unlock_input()

# ──────────────────────────────────────────────────────────────────────────────
# Encontros selvagens
# ──────────────────────────────────────────────────────────────────────────────
func _on_wild_encounter_started(_pokemon: Node) -> void:
	_shake_camera()
	AudioManager.play_sfx("encounter")

func _shake_camera() -> void:
	if not player:
		return
	var cam : Camera2D = null
	for child in player.get_children():
		if child is Camera2D:
			cam = child
			break
	if not cam:
		return
	var origin := cam.offset
	var tween := cam.create_tween()
	for i in 6:
		var dx := randf_range(-4.0, 4.0)
		var dy := randf_range(-3.0, 3.0)
		tween.tween_property(cam, "offset", origin + Vector2(dx, dy), 0.04)
	tween.tween_property(cam, "offset", origin, 0.06)

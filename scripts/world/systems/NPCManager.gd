## NPCManager.gd — Instancia NPCs das zonas e gerencia presença baseada em distância.
## Carrega posições de NPCs do zones.json via ZoneManager.
## Desinstancia NPCs além de DESPAWN_RADIUS_TILES.
extends Node

# ──────────────────────────────────────────────────────────────────────────────
# Constantes
# ──────────────────────────────────────────────────────────────────────────────
const DESPAWN_RADIUS_TILES : int    = 280
const TILE_SIZE            : int    = 16
const CHECK_INTERVAL_SEC   : float  = 2.0   # verifica distância a cada N segundos

const NPC_SCENE : String = "res://scenes/entities/NpcEntity.tscn"

# ──────────────────────────────────────────────────────────────────────────────
# Estado
# ──────────────────────────────────────────────────────────────────────────────
## npc_id → instância Node ativa
var _active_npcs   : Dictionary = {}
## npc_id → dados do NPC (do zones.json)
var _npc_data      : Dictionary = {}

var _player        : Node2D = null
var _check_timer   : float  = 0.0
var _npc_scene     : PackedScene = null
var _spawn_parent  : Node   = null

# ──────────────────────────────────────────────────────────────────────────────
# Ciclo de vida
# ──────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_npc_scene    = load(NPC_SCENE) as PackedScene
	_spawn_parent = self

	if not _npc_scene:
		push_warning("NPCManager: NpcEntity.tscn não encontrado em %s" % NPC_SCENE)

	EventBus.zone_changed.connect(_on_zone_changed)
	set_process(true)

func _process(delta: float) -> void:
	if not _player:
		_player = _find_player()

	_check_timer += delta
	if _check_timer >= CHECK_INTERVAL_SEC:
		_check_timer = 0.0
		_despawn_distant()

# ──────────────────────────────────────────────────────────────────────────────
# API pública
# ──────────────────────────────────────────────────────────────────────────────
## Define nó pai para as instâncias de NPC.
func set_spawn_parent(parent: Node) -> void:
	_spawn_parent = parent

## Define player manualmente.
func set_player(p: Node2D) -> void:
	_player = p

## Força recarregamento dos NPCs da zona atual.
func refresh_zone(zone: Dictionary) -> void:
	_spawn_npcs_for_zone(zone)

## Retorna quantidade de NPCs ativos.
func get_active_count() -> int:
	return _active_npcs.size()

# ──────────────────────────────────────────────────────────────────────────────
# Lógica de spawn/despawn
# ──────────────────────────────────────────────────────────────────────────────
func _on_zone_changed(zone_id: String) -> void:
	var zone_manager := _get_zone_manager()
	if not zone_manager:
		return

	var zone : Dictionary = zone_manager.get_zone_by_id(zone_id)
	if zone.is_empty():
		return

	_spawn_npcs_for_zone(zone)

func _spawn_npcs_for_zone(zone: Dictionary) -> void:
	if not _npc_scene:
		return

	var npcs : Array = zone.get("npcs", [])
	for npc_data in npcs:
		var npc_id : String = npc_data.get("id", "")
		if npc_id.is_empty():
			continue
		# Já instanciado
		if _active_npcs.has(npc_id) and is_instance_valid(_active_npcs[npc_id]):
			continue

		_spawn_npc(npc_id, npc_data)

func _spawn_npc(npc_id: String, data: Dictionary) -> void:
	if not _npc_scene:
		return

	var tile = data.get("tile", [0, 0])
	var world_pos := Vector2(
		float(tile[0]) * TILE_SIZE,
		float(tile[1]) * TILE_SIZE
	)

	var instance := _npc_scene.instantiate()
	if not instance:
		return

	instance.global_position = world_pos

	# Injeta ID e dialog_id se o NPC tiver essas propriedades
	if "npc_id" in instance:
		instance.npc_id = npc_id
	if "dialog_id" in instance:
		instance.dialog_id = data.get("dialog_id", "")

	_spawn_parent.add_child(instance)
	_active_npcs[npc_id] = instance
	_npc_data[npc_id]    = data

func _despawn_distant() -> void:
	if not _player:
		return

	var despawn_px : float = DESPAWN_RADIUS_TILES * TILE_SIZE
	var to_remove  : Array = []

	for npc_id in _active_npcs:
		var inst = _active_npcs[npc_id]
		if not is_instance_valid(inst):
			to_remove.append(npc_id)
			continue
		var dist : float = _player.global_position.distance_to(inst.global_position)
		if dist > despawn_px:
			to_remove.append(npc_id)

	for npc_id in to_remove:
		var inst = _active_npcs.get(npc_id)
		_active_npcs.erase(npc_id)
		if inst and is_instance_valid(inst):
			inst.queue_free()

# ──────────────────────────────────────────────────────────────────────────────
# Utilitários
# ──────────────────────────────────────────────────────────────────────────────
func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null

func _get_zone_manager() -> Node:
	var parent := get_parent()
	if parent:
		for child in parent.get_children():
			if child.name == "ZoneManager":
				return child
	return null

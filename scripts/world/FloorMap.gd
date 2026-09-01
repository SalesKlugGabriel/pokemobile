## FloorMap.gd — Base para cenas de andares de dungeon.
## Cada andar de dungeon (MtMoon_B1, RockTunnel_B2, etc.) usa este script.
## Registra o player, aplica pending_spawn e emite zone_changed.
## Transições entre andares e saídas usam WarpZone — sem DungeonPortal.
class_name FloorMap
extends Node2D

## ID da zona (chave em zones.json — usado pelo AudioManager e ZoneManager)
@export var zone_id   : String = ""
## Se true, aplica escuridão (Rock Tunnel, Cerulean Cave, etc.)
## Visão ampliada com HM05 Flash (verificado via SaveManager)
@export var dark_cave : bool   = false

## ID da ESTRUTURA de múltiplos andares (ex: "pokemon_tower", "cerulean_cave")
## — bate com o "target" de objetivos reach_floor/traverse_floors em
## quests.json. Vazio = este andar não conta pra nenhum objetivo desse tipo
## (padrão pra todo FloorMap que já existia antes desta peça de motor).
@export var structure_id : String = ""
## Número deste andar dentro da estrutura acima. 0 = não é andar rastreado
## (não emite floor_reached). Ex: 5 pro 5º andar da Torre Pokémon.
@export var floor_number : int    = 0

const DARK_RADIUS_TILES := 3

func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		WorldManager.player = player
	WorldManager.apply_pending_spawn()
	EventBus.map_changed.emit("", zone_id)
	if zone_id != "":
		EventBus.zone_changed.emit(zone_id)
	if structure_id != "" and floor_number > 0:
		EventBus.floor_reached.emit(structure_id, floor_number)
	if dark_cave:
		_apply_darkness()

func _apply_darkness() -> void:
	# Cria CanvasLayer de escuridão com shader circular ao redor do player
	# O raio aumenta para DARK_RADIUS_TILES * 3 se o jogador tiver HM Flash
	var has_flash := false
	if SaveManager.has_method("has_hm"):
		has_flash = SaveManager.has_hm("flash")
	var radius_tiles := DARK_RADIUS_TILES * 3 if has_flash else DARK_RADIUS_TILES
	_spawn_darkness_layer(radius_tiles)

func _spawn_darkness_layer(radius_tiles: int) -> void:
	# Overlay preto com buraco circular (shader simples via ColorRect)
	# Requer shader "res://assets/shaders/darkness.gdshader" — criado em Sprint 9B.5
	var overlay := CanvasLayer.new()
	overlay.layer = 50
	overlay.name = "DarknessOverlay"
	add_child(overlay)
	# Shader placeholder — sem crash se shader ausente
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0.92)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(rect)
	push_warning("FloorMap: darkness shader placeholder — criar res://assets/shaders/darkness.gdshader para visão real")

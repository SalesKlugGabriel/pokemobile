## WarpZone.gd — Area2D que transporta o jogador para outro mapa ao pisá-la.
## Colocar na cena de mapa com CollisionShape2D. target_map e spawn_tile
## configurados pelo Inspector.
class_name WarpZone
extends Area2D

## Caminho da cena de destino (ex: "res://scenes/world/maps/Route1.tscn")
@export var target_map : String = ""
## Tile de spawn no mapa destino
@export var spawn_tile : Vector2i = Vector2i.ZERO

## Cooldown inicial para evitar warp imediato ao spawnar no tile da zona
var _cooldown : float = 0.0
const WARP_COOLDOWN : float = 1.0

func _ready() -> void:
	_cooldown = WARP_COOLDOWN
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

func _on_body_entered(body: Node) -> void:
	if _cooldown > 0.0:
		return
	if body is TrainerEntity and target_map != "":
		WorldManager.warp_to(target_map, spawn_tile)

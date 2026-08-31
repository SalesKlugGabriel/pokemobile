## WarpZone.gd — Area2D que transporta o jogador para outro mapa ao pisá-la.
## Colocar na cena de mapa com CollisionShape2D. target_map e spawn_tile
## configurados pelo Inspector.
class_name WarpZone
extends Area2D

## Caminho da cena de destino (ex: "res://scenes/world/maps/Route1.tscn")
@export var target_map : String = ""
## Tile de spawn no mapa destino
@export var spawn_tile : Vector2i = Vector2i.ZERO

## Se true: esta é uma ENTRADA de Centro Pokémon — antes de entrar, guarda de
## onde o jogador veio (pra saída de dentro do PokemonCenter saber voltar pro
## lugar certo, não sempre pro mesmo lugar fixo).
@export var is_pokemon_center_entrance : bool = false
## Se true: esta é a SAÍDA do Centro Pokémon — ignora target_map/spawn_tile
## acima e usa o que foi guardado pela entrada correspondente.
@export var uses_remembered_return : bool = false

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
	if not body is TrainerEntity:
		return
	if uses_remembered_return:
		WorldManager.warp_to_remembered_return()
		return
	if target_map == "":
		return
	if is_pokemon_center_entrance:
		WorldManager.remember_pokemon_center_return(
			get_tree().current_scene.scene_file_path, body.grid_pos
		)
	WorldManager.warp_to(target_map, spawn_tile)

## Cena de validação visual isolada do Player V1; não é parte do Laboratório.
extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var player: Node3D = $PlayerV1


func _ready() -> void:
	camera.look_at(player.global_position + Vector3.UP * 0.78, Vector3.UP)
	var animator := player.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animator and animator.has_animation("PLAYER_V1_IDLE"):
		animator.play("PLAYER_V1_IDLE")

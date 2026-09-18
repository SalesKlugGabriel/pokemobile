## WORLD_LAB Fase 4 — terreno isolado da fábrica, sem gameplay/spawn/scatter.
extends Node3D

const WorldSpec := preload("res://scripts/world_factory/WorldSpec.gd")
const TerrainFactory := preload("res://scripts/world_factory/WorldTerrainFactory.gd")
const PLAYER_V1 := preload("res://assets/characters/player_v1/player_v1.glb")

var factory: WorldTerrainFactory
var chunk_count := 0


func _ready() -> void:
	var spec := WorldSpec.carregar_world_lab()
	var errors := WorldSpec.validar(spec)
	if not errors.is_empty():
		push_error("WORLD_LAB spec inválida: " + str(errors))
		return
	factory = TerrainFactory.new(spec)
	_build_chunks(spec)
	_build_water(spec)
	_place_scale_reference(spec)


func _build_chunks(spec: Dictionary) -> void:
	var bounds: Dictionary = spec["bounds_m"]
	var terrain: Dictionary = spec["terrain"]
	var count_x := int(float(bounds["width"]) / float(terrain["chunk_size_m"]))
	var count_z := int(float(bounds["depth"]) / float(terrain["chunk_size_m"]))
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.92
	for cx in count_x:
		for cz in count_z:
			var root := Node3D.new()
			root.name = "TerrainChunk_%d_%d" % [cx, cz]
			add_child(root)
			var mesh := factory.gerar_malha_chunk(cx, cz)
			var visual := MeshInstance3D.new()
			visual.name = "Visual"
			visual.mesh = mesh
			visual.material_override = material
			root.add_child(visual)
			var body := StaticBody3D.new()
			body.name = "Collision"
			var shape := CollisionShape3D.new()
			shape.shape = mesh.create_trimesh_shape()
			body.add_child(shape)
			root.add_child(body)
			chunk_count += 1


func _build_water(spec: Dictionary) -> void:
	var bounds: Dictionary = spec["bounds_m"]
	var terrain: Dictionary = spec["terrain"]
	var water := MeshInstance3D.new()
	water.name = "WaterVisualOnly"
	var plane := PlaneMesh.new()
	plane.size = Vector2(float(bounds["width"]), float(bounds["depth"]))
	water.mesh = plane
	water.position = Vector3(
		float(bounds["min_x"]) + float(bounds["width"]) * .5,
		float(terrain["sea_level_m"]),
		float(bounds["min_z"]) + float(bounds["depth"]) * .5)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.08, 0.36, 0.57, .58)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = .22
	water.material_override = material
	add_child(water)


func _place_scale_reference(spec: Dictionary) -> void:
	var spawn: Array = spec["manual_reservations"][0]["center_m"]
	var x := float(spawn[0])
	var z := float(spawn[1])
	var player := PLAYER_V1.instantiate() as Node3D
	player.name = "PlayerV1ScaleReference"
	player.position = Vector3(x, factory.altura_em(x, z) + .01, z)
	add_child(player)
	var animation := player.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation and animation.has_animation("PLAYER_V1_IDLE"):
		animation.play("PLAYER_V1_IDLE")

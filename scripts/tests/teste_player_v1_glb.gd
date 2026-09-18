## Teste isolado do Player V1 importado, sem tocar no treinador oficial.
extends SceneTree

const PLAYER_SCENE := "res://assets/characters/player_v1/player_v1.glb"
const VISUAL_TEST_SCENE := "res://scenes/tests/player_v1_test.tscn"
var ok := 0
var failures := 0


func _check(condition: bool, description: String) -> void:
	if condition:
		ok += 1
		print("OK: ", description)
	else:
		failures += 1
		push_error("FALHA: " + description)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var visual_test := load(VISUAL_TEST_SCENE) as PackedScene
	_check(visual_test != null, "cena visual isolada carrega")
	if visual_test:
		var visual_instance := visual_test.instantiate() as Node3D
		root.add_child(visual_instance)
		await process_frame
		_check(visual_instance.get_node_or_null("PlayerV1") != null, "cena visual monta o Player V1")
		_check(visual_instance.get_node_or_null("TerrenoAtual") != null, "cena visual monta o terreno atual")
		visual_instance.queue_free()
	var packed := load(PLAYER_SCENE) as PackedScene
	_check(packed != null, "GLB importa como PackedScene")
	if packed == null:
		_finish()
		return
	var player := packed.instantiate() as Node3D
	root.add_child(player)
	var skeleton := player.find_child("Skeleton3D", true, false) as Skeleton3D
	_check(skeleton != null, "skeleton presente")
	if skeleton:
		_check(skeleton.get_bone_count() >= 25, "skeleton preserva 25 ossos")
	var animation_player := player.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_check(animation_player != null, "AnimationPlayer presente")
	if animation_player:
		var clips := animation_player.get_animation_list()
		print("PLAYER_V1_IMPORTED_ANIMATIONS=", clips)
		for clip in ["PLAYER_V1_IDLE", "PLAYER_V1_WALK", "PLAYER_V1_RUN"]:
			_check(animation_player.has_animation(clip), "clip importado: " + clip)
	_check(_meshes(player).size() <= 9, "runtime usa no máximo 9 malhas por material")
	var bounds := _bounds(player)
	print("PLAYER_V1_IMPORTED_BOUNDS=", bounds)
	_check(abs(bounds.position.y) <= 0.02, "pés no solo após importação")
	_check(abs(bounds.size.y - 1.60) <= 0.03, "altura preservada em 1,60 m")
	_check(bounds.size.z > 0.15 and bounds.size.x > 0.15, "volume horizontal válido")
	player.queue_free()
	_finish()


func _bounds(root_node: Node3D) -> AABB:
	var has_bounds := false
	var result := AABB()
	for mesh in _meshes(root_node):
		var local := mesh.get_aabb()
		for x in [local.position.x, local.end.x]:
			for y in [local.position.y, local.end.y]:
				for z in [local.position.z, local.end.z]:
					var point := mesh.global_transform * Vector3(x, y, z)
					if has_bounds:
						result = result.expand(point)
					else:
						result = AABB(point, Vector3.ZERO)
						has_bounds = true
	return result


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_meshes(child))
	return result


func _finish() -> void:
	print("=== Resultado: %d ok, %d falhas ===" % [ok, failures])
	quit(1 if failures else 0)

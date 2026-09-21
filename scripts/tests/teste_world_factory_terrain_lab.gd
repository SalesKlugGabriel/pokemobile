extends SceneTree

const LAB := preload("res://scenes/tests/world_factory_terrain_lab.tscn")
var ok := 0
var fail := 0


func _check(condition: bool, label: String) -> void:
	if condition:
		ok += 1
		print("OK: ", label)
	else:
		fail += 1
		push_error("FALHA: " + label)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var lab := LAB.instantiate()
	root.add_child(lab)
	await process_frame
	_check(lab.factory != null, "factory é criada pela spec")
	_check(lab.chunk_count == 16, "WORLD_LAB cria 16 chunks de 64 m")
	var visual_chunks := 0
	var collision_chunks := 0
	for child in lab.get_children():
		if child.name.begins_with("TerrainChunk_"):
			if child.get_node_or_null("Visual") is MeshInstance3D:
				visual_chunks += 1
			if child.get_node_or_null("Collision") is StaticBody3D:
				collision_chunks += 1
	_check(visual_chunks == 16, "cada chunk possui malha visual")
	_check(collision_chunks == 16, "cada chunk possui colisão triangulada")
	_check(lab.get_node_or_null("WaterVisualOnly") is MeshInstance3D, "água visual existe sem corpo físico")
	var water := lab.get_node_or_null("WaterVisualOnly") as MeshInstance3D
	_check(water != null and water.material_override is ShaderMaterial,
		"água usa material shader extensível")
	if water and water.mesh is PlaneMesh:
		var plane := water.mesh as PlaneMesh
		_check(plane.subdivide_width == 64 and plane.subdivide_depth == 64,
			"água possui malha subdividida para ondas suaves")
	var rock_root := lab.get_node_or_null("RockFormations") as Node3D
	_check(rock_root != null and rock_root.get_child_count() == 5,
		"laboratório instancia cinco formações rochosas da biblioteca")
	if rock_root and lab.factory:
		var all_grounded := true
		for rock in rock_root.get_children():
			var node := rock as Node3D
			all_grounded = all_grounded and node != null and absf(node.position.y - lab.factory.altura_em(node.position.x, node.position.z) + .03) < .001
		_check(all_grounded, "rochas assentam na superfície da factory")
	var player := lab.get_node_or_null("PlayerV1ScaleReference") as Node3D
	_check(player != null, "Player V1 está na cena como régua")
	if player and lab.factory:
		_check(absf(player.position.y - lab.factory.altura_em(player.position.x, player.position.z) - .01) < .001,
			"Player V1 repousa sobre a altura da factory")
	lab.queue_free()
	print("=== Resultado: %d ok, %d falhas ===" % [ok, fail])
	quit(1 if fail > 0 else 0)

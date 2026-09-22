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
	var vegetation := lab.get_node_or_null("Vegetation") as Node3D
	_check(vegetation != null, "vegetação é montada pela World Factory")
	if vegetation:
		var multimeshes := 0
		var tree_lod_instances := 0
		var range_configured := true
		var lod_ranges_configured := true
		for child in vegetation.get_children():
			var instance := child as MultiMeshInstance3D
			if instance and instance.multimesh and instance.multimesh.instance_count > 0:
				multimeshes += 1
				if instance.name.begins_with("TreesLod1_"):
					tree_lod_instances += 1
					lod_ranges_configured = lod_ranges_configured and instance.visibility_range_begin > 0.0
				range_configured = range_configured and instance.visibility_range_end > 0.0
		_check(multimeshes == 19, "vegetação usa 19 MultiMeshes para variantes, arbustos e LOD")
		_check(tree_lod_instances == 5, "cinco variantes de árvore possuem LOD1 distante")
		_check(lod_ranges_configured, "LOD1 de árvore inicia somente fora da faixa próxima")
		_check(range_configured, "vegetação possui visibility range para o laboratório")
		var lod_is_lighter := true
		for variant in ["a", "b", "c", "d", "e"]:
			var source := FileAccess.open("res://assets/models/environment/trees/tree_%s.glb" % variant, FileAccess.READ)
			var lod := FileAccess.open("res://assets/models/environment/trees/tree_%s_lod1.glb" % variant, FileAccess.READ)
			lod_is_lighter = lod_is_lighter and source != null and lod != null
			if source and lod:
				lod_is_lighter = lod_is_lighter and lod.get_length() < source.get_length()
		_check(lod_is_lighter, "arquivos LOD1 são menores que as árvores próximas")
		var tree_visual := vegetation.get_node_or_null("Trees_A") as MultiMeshInstance3D
		var grass_visual := vegetation.get_node_or_null("Grass_Short") as MultiMeshInstance3D
		var bush_visual := vegetation.get_node_or_null("Bush_01") as MultiMeshInstance3D
		_check(tree_visual != null and tree_visual.material_override == null,
			"árvores preservam materiais PBR próprios do GLB")
		_check(grass_visual != null and grass_visual.material_override is ShaderMaterial,
			"grama mantém shader V3 de vento e variação")
		_check(bush_visual != null and bush_visual.material_override == null,
			"arbustos preservam material PBR próprio do GLB")
		_check(int(lab.vegetation_count.get("trees", 0)) > 0
			and int(lab.vegetation_count.get("bushes", 0)) > 0
			and int(lab.vegetation_count.get("grass_short", 0)) > 0
			and int(lab.vegetation_count.get("corals", 0)) > 0,
			"árvores, grama e corais são distribuídos")
	var player := lab.get_node_or_null("PlayerV1ScaleReference") as Node3D
	_check(player != null, "Player V1 está na cena como régua")
	if player and lab.factory:
		_check(absf(player.position.y - lab.factory.altura_em(player.position.x, player.position.z) - .01) < .001,
			"Player V1 repousa sobre a altura da factory")
	lab.queue_free()
	print("=== Resultado: %d ok, %d falhas ===" % [ok, fail])
	quit(1 if fail > 0 else 0)

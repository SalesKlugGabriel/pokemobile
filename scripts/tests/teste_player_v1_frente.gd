## Regressão da orientação canônica do Player V1.
##
## Frente do GLB e frente de Locomocao3D precisam ser -Z. A medida usa sapatos
## e boné porque ambos projetam a silhueta para a frente; não depende de nome de
## osso nem de comentário de pipeline.
extends SceneTree

const PLAYER_SCENE := "res://assets/characters/player_v1/player_v1.glb"
const PLAYER_VISUAL := preload("res://scripts/gameplay_v3/presentation/PlayerVisual3D.gd")
const ALTURA_DO_PE := 0.15
const ALTURA_DA_CABECA := 1.35
const CONFERENCIAS := 7

var ok := 0
var fail := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		ok += 1
		print("OK: ", label)
	else:
		fail += 1
		push_error("FALHA: %s %s" % [label, detail])


func _run() -> void:
	var packed := load(PLAYER_SCENE) as PackedScene
	_check(packed != null, "GLB do treinador carrega")
	if packed == null:
		_finish()
		return
	var raw := packed.instantiate() as Node3D
	root.add_child(raw)
	await process_frame
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(raw, meshes)
	_check(not meshes.is_empty(), "GLB possui malhas de runtime")
	var measure := _measure_front(meshes)
	_check(int(measure["feet_count"]) > 50 and int(measure["head_count"]) > 50,
		"medição encontrou sapatos e boné", str(measure))
	_check((float(measure["feet_front"]) > 0.0) == (float(measure["head_front"]) > 0.0),
		"sapatos e boné apontam para o mesmo lado", str(measure))
	var front := float(measure["feet_front"]) + float(measure["head_front"])
	print("MEDICAO_PLAYER_V1 frente_z=%.4f sapatos=%.4f bone=%.4f" % [front, float(measure["feet_front"]), float(measure["head_front"])])
	_check(front < -0.05, "GLB exportado aponta para -Z no Godot", "frente_z=%.4f" % front)
	var locomotion := load("res://scripts/gameplay_v3/movimento/Locomocao3D.gd")
	_check(absf(float(locomotion.girar_para(0.0, Vector3(0.0, 0.0, -5.0), 1.0, 100000.0))) < 0.01,
		"Locomocao3D mantém -Z como frente do corpo")
	raw.queue_free()

	var visual := PLAYER_VISUAL.new() as Node3D
	root.add_child(visual)
	await process_frame
	var visual_model := visual.get_node_or_null("PlayerV1GLB") as Node3D
	var visual_meshes: Array[MeshInstance3D] = []
	if visual_model:
		_collect_meshes(visual_model, visual_meshes)
	var visual_measure := _measure_front(visual_meshes)
	var source := FileAccess.get_file_as_string("res://scripts/gameplay_v3/presentation/PlayerVisual3D.gd")
	var visual_front := float(visual_measure["feet_front"]) + float(visual_measure["head_front"])
	_check(visual_model != null and visual_front < -0.05 and not source.contains("CORRECAO_DE_FRENTE"),
		"ponte visual não mantém compensação de 180°", "frente_z=%.4f" % visual_front)
	visual.queue_free()
	_finish()


func _measure_front(meshes: Array[MeshInstance3D]) -> Dictionary:
	var feet_min := INF
	var feet_max := -INF
	var head_min := INF
	var head_max := -INF
	var feet_count := 0
	var head_count := 0
	for mesh_instance in meshes:
		for surface in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var world_vertex := mesh_instance.global_transform * vertex
				if world_vertex.y < ALTURA_DO_PE:
					feet_min = minf(feet_min, world_vertex.z)
					feet_max = maxf(feet_max, world_vertex.z)
					feet_count += 1
				elif world_vertex.y > ALTURA_DA_CABECA:
					head_min = minf(head_min, world_vertex.z)
					head_max = maxf(head_max, world_vertex.z)
					head_count += 1
	return {
		"feet_count": feet_count,
		"head_count": head_count,
		"feet_front": feet_min + feet_max if feet_count > 0 else 0.0,
		"head_front": head_min + head_max if head_count > 0 else 0.0
	}


func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		result.append(node)
	for child in node.get_children():
		_collect_meshes(child, result)


func _finish() -> void:
	if ok + fail != CONFERENCIAS:
		fail += 1
		push_error("FALHA: guarda de contagem esperava %d, rodaram %d" % [CONFERENCIAS, ok + fail - 1])
	print("=== Resultado: %d ok, %d falhas ===" % [ok, fail])
	quit(1 if fail > 0 else 0)

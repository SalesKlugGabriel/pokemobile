## Gate do GLB de trabalho, executado antes de tocar no asset canônico.
extends SceneTree

const PACOTE := preload("res://assets/models/pokemon/source/pidgeot_golden/Pidgeot_Golden_Working.glb")
var ok := 0
var falhas := 0


func _initialize() -> void:
	call_deferred("_rodar")


func _rodar() -> void:
	var modelo := PACOTE.instantiate() as Node3D
	root.add_child(modelo)
	await process_frame
	var resultado := ValidadorDeModelo.conferir(modelo, 18)
	_conferir(bool(resultado["ok"]), "1,50 m e pés no zero passam no validador")
	var frente := modelo.find_child("PKM_PIDGEOT_FRONT_REFERENCE", true, false) as Node3D
	_conferir(frente != null and frente.global_position.z < -0.5,
		"bico aponta para −Z no Godot")
	var arm := _esqueleto(modelo)
	_conferir(arm != null and arm.get_bone_count() == 12,
		"asas, pernas e cauda possuem ossos próprios")
	var animador := modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_conferir(animador != null, "AnimationPlayer importado")
	if animador != null:
		for acao in ["IDLE", "WALK", "RUN", "FLY", "ATTACK_01", "HIT", "FAINT"]:
			_conferir(animador.has_animation("PKM_PIDGEOT_" + acao), "Action " + acao)
		_conferir(bool(ValidadorDeModelo.conferir_animacoes(modelo)["ok"]),
			"papéis de animação resolvidos")
		if arm != null:
			var perna := arm.find_bone("leg_l")
			var asa := arm.find_bone("wing_upper_l")
			_conferir(perna >= 0 and asa >= 0, "ossos de perna e asa acessíveis")
			if perna >= 0 and asa >= 0:
				animador.play("PKM_PIDGEOT_WALK")
				animador.seek(0, true)
				animador.advance(0)
				var walk := absf(arm.get_bone_pose_rotation(perna).get_euler().x)
				animador.play("PKM_PIDGEOT_RUN")
				animador.seek(0, true)
				animador.advance(0)
				var run := absf(arm.get_bone_pose_rotation(perna).get_euler().x)
				print("PIDGEOT_GAIT walk=%.3f run=%.3f" % [walk, run])
				_conferir(walk > 0.3 and run > walk + 0.25,
					"RUN move perna com amplitude distinta de WALK")
				animador.play("PKM_PIDGEOT_FLY")
				animador.seek(0, true)
				animador.advance(0)
				var up := arm.get_bone_pose_rotation(asa).get_euler().z
				animador.seek(0.4, true)
				animador.advance(0)
				var down := arm.get_bone_pose_rotation(asa).get_euler().z
				_conferir(absf(up-down)>0.6, "FLY articula as asas")
	_conferir(_triangulos(modelo) <= 2500, "orçamento de 2.500 triângulos")
	modelo.queue_free()
	print("=== Resultado: %d ok, %d falha(s) ===" % [ok, falhas])
	quit(1 if falhas else 0)


func _esqueleto(no: Node) -> Skeleton3D:
	if no is Skeleton3D:
		return no
	for filho in no.get_children():
		var encontrado := _esqueleto(filho)
		if encontrado != null:
			return encontrado
	return null


func _triangulos(no: Node) -> int:
	var total := 0
	if no is MeshInstance3D:
		var mesh := (no as MeshInstance3D).mesh
		for superficie in mesh.get_surface_count():
			total += mesh.surface_get_array_index_len(superficie)/3
	for filho in no.get_children():
		total += _triangulos(filho)
	return total


func _conferir(condicao: bool, descricao: String) -> void:
	if condicao:
		ok += 1
		print("OK: ", descricao)
	else:
		falhas += 1
		push_error("FALHA: " + descricao)

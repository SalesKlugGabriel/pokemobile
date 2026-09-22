## Gate técnico do GLB de trabalho; não depende do modelo canônico.
extends SceneTree

const PACOTE := preload("res://assets/models/pokemon/source/charizard_golden/Charizard_Golden_Working.glb")
var ok := 0
var falhas := 0


func _initialize() -> void:
	call_deferred("_rodar")


func _rodar() -> void:
	var modelo := PACOTE.instantiate() as Node3D
	root.add_child(modelo)
	await process_frame
	var caixa := ValidadorDeModelo.conferir(modelo, 6)
	_conferir(bool(caixa["ok"]), "1,70 m e pés em Y=0 passam no validador real")
	var frente := modelo.find_child("PKM_CHARIZARD_FRONT_REFERENCE", true, false) as Node3D
	_conferir(frente != null and frente.global_position.z < -0.55,
		"marcador anatômico confirma frente em −Z no Godot")
	var arm := _encontrar_esqueleto(modelo)
	_conferir(arm != null and arm.get_bone_count() >= 23,
		"rig contém articulações de braço, perna, asas e cauda")
	var animador := modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_conferir(animador != null, "AnimationPlayer importa do GLB de trabalho")
	if animador != null:
		for nome in ["IDLE", "WALK", "RUN", "ATTACK_01", "HIT", "FAINT", "FLY"]:
			_conferir(animador.has_animation("PKM_CHARIZARD_" + nome),
				"Action PKM_CHARIZARD_%s disponível" % nome)
		var papel := ValidadorDeModelo.conferir_animacoes(modelo)
		_conferir(bool(papel["ok"]), "papéis de animação resolvem pelo contrato")
		if arm != null and animador.has_animation("PKM_CHARIZARD_WALK") and animador.has_animation("PKM_CHARIZARD_RUN"):
			var leg := arm.find_bone("leg_l")
			var shin := arm.find_bone("shin_l")
			_conferir(leg >= 0 and shin >= 0, "perna e joelho existem como ossos distintos")
			if leg >= 0 and shin >= 0:
				animador.play("PKM_CHARIZARD_WALK")
				animador.seek(0.0, true)
				animador.advance(0.0)
				var passo := absf(arm.get_bone_pose_rotation(leg).get_euler().x)
				animador.play("PKM_CHARIZARD_RUN")
				animador.seek(0.0, true)
				animador.advance(0.0)
				var corrida := absf(arm.get_bone_pose_rotation(leg).get_euler().x)
				print("POSE walk=%.3f run=%.3f" % [passo, corrida])
				_conferir(passo > 0.25 and corrida > passo * 1.25,
					"RUN articula a perna com amplitude maior que WALK")
				_conferir(_triangulos(modelo) <= 3500,
					"malha cabe no orçamento de 3.500 triângulos")
	modelo.queue_free()
	print("=== Resultado: %d ok, %d falha(s) ===" % [ok, falhas])
	quit(1 if falhas > 0 else 0)


func _encontrar_esqueleto(no: Node) -> Skeleton3D:
	if no is Skeleton3D:
		return no
	for filho in no.get_children():
		var achado := _encontrar_esqueleto(filho)
		if achado != null:
			return achado
	return null


func _triangulos(no: Node) -> int:
	var total := 0
	if no is MeshInstance3D:
		var visual := no as MeshInstance3D
		for superficie in visual.mesh.get_surface_count():
			var indice: int = visual.mesh.surface_get_array_index_len(superficie)
			total += indice / 3 if indice > 0 else visual.mesh.surface_get_array_len(superficie) / 3
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

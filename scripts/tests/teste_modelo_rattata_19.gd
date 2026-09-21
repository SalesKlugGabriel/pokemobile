## Rattata #19 é o primeiro selvagem de volume; não pode voltar ao primitivo.
extends SceneTree

var ok := 0
var falhas := 0


func _initialize() -> void:
	call_deferred("_rodar")


func _rodar() -> void:
	var caminho := "res://assets/models/pokemon/19.glb"
	_conferir(ResourceLoader.exists(caminho), "GLB do Rattata existe no caminho canônico")
	var pacote := load(caminho) as PackedScene
	_conferir(pacote != null, "GLB é um PackedScene importável")
	if pacote == null:
		_finalizar()
		return
	var modelo := pacote.instantiate() as Node3D
	root.add_child(modelo)
	await process_frame

	var Validador: GDScript = load("res://scripts/gameplay_v3/pokemon/ValidadorDeModelo.gd")
	var geometria: Dictionary = Validador.conferir(modelo, 19)
	_conferir(bool(geometria["ok"]), "altura 0,30 m e pés em Y=0 passam na régua")
	modelo.position.y = 2.0
	_conferir(bool(Validador.conferir(modelo, 19)["ok"]),
		"validador mede pés locais mesmo quando o Pokémon nasce acima de Y=0")
	modelo.position.y = 0.0
	var frente := modelo.find_child("PKM_RATTATA_FRONT_REFERENCE", true, false) as Node3D
	_conferir(frente != null and frente.global_position.z < -0.01,
		"marcador medido confirma frente em −Z no Godot")
	var animacoes: Dictionary = Validador.conferir_animacoes(modelo)
	_conferir(bool(animacoes["ok"]), "entrega idle, locomoção, ataque e hit")

	var esqueleto := _skeleton(modelo)
	_conferir(esqueleto != null, "rig adaptado ao quadrúpede está presente")
	if esqueleto != null:
		_conferir(esqueleto.get_bone_count() >= 14, "rig contém corpo, quatro patas, orelhas e cauda")
	var player := modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_conferir(player != null, "AnimationPlayer foi exportado")
	if player != null:
		for acao in ["PKM_RATTATA_IDLE", "PKM_RATTATA_WALK", "PKM_RATTATA_RUN",
				"PKM_RATTATA_ATTACK_01", "PKM_RATTATA_HIT", "PKM_RATTATA_FAINT"]:
			_conferir(player.has_animation(acao), "Action presente: %s" % acao)
	_conferir(_materiais(modelo) <= 2, "runtime mantém no máximo dois materiais")
	_conferir(_triangulos(modelo) <= 2500, "malha é apropriada para selvagem comum")
	modelo.queue_free()
	_finalizar()


func _materiais(no: Node) -> int:
	var achados := {}
	for mesh in _malhas(no):
		for superficie in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(superficie)
			if material != null:
				achados[material.resource_path if not material.resource_path.is_empty() else str(material)] = true
	return achados.size()


func _triangulos(no: Node) -> int:
	var total := 0
	for mesh in _malhas(no):
		for superficie in mesh.mesh.get_surface_count():
			total += mesh.mesh.surface_get_array_len(superficie) / 3
	return total


func _malhas(no: Node) -> Array[MeshInstance3D]:
	var achadas: Array[MeshInstance3D] = []
	if no is MeshInstance3D:
		achadas.append(no)
	for filho in no.get_children():
		achadas.append_array(_malhas(filho))
	return achadas


func _skeleton(no: Node) -> Skeleton3D:
	if no is Skeleton3D:
		return no
	for filho in no.get_children():
		var achado := _skeleton(filho)
		if achado != null:
			return achado
	return null


func _conferir(condicao: bool, mensagem: String) -> void:
	if condicao:
		ok += 1
		print("  OK  %s" % mensagem)
	else:
		falhas += 1
		push_error("FALHA: %s" % mensagem)


func _finalizar() -> void:
	print("=== Resultado: %d ok, %d falha(s) ===" % [ok, falhas])
	quit(1 if falhas > 0 else 0)

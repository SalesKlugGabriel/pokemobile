## Impede regressão da biblioteca ambiental a GLBs sem escala, apoio ou LOD real.
extends SceneTree

const VARIANTES := ["a", "b", "c", "d", "e"]
var ok := 0
var falhas := 0


func _initialize() -> void:
	call_deferred("_rodar")


func _rodar() -> void:
	for variante in VARIANTES:
		var proxima := _carregar("res://assets/models/environment/trees/tree_%s.glb" % variante)
		var distante := _carregar("res://assets/models/environment/trees/tree_%s_lod1.glb" % variante)
		_conferir(proxima != null, "TREE_%s LOD0 importa como PackedScene" % variante.to_upper())
		_conferir(distante != null, "TREE_%s LOD1 importa como PackedScene" % variante.to_upper())
		if proxima == null or distante == null:
			continue
		var modelo_proximo := proxima.instantiate() as Node3D
		var modelo_distante := distante.instantiate() as Node3D
		root.add_child(modelo_proximo)
		root.add_child(modelo_distante)
		await process_frame
		var caixa := _caixa_local(modelo_proximo)
		_conferir(caixa.size.y >= 4.0 and caixa.size.y <= 9.0,
			"TREE_%s mantém escala de árvore jogável" % variante.to_upper())
		_conferir(absf(caixa.position.y) <= 0.08,
			"TREE_%s apoia raízes em Y=0" % variante.to_upper())
		_conferir(_triangulos(modelo_distante) < _triangulos(modelo_proximo),
			"TREE_%s LOD1 reduz triângulos de verdade" % variante.to_upper())
		modelo_proximo.queue_free()
		modelo_distante.queue_free()
	_finalizar()


func _carregar(caminho: String) -> PackedScene:
	return load(caminho) as PackedScene


func _caixa_local(modelo: Node3D) -> AABB:
	var resultado := AABB()
	var iniciou := false
	for malha in _malhas(modelo):
		var caixa := malha.get_aabb()
		var local := modelo.global_transform.affine_inverse() * malha.global_transform
		for canto in _cantos(caixa):
			var ponto := local * canto
			if iniciou:
				resultado = resultado.expand(ponto)
			else:
				resultado = AABB(ponto, Vector3.ZERO)
				iniciou = true
	return resultado


func _cantos(caixa: AABB) -> Array[Vector3]:
	var fim := caixa.end
	return [
		caixa.position, Vector3(fim.x, caixa.position.y, caixa.position.z),
		Vector3(caixa.position.x, fim.y, caixa.position.z),
		Vector3(caixa.position.x, caixa.position.y, fim.z),
		Vector3(fim.x, fim.y, caixa.position.z), Vector3(fim.x, caixa.position.y, fim.z),
		Vector3(caixa.position.x, fim.y, fim.z), fim,
	]


func _malhas(no: Node) -> Array[MeshInstance3D]:
	var resultado: Array[MeshInstance3D] = []
	if no is MeshInstance3D:
		resultado.append(no)
	for filho in no.get_children():
		resultado.append_array(_malhas(filho))
	return resultado


func _triangulos(no: Node) -> int:
	var total := 0
	for malha in _malhas(no):
		for superficie in malha.mesh.get_surface_count():
			total += malha.mesh.surface_get_array_len(superficie) / 3
	return total


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

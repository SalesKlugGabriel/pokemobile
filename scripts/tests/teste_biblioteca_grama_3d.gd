## Garante que os clusters instanciados de grama mantêm escala e geometria útil.
extends SceneTree

const VARIANTES := ["short", "mid", "tall"]
var ok := 0
var falhas := 0


func _initialize() -> void:
	call_deferred("_rodar")


func _rodar() -> void:
	var triangulos_anteriores := 0
	for variante in VARIANTES:
		var pacote := load("res://assets/models/environment/grass/grass_%s.glb" % variante) as PackedScene
		_conferir(pacote != null, "GRASS_%s importa como PackedScene" % variante.to_upper())
		if pacote == null:
			continue
		var modelo := pacote.instantiate() as Node3D
		root.add_child(modelo)
		await process_frame
		var caixa := _caixa_local(modelo)
		var triangulos := _triangulos(modelo)
		_conferir(caixa.size.y >= 0.20 and caixa.size.y <= 1.10,
			"GRASS_%s tem altura de vegetação em escala de jogo" % variante.to_upper())
		_conferir(absf(caixa.position.y) <= 0.03,
			"GRASS_%s nasce apoiada no terreno" % variante.to_upper())
		_conferir(triangulos > triangulos_anteriores,
			"GRASS_%s aumenta densidade geométrica entre as três alturas" % variante.to_upper())
		triangulos_anteriores = triangulos
		modelo.queue_free()
	_finalizar()


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
	return [caixa.position, Vector3(fim.x, caixa.position.y, caixa.position.z),
		Vector3(caixa.position.x, fim.y, caixa.position.z), Vector3(caixa.position.x, caixa.position.y, fim.z),
		Vector3(fim.x, fim.y, caixa.position.z), Vector3(fim.x, caixa.position.y, fim.z),
		Vector3(caixa.position.x, fim.y, fim.z), fim]


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

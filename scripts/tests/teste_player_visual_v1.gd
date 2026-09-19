## Teste da ponte visual do Player V1. Roda fora do laboratório para separar a
## integração visual de terreno, input e física de gameplay.
extends SceneTree

const CONFERENCIAS_ESPERADAS := 11
const PlayerVisualScript = preload("res://scripts/gameplay_v3/presentation/PlayerVisual3D.gd")

var ok := 0
var falhas := 0


func _conf(condicao: bool, descricao: String) -> void:
	if condicao:
		ok += 1
		print("OK: ", descricao)
	else:
		falhas += 1
		push_error("FALHA: " + descricao)


func _init() -> void:
	call_deferred("_rodar")


func _rodar() -> void:
	var visual: Node3D = PlayerVisualScript.new()
	root.add_child(visual)
	# Em testes --script, o _ready do filho acontece no quadro seguinte.
	await process_frame
	_conf(bool(visual.call("tem_modelo")), "GLB Player V1 foi instanciado")
	_conf(not bool(visual.call("fallback_ativo")), "fallback não é usado com asset válido")
	_conf(visual.get_node_or_null("PlayerV1GLB") != null, "instância do GLB tem nome explícito")
	_conf(visual.call("clipe_atual") == "PLAYER_V1_IDLE", "idle é o clipe inicial")
	for estado in ["walk", "run", "idle"]:
		visual.call("apresentar_locomocao", estado)
		await process_frame
		_conf(visual.call("clipe_atual") == PlayerVisualScript.CLIPES_POR_ESTADO[estado],
			"estado " + estado + " toca sua Action")
	visual.queue_free()

	var treinador := TrainerController3D.new()
	root.add_child(treinador)
	await process_frame
	var ponte := treinador.get_node_or_null("PlayerVisualV1")
	_conf(ponte != null, "treinador monta a ponte visual")
	_conf(ponte != null and bool(ponte.call("tem_modelo")), "treinador usa GLB, não placeholder")
	_conf(_capsulas_visuais_diretas(treinador).is_empty(),
		"cápsula amarela não é mais visual direto do treinador")
	treinador.velocity = Vector3(Locomocao3D.VELOCIDADE_CAMINHADA, 0.0, 0.0)
	treinador.visual_do_jogador.call("apresentar_locomocao", treinador.estado_visual_de_locomocao())
	await process_frame
	_conf(ponte.call("clipe_atual") == "PLAYER_V1_WALK",
		"ponte usa o estado visual canônico do treinador")
	treinador.queue_free()

	if ok + falhas != CONFERENCIAS_ESPERADAS:
		falhas += 1
		push_error("FALHA: guarda de contagem esperava %d, rodaram %d" % [
			CONFERENCIAS_ESPERADAS, ok + falhas - 1])
	print("=== Resultado: %d ok, %d falhas ===" % [ok, falhas])
	quit(1 if falhas else 0)


func _capsulas_visuais_diretas(treinador: TrainerController3D) -> Array[MeshInstance3D]:
	var resultado: Array[MeshInstance3D] = []
	for filho in treinador.get_children():
		if filho is MeshInstance3D and filho.mesh is CapsuleMesh:
			resultado.append(filho)
	return resultado

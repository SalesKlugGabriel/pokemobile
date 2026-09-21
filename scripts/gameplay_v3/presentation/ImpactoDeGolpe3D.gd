## ImpactoDeGolpe3D — leitura espacial do acerto, sem regra de combate.
##
## `RelatorioDeGolpe.montar_3d()` já entrega destino, tipo, efetividade e a
## fração de vida atingida. Este componente só transforma esse resultado em um
## pulso breve: não decide dano, não classifica tipo e não procura o alvo.
class_name ImpactoDeGolpe3D
extends Node3D

const DURACAO := 0.42
const MAXIMO_DE_IMPACTOS := 12

var _event_bus: Node = null
var _impactos: Array[Node3D] = []


func _ready() -> void:
	_event_bus = get_node_or_null("/root/EventBus")
	if _event_bus != null:
		_event_bus.golpe_resolvido.connect(mostrar)


func _exit_tree() -> void:
	if is_instance_valid(_event_bus) and _event_bus.golpe_resolvido.is_connected(mostrar):
		_event_bus.golpe_resolvido.disconnect(mostrar)
	_event_bus = null


## Porta pública para o EventBus e para a régua isolada.
func mostrar(relatorio: Dictionary) -> void:
	if not (relatorio.get("destino") is Vector3):
		push_warning("ImpactoDeGolpe3D ignorou relatório sem destino: %s" % relatorio)
		return
	_limitar()
	var impacto := Node3D.new()
	impacto.name = "Impacto_%s" % str(relatorio.get("golpe", "acerto"))
	impacto.position = relatorio["destino"]
	impacto.set_meta("tempo", 0.0)
	impacto.set_meta("escala_final", _escala_final(relatorio))
	impacto.set_meta("cor", _cor(relatorio))
	_add_aneis(impacto, _cor(relatorio))
	add_child(impacto)
	_impactos.append(impacto)


func estado_visual() -> Dictionary:
	return {"ativos": _impactos.size(), "limite": MAXIMO_DE_IMPACTOS}


func _process(delta: float) -> void:
	for impacto in _impactos.duplicate():
		if not is_instance_valid(impacto):
			_impactos.erase(impacto)
			continue
		var tempo: float = float(impacto.get_meta("tempo")) + delta
		impacto.set_meta("tempo", tempo)
		var progresso := clampf(tempo / DURACAO, 0.0, 1.0)
		var escala_final: float = float(impacto.get_meta("escala_final"))
		impacto.scale = Vector3.ONE * lerpf(0.35, escala_final, progresso)
		impacto.rotation.y += delta * 3.5
		_atualizar_opacidade(impacto, 1.0 - progresso)
		if progresso >= 1.0:
			_impactos.erase(impacto)
			impacto.queue_free()


func _limitar() -> void:
	while _impactos.size() >= MAXIMO_DE_IMPACTOS:
		var antigo: Node3D = _impactos.pop_front()
		if is_instance_valid(antigo):
			antigo.queue_free()


func _add_aneis(pai: Node3D, cor: Color) -> void:
	for indice in 2:
		var anel := MeshInstance3D.new()
		anel.name = "Anel%d" % indice
		var malha := TorusMesh.new()
		malha.inner_radius = 0.20 + indice * 0.12
		malha.outer_radius = 0.245 + indice * 0.12
		malha.rings = 12
		malha.ring_segments = 8
		anel.mesh = malha
		anel.rotation.x = PI * 0.5
		anel.position.y = indice * 0.08
		anel.material_override = _material(cor.lightened(indice * 0.10))
		pai.add_child(anel)


func _atualizar_opacidade(impacto: Node3D, opacidade: float) -> void:
	for filho in impacto.get_children():
		if not (filho is MeshInstance3D):
			continue
		var material := filho.material_override as StandardMaterial3D
		if material != null:
			var cor := material.albedo_color
			cor.a = opacidade
			material.albedo_color = cor


func _escala_final(relatorio: Dictionary) -> float:
	# A fração já vem do motor. Aqui ela apenas modula a leitura do VFX.
	var fracao := clampf(float(relatorio.get("fracao_da_vida", 0.0)), 0.0, 1.0)
	var escala := lerpf(0.95, 1.75, fracao)
	match str(relatorio.get("efetividade", "neutro")):
		"forte": escala *= 1.15
		"muito_forte": escala *= 1.32
		"imune": escala *= 0.70
	return escala


func _cor(relatorio: Dictionary) -> Color:
	if str(relatorio.get("efetividade", "")) == "imune":
		return Color(0.62, 0.67, 0.78, 0.88)
	match str(relatorio.get("tipo", "Normal")).to_lower():
		"fire": return Color(1.0, 0.31, 0.08, 0.92)
		"water": return Color(0.10, 0.65, 1.0, 0.92)
		"electric": return Color(1.0, 0.88, 0.12, 0.92)
		"grass": return Color(0.28, 0.92, 0.34, 0.92)
		"ice": return Color(0.45, 0.92, 1.0, 0.92)
		"psychic": return Color(0.98, 0.30, 0.70, 0.92)
		"ghost": return Color(0.55, 0.37, 0.94, 0.92)
		_: return Color(1.0, 0.78, 0.28, 0.90)


func _material(cor: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = cor
	material.emission_enabled = true
	material.emission = cor
	return material

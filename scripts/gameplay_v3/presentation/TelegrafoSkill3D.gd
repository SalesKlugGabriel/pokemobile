## TelegrafoSkill3D — aviso espacial de uma skill com cast time.
##
## A geometria de combate continua em FormaDeArea3D/UsoDeSkill. Este nó recebe o
## anúncio pronto do EventBus e só o torna legível no chão; não converte unidades,
## não escolhe alvos e não recalcula duração.
class_name TelegrafoSkill3D
extends Node3D

const SEGMENTOS := 32
const ALTURA_SOBRE_O_CHAO := 0.035

var _event_bus: Node = null
var _aviso: Dictionary = {}
var _malha: MeshInstance3D = null


func _ready() -> void:
	_event_bus = get_node_or_null("/root/EventBus")
	if _event_bus != null:
		_event_bus.skill_anunciada.connect(mostrar)
		_event_bus.skill_cancelada.connect(cancelar)
		_event_bus.golpe_resolvido.connect(_ao_golpe_resolvido)


func _exit_tree() -> void:
	if is_instance_valid(_event_bus):
		if _event_bus.skill_anunciada.is_connected(mostrar):
			_event_bus.skill_anunciada.disconnect(mostrar)
		if _event_bus.skill_cancelada.is_connected(cancelar):
			_event_bus.skill_cancelada.disconnect(cancelar)
		if _event_bus.golpe_resolvido.is_connected(_ao_golpe_resolvido):
			_event_bus.golpe_resolvido.disconnect(_ao_golpe_resolvido)


## Porta pública também usada pelo teste. `anuncio` vem de UsoDeSkill.anuncio().
func mostrar(anuncio: Dictionary) -> void:
	if not _anuncio_valido(anuncio):
		push_warning("TelegrafoSkill3D ignorou anúncio incompleto: %s" % anuncio)
		return
	_aviso = anuncio.duplicate(true)
	_reconstruir()


func cancelar(golpe: String = "") -> void:
	if golpe.is_empty() or golpe == str(_aviso.get("golpe", "")):
		_aviso.clear()
		if is_instance_valid(_malha):
			_malha.queue_free()
		_malha = null


func estado_visual() -> Dictionary:
	return {"ativo": is_instance_valid(_malha), "golpe": str(_aviso.get("golpe", "")),
		"forma": str(_aviso.get("area_type", ""))}


func _process(_delta: float) -> void:
	if _aviso.is_empty():
		return
	# `resolve_em` é produzido pela regra. O VFX só respeita o prazo recebido.
	if _agora() >= float(_aviso.get("resolve_em", INF)):
		cancelar(str(_aviso.get("golpe", "")))


func _ao_golpe_resolvido(relatorio: Dictionary) -> void:
	var golpe := str(relatorio.get("golpe", relatorio.get("move_id", "")))
	if not golpe.is_empty():
		cancelar(golpe)


func _reconstruir() -> void:
	if is_instance_valid(_malha):
		_malha.queue_free()
	var origem: Vector3 = _aviso["origem"]
	var direcao: Vector3 = _direcao_plana(_aviso["direcao"])
	var vertices := _vertices(str(_aviso["area_type"]), origem, direcao,
		float(_aviso["alcance"]), float(_aviso["raio"]), float(_aviso["largura"]))
	var immediate := ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for ponto in vertices:
		immediate.surface_add_vertex(ponto)
	immediate.surface_end()
	_malha = MeshInstance3D.new()
	_malha.name = "AreaDeAviso"
	_malha.mesh = immediate
	_malha.material_override = _material(str(_aviso.get("tipo", "Normal")))
	add_child(_malha)


func _vertices(forma: String, origem: Vector3, direcao: Vector3, alcance: float,
		raio: float, largura: float) -> PackedVector3Array:
	var centro := _no_chao(origem)
	match forma.to_lower():
		"circle":
			return _leque(centro, maxf(raio, 0.35), 0.0, TAU)
		"cone":
			var angulo := atan2(direcao.x, direcao.z)
			return _leque(centro, maxf(raio, alcance), angulo - deg_to_rad(35.0), angulo + deg_to_rad(35.0))
		"line":
			return _faixa(centro, direcao, maxf(alcance, 0.5), maxf(largura, 0.35))
		_:
			# single é um alvo à frente: a marca não muda a área real, só explicita
			# para onde o arco/alcance já calculado vai resolver.
			return _leque(centro + direcao * maxf(alcance, 0.5), maxf(raio, 0.28), 0.0, TAU)


func _leque(centro: Vector3, raio: float, inicio: float, fim: float) -> PackedVector3Array:
	var resultado := PackedVector3Array()
	var partes := maxi(3, roundi(SEGMENTOS * absf(fim - inicio) / TAU))
	for indice in partes:
		var a := inicio + (fim - inicio) * float(indice) / float(partes)
		var b := inicio + (fim - inicio) * float(indice + 1) / float(partes)
		resultado.append(centro)
		resultado.append(centro + Vector3(sin(a), 0.0, cos(a)) * raio)
		resultado.append(centro + Vector3(sin(b), 0.0, cos(b)) * raio)
	return resultado


func _faixa(origem: Vector3, direcao: Vector3, comprimento: float, largura: float) -> PackedVector3Array:
	var lado := Vector3(-direcao.z, 0.0, direcao.x) * largura * 0.5
	var fim := origem + direcao * comprimento
	return PackedVector3Array([origem - lado, fim - lado, fim + lado,
		origem - lado, fim + lado, origem + lado])


func _no_chao(posicao: Vector3) -> Vector3:
	return Vector3(posicao.x, Terreno3D.altura_em(posicao.x, posicao.z) + ALTURA_SOBRE_O_CHAO, posicao.z)


func _direcao_plana(valor: Vector3) -> Vector3:
	var plana := Vector3(valor.x, 0.0, valor.z)
	return plana.normalized() if plana.length_squared() > 0.0001 else Vector3.FORWARD


func _material(tipo: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(1.0, 0.34, 0.16, 0.30) if tipo.to_lower() != "water" else Color(0.18, 0.66, 1.0, 0.30)
	material.emission_enabled = true
	material.emission = material.albedo_color
	return material


func _anuncio_valido(anuncio: Dictionary) -> bool:
	return anuncio.get("origem") is Vector3 and anuncio.get("direcao") is Vector3 \
		and anuncio.has("area_type") and anuncio.has("alcance") and anuncio.has("raio") \
		and anuncio.has("largura") and anuncio.has("resolve_em")


func _agora() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

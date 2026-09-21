## PokemonVisual3D — ponte genérica entre um corpo de Pokémon e Actions do GLB.
##
## Não toca em posição, rotação, física, colisão, dano nem IA. O pai publica
## somente o contrato RFC-010; este nó encontra a Action correspondente no
## asset e a toca in-place.
class_name PokemonVisual3D
extends Node3D

const TRANSICAO := 0.12
const ESTADOS_VALIDOS := ["idle", "walk", "run", "swim", "fly"]
const PAPEIS_VALIDOS := ["attack", "hit", "faint"]

var _corpo: Node = null
var _modelo: Node3D = null
var _animacao: AnimationPlayer = null
var _estado_atual := ""
var _acao_transitoria := ""
var _fallback_ativo := false
var _aviso_emitido: Dictionary = {}

## Configuração explícita para permitir que `PokemonInstance3D` continue dono
## da carga e validação do GLB. Deve ser chamada depois que o modelo entrar na
## árvore; não procura nós globais nem espécie por espécie.
func configurar(corpo: Node, modelo: Node3D) -> void:
	_desconectar()
	_corpo = corpo
	_modelo = modelo
	_animacao = _modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer \
		if _modelo != null else null
	if _corpo != null and _corpo.has_signal("animacao_visual_solicitada"):
		_corpo.connect("animacao_visual_solicitada", _ao_pedir_acao)
	if _animacao == null:
		_ativar_fallback("o GLB não contém AnimationPlayer")
		return
	if not _animacao.animation_finished.is_connected(_ao_terminar_acao):
		_animacao.animation_finished.connect(_ao_terminar_acao)
	_atualizar_locomocao(true)

func _exit_tree() -> void:
	_desconectar()

func _process(_delta: float) -> void:
	_atualizar_locomocao(false)

func tem_animacao() -> bool:
	return _animacao != null and not _fallback_ativo

func fallback_ativo() -> bool:
	return _fallback_ativo

func clipe_atual() -> String:
	return _animacao.current_animation if _animacao != null else ""

func _atualizar_locomocao(forcar: bool) -> void:
	if _corpo == null or _animacao == null or not _acao_transitoria.is_empty():
		return
	var estado := str(_corpo.call("estado_visual_de_locomocao"))
	if not ESTADOS_VALIDOS.has(estado):
		_aviso("estado inválido recebido: %s" % estado)
		estado = "idle"
	if forcar or estado != _estado_atual:
		_estado_atual = estado
		_tocar_locomocao(estado)

func _tocar_locomocao(estado: String) -> void:
	var clipe := _resolver_locomocao(estado)
	if clipe.is_empty():
		_ativar_fallback("sem Action de locomoção para %s" % estado)
		return
	_tocar(clipe)

func _resolver_locomocao(estado: String) -> String:
	# `walk` no validador significa papel de locomoção e já considera os
	# sinônimos por asset. Primeiro respeitamos swim/fly/run específicos, depois
	# caímos para a locomoção declarada pela espécie, por fim idle.
	var clipe := ValidadorDeModelo.animacao_de(_animacao, estado)
	if clipe.is_empty() and estado != "walk":
		clipe = ValidadorDeModelo.animacao_de(_animacao, "walk")
	if clipe.is_empty() and estado != "idle":
		clipe = ValidadorDeModelo.animacao_de(_animacao, "idle")
	return clipe

func _ao_pedir_acao(papel: String) -> void:
	if _animacao == null:
		return
	if not PAPEIS_VALIDOS.has(papel):
		_aviso("papel transitório inválido: %s" % papel)
		return
	var clipe := ValidadorDeModelo.animacao_de(_animacao, papel)
	if clipe.is_empty():
		# Um asset sem ataque/hit/faint não é silenciosamente aceito. Mantemos a
		# locomoção, mas o marcador magenta torna a lacuna visível no laboratório.
		_ativar_fallback("sem Action para %s" % papel)
		return
	_acao_transitoria = papel
	_tocar(clipe)

func _ao_terminar_acao(nome: StringName) -> void:
	if _acao_transitoria.is_empty():
		return
	if str(nome) != clipe_atual():
		return
	# Faint não retorna para idle: o corpo já caiu no gameplay e sua pose final
	# precisa permanecer legível até a entidade ser removida.
	if _acao_transitoria == "faint":
		return
	_acao_transitoria = ""
	_atualizar_locomocao(true)

func _tocar(clipe: String) -> void:
	if _animacao.current_animation != clipe:
		_animacao.play(clipe, TRANSICAO)

func _ativar_fallback(motivo: String) -> void:
	if _fallback_ativo:
		_aviso(motivo)
		return
	_fallback_ativo = true
	_aviso(motivo)
	var marcador := MeshInstance3D.new()
	marcador.name = "FallbackAnimacaoVisivel"
	var malha := SphereMesh.new()
	malha.radius = 0.12
	malha.height = 0.24
	marcador.mesh = malha
	marcador.position.y = 0.20
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.02, 0.66)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.0, 0.34)
	marcador.material_override = material
	add_child(marcador)

func _aviso(motivo: String) -> void:
	if _aviso_emitido.has(motivo):
		return
	_aviso_emitido[motivo] = true
	push_warning("PokemonVisual3D: fallback visível — " + motivo)

func _desconectar() -> void:
	if is_instance_valid(_corpo) and _corpo.has_signal("animacao_visual_solicitada") \
			and _corpo.is_connected("animacao_visual_solicitada", _ao_pedir_acao):
		_corpo.disconnect("animacao_visual_solicitada", _ao_pedir_acao)
	if is_instance_valid(_animacao) and _animacao.animation_finished.is_connected(_ao_terminar_acao):
		_animacao.animation_finished.disconnect(_ao_terminar_acao)
	_corpo = null
	_modelo = null
	_animacao = null

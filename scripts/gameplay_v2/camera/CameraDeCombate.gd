## Câmera local da Gameplay V2. Ela recebe contexto e referências; não decide
## quando existe combate, boss ou interior.
class_name CameraDeCombate
extends Camera2D

signal contexto_visual_aplicado(nome: String)

@export var treinador_path : NodePath
@export var pokemon_path : NodePath
@export var zoom_exploracao := Vector2(0.72, 0.72)
@export var zoom_combate := Vector2(0.68, 0.68)
@export var zoom_combate_grande := Vector2(0.62, 0.62)
@export var zoom_boss := Vector2(0.54, 0.54)
@export var zoom_interior := Vector2(0.82, 0.82)
@export_range(0.1, 20.0, 0.1) var velocidade_zoom := 5.5
@export_range(0.1, 20.0, 0.1) var velocidade_enquadramento := 7.0
@export_range(0.0, 800.0, 8.0) var deslocamento_maximo_ao_pokemon := 240.0
@export var deslocamento_hud := Vector2(0.0, -28.0)

var _treinador : Node2D
var _pokemon : Node2D
var _contextos := {"exploracao": 0}
var _contexto_ativo := "exploracao"
var _zoom_alvo := Vector2.ONE
var _intensidade_tremor := 0.0
var _tempo_tremor := 0.0

func _ready() -> void:
	position_smoothing_enabled = false
	_treinador = get_node_or_null(treinador_path) as Node2D
	_pokemon = get_node_or_null(pokemon_path) as Node2D
	_zoom_alvo = _zoom_do_contexto(_contexto_ativo)
	zoom = _zoom_alvo

func definir_alvos(treinador: Node2D, pokemon: Node2D = null) -> void:
	_treinador = treinador
	_pokemon = pokemon

## Mantém contextos concorrentes. O de maior prioridade vence; no empate, o
## nome torna o resultado determinístico.
func solicitar_contexto(nome: String, prioridade: int) -> void:
	if nome.is_empty():
		return
	_contextos[nome] = prioridade
	_recalcular_contexto()

func remover_contexto(nome: String) -> void:
	if nome == "exploracao":
		return
	_contextos.erase(nome)
	_recalcular_contexto()

## Porta simples para o sinal acordado na D-001.
func ao_contexto_de_camera(nome: String, prioridade: int) -> void:
	_contextos.clear()
	_contextos["exploracao"] = 0
	_contextos[nome] = prioridade
	_recalcular_contexto()

func contexto_ativo() -> String:
	return _contexto_ativo

func contexto_feedback() -> Dictionary:
	return {
		"contexto": _contexto_ativo,
		"posicao": global_position,
		"zoom": zoom,
		"zoom_alvo": _zoom_alvo,
		"treinador_id": _treinador.get_instance_id() if is_instance_valid(_treinador) else 0,
		"pokemon_id": _pokemon.get_instance_id() if is_instance_valid(_pokemon) else 0,
		"limites": Rect2(limit_left, limit_top, limit_right - limit_left, limit_bottom - limit_top),
		"tremor_ativo": _tempo_tremor > 0.0,
	}

func tremer(intensidade: float = 1.0, duracao: float = 0.18) -> void:
	_intensidade_tremor = maxf(_intensidade_tremor, clampf(intensidade, 0.0, 1.0))
	_tempo_tremor = maxf(_tempo_tremor, duracao)

func _process(delta: float) -> void:
	var peso_zoom := 1.0 - exp(-velocidade_zoom * delta)
	zoom = zoom.lerp(_zoom_alvo, peso_zoom)

	var destino := _destino_do_enquadramento()
	var peso_pos := 1.0 - exp(-velocidade_enquadramento * delta)
	global_position = global_position.lerp(destino, peso_pos)
	_atualizar_tremor(delta)

func _destino_do_enquadramento() -> Vector2:
	if not is_instance_valid(_treinador):
		return global_position
	var base := _treinador.global_position
	if is_instance_valid(_pokemon) and _pokemon.visible:
		var ate_pokemon : Vector2 = _pokemon.global_position - base
		if ate_pokemon.length() > deslocamento_maximo_ao_pokemon * 2.0:
			ate_pokemon = ate_pokemon.normalized() * deslocamento_maximo_ao_pokemon * 2.0
		base += ate_pokemon * 0.5
	return _limitar_ao_mundo(base + deslocamento_hud / zoom)

func _limitar_ao_mundo(ponto: Vector2) -> Vector2:
	if limit_right <= limit_left or limit_bottom <= limit_top:
		return ponto
	var metade := get_viewport_rect().size * 0.5 / zoom
	var minimo := Vector2(limit_left, limit_top) + metade
	var maximo := Vector2(limit_right, limit_bottom) - metade
	if minimo.x > maximo.x:
		ponto.x = (float(limit_left) + float(limit_right)) * 0.5
	else:
		ponto.x = clampf(ponto.x, minimo.x, maximo.x)
	if minimo.y > maximo.y:
		ponto.y = (float(limit_top) + float(limit_bottom)) * 0.5
	else:
		ponto.y = clampf(ponto.y, minimo.y, maximo.y)
	return ponto

func _recalcular_contexto() -> void:
	var melhor_nome := "exploracao"
	var melhor_prioridade := -2147483648
	var nomes := _contextos.keys()
	nomes.sort()
	for nome in nomes:
		var prioridade : int = int(_contextos[nome])
		if prioridade > melhor_prioridade:
			melhor_prioridade = prioridade
			melhor_nome = str(nome)
	if melhor_nome == _contexto_ativo:
		return
	_contexto_ativo = melhor_nome
	_zoom_alvo = _zoom_do_contexto(melhor_nome)
	contexto_visual_aplicado.emit(melhor_nome)

func _zoom_do_contexto(nome: String) -> Vector2:
	match nome:
		"boss", "alpha":
			return zoom_boss
		"combate_grande":
			return zoom_combate_grande
		"combate":
			return zoom_combate
		"interior":
			return zoom_interior
		_:
			return zoom_exploracao

func _atualizar_tremor(delta: float) -> void:
	if _tempo_tremor <= 0.0:
		offset = offset.lerp(Vector2.ZERO, 1.0 - exp(-18.0 * delta))
		return
	_tempo_tremor -= delta
	var forca := 10.0 * _intensidade_tremor
	offset = Vector2(randf_range(-forca, forca), randf_range(-forca, forca))
	if _tempo_tremor <= 0.0:
		_intensidade_tremor = 0.0

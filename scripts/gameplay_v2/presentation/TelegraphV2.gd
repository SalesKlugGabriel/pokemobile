## Renderer cancelável de telegrafia. Toda geometria chega resolvida em pixels
## pelo gameplay; este nó apenas apresenta o estado recebido.
class_name TelegraphV2
extends Node2D

const COR_HOSTIL := Color(1.0, 0.26, 0.13)
const COR_ALIADA := Color(0.20, 0.84, 1.0)
const TEMPO_SAIDA := 0.16

var _casts : Dictionary = {}

func _ready() -> void:
	z_index = 1

func mostrar_golpe(cast_id: int, dados: Dictionary) -> void:
	if cast_id < 0 or not _dados_validos(dados):
		return
	var copia := dados.duplicate(true)
	copia["decorrido"] = 0.0
	copia["encerrado"] = false
	copia["saida"] = 0.0
	_casts[cast_id] = copia
	set_process(true)
	queue_redraw()

func encerrar_golpe(cast_id: int, motivo: String) -> void:
	if not _casts.has(cast_id):
		return
	var dados : Dictionary = _casts[cast_id]
	dados["encerrado"] = true
	dados["motivo"] = motivo
	dados["saida"] = 0.0
	_casts[cast_id] = dados
	queue_redraw()

func limpar() -> void:
	_casts.clear()
	set_process(false)
	queue_redraw()

func quantidade_ativa() -> int:
	return _casts.size()

func _process(delta: float) -> void:
	var remover : Array[int] = []
	for chave in _casts:
		var dados : Dictionary = _casts[chave]
		if bool(dados.get("encerrado", false)):
			dados["saida"] = float(dados.get("saida", 0.0)) + delta
			if float(dados["saida"]) >= TEMPO_SAIDA:
				remover.append(int(chave))
		else:
			dados["decorrido"] = float(dados.get("decorrido", 0.0)) + delta
		_casts[chave] = dados
	for chave in remover:
		_casts.erase(chave)
	if _casts.is_empty():
		set_process(false)
	queue_redraw()

func _draw() -> void:
	for dados in _casts.values():
		_desenhar_cast(dados)

func _desenhar_cast(dados: Dictionary) -> void:
	var origem : Vector2 = dados.get("origem", Vector2.ZERO) - global_position
	var direcao : Vector2 = dados.get("direcao", Vector2.RIGHT)
	if direcao.length_squared() <= 0.0001:
		direcao = Vector2.RIGHT
	direcao = direcao.normalized()
	var duracao := maxf(0.001, float(dados.get("duracao", 0.001)))
	var progresso := clampf(float(dados.get("decorrido", 0.0)) / duracao, 0.0, 1.0)
	var alfa_saida := 1.0
	if bool(dados.get("encerrado", false)):
		alfa_saida = 1.0 - clampf(float(dados.get("saida", 0.0)) / TEMPO_SAIDA, 0.0, 1.0)
	var cor := _cor_do_cast(dados)
	cor.a *= alfa_saida
	var forma := str(dados.get("area_type", "circle")).to_lower()
	var raio := maxf(12.0, float(dados.get("raio", dados.get("comprimento", 96.0))))
	var largura := maxf(12.0, float(dados.get("largura", 64.0)))
	var comprimento := maxf(12.0, float(dados.get("comprimento", raio)))
	var abertura := maxf(0.05, float(dados.get("abertura", deg_to_rad(70.0))))

	match forma:
		"ring":
			var interno := raio * clampf(float(dados.get("fracao_vazia", 0.45)), 0.0, 1.0)
			if dados.has("raio_interno"):
				interno = maxf(0.0, float(dados["raio_interno"]))
			_desenhar_anel(origem, interno, raio, cor, progresso)
		"cone":
			_desenhar_cone(origem, direcao, comprimento, abertura, cor, progresso)
		"line", "rectangle", "beam", "projectile":
			_desenhar_faixa(origem, direcao, comprimento, largura, cor, progresso, forma == "beam")
		"single", "target", "contact":
			_desenhar_alvo(origem, raio, cor, progresso)
		"global":
			_desenhar_alvo(origem, raio, cor, progresso)
		_:
			_desenhar_circulo(origem, raio, cor, progresso)

func _desenhar_circulo(centro: Vector2, raio: float, cor: Color, progresso: float) -> void:
	draw_circle(centro, raio, Color(cor.r, cor.g, cor.b, 0.10 * cor.a))
	draw_arc(centro, raio, 0.0, TAU, 64, Color(cor.r, cor.g, cor.b, 0.96 * cor.a), 5.0, true)
	if progresso > 0.0:
		draw_arc(centro, raio * 0.82, -PI * 0.5, -PI * 0.5 + TAU * progresso,
			64, Color(cor.r, cor.g, cor.b, 0.72 * cor.a), 10.0, true)

func _desenhar_anel(centro: Vector2, interno: float, externo: float, cor: Color, progresso: float) -> void:
	draw_arc(centro, externo, 0.0, TAU, 64, Color(cor.r, cor.g, cor.b, 0.96 * cor.a), 5.0, true)
	draw_arc(centro, interno, 0.0, TAU, 48, Color(cor.r, cor.g, cor.b, 0.74 * cor.a), 4.0, true)
	var meio := lerpf(interno, externo, 0.5)
	draw_arc(centro, meio, -PI * 0.5, -PI * 0.5 + TAU * progresso,
		64, Color(cor.r, cor.g, cor.b, 0.48 * cor.a), maxf(4.0, externo - interno), true)

func _desenhar_faixa(origem: Vector2, direcao: Vector2, comprimento: float,
		largura: float, cor: Color, progresso: float, feixe: bool) -> void:
	var lado := Vector2(-direcao.y, direcao.x) * largura * 0.5
	var fim := origem + direcao * comprimento
	var pontos := PackedVector2Array([origem - lado, fim - lado, fim + lado, origem + lado])
	draw_colored_polygon(pontos, Color(cor.r, cor.g, cor.b, 0.11 * cor.a))
	draw_polyline(PackedVector2Array([origem - lado, fim - lado, fim + lado, origem + lado, origem - lado]),
		Color(cor.r, cor.g, cor.b, 0.94 * cor.a), 5.0, true)
	var frente := origem + direcao * comprimento * progresso
	draw_line(frente - lado, frente + lado, Color(cor.r, cor.g, cor.b, 0.76 * cor.a),
		10.0 if feixe else 7.0, true)

func _desenhar_cone(origem: Vector2, direcao: Vector2, comprimento: float,
		abertura: float, cor: Color, progresso: float) -> void:
	var angulo := direcao.angle()
	var pontos := PackedVector2Array([origem])
	var segmentos := 28
	for i in segmentos + 1:
		var t := float(i) / float(segmentos)
		var a := angulo - abertura * 0.5 + abertura * t
		pontos.append(origem + Vector2.from_angle(a) * comprimento)
	draw_colored_polygon(pontos, Color(cor.r, cor.g, cor.b, 0.11 * cor.a))
	draw_polyline(PackedVector2Array([origem, pontos[1]]), Color(cor.r, cor.g, cor.b, 0.94 * cor.a), 5.0, true)
	draw_arc(origem, comprimento, angulo - abertura * 0.5, angulo + abertura * 0.5,
		segmentos, Color(cor.r, cor.g, cor.b, 0.94 * cor.a), 5.0, true)
	draw_line(origem, pontos[pontos.size() - 1], Color(cor.r, cor.g, cor.b, 0.94 * cor.a), 5.0, true)
	var raio_progresso := comprimento * progresso
	draw_arc(origem, raio_progresso, angulo - abertura * 0.5, angulo + abertura * 0.5,
		segmentos, Color(cor.r, cor.g, cor.b, 0.66 * cor.a), 8.0, true)

func _desenhar_alvo(centro: Vector2, raio: float, cor: Color, progresso: float) -> void:
	draw_circle(centro, raio, Color(cor.r, cor.g, cor.b, 0.08 * cor.a))
	draw_arc(centro, raio, 0.0, TAU, 48, Color(cor.r, cor.g, cor.b, 0.96 * cor.a), 4.0, true)
	var cruz := raio * (0.35 + 0.35 * progresso)
	draw_line(centro - Vector2(cruz, 0), centro + Vector2(cruz, 0), Color(cor.r, cor.g, cor.b, 0.8 * cor.a), 3.0, true)
	draw_line(centro - Vector2(0, cruz), centro + Vector2(0, cruz), Color(cor.r, cor.g, cor.b, 0.8 * cor.a), 3.0, true)

func _cor_do_cast(dados: Dictionary) -> Color:
	if dados.has("cor") and dados["cor"] is Color:
		return dados["cor"]
	return COR_HOSTIL if bool(dados.get("hostil", true)) else COR_ALIADA

func _dados_validos(dados: Dictionary) -> bool:
	return dados.has("area_type") and dados.has("origem") and dados.has("direcao") \
		and dados.has("duracao") and float(dados["duracao"]) > 0.0 and dados.has("hostil")

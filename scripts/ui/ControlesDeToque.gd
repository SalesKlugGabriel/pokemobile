## ControlesDeToque.gd — O jogo no celular (09/09).
##
## 🔴 Por que este arquivo substituiu os dois anteriores (VirtualJoystick +
## VirtualButtons): o Gabriel não conseguia nem COMEÇAR o jogo no celular.
## Reproduzi num iPhone 13 emulado com toque de verdade e achei dois problemas
## diferentes, não um:
##
##   1. O jogo desenhava numa faixa 16:9 com tarja preta em cima e embaixo —
##      usava ~40% de um celular em pé. Corrigido fora daqui (a proporção da
##      janela passou de "keep" pra "expand", no project.godot).
##   2. Mesmo tocando no CENTRO EXATO de um botão, nada acontecia. O toque não
##      virava clique. É por isso que o botão de recado "acendia" e não abria.
##
## A correção do 2 é a razão de este arquivo existir: em vez de depender de o
## motor converter toque em clique, **o toque é tratado aqui, sempre**, e vira
## ação de jogo diretamente.
##
## O desenho que o Gabriel pediu:
##   · **Joystick invisível** no quadrante inferior DIREITO — o dedo encosta
##     onde quiser e o eixo nasce ali. Nada de círculo fixo pra acertar.
##   · **Ação por toque único** no resto da tela: tocar num Pokémon ataca,
##     tocar num caído joga a Pokébola, tocar num NPC conversa.
##
## Por que o joystick à direita e não à esquerda (o costume): foi o que ele
## pediu, literalmente. Trocar de lado é uma linha (`LADO_DIREITO`).
class_name ControlesDeToque
extends CanvasLayer

## Fração da tela que o joystick ocupa (quadrante inferior).
const FRACAO_ALTURA : float = 0.5
const FRACAO_LARGURA : float = 0.5
const LADO_DIREITO : bool = true

const RAIO_MORTO : float = 18.0    ## abaixo disso o dedo não é direção, é toque
const RAIO_MAX   : float = 110.0   ## saturação do eixo
const ALCANCE_TOQUE : float = 260.0 ## px de mundo: o quanto o toque "perdoa" a mira

var _dedo_joystick : int = -1
var _origem : Vector2 = Vector2.ZERO
var _atual : Vector2 = Vector2.ZERO
var _acoes_ligadas : Array[String] = []
var _desenho : Control = null
var _botoes : Control = null

## Espião de eventos. Ficou DESLIGADO depois de cumprir o papel dele, mas fica
## aqui porque foi o que resolveu: três tentativas de consertar o toque no
## celular falharam enquanto eu adivinhava. Ligar isto e ler a tela respondeu
## em uma rodada — o Godot RECEBIA o clique da ponte; o que faltava era o jogo
## fazer algo com ele numa tela sem mundo (título, nome, diálogo).
## Ligar de novo é trocar para `true` e reexportar.
const ESPIAO : bool = false
var _espiao_label : Label = null
var _espiao_linhas : Array = []

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ESPIAO:
		_montar_espiao()
	if not _e_celular():
		if _espiao_label:
			_anotar("NAO_E_CELULAR touch=%s larg=%d" % [
				str(DisplayServer.is_touchscreen_available()),
				DisplayServer.window_get_size().x])
		return
	_anotar("CELULAR ok touch=%s larg=%d" % [
		str(DisplayServer.is_touchscreen_available()),
		DisplayServer.window_get_size().x])
	_montar_desenho()
	_montar_botoes()

func _montar_espiao() -> void:
	_espiao_label = Label.new()
	_espiao_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_espiao_label.offset_top = 78.0
	_espiao_label.offset_left = 8.0
	_espiao_label.offset_right = -8.0
	_espiao_label.add_theme_font_size_override("font_size", 13)
	_espiao_label.add_theme_color_override("font_color", Color(1, 1, 0.4))
	_espiao_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	_espiao_label.add_theme_constant_override("shadow_offset_x", 2)
	_espiao_label.add_theme_constant_override("shadow_offset_y", 2)
	_espiao_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_espiao_label)

func _anotar(texto: String) -> void:
	if _espiao_label == null:
		return
	_espiao_linhas.append(texto)
	if _espiao_linhas.size() > 7:
		_espiao_linhas.pop_front()
	_espiao_label.text = "\n".join(_espiao_linhas)

## Roda ANTES de tudo e não filtra nada: se o Godot recebe algum evento, ele
## aparece aqui. Se a tela ficar vazia ao tocar, o motor não está recebendo.
func _unhandled_input(evento: InputEvent) -> void:
	if ESPIAO:
		_anotar(evento.get_class() + " " + evento.as_text().substr(0, 46))

## No navegador, `is_touchscreen_available()` às vezes responde falso mesmo num
## celular. Somar o tamanho da tela evita o pior dos dois erros: sumir com os
## controles justamente em quem só tem toque.
func _e_celular() -> bool:
	if DisplayServer.is_touchscreen_available():
		return true
	return DisplayServer.window_get_size().x < 900

# ──────────────────────────────────────────────────────────────────────────
# O toque
# ──────────────────────────────────────────────────────────────────────────
## Escuta TOQUE e MOUSE. O mouse não é luxo: medido no navegador, o Godot 4.2
## web não entrega evento de toque nenhum ao jogo — quem chega é o mouse (a
## ponte em `tools/exportar_web.sh` converte um no outro). Se um dia o motor
## passar a entregar toque, os dois caminhos convivem sem conflito, porque cada
## um só age quando o outro não está no meio de um arrasto.
func _input(evento: InputEvent) -> void:
	if not _e_celular():
		return

	if evento is InputEventScreenTouch:
		if evento.pressed:
			_comecar(evento.position, evento.index)
		elif evento.index == _dedo_joystick:
			_soltar()
	elif evento is InputEventScreenDrag and evento.index == _dedo_joystick:
		_atual = evento.position
		_aplicar_direcao()
	elif evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		if evento.pressed:
			_comecar(evento.position, -2)
		elif _dedo_joystick == -2:
			_soltar()
	elif evento is InputEventMouseMotion and _dedo_joystick == -2:
		_atual = evento.position
		_aplicar_direcao()

## `indice` identifica o dedo (ou -2, o "dedo" do mouse).
func _comecar(pos: Vector2, indice: int) -> void:
	if _dedo_joystick != -1:
		return
	if _na_zona_do_joystick(pos):
		_dedo_joystick = indice
		_origem = pos
		_atual = pos
		_mostrar_eixo(true)
	else:
		_tocar_no_mundo(pos)

func _na_zona_do_joystick(pos: Vector2) -> bool:
	var tela := get_viewport().get_visible_rect().size
	if pos.y < tela.y * (1.0 - FRACAO_ALTURA):
		return false
	if LADO_DIREITO:
		return pos.x > tela.x * (1.0 - FRACAO_LARGURA)
	return pos.x < tela.x * FRACAO_LARGURA

func _aplicar_direcao() -> void:
	var d := _atual - _origem
	if d.length() < RAIO_MORTO:
		_ligar([])
		_atualizar_desenho()
		return
	var dir := d.limit_length(RAIO_MAX) / RAIO_MAX
	var novas : Array[String] = []
	# Cardinal, nunca diagonal: o mundo é tile a tile, e diagonal faria o
	# personagem trocar de direção a cada quadro numa curva.
	if absf(dir.x) > absf(dir.y):
		novas.append("move_right" if dir.x > 0.0 else "move_left")
	else:
		novas.append("move_down" if dir.y > 0.0 else "move_up")
	_ligar(novas)
	_atualizar_desenho()

func _soltar() -> void:
	_dedo_joystick = -1
	_ligar([])
	_mostrar_eixo(false)

func _ligar(novas: Array[String]) -> void:
	for a in _acoes_ligadas:
		if not (a in novas):
			_injetar(a, false)
	for a in novas:
		if not (a in _acoes_ligadas):
			_injetar(a, true)
	_acoes_ligadas = novas.duplicate()

func _injetar(acao: String, apertada: bool) -> void:
	var e := InputEventAction.new()
	e.action = acao
	e.pressed = apertada
	Input.parse_input_event(e)

# ──────────────────────────────────────────────────────────────────────────
# Toque único = ação. É o que o Gabriel pediu no lugar de uma botoeira.
# ──────────────────────────────────────────────────────────────────────────
## A ordem importa: um Pokémon CAÍDO ganha do vivo, porque é nele que a
## Pokébola funciona — e é o toque que o jogador mais vai querer acertar.
func _tocar_no_mundo(pos_tela: Vector2) -> void:
	var arvore := get_tree()
	if arvore == null:
		return
	var mundo = _posicao_no_mundo(pos_tela)
	if mundo == null:
		# Sem câmera = tela de UI (título, nome, laboratório, diálogo). O espião
		# provou que o evento CHEGA aqui; o que faltava era transformá-lo em
		# algo que essas telas entendem. `interact` é a ação que todas elas já
		# escutam — então tocar em qualquer lugar passa a valer como "confirmar",
		# sem eu precisar caçar tela por tela.
		_injetar_pulso("interact")
		return
	var ponto : Vector2 = mundo

	var caido = _mais_perto("wild_pokemon", ponto, true)
	if caido != null:
		_injetar_pulso("pokeball")
		return
	var vivo = _mais_perto("wild_pokemon", ponto, false)
	if vivo != null:
		EventBus.wild_pokemon_selected.emit(vivo)
		_injetar_pulso("skill_1")
		return
	var npc = _mais_perto("npc", ponto, false)
	if npc != null:
		_injetar_pulso("interact")
		return
	# Nada reconhecível no ponto tocado: vale como "confirmar" mesmo assim —
	# é o que faz avançar diálogo tocando em qualquer lugar da tela, que é o
	# gesto que todo mundo tenta primeiro.
	_injetar_pulso("interact")

func _injetar_pulso(acao: String) -> void:
	_injetar(acao, true)
	await get_tree().process_frame
	_injetar(acao, false)

func _posicao_no_mundo(pos_tela: Vector2):
	var vp := get_viewport()
	if vp == null:
		return null
	var cam := vp.get_camera_2d()
	if cam == null:
		return null
	return cam.get_screen_center_position() + (pos_tela - vp.get_visible_rect().size * 0.5) * cam.zoom.x

func _mais_perto(grupo: String, ponto: Vector2, exigir_caido: bool):
	var melhor = null
	var dist := ALCANCE_TOQUE
	for n in get_tree().get_nodes_in_group(grupo):
		if not is_instance_valid(n) or not (n is Node2D):
			continue
		var caido : bool = n.has_method("esta_desmaiado") and n.esta_desmaiado()
		if caido != exigir_caido:
			continue
		var d : float = ponto.distance_to((n as Node2D).global_position)
		if d < dist:
			dist = d
			melhor = n
	return melhor

# ──────────────────────────────────────────────────────────────────────────
# Desenho — o eixo só aparece enquanto o dedo está na tela
# ──────────────────────────────────────────────────────────────────────────
func _montar_desenho() -> void:
	_desenho = Control.new()
	_desenho.name = "EixoInvisivel"
	_desenho.set_anchors_preset(Control.PRESET_FULL_RECT)
	_desenho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desenho.visible = false
	_desenho.draw.connect(_pintar_eixo)
	add_child(_desenho)

func _mostrar_eixo(v: bool) -> void:
	if _desenho:
		_desenho.visible = v
		_desenho.queue_redraw()

func _atualizar_desenho() -> void:
	if _desenho:
		_desenho.queue_redraw()

func _pintar_eixo() -> void:
	if _dedo_joystick == -1:
		return
	_desenho.draw_circle(_origem, RAIO_MAX * 0.62, Color(1, 1, 1, 0.10))
	_desenho.draw_arc(_origem, RAIO_MAX * 0.62, 0.0, TAU, 32, Color(1, 1, 1, 0.35), 3.0, true)
	var d := (_atual - _origem).limit_length(RAIO_MAX * 0.62)
	_desenho.draw_circle(_origem + d, 26.0, Color(1, 1, 1, 0.30))

# ──────────────────────────────────────────────────────────────────────────
# Os três botões que não dá pra resolver com toque no mundo
# ──────────────────────────────────────────────────────────────────────────
func _montar_botoes() -> void:
	_botoes = HBoxContainer.new()
	_botoes.name = "Atalhos"
	_botoes.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_botoes.offset_left = 12.0
	_botoes.offset_top = 12.0
	_botoes.add_theme_constant_override("separation", 8)
	add_child(_botoes)
	# TEXTO, não emoji: a fonte pixel do jogo não tem glifo de emoji e eles
	# saem como quadradinhos vazios — foi o que apareceu no primeiro teste em
	# celular. Palavra curta lê melhor que ícone quebrado.
	for par in [["BAG", "menu_bag"], ["TIME", "menu_team"], ["MAPA", "menu_map"], ["MENU", "pause"]]:
		var b := Button.new()
		b.text = str(par[0])
		b.custom_minimum_size = Vector2(74, 52)
		b.add_theme_font_size_override("font_size", 15)
		b.modulate = Color(1, 1, 1, 0.82)
		var acao : String = str(par[1])
		b.pressed.connect(func(): _injetar_pulso(acao))
		_botoes.add_child(b)

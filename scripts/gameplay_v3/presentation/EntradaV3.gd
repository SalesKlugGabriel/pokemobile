## EntradaV3 — porta de entrada responsiva da experiência 3D atual.
##
## Não cria save, não interpreta progresso e não escolhe modo de jogo. O único
## mundo 3D jogável desta etapa é o Laboratório; esta tela o torna a entrada
## explícita do projeto sem fingir que a migração já possui um fluxo de save.
extends Control

const DESTINO_MUNDO_3D := "res://scenes/gameplay_v3/Laboratorio3D.tscn"

var _entrar: Button = null

func _ready() -> void:
	_montar()
	_entrar.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or (
		event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]):
		get_viewport().set_input_as_handled()
		_abrir_mundo_3d()

func _montar() -> void:
	var fundo := TextureRect.new()
	fundo.name = "Atmosfera"
	fundo.texture = _gradiente_fundo()
	fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fundo.stretch_mode = TextureRect.STRETCH_SCALE
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)

	# Faixas largas dão profundidade ao primeiro frame sem depender de imagem
	# externa, carregamento de rede ou arte duplicada da V2.
	for faixa in [
		{"nome": "CostaDistante", "cor": Color("164957"), "topo": 0.58},
		{"nome": "Colinas", "cor": Color("0d3039"), "topo": 0.70},
		{"nome": "Mar", "cor": Color("071b2d"), "topo": 0.82},
	]:
		var plano := ColorRect.new()
		plano.name = str(faixa["nome"])
		plano.color = faixa["cor"]
		plano.set_anchors_preset(Control.PRESET_FULL_RECT)
		plano.anchor_top = float(faixa["topo"])
		plano.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(plano)

	var margem := MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margem.add_theme_constant_override("margin_left", 22)
	margem.add_theme_constant_override("margin_right", 22)
	margem.add_theme_constant_override("margin_top", 28)
	margem.add_theme_constant_override("margin_bottom", 28)
	add_child(margem)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margem.add_child(centro)
	var cartao := PanelContainer.new()
	cartao.custom_minimum_size = Vector2(0, 362)
	cartao.add_theme_stylebox_override("panel", _caixa(Color(0.018, 0.045, 0.075, 0.88), 22, Color(0.43, 0.83, 0.82, 0.38)))
	centro.add_child(cartao)
	var coluna := VBoxContainer.new()
	coluna.custom_minimum_size = Vector2(300, 0)
	coluna.add_theme_constant_override("separation", 13)
	cartao.add_child(coluna)

	var selo := Label.new()
	selo.name = "StatusV3"
	selo.text = "LABORATÓRIO V3  •  EM DESENVOLVIMENTO"
	selo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selo.add_theme_font_size_override("font_size", 12)
	selo.add_theme_color_override("font_color", Color("8fe8de"))
	coluna.add_child(selo)

	var titulo := Label.new()
	titulo.text = "POKÉMOBILE"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 44)
	titulo.add_theme_color_override("font_color", Color("f2fbff"))
	titulo.add_theme_color_override("font_outline_color", Color("071b2d"))
	titulo.add_theme_constant_override("outline_size", 8)
	coluna.add_child(titulo)
	var subtitulo := Label.new()
	subtitulo.text = "Explore o mundo em 3D"
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitulo.add_theme_font_size_override("font_size", 19)
	subtitulo.add_theme_color_override("font_color", Color("b4cbd8"))
	coluna.add_child(subtitulo)

	var separador := HSeparator.new()
	separador.modulate = Color(0.40, 0.82, 0.80, 0.55)
	coluna.add_child(separador)
	var descricao := Label.new()
	descricao.text = "Treinador, combate, habilidades e exploração no ambiente de teste V3."
	descricao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	descricao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	descricao.custom_minimum_size = Vector2(0, 48)
	descricao.add_theme_font_size_override("font_size", 15)
	descricao.add_theme_color_override("font_color", Color("d1e0e7"))
	coluna.add_child(descricao)

	_entrar = Button.new()
	_entrar.name = "EntrarMundo3D"
	_entrar.text = "ENTRAR NO MUNDO 3D"
	_entrar.custom_minimum_size = Vector2(0, 58)
	_entrar.add_theme_font_size_override("font_size", 18)
	_entrar.tooltip_text = "Abrir o Laboratório V3"
	_entrar.add_theme_stylebox_override("normal", _caixa(Color("167b78"), 13, Color("a9fff4")))
	_entrar.add_theme_stylebox_override("hover", _caixa(Color("249794"), 13, Color("e6fffc")))
	_entrar.add_theme_stylebox_override("pressed", _caixa(Color("0c5559"), 13, Color("a9fff4")))
	_entrar.pressed.connect(_abrir_mundo_3d)
	coluna.add_child(_entrar)

	var controles := Label.new()
	controles.text = "WASD move  •  mouse gira a câmera  •  habilidades na HUD"
	controles.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controles.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controles.add_theme_font_size_override("font_size", 12)
	controles.add_theme_color_override("font_color", Color("8ba7b5"))
	coluna.add_child(controles)

func _abrir_mundo_3d() -> void:
	get_tree().change_scene_to_file(DESTINO_MUNDO_3D)

func _gradiente_fundo() -> GradientTexture2D:
	var gradiente := Gradient.new()
	gradiente.offsets = PackedFloat32Array([0.0, 0.48, 1.0])
	gradiente.colors = PackedColorArray([Color("0b233b"), Color("165665"), Color("0b233b")])
	var textura := GradientTexture2D.new()
	textura.gradient = gradiente
	textura.width = 32
	textura.height = 512
	textura.fill_from = Vector2(0.5, 0.0)
	textura.fill_to = Vector2(0.5, 1.0)
	return textura

func _caixa(cor: Color, raio: int, borda: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var caixa := StyleBoxFlat.new()
	caixa.bg_color = cor
	caixa.border_color = borda
	caixa.set_border_width_all(1 if borda.a > 0.0 else 0)
	caixa.set_corner_radius_all(raio)
	caixa.content_margin_left = 24.0
	caixa.content_margin_right = 24.0
	caixa.content_margin_top = 20.0
	caixa.content_margin_bottom = 20.0
	caixa.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	caixa.shadow_size = 16
	caixa.shadow_offset = Vector2(0, 8)
	return caixa

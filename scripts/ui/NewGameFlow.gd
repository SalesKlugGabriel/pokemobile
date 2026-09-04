## NewGameFlow.gd — Só o nome do treinador (05/09).
##
## Antes esta tela também escolhia o Pokémon inicial, em três cartões de texto
## com um botão "Escolher" em cada. A pedido do Gabriel, a escolha virou uma
## CENA — o encontro com o Prof. Carvalho e as três pokébolas na mesa
## (EscolhaInicial.gd), como nos jogos originais. Aqui ficou só a pergunta do
## nome, que é o que vem antes no original também.
##
## O nome viaja pra cena seguinte pela static var `EscolhaInicial.nome_treinador`
## — não vale a pena um autoload novo pra carregar uma string por dois segundos.
extends Control

@onready var name_input   : LineEdit = $Layout/TopRow/NameInput
@onready var btn_confirm  : Button   = $Layout/BtnConfirm
@onready var lbl_error    : Label    = $Layout/LblError

const CAMINHO_FUNDO := "res://assets/ui/fundo_titulo.png"

func _ready() -> void:
	_vestir()
	btn_confirm.pressed.connect(_on_confirm)
	name_input.text_submitted.connect(func(_t): _on_confirm())
	name_input.grab_focus()
	set_process_unhandled_input(true)

func _vestir() -> void:
	var bg := $BG as ColorRect
	if bg:
		bg.color = Color(0.06, 0.10, 0.08)
	if ResourceLoader.exists(CAMINHO_FUNDO):
		var paisagem := TextureRect.new()
		paisagem.texture = load(CAMINHO_FUNDO)
		paisagem.set_anchors_preset(Control.PRESET_FULL_RECT)
		paisagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		paisagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		paisagem.modulate = Color(1, 1, 1, 0.55)   # atrás do texto, não competindo
		paisagem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(paisagem)
		move_child(paisagem, 1)
	var confirmar := $Layout/BtnConfirm as Button
	if confirmar:
		confirmar.custom_minimum_size = Vector2(300, 52)
		confirmar.add_theme_font_size_override("font_size", 20)
		confirmar.add_theme_color_override("font_color", Color(1, 0.98, 0.94))
		var caixa := StyleBoxFlat.new()
		caixa.bg_color = Color(0.84, 0.24, 0.20)
		caixa.border_color = Color(0.98, 0.84, 0.36)
		caixa.set_border_width_all(3)
		caixa.set_corner_radius_all(14)
		caixa.set_content_margin_all(10)
		confirmar.add_theme_stylebox_override("normal", caixa)

	var titulo := $Layout/TitleLabel as Label
	if titulo:
		titulo.add_theme_color_override("font_color", Color(0.99, 0.95, 0.84))
		titulo.add_theme_color_override("font_outline_color", Color(0.10, 0.08, 0.06))
		titulo.add_theme_constant_override("outline_size", 10)

## Enter/Z seguem. Sem caminho de teclado, um clique que erra o botão é
## indistinguível de jogo travado — foi o que aconteceu no teste de 04/09.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed
			and not event.is_echo() and event.keycode in [KEY_ENTER, KEY_KP_ENTER]):
		get_viewport().set_input_as_handled()
		_on_confirm()

func _on_confirm() -> void:
	AudioManager.play_sfx("confirm")
	EscolhaInicial.nome_treinador = name_input.text.strip_edges()
	SceneTransition.fade_to("res://scenes/ui/EscolhaInicial.tscn")

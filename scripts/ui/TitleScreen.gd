## TitleScreen.gd — Tela inicial do jogo: New Game / Continue.
extends Control

@onready var btn_continue  : Button = $VBox/BtnContinue
@onready var btn_new_game  : Button = $VBox/BtnNewGame
@onready var label_save    : Label  = $VBox/LabelSave

func _ready() -> void:
	AudioManager.play_bgm("title")
	_vestir_a_tela()
	var has_save := SaveManager.has_save()
	btn_continue.visible = has_save
	if has_save:
		# Carrega brevemente para exibir info do save
		SaveManager.load_game()
		# QuestManager já rodou o próprio _ready() no boot do jogo, antes de
		# saber se havia save pra carregar — sem isso, "Continuar" mostraria
		# todo progresso de quest zerado mesmo tendo save de verdade.
		QuestManager.reload_from_save()
		var poke : Dictionary = SaveManager.get_pokemon_at(0)
		var name_str : String = poke.get("nickname", "") if poke.get("nickname", "") != "" \
					   else GameData.get_species(int(poke.get("species_id", 1))).get("name", "???")
		label_save.text = "Treinador: %s  |  %s Lv.%d  |  %d capturados" % [
			SaveManager.get_trainer().get("name", "???"),
			name_str,
			poke.get("level", 1),
			SaveManager.get_pokedex()["caught"].size()
		]
		label_save.visible = true
	else:
		label_save.visible = false

	btn_continue.pressed.connect(_on_continue)
	btn_new_game.pressed.connect(_on_new_game)
	set_process_unhandled_input(true)

## Enter/Z começa (Continuar se há save, senão Novo Jogo). Sem caminho de
## teclado, um clique que erra o botão parece jogo travado — foi o que
## aconteceu no teste de 04/09, na tela seguinte a esta.
func _unhandled_input(event: InputEvent) -> void:
	var confirmar : bool = event.is_action_pressed("interact") or (
		event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER])
	if not confirmar:
		return
	get_viewport().set_input_as_handled()
	if btn_continue.visible:
		_on_continue()
	else:
		_on_new_game()

## 04/09: a tela de título era um retângulo preto com fonte de sistema — "parece
## que o jogo não carregou". Aqui ela ganha (a) uma paisagem feita com os TILES
## DO PRÓPRIO JOGO (tools/gerar_fundo_titulo.py), (b) o nome com contorno e cor,
## e (c) os três iniciais lado a lado, que é o que faz um fã de Pokémon
## reconhecer o jogo em meio segundo.
##
## Feito em código e não no .tscn de propósito: o fundo e a fileira de iniciais
## são gerados a partir de recursos que podem mudar (atlas, sprites), e assim
## não existe uma cópia da lista de iniciais fora do NewGameFlow.
## Uma turma alegre, não só os três iniciais: Pikachu, Eevee e companhia é o
## que faz a capa parecer "o mundo dos Pokémon" em vez de "menu de seleção".
## Pedido do Gabriel (05/09): "tela colorida, com temática de Pokémon, mundo,
## felicidade, alegria, diversão".
const TURMA : Array[int] = [25, 1, 4, 7, 133, 39]  # Pikachu, os 3 iniciais, Eevee, Jigglypuff

func _vestir_a_tela() -> void:
	var fundo := $BG as ColorRect
	if fundo:
		fundo.color = Color(0.02, 0.04, 0.03)

	var caminho := "res://assets/ui/fundo_titulo.png"
	if ResourceLoader.exists(caminho):
		var paisagem := TextureRect.new()
		paisagem.texture = load(caminho)
		paisagem.set_anchors_preset(Control.PRESET_FULL_RECT)
		paisagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		paisagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		paisagem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(paisagem)
		move_child(paisagem, 1)   # atrás de tudo menos do BG

	# Botões coloridos. O tema 9-slice do projeto é cinza-escuro, feito pra
	# menu de jogo; na capa ele lia como "botão de sistema". Aqui vale a cor —
	# é a tela que precisa dizer "isto é divertido".
	for botao in [$VBox/BtnContinue, $VBox/BtnNewGame]:
		if botao:
			_pintar_botao(botao as Button)
	var lbl := $VBox/LabelSave as Label
	if lbl:
		lbl.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84))
		lbl.add_theme_color_override("font_outline_color", Color(0.09, 0.08, 0.06))
		lbl.add_theme_constant_override("outline_size", 6)

	var titulo := $TitleLabel as Label
	if titulo:
		# Dourado com contorno azul-escuro: é a paleta do logo clássico da
		# franquia, e é o que faz a capa ser reconhecida em meio segundo.
		# A caixa do rótulo é fixa no .tscn (80..140). Ao subir a fonte pra 66 o
		# texto transbordava por cima do subtítulo — por isso a caixa cresce
		# junto, e o subtítulo desce.
		titulo.add_theme_font_size_override("font_size", 66)
		titulo.offset_top = 46
		titulo.offset_bottom = 146
		titulo.offset_left = -320
		titulo.offset_right = 320
		titulo.add_theme_color_override("font_color", Color(0.97, 0.79, 0.28))
		titulo.add_theme_color_override("font_outline_color", Color(0.10, 0.22, 0.56))
		titulo.add_theme_constant_override("outline_size", 16)
	var sub := $SubLabel as Label
	if sub:
		sub.add_theme_font_size_override("font_size", 20)
		sub.offset_top = 152
		sub.offset_bottom = 184
		sub.add_theme_color_override("font_color", Color(0.99, 0.97, 0.92))
		sub.add_theme_color_override("font_outline_color", Color(0.10, 0.22, 0.56))
		sub.add_theme_constant_override("outline_size", 8)

	var fileira := HBoxContainer.new()
	fileira.add_theme_constant_override("separation", 22)
	fileira.alignment = BoxContainer.ALIGNMENT_CENTER
	fileira.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	fileira.offset_left = -430
	fileira.offset_right = 430
	# Acima da faixa de água: na primeira versão a turma ficava com os pés
	# dentro do mar, como se estivessem afundando.
	fileira.offset_top = -238
	fileira.offset_bottom = -102
	fileira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for id in TURMA:
		var icone := PokemonIcon.criar(id, 116)
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fileira.add_child(icone)
		_turma_nos.append(icone)
	add_child(fileira)

	set_process(true)

## Cada Pokémon da capa flutua no seu próprio ritmo. Movimento é o que separa
## "imagem parada com bichos" de "cena viva" — e é barato: um seno por nó.
var _turma_nos : Array[Control] = []
var _t : float = 0.0

func _process(delta: float) -> void:
	_t += delta
	for i in _turma_nos.size():
		var no := _turma_nos[i]
		var deslocamento : float = sin(_t * 2.2 + i * 0.9) * 9.0
		no.position.y = deslocamento

func _on_continue() -> void:
	# Save já carregado no _ready — vai direto ao mapa
	SceneTransition.fade_to("res://scenes/world/maps/WorldMap.tscn")

func _on_new_game() -> void:
	SceneTransition.fade_to("res://scenes/ui/NewGameFlow.tscn")

## Vermelho de pokébola no botão, com relevo e uma borda dourada. Três estados
## (normal/hover/pressionado) porque um botão que não reage ao mouse parece
## enfeite — e na primeira jogada de teste o clique errou o alvo sem nenhum
## retorno visual.
func _pintar_botao(botao: Button) -> void:
	botao.custom_minimum_size = Vector2(300, 56)
	botao.add_theme_font_size_override("font_size", 22)
	botao.add_theme_color_override("font_color", Color(1, 0.98, 0.94))
	botao.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	botao.add_theme_color_override("font_pressed_color", Color(1, 0.92, 0.80))
	botao.add_theme_color_override("font_outline_color", Color(0.30, 0.08, 0.06))
	botao.add_theme_constant_override("outline_size", 6)
	for estado in [["normal", Color(0.84, 0.24, 0.20)],
			["hover", Color(0.94, 0.34, 0.28)],
			["pressed", Color(0.66, 0.16, 0.14)]]:
		var caixa := StyleBoxFlat.new()
		caixa.bg_color = estado[1]
		caixa.border_color = Color(0.98, 0.84, 0.36)
		caixa.set_border_width_all(3)
		caixa.set_corner_radius_all(14)
		caixa.set_content_margin_all(12)
		caixa.shadow_color = Color(0, 0, 0, 0.45)
		caixa.shadow_size = 6
		caixa.shadow_offset = Vector2(0, 4)
		botao.add_theme_stylebox_override(str(estado[0]), caixa)

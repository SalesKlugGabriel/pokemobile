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
const INICIAIS : Array[int] = [1, 4, 7]   # Bulbasaur, Charmander, Squirtle

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

	var titulo := $TitleLabel as Label
	if titulo:
		titulo.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))
		titulo.add_theme_color_override("font_outline_color", Color(0.11, 0.09, 0.06))
		titulo.add_theme_constant_override("outline_size", 12)
	var sub := $SubLabel as Label
	if sub:
		sub.add_theme_color_override("font_color", Color(0.85, 0.72, 0.36))
		sub.add_theme_color_override("font_outline_color", Color(0.11, 0.09, 0.06))
		sub.add_theme_constant_override("outline_size", 6)

	var fileira := HBoxContainer.new()
	fileira.add_theme_constant_override("separation", 28)
	fileira.alignment = BoxContainer.ALIGNMENT_CENTER
	fileira.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	fileira.offset_left = -220
	fileira.offset_right = 220
	fileira.offset_top = -150
	fileira.offset_bottom = -30
	fileira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for id in INICIAIS:
		fileira.add_child(PokemonIcon.criar(id, 104))
	add_child(fileira)

func _on_continue() -> void:
	# Save já carregado no _ready — vai direto ao mapa
	SceneTransition.fade_to("res://scenes/world/maps/WorldMap.tscn")

func _on_new_game() -> void:
	SceneTransition.fade_to("res://scenes/ui/NewGameFlow.tscn")

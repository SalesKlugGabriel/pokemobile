## PauseMenu.gd — Menu de pausa: acesso a Pokémon/Mochila/Pokédex, salvar jogo,
## volume e voltar ao título. É o hub central de menus do overworld — a única
## forma de abrir esses painéis que funciona igual no teclado e no touch (Start).
## Abre/fecha com Escape ou P; bloqueia input do jogo via get_tree().paused.
extends CanvasLayer

const BAG_SCENE     : PackedScene = preload("res://scenes/battle/BagScene.tscn")
const POKEDEX_SCENE : PackedScene = preload("res://scenes/ui/PokedexScene.tscn")

@onready var panel       : PanelContainer = $Panel
@onready var btn_team    : Button         = $Panel/VBox/BtnTeam
@onready var btn_bag     : Button         = $Panel/VBox/BtnBag
@onready var btn_pokedex : Button         = $Panel/VBox/BtnPokedex
@onready var btn_save    : Button         = $Panel/VBox/BtnSave
@onready var btn_resume  : Button         = $Panel/VBox/BtnResume
@onready var btn_title   : Button         = $Panel/VBox/BtnTitle
@onready var label_info  : Label          = $Panel/VBox/LabelInfo
@onready var slider_bgm  : HSlider        = $Panel/VBox/RowBGM/SliderBGM
@onready var slider_sfx  : HSlider        = $Panel/VBox/RowSFX/SliderSFX

var _open          : bool    = false
var _bag_instance  : Control = null

func _ready() -> void:
	# Achado: abrir a pausa (get_tree().paused = true) travava a própria pausa —
	# os botões (Continuar incluso) e o Escape/P ficavam sem efeito porque este
	# nó herdava o modo de processo padrão, que para de rodar quando o jogo pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.hide()
	btn_team.pressed.connect(_on_team)
	btn_bag.pressed.connect(_on_bag)
	btn_pokedex.pressed.connect(_on_pokedex)
	btn_save.pressed.connect(_on_save)
	btn_resume.pressed.connect(_on_resume)
	btn_title.pressed.connect(_on_title)
	slider_bgm.value_changed.connect(func(v): AudioManager.set_bgm_volume(v))
	slider_sfx.value_changed.connect(func(v): AudioManager.set_sfx_volume(v))
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _open:
			_on_resume()
		else:
			_open_menu()
	elif event.is_action_pressed("menu_bag") and not get_tree().paused:
		get_viewport().set_input_as_handled()
		_on_bag()

func _open_menu() -> void:
	_open = true
	label_info.text = ""
	# Sincroniza sliders com volume atual
	slider_bgm.value = AudioManager.get_bgm_volume()
	slider_sfx.value = AudioManager.get_sfx_volume()
	panel.show()
	get_tree().paused = true

func _on_resume() -> void:
	AudioManager.play_sfx("cancel")
	_open = false
	panel.hide()
	get_tree().paused = false

func _on_team() -> void:
	AudioManager.play_sfx("confirm")
	_on_resume()
	EventBus.party_opened.emit()

func _on_bag() -> void:
	AudioManager.play_sfx("confirm")
	if not _bag_instance:
		_bag_instance = BAG_SCENE.instantiate()
		add_child(_bag_instance)
		_bag_instance.anchor_left   = 0.5
		_bag_instance.anchor_top    = 0.5
		_bag_instance.anchor_right  = 0.5
		_bag_instance.anchor_bottom = 0.5
		_bag_instance.offset_left   = -200
		_bag_instance.offset_top    = -150
		_bag_instance.offset_right  = 200
		_bag_instance.offset_bottom = 150
		_bag_instance.bag_closed.connect(func():
			_bag_instance.hide()
			get_tree().paused = false
		)
	_bag_instance.set_battle_mode(false)
	_on_resume()
	get_tree().paused = true
	_bag_instance.refresh(SaveManager.get_inventory())
	_bag_instance.show()

func _on_pokedex() -> void:
	AudioManager.play_sfx("confirm")
	var pokedex := get_node_or_null("PokedexInstance")
	if not pokedex:
		pokedex = POKEDEX_SCENE.instantiate()
		pokedex.name = "PokedexInstance"
		add_child(pokedex)
		pokedex.closed_by_user.connect(func(): get_tree().paused = false)
	_on_resume()
	get_tree().paused = true
	EventBus.pokedex_opened.emit()

func _on_save() -> void:
	AudioManager.play_sfx("confirm")
	SaveManager.save_game()
	label_info.text = "Jogo salvo!"

func _on_title() -> void:
	get_tree().paused = false
	SceneTransition.fade_to("res://scenes/ui/TitleScreen.tscn")

## PauseMenu.gd — Menu de pausa: salvar jogo, volume e voltar ao título.
## Abre/fecha com Escape ou P; bloqueia input do jogo via get_tree().paused.
extends CanvasLayer

@onready var panel       : PanelContainer = $Panel
@onready var btn_save    : Button         = $Panel/VBox/BtnSave
@onready var btn_resume  : Button         = $Panel/VBox/BtnResume
@onready var btn_title   : Button         = $Panel/VBox/BtnTitle
@onready var label_info  : Label          = $Panel/VBox/LabelInfo
@onready var slider_bgm  : HSlider        = $Panel/VBox/RowBGM/SliderBGM
@onready var slider_sfx  : HSlider        = $Panel/VBox/RowSFX/SliderSFX

var _open : bool = false

func _ready() -> void:
	panel.hide()
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

func _on_save() -> void:
	AudioManager.play_sfx("confirm")
	SaveManager.save_game()
	label_info.text = "Jogo salvo!"

func _on_title() -> void:
	get_tree().paused = false
	SceneTransition.fade_to("res://scenes/ui/TitleScreen.tscn")

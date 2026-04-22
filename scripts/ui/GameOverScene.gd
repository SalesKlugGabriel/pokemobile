## GameOverScene.gd — Tela de Game Over: exibida quando todo o time do jogador desmaiar.
## Opções: Tentar novamente (carregar save) ou Título.
extends CanvasLayer

@onready var retry_btn : Button = $Panel/VBox/RetryBtn
@onready var title_btn : Button = $Panel/VBox/TitleBtn
@onready var msg_label : Label  = $Panel/VBox/Message

func _ready() -> void:
	layer = 90
	hide()
	retry_btn.pressed.connect(_on_retry)
	title_btn.pressed.connect(_on_title)
	EventBus.game_over.connect(_on_game_over)

func _on_game_over() -> void:
	AudioManager.stop_bgm()
	show()
	AudioManager.play_bgm("gameover")

func _on_retry() -> void:
	if SaveManager.has_save():
		SaveManager.heal_team()
		SceneTransition.fade_to("res://scenes/world/maps/WorldMap.tscn")
	else:
		_on_title()
	hide()

func _on_title() -> void:
	SceneTransition.fade_to("res://scenes/ui/TitleScreen.tscn")
	hide()

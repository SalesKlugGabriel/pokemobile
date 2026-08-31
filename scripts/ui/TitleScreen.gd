## TitleScreen.gd — Tela inicial do jogo: New Game / Continue.
extends Control

@onready var btn_continue  : Button = $VBox/BtnContinue
@onready var btn_new_game  : Button = $VBox/BtnNewGame
@onready var label_save    : Label  = $VBox/LabelSave

func _ready() -> void:
	AudioManager.play_bgm("title")
	var has_save := SaveManager.has_save()
	btn_continue.visible = has_save
	if has_save:
		# Carrega brevemente para exibir info do save
		SaveManager.load_game()
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

func _on_continue() -> void:
	# Save já carregado no _ready — vai direto ao mapa
	SceneTransition.fade_to("res://scenes/world/maps/WorldMap.tscn")

func _on_new_game() -> void:
	SceneTransition.fade_to("res://scenes/ui/NewGameFlow.tscn")

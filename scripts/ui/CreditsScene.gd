## CreditsScene.gd — Tela de créditos, exibida ao completar a pokédex (151/151) ou via menu.
extends CanvasLayer

@onready var scroll_container : ScrollContainer = $Scroll
@onready var credits_label    : RichTextLabel   = $Scroll/Credits
@onready var back_btn         : Button          = $BackBtn

const CREDITS_TEXT := """[center][b]PokéMobile[/b][/center]

[center]Um jogo de exploração e batalha Pokémon para mobile[/center]

[center]━━━━━━━━━━━━━━━━━━━━━━━[/center]

[b]Desenvolvimento[/b]
  Game Design & Programação
  Arte Placeholder — gerado via Python PIL
  Dados — baseados em PokéAPI (pokémon generation 1)

[b]Engine[/b]
  Godot 4.x

[b]Agradecimentos[/b]
  Pokémon © Nintendo / Game Freak
  Este é um projeto de estudo / fã não-comercial

[center]━━━━━━━━━━━━━━━━━━━━━━━[/center]

[center]Obrigado por jogar![/center]
"""

func _ready() -> void:
	layer = 95
	hide()
	credits_label.text = CREDITS_TEXT
	back_btn.pressed.connect(_on_back)
	EventBus.battle_ended.connect(_check_pokedex_complete)

func open() -> void:
	AudioManager.stop_bgm()
	AudioManager.play_bgm("credits")
	show()
	_scroll_credits()

func _on_back() -> void:
	SceneTransition.fade_to("res://scenes/ui/TitleScreen.tscn")
	hide()

func _check_pokedex_complete(result: Dictionary) -> void:
	if result.get("result") != "capture":
		return
	var caught_count := 0
	for id in range(1, 152):
		if SaveManager.is_caught(id):
			caught_count += 1
	if caught_count >= 151:
		await get_tree().create_timer(2.0).timeout
		open()

func _scroll_credits() -> void:
	if not scroll_container:
		return
	var tween := create_tween()
	tween.set_loops(1)
	tween.tween_property(scroll_container, "scroll_vertical",
		int(credits_label.get_content_height()), 20.0)

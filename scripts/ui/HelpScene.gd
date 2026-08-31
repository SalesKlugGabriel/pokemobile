## HelpScene.gd — Guia de ajuda dentro do jogo: como jogar, em português
## simples. Mostra as teclas ATUAIS (se o jogador reatribuiu na tela de
## Controles, o texto aqui já aparece atualizado, não fica desatualizado).
extends CanvasLayer

signal closed_by_user()

@onready var panel     : Panel          = $Panel
@onready var close_btn : Button         = $Panel/Header/CloseBtn
@onready var body      : RichTextLabel  = $Panel/Scroll/Body

func _ready() -> void:
	layer = 60
	panel.hide()
	close_btn.pressed.connect(close)

func open() -> void:
	body.text = _build_text()
	panel.show()
	AudioManager.play_sfx("menu_open")

func close() -> void:
	panel.hide()
	AudioManager.play_sfx("cancel")
	closed_by_user.emit()

func _k(action: String) -> String:
	return "[color=#8fc7ff]%s[/color]" % KeybindManager.key_label(action)

func _build_text() -> String:
	return """[b]Como andar[/b]
%s / %s / %s / %s (ou as setas) andam. Segure %s pra correr.

[b]Interagir[/b]
%s conversa com gente, abre porta e confirma escolhas nos menus.

[b]Menu de Pausa[/b]
%s abre o menu principal — dá pra chegar em tudo por ele:
• [b]Pokémon[/b] — ver o time (nível, HP, golpes)
• [b]Mochila[/b] — usar item, pedra ou MT/MO fora de batalha
• [b]Loja[/b] — comprar e vender item por dinheiro
• [b]Pokédex[/b] — Pokémon já vistos/capturados
• [b]Controles[/b] — trocar qualquer tecla do jogo
• [b]Salvar Jogo[/b]

[b]Atalhos diretos (sem abrir a Pausa)[/b]
%s abre a Mochila · %s abre o Time · %s abre a Pokédex

[b]Batalha[/b]
Quando um Pokémon selvagem aparece (ou um treinador te desafia), a tela de
batalha abre com 4 opções:
• [b]LUTAR[/b] — escolhe um golpe
• [b]MOCHILA[/b] — usa Poção, joga Pokébola pra capturar, etc.
• [b]POKÉMON[/b] — troca o Pokémon que está lutando
• [b]FUGIR[/b] — foge (só funciona contra selvagem)
Se o Pokémon que está lutando desmaia e ainda sobra time vivo, a troca
abre sozinha — não dá pra perder por isso.

[b]Capturar Pokémon[/b]
Numa batalha selvagem, abra a Mochila → aba Pokébolas → Usar. Quanto menor
o HP do Pokémon selvagem, maior a chance de capturar.

[b]Evoluir[/b]
Alguns Pokémon evoluem sozinhos ao subir de nível. Outros precisam de uma
Pedra (Pedra do Fogo, da Água, Trovão...) — compre na Loja, abra a Mochila
→ aba Pedras → Usar → escolha o Pokémon.

[b]MT/MO (ensinar golpe)[/b]
Compre uma MT ou MO na Loja, abra a Mochila → aba TM/HM → Usar → escolha o
Pokémon. Se ele já sabe 4 golpes, você escolhe qual esquecer.

[b]Dinheiro[/b]
Aparece no canto de cima da tela. Ganha vendendo item na Loja (aba
Vender) — todo item de loot que você encontra pode virar dinheiro.

[b]Não decorou uma tecla?[/b]
Vá em Pausa → Controles pra ver ou trocar qualquer tecla do jogo.""" % [
		_k("move_up"), _k("move_left"), _k("move_down"), _k("move_right"), _k("run"),
		_k("interact"),
		_k("pause"),
		_k("menu_bag"), _k("menu_team"), _k("open_pokedex"),
	]

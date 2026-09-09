## PokedexRapida.gd — ícone fixo na tela pra abrir a Pokédex de QUALQUER
## Pokémon visível, com dois cliques (09/09, pedido do Gabriel: "Pokédex deve
## estar um ícone na tela que o jogador clica e depois clica no Pokémon
## alvo"). Substitui o caminho antigo (Menu de Pausa → Pokédex → lista →
## escolher da lista) pra quem já está OLHANDO o Pokémon: clica no ícone,
## clica nele, abre a ficha de 5 abas direto (PokedexDetalhe já existia,
## só nunca era chamado assim). A lista completa (ver todos os 151, mesmo
## os nunca vistos) continua no Menu de Pausa — os dois caminhos convivem,
## cada um serve um caso diferente.
extends Control

var _mirando : bool = false
var _botao : Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	position = Vector2(-70, 10)

	_botao = Button.new()
	_botao.custom_minimum_size = Vector2(60, 36)
	_botao.text = "Pokédex"
	_botao.add_theme_font_size_override("font_size", 10)
	_botao.toggle_mode = true
	_botao.pressed.connect(_on_botao_pressionado)
	add_child(_botao)

	EventBus.wild_pokemon_selected.connect(func(p): _tentar_abrir_de(p))
	EventBus.corpo_desmaiado_clicado.connect(func(p): _tentar_abrir_de(p))
	EventBus.follower_clicado.connect(_abrir_do_lider)

func _on_botao_pressionado() -> void:
	_mirando = _botao.button_pressed
	if _mirando:
		TutorialManager.mostrar("pokedex_clique")
		EventBus.notification_requested.emit("Clique num Pokémon (seu ou selvagem) pra ver a Pokédex dele.")

func _tentar_abrir_de(pokemon: Node) -> void:
	if not _mirando or not is_instance_valid(pokemon):
		return
	var species_id : int = int(pokemon.get("species_id")) if "species_id" in pokemon else -1
	_abrir(species_id)

func _abrir_do_lider() -> void:
	if not _mirando:
		return
	var lider := get_tree().get_first_node_in_group("follower_pokemon")
	if lider and "pokemon_species_id" in lider:
		_abrir(int(lider.pokemon_species_id))

func _abrir(species_id: int) -> void:
	if species_id <= 0:
		return
	if not SaveManager.is_seen(species_id):
		EventBus.notification_requested.emit("Você ainda não viu esse Pokémon de verdade — a ficha fica incompleta.")
	PokedexDetalhe.abrir(get_tree().current_scene, species_id)
	_mirando = false
	_botao.button_pressed = false

## PauseMenu.gd — Menu de pausa: acesso a Pokémon/Mochila/Pokédex, salvar jogo,
## volume e voltar ao título. É o hub central de menus do overworld — a única
## forma de abrir esses painéis que funciona igual no teclado e no touch (Start).
## Abre/fecha com Escape ou P; bloqueia input do jogo via get_tree().paused.
extends CanvasLayer

const BAG_SCENE      : PackedScene = preload("res://scenes/battle/BagScene.tscn")
const POKEDEX_SCENE  : PackedScene = preload("res://scenes/ui/PokedexScene.tscn")
const SHOP_SCENE      : PackedScene = preload("res://scenes/ui/ShopScene.tscn")
const HELP_SCENE      : PackedScene = preload("res://scenes/ui/HelpScene.tscn")
const CONTROLS_SCENE  : PackedScene = preload("res://scenes/ui/ControlsScene.tscn")

## Teleporte (Mecânicas de movimentação, 02/09; corrigido 02/09 sessão
## seguinte — ver git log "voar não é teleporte") — teleporta o jogador pra
## dentro do próprio WorldMap.tscn (mesmo padrão já usado por
## PortalManager.gd), 2 tiles ao sul da porta de cada Centro Pokémon
## (posição real das WarpZones em WorldMap.tscn, conferida tile a tile com
## MapLayouts antes de usar — nenhuma é chute). Indigo Plateau fica de fora
## de propósito: no jogo original também não dá pra teleportar até lá, só
## chegando por Victory Road.
## Correção do Gabriel: isto NÃO é a mecânica de Voar (que é movimento — ver
## TrainerEntity.gd is_flying/_pode_voar, montar num Pokémon Voador pra
## atravessar a água mais rápido). É o golpe Teleporte, de tipo Psíquico —
## reaproveita a mesma trava de "Pokémon do tipo certo sabendo o golpe certo"
## (SaveManager.team_has_move_of_type), só que com outro golpe/tipo.
const WORLD_MAP_SCENE := "res://scenes/world/maps/WorldMap.tscn"
const FLY_DESTINATIONS := {
	"pallet_town":    {"label": "Pallet Town",    "tile": Vector2i(75, 164)},
	"viridian_city":  {"label": "Viridian City",  "tile": Vector2i(75, 88)},
	"pewter_city":    {"label": "Pewter City",    "tile": Vector2i(76, 16)},
	"cerulean_city":  {"label": "Cerulean City",  "tile": Vector2i(261, 16)},
	"saffron_city":   {"label": "Saffron City",   "tile": Vector2i(261, 83)},
	"vermilion_city": {"label": "Vermilion City", "tile": Vector2i(261, 149)},
	"celadon_city":   {"label": "Celadon City",   "tile": Vector2i(161, 83)},
	"lavender_town":  {"label": "Lavender Town",  "tile": Vector2i(441, 83)},
	"fuchsia_city":   {"label": "Fuchsia City",   "tile": Vector2i(441, 149)},
}

@onready var panel       : PanelContainer = $Panel
@onready var btn_team    : Button         = $Panel/VBox/BtnTeam
@onready var btn_bag     : Button         = $Panel/VBox/BtnBag
@onready var btn_shop    : Button         = $Panel/VBox/BtnShop
@onready var btn_pokedex : Button         = $Panel/VBox/BtnPokedex
@onready var btn_fly     : Button         = $Panel/VBox/BtnFly
@onready var btn_help     : Button        = $Panel/VBox/BtnHelp
@onready var btn_controls : Button        = $Panel/VBox/BtnControls
@onready var btn_save    : Button         = $Panel/VBox/BtnSave
@onready var btn_resume  : Button         = $Panel/VBox/BtnResume
@onready var btn_title   : Button         = $Panel/VBox/BtnTitle
@onready var label_info  : Label          = $Panel/VBox/LabelInfo
@onready var slider_bgm  : HSlider        = $Panel/VBox/RowBGM/SliderBGM
@onready var slider_sfx  : HSlider        = $Panel/VBox/RowSFX/SliderSFX

var _open          : bool    = false
var _bag_instance  : Control = null
var _picker        : Control = null
var _pending_item_id : String = ""
var _pending_action  : String = ""   # "evolve" ou "teach"
var _pending_target  : int    = -1
## True = Cancelar no seletor de Teleporte volta pro painel de pausa (aberto
## por dentro do menu, _on_fly). False = Cancelar só fecha e despausa
## (aberto direto pela HUD via open_fly_picker_direct(), o painel de pausa
## nunca chegou a abrir).
var _fly_return_to_panel : bool = true

func _ready() -> void:
	# Achado: abrir a pausa (get_tree().paused = true) travava a própria pausa —
	# os botões (Continuar incluso) e o Escape/P ficavam sem efeito porque este
	# nó herdava o modo de processo padrão, que para de rodar quando o jogo pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")
	panel.hide()
	btn_team.pressed.connect(_on_team)
	btn_bag.pressed.connect(_on_bag)
	btn_shop.pressed.connect(_on_shop)
	btn_pokedex.pressed.connect(_on_pokedex)
	btn_fly.pressed.connect(_on_fly)
	btn_help.pressed.connect(_on_help)
	btn_controls.pressed.connect(_on_controls)
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
	# "Teleporte" só aparece pra quem tem um Pokémon de tipo Psíquico que já
	# sabe o golpe — corrigido 02/09 (sessão seguinte): era Voador/"fly" até
	# aqui, mas isso é a mecânica de movimento (Voar), não teleporte.
	btn_fly.visible = SaveManager.team_has_move_of_type("teleport", "Psychic")
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

func _on_fly() -> void:
	AudioManager.play_sfx("confirm")
	_fly_return_to_panel = true
	_open_fly_picker()

## Atalho pra HUD (botão "Teleporte" sem passar pelo menu de pausa inteiro) —
## pedido do Gabriel (02/09): acesso às funções sem pausar o jogo pra navegar
## um menu que não tem nada a ver. "Pausar" aqui é só o necessário pro
## seletor de destino (o jogador não pode andar enquanto escolhe pra onde
## vai) — o painel de pausa completo nunca chega a abrir.
func open_fly_picker_direct() -> void:
	if not SaveManager.team_has_move_of_type("teleport", "Psychic"):
		return
	AudioManager.play_sfx("confirm")
	_fly_return_to_panel = false
	_open = true
	get_tree().paused = true
	_open_fly_picker()

## Lista as cidades já visitadas (SaveManager.get_visited_maps(), gravado
## via EventBus.zone_changed) que também têm destino de teleporte cadastrado
## — mesmo painel construído em código usado por _open_pokemon_picker
## (motivo: ver o comentário lá, o bug do menu de golpes que travou a
## batalha antes).
func _open_fly_picker() -> void:
	_free_picker()
	panel.hide()

	var pc := PanelContainer.new()
	pc.process_mode  = Node.PROCESS_MODE_ALWAYS
	pc.anchor_left   = 0.28
	pc.anchor_top    = 0.15
	pc.anchor_right  = 0.72
	pc.anchor_bottom = 0.85
	add_child(pc)
	_picker = pc

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	pc.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "Teleportar pra onde?"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title_lbl)

	var visited : Array = SaveManager.get_visited_maps()
	var any_destination := false
	for zone_id in FLY_DESTINATIONS.keys():
		if zone_id not in visited:
			continue
		any_destination = true
		var dest : Dictionary = FLY_DESTINATIONS[zone_id]
		var tile : Vector2i   = dest["tile"]
		var btn := Button.new()
		btn.text = dest["label"]
		btn.pressed.connect(func(): _fly_to(tile))
		vbox.add_child(btn)

	if not any_destination:
		var lbl := Label.new()
		lbl.text = "Ainda não visitou nenhuma cidade pra onde possa teleportar."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lbl)

	var cancel := Button.new()
	cancel.text = "Cancelar"
	cancel.pressed.connect(func():
		_free_picker()
		if _fly_return_to_panel:
			panel.show()
		else:
			_open = false
			get_tree().paused = false
	)
	vbox.add_child(cancel)

func _fly_to(tile: Vector2i) -> void:
	_free_picker()
	_open = false
	get_tree().paused = false
	WorldManager.warp_to(WORLD_MAP_SCENE, tile)

func _on_bag() -> void:
	AudioManager.play_sfx("confirm")
	if not _bag_instance:
		_bag_instance = BAG_SCENE.instantiate()
		add_child(_bag_instance)
		_bag_instance.anchor_left   = 0.12
		_bag_instance.anchor_top    = 0.08
		_bag_instance.anchor_right  = 0.88
		_bag_instance.anchor_bottom = 0.92
		_bag_instance.bag_closed.connect(func():
			_bag_instance.hide()
			get_tree().paused = false
		)
		_bag_instance.item_selected.connect(_on_bag_item_used)
	_bag_instance.set_battle_mode(false)
	_on_resume()
	get_tree().paused = true
	_bag_instance.refresh(SaveManager.get_inventory())
	_bag_instance.show()

func _on_shop() -> void:
	AudioManager.play_sfx("confirm")
	var shop := get_node_or_null("ShopInstance")
	if not shop:
		shop = SHOP_SCENE.instantiate()
		shop.name = "ShopInstance"
		add_child(shop)
		shop.closed_by_user.connect(func(): get_tree().paused = false)
	_on_resume()
	get_tree().paused = true
	shop.open()

## Chamado por um NpcEntity vendedor (opens_shop_on_dialog_end) — mesmo caminho
## do botão "Loja" do menu de Pausa, só que disparado por diálogo no mundo.
func open_shop_externally() -> void:
	_on_shop()

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

## Usar um item da Mochila fora de batalha (Pause → Mochila). Achado: o sinal
## `item_selected` do Bag nunca era conectado aqui — clicar "Usar" fora de
## batalha (numa Pedra, por exemplo) não fazia literalmente nada.
func _on_bag_item_used(item_id: String) -> void:
	var item := GameData.get_item(item_id)
	var category : String = item.get("category", "")
	match category:
		"stone":
			_pending_item_id = item_id
			_pending_action  = "evolve"
			_open_pokemon_picker("Usar %s em qual Pokémon?" % item.get("name", item_id))
		"tm_hm":
			_pending_item_id = item_id
			_pending_action  = "teach"
			_open_pokemon_picker("Ensinar %s pra qual Pokémon?" % item.get("name", item_id))
		"vitamin":
			# Achado (03/09): "vitamin" caía sempre no default abaixo, com uma
			# mensagem que nem era verdade — nenhum item desta categoria tinha
			# handler NA BATALHA também, então usar uma vitamina não fazia
			# literalmente nada em lugar nenhum do jogo. HP Up/Proteína/Ferro/
			# Carbos/Cálcio/Zinco (EVs) e Doce Raro (level_up) agora funcionam
			# de verdade, fora de batalha, igual jogo real.
			_pending_item_id = item_id
			_pending_action  = "vitamin"
			_open_pokemon_picker("Usar %s em qual Pokémon?" % item.get("name", item_id))
		_:
			label_info.text = "%s só pode ser usado numa batalha por enquanto." % item.get("name", item_id)

func _close_bag_flow() -> void:
	_free_picker()
	if _bag_instance:
		_bag_instance.hide()
	get_tree().paused = false

func _free_picker() -> void:
	if _picker:
		_picker.queue_free()
		_picker = null

## Painel genérico "escolha um Pokémon do time" — reaproveitado por pedra e
## por MT/MO. Construído em código (não em .tscn) de propósito: um
## PanelContainer com mais de um filho direto estica todos pro mesmo espaço
## e empilha um por cima do outro — foi exatamente esse bug que travou o
## menu de golpes em batalha antes (ver git log). Aqui só existe UM filho
## direto (o VBox), então o problema não pode acontecer.
func _open_pokemon_picker(title: String) -> void:
	_free_picker()
	if _bag_instance:
		_bag_instance.hide()

	var pc := PanelContainer.new()
	pc.process_mode  = Node.PROCESS_MODE_ALWAYS
	pc.anchor_left   = 0.28
	pc.anchor_top    = 0.15
	pc.anchor_right  = 0.72
	pc.anchor_bottom = 0.85
	add_child(pc)
	_picker = pc

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	pc.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title_lbl)

	var team := SaveManager.get_team()
	for i in team.size():
		var poke : Dictionary = team[i]
		var species_name : String = GameData.get_species(int(poke.get("species_id", 1))).get("name", "???")
		var btn := Button.new()
		btn.text = "%s  Nv.%d  %d/%d HP" % [species_name, int(poke.get("level", 1)),
				int(poke.get("hp_current", 0)), int(poke.get("hp_max", 1))]
		var idx := i
		btn.pressed.connect(func(): _on_picker_target(idx))
		vbox.add_child(btn)

	var cancel := Button.new()
	cancel.text = "Cancelar"
	cancel.pressed.connect(func():
		_free_picker()
		if _bag_instance:
			_bag_instance.show()
	)
	vbox.add_child(cancel)

func _on_picker_target(index: int) -> void:
	if _pending_action == "evolve":
		if SaveManager.try_evolve_with_stone(index, _pending_item_id):
			SaveManager.remove_item(_pending_item_id, 1)
			SaveManager.save_game()
			label_info.text = "Evoluiu!"
		else:
			label_info.text = "Não teve efeito..."
		_close_bag_flow()
	elif _pending_action == "teach":
		var team := SaveManager.get_team()
		var moves : Array = team[index].get("moves", [])
		if moves.size() < 4:
			_teach_and_finish(index, -1)
		else:
			_pending_target = index
			_open_move_replace_picker(index)
	elif _pending_action == "vitamin":
		var item := GameData.get_item(_pending_item_id)
		# PP Up (03/09) precisa de um segundo pick (QUAL golpe), diferente das
		# outras vitaminas — sai cedo antes de fechar a Mochila.
		if item.get("effect", "") == "pp_up":
			_pending_target = index
			_open_pp_move_picker(index)
			return
		var usou := false
		if item.get("effect", "") == "level_up":
			usou = SaveManager.use_rare_candy(index)
			label_info.text = "Subiu de nível!" if usou else "Já está no nível máximo (100)."
		elif item.has("ev_stat"):
			usou = SaveManager.apply_ev_vitamin(index, str(item.get("ev_stat", "")), int(item.get("ev_amount", 0)))
			label_info.text = "Melhorou!" if usou else "Não teve efeito — esse status já está no limite."
		if usou:
			SaveManager.remove_item(_pending_item_id, 1)
			SaveManager.save_game()
		_close_bag_flow()

func _open_move_replace_picker(index: int) -> void:
	_free_picker()
	var pc := PanelContainer.new()
	pc.process_mode  = Node.PROCESS_MODE_ALWAYS
	pc.anchor_left   = 0.28
	pc.anchor_top    = 0.15
	pc.anchor_right  = 0.72
	pc.anchor_bottom = 0.85
	add_child(pc)
	_picker = pc

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	pc.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "Já sabe 4 golpes. Esquecer qual?"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title_lbl)

	var team := SaveManager.get_team()
	var moves : Array = team[index].get("moves", [])
	for i in moves.size():
		var move_name : String = GameData.get_move(moves[i].get("id", "")).get("name", "???")
		var btn := Button.new()
		btn.text = move_name
		var slot := i
		btn.pressed.connect(func(): _teach_and_finish(index, slot))
		vbox.add_child(btn)

	var cancel := Button.new()
	cancel.text = "Cancelar"
	cancel.pressed.connect(func(): _close_bag_flow())
	vbox.add_child(cancel)

## Onda 1, item 7 (03/09): MO (HM) e MT Ouro nunca se gastam — achado ao
## construir isto que MO01/02/03 (Cortar/Voar/Força) já vinham sendo
## consumidos aqui igual qualquer MT comum, mesmo sem serem vendidos na loja
## (price:0) — usar a única cópia numa Pokémon deixava o jogador sem jeito
## de ensinar de novo pra outra. Corrigido junto: a decisão agora vem do
## dado (`single_use` em items.json), não mais "toda MT/MO se gasta".
func _teach_and_finish(index: int, slot: int) -> void:
	var item    : Dictionary = GameData.get_item(_pending_item_id)
	var move_id : String     = item.get("teaches", "")
	if SaveManager.learn_move(index, move_id, slot):
		if item.get("single_use", true):
			SaveManager.remove_item(_pending_item_id, 1)
		SaveManager.save_game()
		label_info.text = "Aprendeu %s!" % GameData.get_move(move_id).get("name", move_id)
	_close_bag_flow()

## PP Up (03/09): igual _open_move_replace_picker, mas escolher um golpe aqui
## não descarta nada — só decide QUAL golpe recebe o PP a mais.
func _open_pp_move_picker(index: int) -> void:
	_free_picker()
	var pc := PanelContainer.new()
	pc.process_mode  = Node.PROCESS_MODE_ALWAYS
	pc.anchor_left   = 0.28
	pc.anchor_top    = 0.15
	pc.anchor_right  = 0.72
	pc.anchor_bottom = 0.85
	add_child(pc)
	_picker = pc

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	pc.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "Aumentar o PP máximo de qual golpe?"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title_lbl)

	var team := SaveManager.get_team()
	var moves : Array = team[index].get("moves", [])
	for i in moves.size():
		var move_name : String = GameData.get_move(moves[i].get("id", "")).get("name", "???")
		var btn := Button.new()
		btn.text = "%s (PP %d)" % [move_name, int(moves[i].get("pp_max", 0))]
		var slot := i
		btn.pressed.connect(func(): _apply_pp_up_and_finish(index, slot))
		vbox.add_child(btn)

	var cancel := Button.new()
	cancel.text = "Cancelar"
	cancel.pressed.connect(func(): _close_bag_flow())
	vbox.add_child(cancel)

func _apply_pp_up_and_finish(index: int, slot: int) -> void:
	if SaveManager.apply_pp_up(index, slot):
		SaveManager.remove_item(_pending_item_id, 1)
		SaveManager.save_game()
		label_info.text = "PP máximo aumentou!"
	else:
		label_info.text = "Esse golpe já está no limite de PP Up."
	_close_bag_flow()

func _on_help() -> void:
	AudioManager.play_sfx("confirm")
	var help := get_node_or_null("HelpInstance")
	if not help:
		help = HELP_SCENE.instantiate()
		help.name = "HelpInstance"
		add_child(help)
		help.closed_by_user.connect(func(): get_tree().paused = false)
	_on_resume()
	get_tree().paused = true
	help.open()

func _on_controls() -> void:
	AudioManager.play_sfx("confirm")
	var controls := get_node_or_null("ControlsInstance")
	if not controls:
		controls = CONTROLS_SCENE.instantiate()
		controls.name = "ControlsInstance"
		add_child(controls)
		controls.closed_by_user.connect(func(): get_tree().paused = false)
	_on_resume()
	get_tree().paused = true
	controls.open()

func _on_save() -> void:
	AudioManager.play_sfx("confirm")
	SaveManager.save_game()
	label_info.text = "Jogo salvo!"

func _on_title() -> void:
	get_tree().paused = false
	SceneTransition.fade_to("res://scenes/ui/TitleScreen.tscn")

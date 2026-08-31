## BattleScene.gd — Controller da UI de batalha.
## Recebe chamadas do BattleManager e gerencia animações, menus e input.
extends Node

const BAG_SCENE := preload("res://scenes/battle/BagScene.tscn")

# ──────────────────────────────────────────────────────────────────────────────
# Referências a nós da cena (preenchidas em _ready via @onready)
# ──────────────────────────────────────────────────────────────────────────────
@onready var enemy_sprite    : AnimatedSprite2D = $BattleArea/EnemyArea/EnemySprite
@onready var player_sprite   : AnimatedSprite2D = $BattleArea/PlayerArea/PlayerSprite

@onready var enemy_name_lbl  : Label            = $BattleArea/EnemyArea/EnemyPanel/EnemyName
@onready var enemy_level_lbl : Label            = $BattleArea/EnemyArea/EnemyPanel/EnemyLevel
@onready var enemy_hp_bar    : ProgressBar      = $BattleArea/EnemyArea/EnemyPanel/EnemyHPBar
@onready var enemy_status_lbl: Label            = $BattleArea/EnemyArea/EnemyPanel/EnemyStatus

@onready var player_name_lbl : Label            = $BattleArea/PlayerArea/PlayerPanel/PlayerName
@onready var player_level_lbl: Label            = $BattleArea/PlayerArea/PlayerPanel/PlayerLevel
@onready var player_hp_bar   : ProgressBar      = $BattleArea/PlayerArea/PlayerPanel/PlayerHPBar
@onready var player_hp_lbl   : Label            = $BattleArea/PlayerArea/PlayerPanel/PlayerHPLabel
@onready var player_status_lbl: Label           = $BattleArea/PlayerArea/PlayerPanel/PlayerStatus
@onready var player_exp_bar  : ProgressBar      = $BattleArea/PlayerArea/PlayerPanel/PlayerExpBar

@onready var dialog_box      : PanelContainer   = $DialogBox
@onready var dialog_text     : RichTextLabel    = $DialogBox/DialogText

@onready var action_menu     : PanelContainer   = $ActionMenu
@onready var move_menu       : PanelContainer   = $MoveMenu
@onready var bag_menu        : PanelContainer   = $BagMenu

# Botões de ação
@onready var btn_fight       : Button           = $ActionMenu/Grid/BtnFight
@onready var btn_bag         : Button           = $ActionMenu/Grid/BtnBag
@onready var btn_pokemon     : Button           = $ActionMenu/Grid/BtnPokemon
@onready var btn_run         : Button           = $ActionMenu/Grid/BtnRun

# Botões de move (4 slots)
@onready var move_buttons    : Array            = [
	$MoveMenu/Layout/Grid/Move1,
	$MoveMenu/Layout/Grid/Move2,
	$MoveMenu/Layout/Grid/Move3,
	$MoveMenu/Layout/Grid/Move4,
]
@onready var move_type_lbl   : Label            = $MoveMenu/Layout/MoveInfo/TypeLabel
@onready var move_pp_lbl     : Label            = $MoveMenu/Layout/MoveInfo/PPLabel
@onready var btn_move_back   : Button           = $MoveMenu/Layout/BtnBack

# ──────────────────────────────────────────────────────────────────────────────
# Estado local
# ──────────────────────────────────────────────────────────────────────────────
var _message_queue : Array[String] = []
var _processing_messages : bool    = false
var _player_bp : BattlePokemon     = null
var _enemy_bp  : BattlePokemon     = null
var _bag_scene_instance : Node     = null

# ──────────────────────────────────────────────────────────────────────────────
# Inicialização
# ──────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_hide_all_menus()
	_connect_buttons()
	BattleManager.on_battle_scene_ready(self)

func _connect_buttons() -> void:
	btn_fight.pressed.connect(_on_fight_pressed)
	btn_bag.pressed.connect(_on_bag_pressed)
	btn_run.pressed.connect(BattleManager.player_try_run)
	btn_move_back.pressed.connect(_on_move_back_pressed)

	for i in move_buttons.size():
		var btn : Button = move_buttons[i]
		btn.pressed.connect(_on_move_selected.bind(i))
		btn.mouse_entered.connect(_on_move_hovered.bind(i))

# ──────────────────────────────────────────────────────────────────────────────
# API chamada pelo BattleManager
# ──────────────────────────────────────────────────────────────────────────────
func show_battle_start(player_bp: BattlePokemon, enemy_bp: BattlePokemon) -> void:
	_player_bp = player_bp
	_enemy_bp  = enemy_bp
	_load_battle_sprites(player_bp, enemy_bp)
	update_hud(player_bp, enemy_bp)
	show_message("Um %s selvagem apareceu!" % enemy_bp.species_name)
	await _flush_messages()
	show_action_menu()

## Achado: a tela de batalha nunca carregava sprite nenhum dos dois lados —
## mesma causa dos outros Pokémon (faltava chamar o SpriteBuilder).
func _load_battle_sprites(player_bp: BattlePokemon, enemy_bp: BattlePokemon) -> void:
	if player_sprite and player_bp:
		player_sprite.sprite_frames = SpriteBuilder.build_pokemon_frames(player_bp.species_id)
		player_sprite.play("idle")
		player_sprite.scale = Vector2(4.0, 4.0)
	if enemy_sprite and enemy_bp:
		enemy_sprite.sprite_frames = SpriteBuilder.build_pokemon_frames(enemy_bp.species_id)
		enemy_sprite.play("idle")
		enemy_sprite.scale = Vector2(4.0, 4.0)

func show_action_menu() -> void:
	_hide_all_menus()
	action_menu.visible = true
	dialog_box.visible  = true
	dialog_text.text    = "O que fazer?"

func show_message(msg: String) -> void:
	_message_queue.append(msg)
	if not _processing_messages:
		_process_message_queue()

func animate_damage(target: BattlePokemon, _amount: int) -> void:
	# Pisca o sprite do alvo (feedback visual simples)
	AudioManager.play_sfx("hit")
	var sprite := enemy_sprite if target == _enemy_bp else player_sprite
	var tween  := create_tween()
	for _i in 3:
		tween.tween_property(sprite, "modulate:a", 0.0, 0.06)
		tween.tween_property(sprite, "modulate:a", 1.0, 0.06)
	update_hud(_player_bp, _enemy_bp)

func animate_capture(shakes: int) -> void:
	AudioManager.play_sfx("catch_throw")
	show_message("Pokébola lançada! (%d agitada(s))" % shakes)

func update_hud(player_bp: BattlePokemon, enemy_bp: BattlePokemon) -> void:
	if player_bp:
		player_name_lbl.text   = player_bp.species_name
		player_level_lbl.text  = "Nv.%d" % player_bp.level
		player_hp_bar.max_value = player_bp.max_hp
		player_hp_bar.value    = player_bp.hp
		player_hp_lbl.text     = "%d/%d" % [player_bp.hp, player_bp.max_hp]
		player_status_lbl.text = player_bp.status_name()
		_update_hp_bar_color(player_hp_bar, player_bp.hp_ratio())

	if enemy_bp:
		enemy_name_lbl.text   = enemy_bp.species_name
		enemy_level_lbl.text  = "Nv.%d" % enemy_bp.level
		enemy_hp_bar.max_value = enemy_bp.max_hp
		enemy_hp_bar.value    = enemy_bp.hp
		enemy_status_lbl.text = enemy_bp.status_name()
		_update_hp_bar_color(enemy_hp_bar, enemy_bp.hp_ratio())

func _update_hp_bar_color(bar: ProgressBar, ratio: float) -> void:
	if ratio > 0.5:
		bar.modulate = Color.GREEN
	elif ratio > 0.25:
		bar.modulate = Color.YELLOW
	else:
		bar.modulate = Color.RED

# ──────────────────────────────────────────────────────────────────────────────
# Fila de mensagens (exibidas sequencialmente com input do jogador)
# ──────────────────────────────────────────────────────────────────────────────
func _process_message_queue() -> void:
	if _message_queue.is_empty():
		_processing_messages = false
		return
	_processing_messages = true
	dialog_box.visible   = true
	var msg : String = _message_queue.pop_front()
	dialog_text.text = msg
	await _wait_for_confirm()
	_process_message_queue()

func _wait_for_confirm() -> void:
	await get_tree().create_timer(0.8).timeout

func _flush_messages() -> Signal:
	# Espera a fila esvaziar
	while not _message_queue.is_empty() or _processing_messages:
		await get_tree().process_frame
	return get_tree().process_frame

# ──────────────────────────────────────────────────────────────────────────────
# Menus
# ──────────────────────────────────────────────────────────────────────────────
func _hide_all_menus() -> void:
	action_menu.visible = false
	move_menu.visible   = false
	bag_menu.visible    = false

func _on_fight_pressed() -> void:
	AudioManager.play_sfx("select")
	_hide_all_menus()
	move_menu.visible = true
	_populate_move_buttons()

func _on_bag_pressed() -> void:
	_hide_all_menus()
	# Cria BagScene na primeira abertura
	if _bag_scene_instance == null:
		_bag_scene_instance = BAG_SCENE.instantiate()
		bag_menu.add_child(_bag_scene_instance)
		_bag_scene_instance.item_selected.connect(_on_bag_item_selected)
		_bag_scene_instance.bag_closed.connect(_on_bag_closed)
	_bag_scene_instance.refresh(SaveManager.get_inventory())
	bag_menu.visible = true

func _on_bag_item_selected(item_id: String) -> void:
	bag_menu.visible = false
	var item_data := GameData.get_item(item_id)
	var category  : String = item_data.get("category", "")
	if category == "ball":
		BattleManager.player_throw_pokeball(item_id)
	else:
		# Usa item no Pokémon do jogador
		if SaveManager.remove_item(item_id):
			BattleManager.player_use_item(item_id, BattleManager.player_pokemon)
		else:
			show_message("Sem %s!" % item_data.get("name", item_id))
			show_action_menu()

func _on_bag_closed() -> void:
	bag_menu.visible = false
	show_action_menu()

func _on_move_back_pressed() -> void:
	_hide_all_menus()
	show_action_menu()

func _on_move_selected(index: int) -> void:
	if _player_bp == null:
		return
	var moves := _player_bp.moves
	if index >= moves.size():
		return
	var move := moves[index]
	if move.get("pp_current", 0) <= 0:
		show_message("Sem PP!")
		return
	AudioManager.play_sfx("confirm")
	_hide_all_menus()
	BattleManager.player_select_move(index)

func _on_move_hovered(index: int) -> void:
	if _player_bp == null:
		return
	var moves := _player_bp.moves
	if index >= moves.size():
		return
	var move := moves[index]
	move_type_lbl.text = move.get("type", "???")
	move_pp_lbl.text   = "PP %d/%d" % [move.get("pp_current", 0), move.get("pp", 0)]

func _populate_move_buttons() -> void:
	if _player_bp == null:
		return
	var moves := _player_bp.moves
	for i in move_buttons.size():
		var btn : Button = move_buttons[i]
		if i < moves.size():
			var m := moves[i]
			btn.text     = m.get("name", "---")
			btn.disabled = m.get("pp_current", 0) <= 0
			btn.visible  = true
		else:
			btn.visible = false

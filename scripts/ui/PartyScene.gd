## PartyScene.gd — Tela de party: lista os Pokémon do jogador com HP/nível/moves.
## Abre via Tab (input "party"), fecha com Esc/Tab.
extends CanvasLayer

@onready var panel      : PanelContainer = $Panel
@onready var list       : VBoxContainer  = $Panel/Scroll/List
@onready var btn_close  : Button         = $Panel/Header/BtnClose

var _open : bool = false

func _ready() -> void:
	panel.hide()
	btn_close.pressed.connect(_close)
	EventBus.party_opened.connect(_open_party)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_team"):
		get_viewport().set_input_as_handled()
		if _open:
			_close()
		else:
			_open_party()
	elif event.is_action_pressed("pause") and _open:
		get_viewport().set_input_as_handled()
		_close()

func _open_party() -> void:
	_build_list()
	_open = true
	panel.show()
	get_tree().paused = true

func _close() -> void:
	_open = false
	panel.hide()
	get_tree().paused = false

func _build_list() -> void:
	for child in list.get_children():
		child.queue_free()

	var party : Array = SaveManager.get_team()
	if party.is_empty():
		var lbl := Label.new()
		lbl.text = "Sem Pokémon na party."
		list.add_child(lbl)
		return

	for poke in party:
		var species_id : int    = int(poke.get("species_id", 1))
		var species     : Dictionary = GameData.get_species(species_id)
		var name_str    : String = poke.get("nickname", "") if poke.get("nickname", "") != "" \
								  else species.get("name", "???")
		var level       : int   = poke.get("level", 1)
		var hp_cur      : int   = poke.get("hp_current", 0)
		var hp_max      : int   = poke.get("hp_max", 1)

		# Card do Pokémon
		var card := PanelContainer.new()
		var vbox := VBoxContainer.new()
		var lbl_top := Label.new()
		lbl_top.text = "%s  Lv.%d     HP: %d/%d" % [name_str, level, hp_cur, hp_max]
		lbl_top.add_theme_font_size_override("font_size", 13)

		# Moves
		var moves_arr : Array = poke.get("moves", [])
		var lbl_moves := Label.new()
		var move_names : Array = []
		for m in moves_arr:
			var move_data : Dictionary = GameData.get_move(m.get("move_id", ""))
			move_names.append(move_data.get("name", m.get("move_id", "?")))
		lbl_moves.text = "  " + "  |  ".join(move_names)
		lbl_moves.add_theme_font_size_override("font_size", 11)
		lbl_moves.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

		vbox.add_child(lbl_top)
		vbox.add_child(lbl_moves)
		card.add_child(vbox)
		list.add_child(card)

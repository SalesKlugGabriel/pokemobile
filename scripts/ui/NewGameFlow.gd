## NewGameFlow.gd — Fluxo de Novo Jogo: nome do treinador + escolha do starter.
extends Control

const STARTERS := [
	{ "species_id": 1,  "name": "Bulbasaur",  "type": "Planta / Veneno", "desc": "Fácil. Vantagem nos primeiros ginásios." },
	{ "species_id": 4,  "name": "Charmander", "type": "Fogo",            "desc": "Difícil. Poderoso nas etapas finais." },
	{ "species_id": 7,  "name": "Squirtle",   "type": "Água",            "desc": "Equilibrado. Boa defesa e versatilidade." },
]

var _selected_index : int = 0

@onready var name_input    : LineEdit        = $Layout/TopRow/NameInput
@onready var starter_cards : HBoxContainer  = $Layout/StarterRow/Cards
@onready var btn_confirm   : Button         = $Layout/BtnConfirm
@onready var lbl_error     : Label          = $Layout/LblError

func _ready() -> void:
	_build_starter_cards()
	btn_confirm.pressed.connect(_on_confirm)
	_select(0)

func _build_starter_cards() -> void:
	for i in STARTERS.size():
		var idx := i
		var data : Dictionary = STARTERS[i]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(200, 160)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 6)

		var lbl_name := Label.new()
		lbl_name.text = data["name"]
		lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_name.add_theme_font_size_override("font_size", 18)

		var lbl_type := Label.new()
		lbl_type.text = data["type"]
		lbl_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_type.add_theme_font_size_override("font_size", 12)
		lbl_type.modulate = Color(0.7, 0.7, 0.7)

		var lbl_desc := Label.new()
		lbl_desc.text = data["desc"]
		lbl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_desc.add_theme_font_size_override("font_size", 11)
		lbl_desc.modulate = Color(0.55, 0.55, 0.55)
		lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		var btn := Button.new()
		btn.text = "Escolher"
		btn.pressed.connect(func(): _select(idx))

		vb.add_child(lbl_name)
		vb.add_child(lbl_type)
		vb.add_child(lbl_desc)
		vb.add_child(btn)
		card.add_child(vb)
		starter_cards.add_child(card)

func _select(index: int) -> void:
	_selected_index = index
	# Destaca card selecionado
	for i in starter_cards.get_child_count():
		var card := starter_cards.get_child(i) as PanelContainer
		card.modulate = Color(1, 0.6, 0.2) if i == index else Color(1, 1, 1)

func _on_confirm() -> void:
	var trainer_name := name_input.text.strip_edges()
	if trainer_name.length() == 0:
		trainer_name = "Ash"
	var starter_id : int = STARTERS[_selected_index]["species_id"]
	SaveManager.new_game(trainer_name, starter_id)
	QuestManager.reload_from_save()  # zera progresso de quest de um save anterior, se havia
	SceneTransition.fade_to("res://scenes/world/maps/WorldMap.tscn")

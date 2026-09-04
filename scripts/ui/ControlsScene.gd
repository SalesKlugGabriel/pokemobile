## ControlsScene.gd — Tela de Controles: reatribuir tecla de cada ação.
## Clique em "Alterar", aperta a tecla nova, salva sozinho (KeybindManager).
extends CanvasLayer

signal closed_by_user()

@onready var panel        : Panel         = $Panel
@onready var close_btn    : Button        = $Panel/Header/CloseBtn
@onready var status_label : Label         = $Panel/StatusLabel
@onready var list         : VBoxContainer = $Panel/Scroll/List
@onready var btn_reset    : Button        = $Panel/BtnReset

var _waiting_for_action : String = ""
var _row_buttons : Dictionary = {}   # action -> Button (pra atualizar o texto)

func _ready() -> void:
	layer = 60
	panel.hide()
	close_btn.pressed.connect(close)
	btn_reset.pressed.connect(_on_reset)
	set_process_unhandled_key_input(true)

func open() -> void:
	_waiting_for_action = ""
	status_label.text = ""
	_populate()
	panel.show()
	UIStack.empilhar(self, close)
	AudioManager.play_sfx("menu_open")

func close() -> void:
	_waiting_for_action = ""
	panel.hide()
	UIStack.desempilhar(self)
	AudioManager.play_sfx("cancel")
	closed_by_user.emit()

func _populate() -> void:
	for child in list.get_children():
		child.queue_free()
	_row_buttons.clear()
	for action in KeybindManager.REBINDABLE_ACTIONS:
		list.add_child(_make_row(action))

func _make_row(action: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var lbl := Label.new()
	lbl.text = KeybindManager.ACTION_LABELS.get(action, action)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(lbl)

	var key_lbl := Label.new()
	key_lbl.text = KeybindManager.key_label(action)
	key_lbl.custom_minimum_size = Vector2(90, 0)
	key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_lbl.add_theme_font_size_override("font_size", 14)
	key_lbl.modulate = Color(0.8, 0.85, 1.0)
	row.add_child(key_lbl)

	var btn := Button.new()
	btn.text = "Alterar"
	btn.custom_minimum_size = Vector2(90, 0)
	btn.pressed.connect(_on_change_pressed.bind(action, key_lbl, btn))
	row.add_child(btn)
	_row_buttons[action] = btn

	return row

func _on_change_pressed(action: String, key_lbl: Label, btn: Button) -> void:
	if _waiting_for_action != "":
		return  # já esperando outra tecla, ignora clique duplo
	_waiting_for_action = action
	status_label.text = ""
	btn.text = "..."
	key_lbl.text = "Pressione uma tecla"

func _unhandled_key_input(event: InputEvent) -> void:
	if _waiting_for_action == "" or not event is InputEventKey or not event.pressed:
		return
	var action := _waiting_for_action
	_waiting_for_action = ""
	get_viewport().set_input_as_handled()

	if event.keycode == KEY_ESCAPE:
		_populate()  # cancela, redesenha do jeito que estava
		return

	var conflict := KeybindManager.find_conflict(event.physical_keycode, action)
	KeybindManager.rebind(action, event)
	_populate()
	if conflict != "":
		var conflict_label : String = KeybindManager.ACTION_LABELS.get(conflict, conflict)
		status_label.text = "\"%s\" ficou sem tecla (essa tecla foi pra cá)." % conflict_label
		AudioManager.play_sfx("cancel")

func _on_reset() -> void:
	KeybindManager.reset_all_to_default()
	_populate()

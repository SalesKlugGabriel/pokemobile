## DialogBox.gd — Caixa de diálogo para NPCs (overlay do overworld).
## Conecta ao EventBus.npc_dialog_requested, exibe linhas uma a uma,
## avança com Z/Enter, fecha e emite dialog_ended ao terminar.
extends CanvasLayer

@onready var panel      : PanelContainer = $Panel
@onready var label_name : Label          = $Panel/VBox/LabelName
@onready var label_text : RichTextLabel  = $Panel/VBox/LabelText
@onready var icon_next  : TextureRect    = $Panel/VBox/HBoxBottom/IconNext

var _lines    : Array  = []
var _index    : int    = 0
var _active   : bool   = false
var _npc_name : String = ""

func _ready() -> void:
	panel.hide()
	EventBus.npc_dialog_requested.connect(_on_dialog_requested)

func _on_dialog_requested(npc: Node, dialog_id: String) -> void:
	var lines : Array = GameData.get_dialog(dialog_id)
	_npc_name = npc.get("npc_name") if npc.get("npc_name") else ""
	_start(lines)

func _start(lines: Array) -> void:
	_lines  = lines
	_index  = 0
	_active = true
	panel.show()
	_show_line()

func _show_line() -> void:
	if _index >= _lines.size():
		_close()
		return
	label_name.text    = _npc_name
	label_name.visible = _npc_name != ""
	label_text.text    = _lines[_index]
	icon_next.visible  = (_index < _lines.size() - 1)

func _close() -> void:
	_active = false
	panel.hide()
	EventBus.dialog_ended.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		AudioManager.play_sfx("select")
		_index += 1
		_show_line()

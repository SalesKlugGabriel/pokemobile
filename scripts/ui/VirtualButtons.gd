## VirtualButtons.gd — Botões de ação touch para mobile.
## Botões: A (interagir/confirmar), B (correr/voltar), Start (pause).
class_name VirtualButtons
extends Control

@onready var btn_a     : TouchScreenButton = $BtnA
@onready var btn_b     : TouchScreenButton = $BtnB
@onready var btn_start : TouchScreenButton = $BtnStart

func _ready() -> void:
	if not DisplayServer.is_touchscreen_available():
		hide()
		return
	show()
	_setup_button(btn_a,     "interact",  Color(0.3, 0.7, 0.3))
	_setup_button(btn_b,     "run",       Color(0.7, 0.3, 0.3))
	_setup_button(btn_start, "pause",     Color(0.5, 0.5, 0.7))

func _setup_button(btn: TouchScreenButton, action: String, _color: Color) -> void:
	if not btn:
		return
	btn.action = action

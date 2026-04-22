## VirtualJoystick.gd — Joystick virtual para controle touch do player.
## Emite os mesmos input actions que o teclado (move_up/down/left/right).
## Coloca um joystick analógico no canto inferior esquerdo da tela.
class_name VirtualJoystick
extends Control

# ──────────────────────────────────────────────────────────────────────────────
# Configuração
# ──────────────────────────────────────────────────────────────────────────────
@export var dead_zone      : float = 12.0   # raio mínimo para ativar direção
@export var joystick_radius: float = 48.0   # raio máximo do thumb

# ──────────────────────────────────────────────────────────────────────────────
# Nós
# ──────────────────────────────────────────────────────────────────────────────
@onready var base_circle   : Control = $BaseCircle
@onready var thumb_circle  : Control = $ThumbCircle

# ──────────────────────────────────────────────────────────────────────────────
# Estado
# ──────────────────────────────────────────────────────────────────────────────
var _touch_index  : int     = -1
var _origin       : Vector2 = Vector2.ZERO
var _direction    : Vector2 = Vector2.ZERO

# Ações ativas no momento
var _active_actions : Array[String] = []

func _ready() -> void:
	# Garante que é visível apenas quando há touch disponível
	if not DisplayServer.is_touchscreen_available():
		hide()
		return
	show()
	_reset_thumb()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			var local_pos := to_local(event.position)
			if _is_in_joystick_area(local_pos):
				_touch_index = event.index
				_origin = local_pos
				_update(local_pos)
		elif not event.pressed and event.index == _touch_index:
			_release()

	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			_update(to_local(event.position))

func _update(touch_pos: Vector2) -> void:
	var delta   := touch_pos - _origin
	var clamped := delta.limit_length(joystick_radius)
	_direction  = delta.normalized() if delta.length() > dead_zone else Vector2.ZERO

	# Move o thumb visualmente
	if thumb_circle:
		thumb_circle.position = base_circle.position + clamped

	# Emite input actions direcionais
	_emit_directions(_direction)

func _release() -> void:
	_touch_index = -1
	_direction   = Vector2.ZERO
	_reset_thumb()
	_emit_directions(Vector2.ZERO)

func _reset_thumb() -> void:
	if thumb_circle and base_circle:
		thumb_circle.position = base_circle.position

func _is_in_joystick_area(pos: Vector2) -> bool:
	if not base_circle:
		return pos.x < 200 and pos.y > size.y - 200
	var center := base_circle.position + base_circle.size * 0.5
	return pos.distance_to(center) < joystick_radius * 2.0

# ──────────────────────────────────────────────────────────────────────────────
# Input injection
# ──────────────────────────────────────────────────────────────────────────────

func _emit_directions(dir: Vector2) -> void:
	var new_actions : Array[String] = []
	if dir.y < -0.3:  new_actions.append("move_up")
	if dir.y > 0.3:   new_actions.append("move_down")
	if dir.x < -0.3:  new_actions.append("move_left")
	if dir.x > 0.3:   new_actions.append("move_right")

	# Pressionar novas ações
	for action in new_actions:
		if action not in _active_actions:
			_inject_action(action, true)

	# Soltar ações que não estão mais ativas
	for action in _active_actions:
		if action not in new_actions:
			_inject_action(action, false)

	_active_actions = new_actions

func _inject_action(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action  = action
	ev.pressed = pressed
	Input.parse_input_event(ev)

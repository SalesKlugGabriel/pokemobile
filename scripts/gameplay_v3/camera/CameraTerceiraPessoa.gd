## CameraTerceiraPessoa.gd — A câmera do treinador no mundo (§13, §11).
##
## Braço de mola atrás do ombro: o mouse gira o braço, a câmera fica na ponta, e
## ela recua sozinha quando há parede no caminho.
##
## ── Por que `SpringArm3D` e não posição calculada à mão ─────────────────────
##
## O `SpringArm3D` do Godot já resolve o problema difícil — encostar numa parede
## e aproximar a câmera em vez de atravessá-la. Reimplementar isso com raycast
## próprio é o tipo de código que funciona no teste e falha na primeira quina
## do terreno de verdade.
##
## ── O que esta classe NÃO decide ────────────────────────────────────────────
##
## Distância final, FOV, curva de transição e enquadramento são **apresentação**,
## e a fronteira com o Codex continua valendo na V3 (§48). O que está aqui são
## os números mínimos pra existir uma câmera jogável — ele ajusta depois.
class_name CameraTerceiraPessoa
extends SpringArm3D

## Quanto o mouse gira, em radianos por pixel. Fica aqui como padrão; o valor
## final vai pro `CameraProfile` da espécie (§19) e às opções do jogador.
@export var sensibilidade : float = 0.0035

## §13 pede transição suave. Estes limites são de conforto, não de física:
## deixar olhar direto pra cima ou pra baixo desorienta e não serve pra nada.
const PITCH_MIN : float = deg_to_rad(-70.0)
const PITCH_MAX : float = deg_to_rad(35.0)

const DISTANCIA_PADRAO : float = 5.0
const ALTURA_DO_OMBRO  : float = 1.5

var _pitch : float = deg_to_rad(-12.0)
var _yaw   : float = 0.0
var camera : Camera3D = null

func _ready() -> void:
	spring_length = DISTANCIA_PADRAO
	position.y = ALTURA_DO_OMBRO
	# A mola precisa ignorar o próprio corpo do dono, senão ela encosta nele e
	# a câmera cola na nuca.
	var dono := get_parent()
	if dono is CollisionObject3D:
		add_excluded_object((dono as CollisionObject3D).get_rid())

	camera = Camera3D.new()
	camera.current = true
	add_child(camera)
	_aplicar()

## Gira a câmera. Recebe o movimento do mouse em pixels — quem traduz evento em
## chamada é o controlador, porque quem manda no input é o `ControlModeManager`.
func girar(movimento_do_mouse: Vector2) -> void:
	_yaw -= movimento_do_mouse.x * sensibilidade
	_pitch = clampf(_pitch - movimento_do_mouse.y * sensibilidade, PITCH_MIN, PITCH_MAX)
	_aplicar()

func _aplicar() -> void:
	rotation = Vector3(_pitch, _yaw, 0.0)

## A base achatada da câmera, pro movimento seguir pra onde se está olhando.
## Só o yaw: incluir o pitch faria o W andar pro chão quando se olha pra baixo.
func base_do_movimento() -> Basis:
	return Basis(Vector3.UP, _yaw)

func yaw() -> float:
	return _yaw

## Define o ângulo diretamente. Existe pra a VOLTA da transferência (Fase 7):
## a câmera do treinador herda o ângulo em que o Pokémon estava olhando, senão
## o jogador reassume virado pra trás depois de uma luta que o girou.
##
## Faltava aqui e existia só na câmera de 1ª pessoa — o teste da Fase 7 pegou,
## porque a ida funcionava e a volta chamava um método que não existia.
func definir_yaw(novo: float) -> void:
	_yaw = novo
	_aplicar()

## §13: afastar/aproximar sem cortes. Usado pelo contexto de câmera
## (`contexto_de_camera`, contrato herdado da D-003) quando a briga cresce.
func distancia_alvo(d: float, delta: float, velocidade: float = 6.0) -> void:
	spring_length = move_toward(spring_length, d, velocidade * delta)

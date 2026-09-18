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

## RFC-007, decisão 3. Era 1,5 m, calibrado contra a cápsula de 1,75 m que o
## treinador tinha antes do `player_v1.glb` existir. Com o corpo agora em
## 1,60 m, **a proporção é que foi preservada, não o número**: 1,5 / 1,75 =
## 0,857, e 1,60 × 0,857 = **1,371 m**.
##
## Preservar a proporção e não o valor absoluto é o que impede a câmera de
## subir pra altura dos olhos (ou descer pro peito) só porque o personagem
## mudou de tamanho. E não é estimativa visual — é a mesma razão de antes,
## aplicada à altura nova. Quem confere no navegador é o Gabriel; se ele achar
## alto ou baixo, **este** é o número a mexer, não a cápsula.
const ALTURA_DO_OMBRO  : float = 1.371

var _pitch : float = deg_to_rad(-12.0)
var _yaw   : float = 0.0
var camera : Camera3D = null

## Coloca a câmera na altura do ombro do dono, na posição dele.
##
## Existe porque a câmera é `top_level` (ver TrainerController3D._ready): ela
## não herda mais a transformação do corpo, e por isso também não herda a
## posição. Quem sabe qual é a altura do ombro é a câmera, não o corpo — então
## o offset fica aqui, e o dono só informa onde os pés estão.
##
## ⚠️ Sem isto, a correção do `top_level` consertaria a rotação e enfiaria a
## câmera no chão: `position.y = ALTURA_DO_OMBRO` no `_ready` passa a ser uma
## altura ABSOLUTA de 1,5 m no mundo, e o treinador andando numa encosta de 40 m
## sairia de quadro. Um conserto que quebra outra coisa em silêncio é o padrão
## que esta sessão passou o dia caçando.
func seguir(pes_do_dono: Vector3) -> void:
	global_position = pes_do_dono + Vector3.UP * ALTURA_DO_OMBRO

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

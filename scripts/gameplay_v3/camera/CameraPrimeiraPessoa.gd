## CameraPrimeiraPessoa.gd — Ver o mundo pelos olhos do Pokémon (§17, §19).
##
## A câmera que existe pra a fantasia central funcionar: *"quando a batalha
## começa, eu assumo o controle do meu Pokémon"*.
##
## ── Por que ela não é a mesma classe da 3ª pessoa ───────────────────────────
##
## A de 3ª pessoa é um braço de mola que precisa recuar quando há parede. Esta
## está **dentro** da cabeça — não há o que recuar, e o `SpringArm3D` só
## atrapalharia. São problemas diferentes, e uma classe que servisse aos dois
## seria uma classe com um `if` no meio.
##
## ── O que ela NÃO decide ────────────────────────────────────────────────────
##
## Altura dos olhos, FOV e sensibilidade vêm do `CameraProfile` da espécie
## (§19). Um Onix e um Rattata não podem usar a mesma câmera, e quem sabe a
## diferença é o perfil — não este arquivo.
class_name CameraPrimeiraPessoa
extends Node3D

var camera : Camera3D = null
var sensibilidade : float = 0.0035

var _pitch : float = 0.0
var _yaw : float = 0.0
var _pitch_min : float = deg_to_rad(-80.0)
var _pitch_max : float = deg_to_rad(80.0)

func _ready() -> void:
	camera = Camera3D.new()
	camera.current = false
	add_child(camera)

## Aplica o perfil da espécie. Chamado quando o jogador assume aquele Pokémon —
## trocar de Pokémon troca de câmera junto, porque o corpo é outro.
func aplicar_perfil(perfil: Dictionary) -> void:
	position.y = float(perfil.get("altura_dos_olhos", 1.5))
	# Adianta um pouco em bicho grande: em 1ª pessoa, o próprio corpo de um
	# Onix ocuparia a tela inteira.
	position.z = -float(perfil.get("offset_frente", 0.0))
	sensibilidade = float(perfil.get("sensibilidade", 0.0035))
	_pitch_min = float(perfil.get("pitch_min", deg_to_rad(-80.0)))
	_pitch_max = float(perfil.get("pitch_max", deg_to_rad(80.0)))
	if camera != null:
		camera.fov = float(perfil.get("fov", 75.0))
		camera.near = float(perfil.get("near", 0.08))
	_aplicar()

func girar(movimento_do_mouse: Vector2) -> void:
	_yaw -= movimento_do_mouse.x * sensibilidade
	_pitch = clampf(_pitch - movimento_do_mouse.y * sensibilidade, _pitch_min, _pitch_max)
	_aplicar()

func _aplicar() -> void:
	rotation = Vector3(_pitch, _yaw, 0.0)

func yaw() -> float:
	return _yaw

## Herdar a direção na troca de corpo é o que faz a transferência parecer um
## movimento só, em vez de duas cenas coladas. Ver o desenho da Fase 7 em
## `docs/COMBAT_FIRST_PERSON.md`.
func definir_yaw(novo: float) -> void:
	_yaw = novo
	_aplicar()

## A base do movimento: só o yaw, achatado. Incluir o pitch faria o Pokémon
## tentar andar pro chão quando o jogador olha pra baixo.
func base_do_movimento() -> Basis:
	return Basis(Vector3.UP, _yaw)

## Pra onde se está mirando, COM o pitch — é isto que a mira de skill usa (§22),
## e é diferente da direção em que se anda.
func direcao_de_mira() -> Vector3:
	return -global_transform.basis.z

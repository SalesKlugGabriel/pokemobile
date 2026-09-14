## TrainerController3D.gd — O treinador no mundo 3D (§11).
##
## Terceira pessoa. WASD relativo à câmera, mouse olhando, corrida, colisão real,
## gravidade, inclinação e **a mesma stamina da V2**.
##
## ── O que veio de graça do que já existia ───────────────────────────────────
##
## `Stamina.gd` entra **sem uma linha alterada**. Ela é classe pura: as três
## linhas de progressão, os três degraus de exaustão e a espera de 1 segundo
## depois do zero nunca souberam se o jogo era 2D ou 3D. É o pivô cobrando o
## juro da disciplina de manter regra fora do nó.
##
## ── Quem manda no input ─────────────────────────────────────────────────────
##
## Este nó **não decide** se deve escutar. O `ControlModeManager` liga e desliga
## o processamento de input dele (§12). Quando o jogador assume o Pokémon, este
## controlador para de ter vontade própria — mas **continua no mundo, com
## física**, porque a §17 diz que o treinador permanece lá.
extends CharacterBody3D
class_name TrainerController3D

signal stamina_mudou(atual: float, maximo: float, estado: String)
signal comecou_a_andar()
signal parou()

var stamina : Stamina = Stamina.new()
var camera : CameraTerceiraPessoa = null

## §11: a §5 da V2 vale igual — correr, nadar, escalar e pular custam fôlego.
var _parado_antes : bool = true

## Preenchido de fora quando o controle vem do toque, como na V2. `mover()` é a
## porta; o teclado é só uma das fontes.
var intencao : Vector2 = Vector2.ZERO
var quer_correr : bool = false
var le_teclado : bool = true

func _ready() -> void:
	add_to_group("treinador_v3")
	add_to_group("player")   # a ponte de feedback já procura este grupo
	_montar_corpo()
	camera = CameraTerceiraPessoa.new()
	add_child(camera)

## Corpo mínimo. Malha e animação são do Codex (§48) — o que está aqui é o
## necessário pra colidir e pra dar pra ver onde o personagem está.
func _montar_corpo() -> void:
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.35
	capsula.height = 1.75
	forma.shape = capsula
	forma.position.y = 0.875
	add_child(forma)

	var vis := MeshInstance3D.new()
	var malha := CapsuleMesh.new()
	malha.radius = 0.35
	malha.height = 1.75
	vis.mesh = malha
	vis.position.y = 0.875
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.82, 0.35)
	vis.material_override = mat
	add_child(vis)

	# §11: inclinação. Sem isto o corpo trava na primeira ladeira e "sobe"
	# qualquer parede vertical — os dois ficam errados ao mesmo tempo.
	floor_max_angle = Locomocao3D.ANGULO_MAXIMO_DE_SUBIDA
	floor_snap_length = 0.4

# ──────────────────────────────────────────────────────────────────────────────
# Input
# ──────────────────────────────────────────────────────────────────────────────

func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion and camera != null:
		camera.girar((evento as InputEventMouseMotion).relative)

func _ler_teclado() -> void:
	if not le_teclado:
		return
	# Uma fonte só de intenção, como na V2: o toque preenche o MESMO campo, pra
	# nenhuma regra precisar ser escrita duas vezes.
	intencao = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down"))
	quer_correr = Input.is_action_pressed("run") and stamina.atual > 0.0

## A porta do toque e do teste. Desliga o teclado sozinho, como na V2.
func mover(nova_intencao: Vector2, correndo: bool = false) -> void:
	le_teclado = false
	intencao = nova_intencao
	quer_correr = correndo

func soltar_movimento() -> void:
	intencao = Vector2.ZERO
	quer_correr = false
	le_teclado = true

# ──────────────────────────────────────────────────────────────────────────────
# O laço
# ──────────────────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	_ler_teclado()
	_tick_stamina(delta)

	var base : Basis = camera.base_do_movimento() if camera != null else Basis.IDENTITY
	var alvo := Locomocao3D.velocidade_alvo(
		intencao, quer_correr, base, stamina.fator_de_velocidade())
	velocity = Locomocao3D.avancar(velocity, alvo, delta)
	velocity.y = Locomocao3D.aplicar_gravidade(velocity.y, is_on_floor(), delta)

	move_and_slide()

	# Vira pra onde anda, não pra onde a câmera olha — é o que deixa andar de
	# lado e de costas parecer natural em 3ª pessoa.
	rotation.y = Locomocao3D.girar_para(rotation.y, velocity, delta)
	_conferir_parada()

func _tick_stamina(delta: float) -> void:
	var acoes : Array = []
	# Correr parado não é corrida. Cobrar isso seria armadilha invisível — mesma
	# decisão da V2.
	if quer_correr and intencao != Vector2.ZERO:
		acoes.append("correr")
	if stamina.passo(delta, acoes, esta_parado()):
		stamina_mudou.emit(stamina.atual, stamina.maximo(), stamina.estado())

func esta_parado() -> bool:
	return Locomocao3D.esta_parado(velocity)

func _conferir_parada() -> void:
	var agora := esta_parado()
	if agora == _parado_antes:
		return
	_parado_antes = agora
	if agora:
		parou.emit()
	else:
		comecou_a_andar.emit()

# ──────────────────────────────────────────────────────────────────────────────
# Ganchos do ControlModeManager (§12)
# ──────────────────────────────────────────────────────────────────────────────

## Chamado quando o jogador volta a ser o treinador.
func ao_assumir_controle() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if camera != null and camera.camera != null:
		camera.camera.current = true

## Chamado quando o jogador assume o Pokémon. A intenção é zerada de propósito:
## sem isso, o treinador continuaria andando pra sempre na última direção que o
## jogador segurava quando a batalha começou.
func ao_perder_controle() -> void:
	intencao = Vector2.ZERO
	quer_correr = false
	le_teclado = true

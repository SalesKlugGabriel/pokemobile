## PokebolaLancada3D.gd — A bola no ar (Fase 21).
##
## O nó que faz `RegraDeArremesso` acontecer no mundo. Ele não decide nada: a
## trajetória é da regra, o acerto é da regra, e o "pegou ou não" é de
## `RegrasDeCorpo`, via `Corpo3D`. Aqui só se move e se avisa.
##
## ── Por que a bola tem vida própria e não é um raycast ──────────────────────
##
## Um raycast resolveria o acerto no mesmo quadro do arremesso, e isso apagaria
## a única coisa que a §28 pede: o **tempo** entre decidir e saber. Jogar a bola
## sabendo que o Alpha ainda vem pra cima de você é a mecânica; saber na hora
## seria só um botão de sorteio.
##
## ⚠️ O alvo é guardado por referência, mas nunca confiado: o corpo pode expirar
## no meio do voo (a janela é de 10 a 15 s e a bola leva quase um segundo). Toda
## leitura passa por `is_instance_valid`.
extends Node3D
class_name PokebolaLancada3D

## Acertou e o corpo respondeu. `resultado` é o que `Corpo3D.tentar_capturar`
## devolveu — quem mostra na tela é a HUD (Codex), que não recalcula nada.
signal resolveu(resultado: Dictionary)

## A bola caiu sem acertar ninguém. Separado de `resolveu` de propósito: errar o
## arremesso e falhar a captura são coisas diferentes, e a tela precisa poder
## dizer qual foi.
signal errou()

var velocidade : Vector3 = Vector3.ZERO
var gravidade : float = 0.0
var ball : String = "pokeball"
var sorte : int = 0
var alvo : Node3D = null

var _tempo : float = 0.0
var _origem : Vector3 = Vector3.ZERO
var _resolvida : bool = false

# ──────────────────────────────────────────────────────────────────────────────

## Nasce já com posição e velocidade. Mesmo contrato de nascimento da Fase 11:
## a posição vai ANTES de entrar na árvore.
static func lancar(pai: Node, origem: Vector3, direcao: Vector3,
		alvo_pretendido: Node3D, qual_ball: String = "pokeball",
		sorte_do_treinador: int = 0,
		gravidade_do_mundo: float = 0.0) -> PokebolaLancada3D:
	var b := PokebolaLancada3D.new()
	b.position = origem
	b._origem = origem
	# ⚠️ A gravidade vem de fora, e o padrão é a do mundo — nunca um número
	# escrito aqui. Uma bola que cai diferente do resto do mundo é o tipo de
	# coisa que ninguém nomeia e todo mundo sente como estranho.
	b.gravidade = gravidade_do_mundo if gravidade_do_mundo > 0.0 \
		else Locomocao3D.GRAVIDADE

	# Havendo alvo, a bola é arremessada NELE. Arco fixo na direção do olhar
	# passa por cima de um corpo no chão — medido: 2,49 m acima de um alvo a
	# 6 m. Sem alvo (arremesso no vazio), o arco livre é o certo.
	if alvo_pretendido != null and is_instance_valid(alvo_pretendido):
		b.velocidade = RegraDeArremesso.velocidade_para_acertar(
			origem, _pos_de(alvo_pretendido), b.gravidade)
	else:
		b.velocidade = RegraDeArremesso.velocidade_inicial(direcao)
	b.ball = qual_ball
	b.sorte = sorte_do_treinador
	b.alvo = alvo_pretendido
	pai.add_child(b)
	return b

## A posição de um nó, segura mesmo fora da árvore — a mesma armadilha do
## `Corpo3D.onde_caiu`: `global_position` fora da árvore devolve a origem, em
## silêncio, e a bola sairia voando pro meio do mundo.
static func _pos_de(no: Node3D) -> Vector3:
	return no.global_position if no.is_inside_tree() else no.position

func _ready() -> void:
	add_to_group("pokebola_v3")
	_montar_corpo()

## Esfera mínima. Arte é do Codex (§48) — isto é só pra dar pra ver a bola.
func _montar_corpo() -> void:
	var vis := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.16
	esfera.height = 0.32
	vis.mesh = esfera
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.22, 0.20)
	vis.material_override = mat
	add_child(vis)

func _physics_process(delta: float) -> void:
	if _resolvida:
		return
	_tempo += delta
	position = RegraDeArremesso.posicao_em(_origem, velocidade, _tempo, gravidade)

	if _acertou_o_alvo():
		_resolver()
		return

	# Rede de segurança dupla: tocou o chão, ou passou do tempo. Sem a segunda,
	# uma bola jogada pro céu viveria pra sempre num mundo sem teto.
	if _tocou_o_chao() or _tempo >= RegraDeArremesso.VIDA_MAXIMA:
		_falhar()

func _acertou_o_alvo() -> bool:
	if not is_instance_valid(alvo):
		return false
	var raio : float = 0.0
	if alvo.get("raio_de_alvo") != null:
		raio = float(alvo.get("raio_de_alvo"))
	return RegraDeArremesso.acertou(global_position, alvo.global_position, raio)

## O chão do mundo, não um plano em zero: a bola tem de pousar na encosta onde
## a encosta está.
func _tocou_o_chao() -> bool:
	return global_position.y <= Terreno3D.altura_em(
		global_position.x, global_position.z)

func _resolver() -> void:
	_resolvida = true
	var resultado : Dictionary = {}
	if alvo.has_method("tentar_capturar"):
		resultado = alvo.tentar_capturar(ball, sorte)
	else:
		resultado = {"pegou": false, "gastou": false,
			"motivo": "Não dá pra capturar isso."}
	resolveu.emit(resultado)
	queue_free()

func _falhar() -> void:
	_resolvida = true
	errou.emit()
	queue_free()

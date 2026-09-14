## Locomocao3D.gd — A matemática do movimento em 3D (§11).
##
## É a `Locomocao` da V2 com um eixo a mais, e **de propósito ela continua uma
## classe pura**: aceleração, atrito, histerese e velocidade-alvo são conta, e
## conta que mora fora do nó é conta que dá pra provar sem subir o jogo.
##
## ── O que veio inteiro da V2 ────────────────────────────────────────────────
##
## A regra de normalizar num lugar só (mata a diagonal mais rápida), atrito
## maior que aceleração (parar responde melhor que arrancar) e o respeito ao
## analógico parcial. Tudo isso foi testado em 2D e vale igual aqui.
##
## ── O que é novo, e por quê ─────────────────────────────────────────────────
##
## **Gravidade e inclinação.** Em 2D o chão era implícito; em 3D ele tem altura,
## e o §11 pede colisão, gravidade e inclinação. A decisão de design que isso
## exige: **até que ângulo ainda é chão?** Acima disso é parede, e o corpo
## escorrega em vez de subir.
class_name Locomocao3D
extends RefCounted

## Metros por segundo. A V2 pensava em pixels com tile de 128; aqui a unidade é
## o metro, e um treinador de ~1,7 m andando a 4,5 m/s é ritmo de Action RPG —
## mais rápido que o humano real, porque mundo grande com velocidade realista
## vira caminhada de ida e volta.
const VELOCIDADE_CAMINHADA : float = 4.5
const VELOCIDADE_CORRIDA   : float = 8.0

const ACELERACAO : float = 40.0   ## m/s²
const ATRITO     : float = 55.0   ## parar continua sendo mais rápido que arrancar

const LIMIAR_PARADO : float = 0.2   ## m/s

## §11: inclinação. Acima disto não é chão que se sobe — é parede.
## 46° é generoso: deixa subir colina íngreme sem transformar falésia em rampa.
const ANGULO_MAXIMO_DE_SUBIDA : float = deg_to_rad(46.0)

## Gravidade. Mais forte que a real (9,8) porque queda realista em jogo de ação
## parece flutuar — o corpo demora demais pra assentar depois de um degrau.
const GRAVIDADE : float = 22.0
const VELOCIDADE_TERMINAL : float = 55.0

# ──────────────────────────────────────────────────────────────────────────────
# Horizontal
# ──────────────────────────────────────────────────────────────────────────────

## A velocidade horizontal que a intenção pede.
##
## `intencao` é o vetor bruto no plano (x = direita, z = frente), **não
## normalizado**: normalizar aqui, e só aqui, mata a diagonal mais rápida sem
## matar o analógico pela metade. Mesma regra da V2.
##
## `base` é a direção "pra frente" da câmera, projetada no plano — é o que faz
## W andar pra onde o jogador está olhando, e não pro norte do mundo.
static func velocidade_alvo(intencao: Vector2, correndo: bool,
		base: Basis, fator_de_exaustao: float = 1.0) -> Vector3:
	if intencao == Vector2.ZERO:
		return Vector3.ZERO
	var i := intencao if intencao.length() <= 1.0 else intencao.normalized()

	# Frente e direita da câmera, achatadas no plano: sem isso, olhar pra cima
	# faria o personagem tentar andar pro céu.
	var frente := -base.z
	frente.y = 0.0
	frente = frente.normalized() if frente.length_squared() > 0.0 else Vector3.FORWARD
	var direita := base.x
	direita.y = 0.0
	direita = direita.normalized() if direita.length_squared() > 0.0 else Vector3.RIGHT

	var v : float = VELOCIDADE_CORRIDA if correndo else VELOCIDADE_CAMINHADA
	return (direita * i.x + frente * i.y) * v * maxf(0.0, fator_de_exaustao)

## A velocidade horizontal deste quadro. Preserva o Y de quem chamou — quem
## manda na vertical é a gravidade, não a intenção.
static func avancar(atual: Vector3, alvo: Vector3, delta: float) -> Vector3:
	var h_atual := Vector3(atual.x, 0.0, atual.z)
	var h_alvo  := Vector3(alvo.x, 0.0, alvo.z)
	var taxa : float = ACELERACAO if h_alvo.length() > h_atual.length() else ATRITO
	var h := h_atual.move_toward(h_alvo, taxa * delta)
	return Vector3(h.x, atual.y, h.z)

## Só a parte que anda. `velocity.y` de um corpo caindo não é "estar andando".
static func esta_parado(velocidade: Vector3) -> bool:
	return Vector2(velocidade.x, velocidade.z).length() < LIMIAR_PARADO

# ──────────────────────────────────────────────────────────────────────────────
# Vertical
# ──────────────────────────────────────────────────────────────────────────────

## A velocidade vertical depois de `delta` no ar. No chão, zera — mas com um
## resto negativo pequeno, que é o que mantém o corpo colado na ladeira em
## descida. Zerar de verdade faz o personagem "pular" degrau abaixo.
static func aplicar_gravidade(vy: float, no_chao: bool, delta: float) -> float:
	if no_chao:
		return -1.0
	return maxf(-VELOCIDADE_TERMINAL, vy - GRAVIDADE * delta)

## Esta superfície é chão que se sobe, ou parede? (§11)
static func e_chao(normal: Vector3) -> bool:
	return normal.angle_to(Vector3.UP) <= ANGULO_MAXIMO_DE_SUBIDA

# ──────────────────────────────────────────────────────────────────────────────
# Orientação
# ──────────────────────────────────────────────────────────────────────────────

## Pra onde o corpo deve OLHAR, dado como ele está se movendo.
##
## Em 3ª pessoa o personagem vira pra direção do movimento, não pra direção da
## câmera — é o que deixa andar de lado e pra trás parecer natural. A virada é
## gradual: virar instantâneo lê como boneco sendo girado, não como alguém
## mudando de direção.
static func girar_para(atual: float, velocidade: Vector3, delta: float,
		graus_por_segundo: float = 720.0) -> float:
	if esta_parado(velocidade):
		return atual
	var alvo := atan2(velocidade.x, velocidade.z)
	return rotate_toward(atual, alvo, deg_to_rad(graus_por_segundo) * delta)

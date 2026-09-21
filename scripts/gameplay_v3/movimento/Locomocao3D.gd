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

## Metros por segundo — **a régua do Gabriel, 21/09/2026**:
##
##   > *"velocidade de movimentação padrão do ser humano é 1,5 m/s e cerca de
##   > 3,5 m/s correndo"*
##
## Eram 4,5 e 8,0, e o comentário que estava aqui defendia isso com um
## argumento de gênero: *"mais rápido que o humano real, porque mundo grande com
## velocidade realista vira caminhada de ida e volta"*. O Gabriel decidiu o
## contrário, e os números dele são os reais.
##
## ── O que essa troca inverte, e foi medido antes de aplicar ─────────────────
##
## A 8,0 m/s o treinador era **mais rápido que todo Pokémon do jogo** — inclusive
## o Pidgeot (7,15 m/s). A 3,5 ele passa a ser **mais lento que todos**.
##
## Isso não é efeito colateral: é a fantasia do projeto voltando ao lugar.
## *"Quando a batalha começa, eu assumo o controle do meu Pokémon"* — com o
## treinador mais rápido que tudo, assumir o Pokémon não trazia vantagem de
## deslocamento nenhuma. Agora traz, e perseguir um selvagem a pé deixa de
## funcionar, que é o comportamento certo.
##
## ⚠️ A velocidade dos Pokémon **não** foi mexida junto, de propósito: a régua é
## sobre o **ser humano**, e escalar tudo junto teria apagado exatamente a
## inversão acima.
const VELOCIDADE_CAMINHADA : float = 1.5
const VELOCIDADE_CORRIDA   : float = 3.5

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
	# 🔴 O sinal do `i.y` era o TERCEIRO bug do relato do Gabriel, e o único que
	# sobrou depois de consertar o giro e a câmera. Estava `frente * i.y`.
	#
	# `intencao.y` segue a convenção de tela, a mesma da V2 e a mesma que
	# `Input.get_axis("move_up", "move_down")` produz: **−1 é pra frente**. Então
	# `frente * i.y` com o W apertado dava `frente * (−1)` — andar pra trás.
	#
	# Medido, com a câmera já independente: a Camera3D olhava pra
	# (−0,874 · 0 · +0,438) e o personagem andava pra (+0,894 · 0 · −0,448). O
	# oposto exato. É a frase dele, literal: *"aperto W e ele vem em direção da
	# câmera"*.
	return (direita * i.x + frente * -i.y) * v * maxf(0.0, fator_de_exaustao)

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
	# 🔴 Corrigido em 17/09. Estava `atan2(velocidade.x, velocidade.z)`, e isso
	# devolve o ângulo 180° errado: em Godot um nó com `rotation.y = 0` olha pra
	# **−Z**, então pra olhar na direção `d` o ângulo é `atan2(-d.x, -d.z)`.
	#
	# Medido antes de mexer, isolando a conta:
	#
	#     indo pra −Z (frente)  devolvia −3,14   correto  0,00
	#     indo pra +Z           devolvia  0,00   correto −3,14
	#     indo pra +X           devolvia  1,57   correto −1,57
	#
	# Sozinho este erro só deixaria o personagem de costas. O que o Gabriel
	# sentiu — *"aperto W e ele vem em direção da câmera"* — vinha da soma com o
	# segundo bug, a câmera que era filha do corpo e girava junto (ver
	# TrainerController3D._ready).
	var alvo := atan2(-velocidade.x, -velocidade.z)
	return rotate_toward(atual, alvo, deg_to_rad(graus_por_segundo) * delta)

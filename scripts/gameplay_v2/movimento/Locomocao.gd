## Locomocao.gd — A matemática do movimento contínuo (§4 da especificação).
##
## Pedido do Gabriel: *"WASD / analógico, caminhada, corrida, colisão real com
## cenário, navegação precisa, **sem sensação de movimentação por grid**"*.
##
## ── O que muda em relação ao jogo atual ──────────────────────────────────────
##
## Hoje o treinador anda com `try_move()`: escolhe um tile, trava a entrada e
## interpola por 0,18 s. Enquanto o passo corre, **o jogo não escuta o
## jogador** — daí o `BUFFER_MS` de 160 ms que existe lá pra disfarçar a perda
## de tecla. Buffer de entrada é remendo de controle que não obedece.
##
## Aqui não há passo. Há intenção, aceleração e velocidade. Soltar a tecla
## desacelera; virar no meio do caminho vira na hora; a diagonal é diagonal de
## verdade, e não dois passos em L.
##
## ── Por que classe pura ──────────────────────────────────────────────────────
##
## Aceleração, atrito e a conversão de velocidade em direção olhada são conta.
## Ficam aqui pra poder ser provadas sem subir o jogo. Quem tem corpo
## (`CorpoLivre`) chama e obedece.
class_name Locomocao
extends RefCounted

# ──────────────────────────────────────────────────────────────────────────────
# Os números
# ──────────────────────────────────────────────────────────────────────────────

## Em pixels por segundo, na régua de tile 128. Caminhar a 420 px/s é ~3,3
## tiles por segundo — mais rápido que os 5,5 tiles/s do `try_move` atual em
## corrida? Não: o `try_move` anda 128 px em 0,18 s, ou seja 711 px/s. A V2
## começa mais devagar de propósito, porque movimento contínuo com aceleração
## *parece* mais rápido que teletransporte de tile no mesmo número.
## Isto é chute informado e vai ser ajustado no playtest — declarado como
## PROXY, não como CONFIRMADO.
const VELOCIDADE_CAMINHADA : float = 420.0
const VELOCIDADE_CORRIDA   : float = 760.0

## Quanto tempo pra chegar na velocidade cheia, e pra parar. Baixo demais dá
## sensação de gelo; alto demais dá sensação de carrinho de supermercado.
const ACELERACAO : float = 3600.0   ## px/s²
const ATRITO     : float = 4800.0   ## px/s² — parar é mais rápido que arrancar

## Abaixo disto a entidade é considerada parada (pra stamina e pra animação).
const LIMIAR_PARADO : float = 12.0

# ──────────────────────────────────────────────────────────────────────────────
# As contas
# ──────────────────────────────────────────────────────────────────────────────

## A velocidade-alvo que a intenção do jogador pede.
##
## `intencao` é o vetor bruto do teclado/analógico, NÃO normalizado. Normalizar
## aqui, e só aqui, é o que impede o clássico "andar mais rápido na diagonal" —
## e ao mesmo tempo preserva o analógico: um manche empurrado até a metade
## continua valendo metade.
static func velocidade_alvo(intencao: Vector2, correndo: bool,
		fator_de_exaustao: float = 1.0) -> Vector2:
	if intencao == Vector2.ZERO:
		return Vector2.ZERO
	var i := intencao if intencao.length() <= 1.0 else intencao.normalized()
	var v := VELOCIDADE_CORRIDA if correndo else VELOCIDADE_CAMINHADA
	return i * v * maxf(0.0, fator_de_exaustao)

## A velocidade deste frame, indo de `atual` na direção de `alvo`.
##
## Usa aceleração quando está ganhando velocidade e atrito quando está
## perdendo. A diferença importa: sem ela, soltar a tecla e trocar de direção
## levariam o mesmo tempo, e o personagem responderia mal justamente na hora em
## que o jogador está fugindo de alguma coisa.
static func avancar(atual: Vector2, alvo: Vector2, delta: float) -> Vector2:
	var taxa : float = ACELERACAO if alvo.length() > atual.length() else ATRITO
	return atual.move_toward(alvo, taxa * delta)

## Está parado o bastante pra contar como parado?
static func esta_parado(velocidade: Vector2) -> bool:
	return velocidade.length() < LIMIAR_PARADO

# ──────────────────────────────────────────────────────────────────────────────
# Direção olhada
# ──────────────────────────────────────────────────────────────────────────────

## A direção do sprite (o enum `BaseEntity.Direction`: 0 baixo, 1 esquerda,
## 2 direita, 3 cima) a partir de uma velocidade contínua.
##
## O eixo dominante vence, com **histerese**: só troca de direção quando o
## outro eixo é claramente maior (fator 1,2). Sem isso, andar quase na diagonal
## faz o sprite piscar entre duas direções no meio do caminho, que é um dos
## bugs mais visíveis de jogo top-down com movimento livre.
static func direcao_olhada(velocidade: Vector2, anterior: int) -> int:
	if esta_parado(velocidade):
		return anterior
	var ax := absf(velocidade.x)
	var ay := absf(velocidade.y)
	var horizontal_antes : bool = anterior == 1 or anterior == 2
	if horizontal_antes:
		if ay > ax * 1.2:
			return 3 if velocidade.y < 0.0 else 0
		return 1 if velocidade.x < 0.0 else 2
	if ax > ay * 1.2:
		return 1 if velocidade.x < 0.0 else 2
	return 3 if velocidade.y < 0.0 else 0

# ──────────────────────────────────────────────────────────────────────────────
# Ponte com o mundo em tiles
# ──────────────────────────────────────────────────────────────────────────────

## O tile em que uma posição de mundo cai.
##
## Existe porque o mundo inteiro — warp, pesca, surf, mergulho, zona de spawn,
## quest — pergunta "em que tile você está". O movimento deixa de ser em grid,
## mas a **pergunta** continua válida: a V2 não reescreve nada disso, só passa
## a derivar o tile da posição em vez de o tile ser a posição.
static func tile_de(pos: Vector2, tamanho_do_tile: int = 128) -> Vector2i:
	return Vector2i(floori(pos.x / float(tamanho_do_tile)),
					floori(pos.y / float(tamanho_do_tile)))

## O centro de um tile, em pixels. O inverso de `tile_de`, pra nascer/chegar de
## um warp exatamente no meio do tile e não encostado numa parede.
static func centro_do_tile(tile: Vector2i, tamanho_do_tile: int = 128) -> Vector2:
	return Vector2(tile) * float(tamanho_do_tile) \
		+ Vector2(tamanho_do_tile / 2.0, tamanho_do_tile / 2.0)

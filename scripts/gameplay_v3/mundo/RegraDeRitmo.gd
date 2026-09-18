## RegraDeRitmo.gd — Quem pensa todo quadro, e quem pensa de vez em quando.
##
## ── O custo que esta fase ataca ─────────────────────────────────────────────
##
## Hoje **todo** selvagem vivo roda o pacote completo a 60 Hz: decidir (IA),
## girar, gravidade, `move_and_slide` e o tique de travessia — esteja ele a 3
## metros do jogador ou a 80, visível ou atrás de um morro. O custo é o mesmo
## pro bicho que está te mordendo e pro que está pastando longe, fora da tela.
##
## Isto é **LOD de lógica**: a mesma ideia que o Codex aplica em malha e
## textura, do lado de cá. E é a metade da performance que é minha — vegetação,
## modelo e sombra são dele (§42).
##
## ── A regra que importa mais que a economia ─────────────────────────────────
##
## **Quem está em jogo nunca desacelera.** Um bicho que te persegue, que está
## numa briga, que foi provocado, ou que o jogador controla, pensa todo quadro,
## **independente da distância**. Economizar aí é como nasce o pior bug possível
## deste projeto: o inimigo que "trava" no meio da perseguição, e o jogador
## lendo isso como o jogo desistindo dele. O `_despejar_distantes` do spawner já
## tem essa mesma regra por escrito, pela mesma razão.
##
## Então a economia só alcança quem está **ocioso e longe** — que, num mundo
## aberto, é a maioria esmagadora.
##
## Classe pura: nenhum autoload citado — a regra da Fase 11.
class_name RegraDeRitmo
extends RefCounted

## Dentro deste raio, todo mundo pensa todo quadro. É folgado de propósito:
## `RegraDeSpawn.RAIO_MAXIMO` é 28 m, então tudo que acabou de nascer está
## dentro, e a economia nunca pega quem está chegando.
const RAIO_TOTAL : float = 35.0

## Entre `RAIO_TOTAL` e este, pensa um quadro sim, um não.
const RAIO_MEDIO : float = 70.0

const DIVISOR_PERTO : int = 1
const DIVISOR_MEDIO : int = 2

## Além de `RAIO_MEDIO`: um quadro em cada quatro.
##
## O teto é 4 de propósito, e não 8 ou 16. Pular quadro obriga a compensar a
## distância andada (ver `fator_de_avanco`), e passo grande demais atravessa
## parede fina: a economia viraria bicho passando por dentro de pedra, longe da
## vista, onde ninguém descobre até ser tarde.
const DIVISOR_LONGE : int = 4

# ──────────────────────────────────────────────────────────────────────────────

## De quantos em quantos quadros este corpo pensa.
##
## `protegido` é a trava acima: quem está em jogo devolve 1 sempre, e a
## distância nem é consultada.
static func divisor(distancia: float, protegido: bool = false) -> int:
	if protegido:
		return DIVISOR_PERTO
	if distancia <= RAIO_TOTAL:
		return DIVISOR_PERTO
	if distancia <= RAIO_MEDIO:
		return DIVISOR_MEDIO
	return DIVISOR_LONGE

## Este corpo pensa NESTE quadro?
##
## `fase` espalha o trabalho: sem ela, todos os distantes pensariam no **mesmo**
## quadro, e em vez de um custo baixo e constante teríamos um pico a cada 4
## quadros — trocaríamos a média pelo engasgo, que é o que o jogador sente. O id
## da instância serve de fase porque é estável e diferente por corpo.
static func deve_pensar(quadro: int, distancia: float, protegido: bool = false,
		fase: int = 0) -> bool:
	var d : int = divisor(distancia, protegido)
	if d <= 1:
		return true
	return posmod(quadro + posmod(fase, d), d) == 0

## Quanto multiplicar o avanço de quem acabou de pensar depois de pular quadros.
##
## Sem isto, o mundo distante anda em **câmera lenta**: um corpo que pensa 1 em
## cada 4 quadros percorre 1/4 do caminho, e a economia vira bug visual assim
## que o jogador se aproxima e vê o bando arrastado. `move_and_slide` usa o
## passo de física do motor, não um delta nosso — então a compensação tem de ir
## na velocidade, não no delta.
static func fator_de_avanco(quadros_pulados: int) -> float:
	return float(maxi(0, quadros_pulados) + 1)

## Quanto tempo de mundo se passou pra quem pulou quadros. Serve pro que é
## contado em segundos (esfriamento, aviso de golpe, travessia), que não pode
## andar mais devagar só porque o corpo está longe.
static func delta_acumulado(delta: float, quadros_pulados: int) -> float:
	return delta * fator_de_avanco(quadros_pulados)

## Quantos corpos de fato pensam, dado um conjunto de distâncias. Existe pra o
## teste medir a economia como **número**, sem precisar de navegador: FPS só se
## mede renderizando, mas "quantos pensaram" é contável em headless.
static func quantos_pensam(quadro: int, distancias: Array,
		protegidos: Array = []) -> int:
	var n : int = 0
	for i in distancias.size():
		var prot : bool = i < protegidos.size() and bool(protegidos[i])
		if deve_pensar(quadro, float(distancias[i]), prot, i):
			n += 1
	return n

## A economia média num conjunto de distâncias, medida ao longo de um ciclo
## inteiro de quadros. 0,0 = não economiza nada; 0,5 = metade do trabalho.
static func economia_media(distancias: Array, protegidos: Array = []) -> float:
	var total : int = 0
	for quadro in DIVISOR_LONGE:
		total += quantos_pensam(quadro, distancias, protegidos)
	var cheio : int = distancias.size() * DIVISOR_LONGE
	if cheio <= 0:
		return 0.0
	return 1.0 - (float(total) / float(cheio))

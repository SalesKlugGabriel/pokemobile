## RegraDeArremesso.gd — A pokébola atravessando o espaço (Fase 21).
##
## ── O que é novo aqui, e o que NÃO é ────────────────────────────────────────
##
## A captura **já estava inteira e provada** em `RegrasDeCorpo` (V2): chance por
## espécie, peso do nível, multiplicador de Ball, penalidade de shiny e de
## lendário, teto de 95%, uma tentativa por corpo, janela de 10 a 15 s. A RFC da
## V3 lista `Corpo` entre os sistemas **adaptados**, com a frase que define este
## arquivo: *"a regra fica e a interface muda"*.
##
## Então aqui não se decide **se** pegou. Aqui se decide **se a bola chegou** —
## e isso é a parte que só existe em 3D, porque em 2D a captura era um clique
## num cadáver que já estava na tela.
##
## ── Por que a bola voa em arco, e não em linha reta ─────────────────────────
##
## Porque arremessar é o gesto, e o gesto tem de ser legível. Uma bola em linha
## reta é um tiro: acerta ou não acerta, e o jogador lê isso como mira. Um arco
## tem **tempo de voo visível**, e é o tempo de voo que cria a decisão da §28 —
## você joga a bola sabendo que o Alpha ainda está vindo pra cima de você.
##
## ⚠️ A gravidade daqui é a mesma de `Locomocao3D.GRAVIDADE`, recebida por
## parâmetro e nunca copiada: uma bola que cai com gravidade diferente do mundo
## é o tipo de coisa que ninguém nomeia e todo mundo sente como "estranho".
##
## Classe pura: nenhum autoload, nenhum nó — a regra da Fase 11.
class_name RegraDeArremesso
extends RefCounted

## Velocidade inicial do arremesso, em m/s.
##
## 🔴 Era 16, e com ela o braço alcançava **7,26 m** — enquanto o alcance
## declarado dizia 18. Dois números discordando sobre a mesma coisa: a mira
## aceitaria um alvo a 15 m e a bola cairia no meio do caminho, e o jogador
## leria isso como bug de mira. Pego pelo teste, não pela revisão.
##
## 21 m/s dá ~12,5 m de alcance plano — longe o bastante pra não obrigar a
## encostar no corpo, perto o bastante pra manter a §28 (*"decidir enquanto a
## briga continua"*) valendo.
const VELOCIDADE : float = 21.0

## O quanto o arremesso sobe. Puro arco: 0 seria um tiro reto, 1 seria uma
## cesta. 0,35 é o bastante pra ler como "jogou" sem virar lob lento.
const INCLINACAO : float = 0.35

## Raio de acerto da bola. Generoso de propósito: a mira é do mouse e o alvo se
## mexe. Exigir precisão de tiro aqui tornaria a captura um teste de pontaria, e
## a §28 diz que a tensão é a **escolha**, não a mira.
const RAIO_DE_ACERTO : float = 1.1

## Tempo máximo no ar antes de a bola desistir. Rede de segurança: sem isto,
## uma bola jogada pro céu vive pra sempre num mundo sem teto.
const VIDA_MAXIMA : float = 4.0

## Margem entre o que o braço alcança e o que a mira aceita. A bola tem de
## **chegar**, não empatar: aceitar exatamente o alcance balístico faria o tiro
## no limite cair em cima do alvo por um dedo, o que o jogador lê como erro.
const FOLGA_DO_ALCANCE : float = 0.88

## Piso do tempo de voo. Sem ele, um corpo encostado no jogador resolveria no
## mesmo quadro — e a §28 inteira mora no tempo entre decidir e saber.
const TEMPO_MINIMO : float = 0.22

## O quão longe o braço chega, em metros.
##
## ⚠️ **Derivado, não declarado.** Era uma constante independente, e ela
## discordava da balística em mais de 10 m. Uma constante separada precisa ser
## mantida em sincronia à mão com a velocidade, a inclinação e a gravidade — e
## sincronia à mão é como dois números sobre a mesma coisa passam a divergir.
## Agora não existe o que divergir: se alguém mudar a velocidade, o alcance
## acompanha sozinho.
static func alcance_maximo(gravidade: float = 0.0) -> float:
	var g : float = gravidade if gravidade > 0.0 else Locomocao3D.GRAVIDADE
	return alcance(velocidade_inicial(Vector3.FORWARD), g) * FOLGA_DO_ALCANCE

# ──────────────────────────────────────────────────────────────────────────────

## A velocidade inicial de um arremesso numa direção.
##
## A direção de entrada é a da mira (que pode apontar pro chão ou pro céu); ela
## é **achatada** e a subida vem de `INCLINACAO`. É o mesmo princípio de
## `base_do_movimento` da câmera: olhar pra baixo não pode fazer a bola ser
## cuspida no próprio pé.
static func velocidade_inicial(direcao: Vector3,
		velocidade: float = VELOCIDADE) -> Vector3:
	var plana := Vector3(direcao.x, 0.0, direcao.z)
	if plana.length_squared() < 0.000001:
		# Mira exatamente pra cima ou pra baixo: sem direção horizontal pra usar,
		# devolver zero seria a bola caindo na cabeça de quem jogou.
		plana = Vector3.FORWARD
	plana = plana.normalized()
	return (plana + Vector3.UP * INCLINACAO).normalized() * velocidade

## Onde a bola está depois de `t` segundos. Balística simples, sem arrasto:
## posição inicial + velocidade × t − ½ g t².
##
## Existe como função pura (e não só dentro do `_physics_process` do nó) porque
## é isto que deixa o alcance e o tempo de voo serem **medidos** em headless,
## onde não há física rodando.
static func posicao_em(origem: Vector3, velocidade: Vector3, t: float,
		gravidade: float) -> Vector3:
	return origem + velocidade * t - Vector3.UP * (0.5 * gravidade * t * t)

## O tempo de voo de um arremesso até um alvo, em segundos.
##
## Cresce com a distância, e é isso que faz a mecânica ler bem: um corpo
## encostado resolve quase na hora, um a 12 m dá tempo de o Alpha chegar em
## você. Um tempo fixo faria o arremesso longe parecer teleporte.
static func tempo_ate(origem: Vector3, alvo: Vector3) -> float:
	var d : float = Vector3(alvo.x - origem.x, 0.0, alvo.z - origem.z).length()
	return clampf(TEMPO_MINIMO + d / VELOCIDADE, TEMPO_MINIMO, VIDA_MAXIMA * 0.6)

## A velocidade inicial que faz a bola **acertar** este alvo.
##
## 🔴 Existe porque o arco fixo não acertava. Medido ao escrever o teste da Fase
## 21: uma bola arremessada na horizontal, com a inclinação padrão, passa a
## **2,49 m acima** de um corpo a 6 m e só desce lá pelos 15 m. O jogador miraria
## no corpo, a bola sairia por cima, e ele leria isso como mira quebrada.
##
## A conta é a balística invertida: dado o deslocamento e o tempo de voo,
## `v = (Δ + ½ g t² ↑) / t` é a única velocidade que põe a bola lá no instante
## `t`. Não é "mira assistida" — é o que significa **arremessar em alguém**, que
## é o gesto que a §28 descreve. Quem escolhe o alvo continua sendo o jogador.
static func velocidade_para_acertar(origem: Vector3, alvo: Vector3,
		gravidade: float) -> Vector3:
	var t : float = tempo_ate(origem, alvo)
	if t <= 0.0:
		return velocidade_inicial(alvo - origem)
	var delta : Vector3 = alvo - origem
	return (delta + Vector3.UP * (0.5 * gravidade * t * t)) / t

## Quanto tempo até voltar à altura de onde saiu. É o tempo de voo "de mão a
## chão plano", e serve pra dimensionar alcance sem simular.
static func tempo_de_voo(velocidade: Vector3, gravidade: float) -> float:
	if gravidade <= 0.0:
		return VIDA_MAXIMA
	return maxf(0.0, 2.0 * velocidade.y / gravidade)

## O alcance horizontal de um arremesso em terreno plano.
static func alcance(velocidade: Vector3, gravidade: float) -> float:
	var t := tempo_de_voo(velocidade, gravidade)
	return Vector3(velocidade.x, 0.0, velocidade.z).length() * t

# ──────────────────────────────────────────────────────────────────────────────

## A bola acertou este corpo?
##
## Distância de centro a centro contra `RAIO_DE_ACERTO` mais o raio do alvo —
## um Onix comprimido é um alvo maior que um Caterpie, e ignorar isso faria a
## bola atravessar o meio de um bicho enorme.
static func acertou(posicao_da_bola: Vector3, posicao_do_alvo: Vector3,
		raio_do_alvo: float = 0.0) -> bool:
	var limite : float = RAIO_DE_ACERTO + maxf(0.0, raio_do_alvo)
	return posicao_da_bola.distance_to(posicao_do_alvo) <= limite

## Dá pra tentar acertar este corpo daqui? Só distância — quem decide se o corpo
## aceita captura é `RegrasDeCorpo.pode_tentar`, e duplicar aquela decisão aqui
## criaria duas respostas pra mesma pergunta.
##
## Devolve `{"pode", "motivo"}`; o motivo é em português porque vai pra tela.
static func no_alcance(origem: Vector3, alvo: Vector3,
		gravidade: float = 0.0) -> Dictionary:
	var d : float = origem.distance_to(alvo)
	if d > alcance_maximo(gravidade):
		return {"pode": false,
			"motivo": "Longe demais — chegue mais perto pra arremessar."}
	return {"pode": true, "motivo": ""}

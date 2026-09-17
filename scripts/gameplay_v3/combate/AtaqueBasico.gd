## AtaqueBasico.gd — As regras do ataque básico em 1ª pessoa (Fase 9, §18/§22).
##
## Classe pura, como todas as regras da V3: cooldown, alcance, arco e o próprio
## golpe são **conta**, e conta que mora fora do nó é conta que dá pra provar
## sem subir o jogo. A parte que toca o mundo — achar quem está na frente — fica
## em `PokemonInstance3D.atacar()`, porque só ela precisa do espaço de física.
##
## ── A decisão de design que esta classe registra ────────────────────────────
##
## **O ataque básico é Normal, e não do tipo do atacante.**
##
## A alternativa era dar a ele o tipo primário de quem bate. Isso soa generoso e
## quebra o jogo de duas formas: o básico ganharia STAB de graça (1,25×) e
## passaria a ser super-efetivo contra metade do bestiário — tornando as 4
## skills, que são a decisão interessante do combate (§21), quase decorativas.
##
## Normal também é o que o cânone faz com Struggle/Tackle, então a escolha não
## surpreende quem conhece Pokémon.
##
## ── Sem RNG (§22) ──────────────────────────────────────────────────────────
##
## Não existe rolagem de precisão aqui. Se a geometria acertou, é acerto. É a
## mesma regra que a V2 já seguia, e é o que faz o combate parecer habilidade em
## vez de sorte. As duas conferências geométricas — `dentro_do_alcance` e
## `dentro_do_arco` — são o "acertou" inteiro.
class_name AtaqueBasico
extends RefCounted

## Quanto tempo entre dois básicos. Curto de propósito: o básico é o ritmo do
## combate, o que se aperta enquanto as skills esfriam. Longo demais deixa o
## jogador parado esperando, que é o pecado que a §12 da V2 já apontava.
const COOLDOWN : float = 0.45

## Poder do básico. Baixo em relação a qualquer skill de `moves.json` (as mais
## fracas têm 40) — ele existe pra manter pressão, não pra ganhar a luta.
const PODER : float = 25.0

## Metade do ângulo do arco à frente, em radianos. 50° de meio-arco dá 100° de
## abertura: perdoa mira imprecisa sem transformar o básico em ataque em área.
const MEIO_ARCO : float = deg_to_rad(50.0)

## Empurrão do básico, em metros. Pequeno: o básico não deve reposicionar o
## alvo, isso é papel das skills.
const EMPURRAO : float = 0.35

## O golpe, no MESMO formato de `moves.json` — é o que deixa `DanoV2.detalhar`
## e `RelatorioDeGolpe` tratarem o básico sem um caminho especial. Um golpe que
## precisa de código próprio é um golpe que vai divergir do resto.
static func golpe() -> Dictionary:
	return {
		"id": "basico",
		"name": "Ataque básico",
		"type": "Normal",
		"category": "physical",
		"power": PODER,
		"contact": true,
		"area_type": "single",
		# Instantâneo: sem janela de aviso ANTES. É o `RelatorioDeGolpe` que usa
		# isto pra a tela saber que a leitura toda acontece no impacto.
		"cast_time": 0.0,
		"cooldown": COOLDOWN,
	}

## O básico já esfriou? `agora` e `ultimo_uso` em segundos da mesma régua.
##
## `ultimo_uso < 0` significa "nunca usou" — e isso tem de liberar o primeiro
## golpe. Sem este caso, o Pokémon recém-assumido não ataca durante meio segundo
## e o jogador acha que o botão não funcionou.
static func pronto(agora: float, ultimo_uso: float, cooldown: float = COOLDOWN) -> bool:
	if ultimo_uso < 0.0:
		return true
	return (agora - ultimo_uso) >= cooldown

## Quanto falta esfriar, em segundos. Zero quando está pronto. Existe pra a HUD
## poder desenhar o giro do cooldown sem recalcular a regra (a tela nunca
## recalcula — AGENTS.md).
static func esfriando(agora: float, ultimo_uso: float, cooldown: float = COOLDOWN) -> float:
	if pronto(agora, ultimo_uso, cooldown):
		return 0.0
	return maxf(0.0, cooldown - (agora - ultimo_uso))

## O alvo está perto o bastante?
##
## `alcance` vem de `CombatProfile.alcance_basico(altura)` — um Onix alcança mais
## longe que um Rattata sem ninguém cadastrar isso. E o raio do alvo entra na
## conta: um bicho gigante é acertado antes porque o corpo dele começa antes.
static func dentro_do_alcance(distancia: float, alcance: float, raio_do_alvo: float = 0.0) -> bool:
	return distancia <= (alcance + maxf(0.0, raio_do_alvo))

## O alvo está dentro do arco à frente?
##
## Só o plano horizontal: incluir a altura faria o básico errar um Diglett aos
## pés e um Onix acima da cabeça, e nenhum dos dois é o que o jogador vê.
static func dentro_do_arco(olhar: Vector3, para_o_alvo: Vector3,
		meio_arco: float = MEIO_ARCO) -> bool:
	var a := Vector3(olhar.x, 0.0, olhar.z)
	var b := Vector3(para_o_alvo.x, 0.0, para_o_alvo.z)
	if a.length_squared() <= 0.0 or b.length_squared() <= 0.0:
		return false
	return a.normalized().angle_to(b.normalized()) <= meio_arco

## Acertou? A conferência geométrica inteira, num lugar só — é isto que garante
## que "acerto" quer dizer a mesma coisa no jogo e no teste.
static func acertou(olhar: Vector3, do_atacante: Vector3, do_alvo: Vector3,
		alcance: float, raio_do_alvo: float = 0.0,
		meio_arco: float = MEIO_ARCO) -> bool:
	var delta := do_alvo - do_atacante
	var plano := Vector3(delta.x, 0.0, delta.z)
	return dentro_do_alcance(plano.length(), alcance, raio_do_alvo) \
		and dentro_do_arco(olhar, plano, meio_arco)

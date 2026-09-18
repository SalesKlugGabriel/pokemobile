## RegraDeCombate.gd — Quando uma briga começa, quando acaba, e como (Fase 12).
##
## Classe pura. Quem executa — trocar o alvo do selvagem, desligar o spawner,
## mover a câmera — é o `Combate1v1`. Aqui só se decide, e por isso as regras
## de início e fim se provam sem subir o mundo.
##
## ── O que "1v1 no próprio terreno, sem arena" obriga ────────────────────────
##
## A `COMBAT_FIRST_PERSON.md` é explícita: **1v1, no terreno, sem arena**. Isso
## soa simples e cobra três coisas que uma arena resolveria de graça:
##
##   1. **Quem NÃO está na briga precisa ser mantido fora dela.** Sem parede, o
##      terceiro selvagem entraria andando. A regra abaixo é que ele não engaja
##      quem já está lutando — ele continua existindo e vivendo a vida dele.
##   2. **Nada impede o jogador de ir embora.** E isso é bom: fugir tem de ser
##      possível. Mas precisa ter uma linha, senão a briga nunca "termina" —
##      fica pendurada pra sempre a dois quarteirões de distância.
##   3. **O fim tem de ser um EVENTO**, não um estado que alguém consulta. Quem
##      ganhou, quem perdeu, ou se alguém fugiu: um resultado só, declarado uma
##      vez.
class_name RegraDeCombate
extends RefCounted

# ── Como uma briga termina ────────────────────────────────────────────────────

const VITORIA  := "vitoria"    ## o selvagem caiu
const DERROTA  := "derrota"    ## o Pokémon do jogador caiu
const FUGA     := "fuga"       ## alguém se afastou além do limite
const EM_CURSO := "em_curso"   ## ainda não acabou

## A que distância um selvagem hostil dá início à briga.
##
## Menor que o raio de aggro de um agressivo (5 m) **de propósito**: perceber e
## engajar são coisas diferentes. O bicho vê, vem, e só então a briga começa —
## o que dá ao jogador o instante de "ele me viu" antes do "estamos lutando".
const DISTANCIA_DE_ENGAJAMENTO : float = 3.5

## Além disto, a briga acaba em fuga.
##
## Folgado em relação ao engajamento porque fugir tem de ser uma decisão, não um
## acidente: dois passos pra trás no meio da troca de golpes não podem encerrar
## a luta.
const DISTANCIA_DE_FUGA : float = 22.0

## Quantos segundos sem ninguém tomar dano até a briga se desfazer sozinha.
##
## É a válvula contra a briga pendurada: dois lutadores presos em lados opostos
## de uma pedra ficariam "em combate" pra sempre, e o jogador nunca recuperaria
## o treinador.
const SEGUNDOS_SEM_NADA_ATE_DESFAZER : float = 20.0

# ── Começar ───────────────────────────────────────────────────────────────────

## Esta briga pode começar?
##
## `ja_em_combate` é a trava do 1v1: enquanto uma briga corre, nenhuma outra
## começa. Sem ela, três selvagens próximos abririam três combates e o jogador
## estaria em todos ao mesmo tempo.
static func pode_comecar(distancia: float, selvagem_hostil: bool,
		selvagem_vivo: bool, defensor_vivo: bool, ja_em_combate: bool) -> bool:
	if ja_em_combate:
		return false
	if not selvagem_vivo or not defensor_vivo:
		return false
	if not selvagem_hostil:
		return false
	return distancia <= DISTANCIA_DE_ENGAJAMENTO

# ── Terminar ──────────────────────────────────────────────────────────────────

## Como esta briga está agora.
##
## ── A ordem importa, e é a mesma lição da IA do selvagem ───────────────────
##
## **Derrota é conferida antes de vitória.** Se os dois caírem no mesmo quadro —
## acontece, um golpe de área pode matar quem o usou via recuo — o jogador não
## pode receber "vitória" com o próprio Pokémon desmaiado. Perder empatado é
## perder.
##
## E as duas vêm antes da fuga: quem caiu não fugiu.
static func resultado(defensor_vivo: bool, selvagem_vivo: bool,
		distancia: float, segundos_sem_dano: float) -> String:
	if not defensor_vivo:
		return DERROTA
	if not selvagem_vivo:
		return VITORIA
	if distancia > DISTANCIA_DE_FUGA:
		return FUGA
	if segundos_sem_dano >= SEGUNDOS_SEM_NADA_ATE_DESFAZER:
		return FUGA
	return EM_CURSO

static func acabou(r: String) -> bool:
	return r != EM_CURSO

## A frase do resultado, em português, pra tela e pra linha do tempo do feedback.
##
## Frase, não sigla: quando o Gabriel reportar "acabou e eu não entendi por quê",
## é isto que o recado dele vai carregar.
static func frase(r: String) -> String:
	match r:
		VITORIA: return "venceu a batalha"
		DERROTA: return "seu Pokémon foi derrotado"
		FUGA:    return "a batalha se desfez — ninguém estava mais ao alcance"
		_:       return "batalha em curso"

# ── Quem pode entrar, e quem não pode ────────────────────────────────────────

## Este terceiro pode engajar quem já está em combate?
##
## **Não.** É o que sustenta o 1v1 sem arena: o selvagem que passa por perto
## continua vivo, andando e reagindo ao mundo — ele só não entra numa briga que
## já tem dois donos.
##
## ⚠️ Isto NÃO é o mesmo que "ele fica parado". Um bicho congelado a dois metros
## da luta é tão estranho quanto um que entra nela. Ele continua com a IA dele;
## o que muda é que os dois combatentes deixam de ser alvo válido.
static func pode_engajar(alvo_em_combate: bool) -> bool:
	return not alvo_em_combate

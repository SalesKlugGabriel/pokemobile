## Contorno.gd — Sair de onde entalou (§61).
##
## Pedido do Gabriel: *"IA precisa ter prevenção de deadlock/separation."*
##
## ── O problema, concreto ─────────────────────────────────────────────────────
##
## Quem persegue em linha reta encosta na primeira parede que fica entre ele e o
## alvo e **para ali**. `move_and_slide()` desliza em quina, mas empurrando de
## frente contra uma face reta o vetor de deslize é zero — e o Pokémon fica
## vibrando contra o muro pra sempre.
##
## Foi assim que o primeiro teste da cena pegou o Pokémon parado a 600 px do
## alvo: o código estava "certo", e mesmo assim ele nunca chegava.
##
## ── A solução, e por que não é pathfinding ───────────────────────────────────
##
## Um A* de verdade precisaria de malha de navegação em 36 mapas gerados por
## código. Isto aqui resolve o caso real (uma parede entre dois pontos) com uma
## regra: **se eu quero andar e não estou andando, ando de lado por um tempo.**
##
## Escolher SEMPRE o mesmo lado importa. Alternar faz o corpo oscilar preso na
## quina, que é pior que ficar parado — parece bug, e é.
##
## Não resolve labirinto. Resolve muro, que é o que existe. Quando o mundo pedir
## mais, aí vira navegação de verdade — e isso estará declarado, não escondido.
class_name Contorno
extends RefCounted

## Abaixo desta fração da velocidade desejada, considera-se "não está andando".
const FRACAO_DE_TRAVADO : float = 0.35

## Quanto tempo preso antes de tentar contornar. Curto o bastante pra não ser
## visível como hesitação, longo o bastante pra não disparar em toda esbarrada.
const PACIENCIA : float = 0.25

## Quanto tempo andando de lado antes de tentar seguir reto de novo.
const DURACAO : float = 0.6

var _travado_ha : float = 0.0
var _contornando : float = 0.0
var _lado : float = 1.0
var _ultima_pos : Vector2 = Vector2.ZERO
var _tem_referencia : bool = false

## A velocidade a usar de verdade neste quadro.
##
## `desejada` é pra onde se quer ir; `pos` é onde o corpo está AGORA (depois do
## movimento do quadro anterior). O deslocamento real entre duas chamadas é o
## que denuncia a trava — não dá pra confiar em `velocity`, porque
## `move_and_slide()` a reescreve e um corpo preso pode continuar "querendo".
func ajustar(desejada: Vector2, pos: Vector2, delta: float) -> Vector2:
	if not _tem_referencia:
		_ultima_pos = pos
		_tem_referencia = true
		return desejada

	var andou : float = pos.distance_to(_ultima_pos)
	_ultima_pos = pos

	if desejada.length() < 1.0:
		_travado_ha = 0.0
		_contornando = 0.0
		return desejada

	# Quanto ele DEVERIA ter andado neste quadro, se nada atrapalhasse.
	var esperado : float = desejada.length() * delta

	if _contornando > 0.0:
		_contornando -= delta
		return desejada.rotated(_lado * PI * 0.5)

	if andou < esperado * FRACAO_DE_TRAVADO:
		_travado_ha += delta
		if _travado_ha >= PACIENCIA:
			_travado_ha = 0.0
			_contornando = DURACAO
			# O lado é escolhido UMA vez por trava e mantido até ela acabar.
			# Sortear a cada quadro faria o corpo tremer na quina.
			_lado = 1.0 if (int(pos.x) + int(pos.y)) % 2 == 0 else -1.0
			return desejada.rotated(_lado * PI * 0.5)
	else:
		_travado_ha = 0.0

	return desejada

## Está contornando agora? A HUD e o recado de feedback usam pra explicar um
## Pokémon que parece estar "indo pro lado errado" — sem isso, o jogador vê
## comportamento estranho e não tem como saber que é proposital.
func esta_contornando() -> bool:
	return _contornando > 0.0

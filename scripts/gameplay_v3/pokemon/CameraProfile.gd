## CameraProfile.gd — Como se vê o mundo pelos olhos de cada Pokémon (§19).
##
## *"Não usar exatamente a mesma posição de câmera para todos. Prioridade:
## jogabilidade > anatomia perfeita."*
##
## ── A regra que resolve o conflito ──────────────────────────────────────────
##
## Um Diglett tem 0,2 m. A câmera anatomicamente correta dele fica a 20 cm do
## chão, e o jogador não vê nada além de grama. Um Onix tem 8,8 m e a câmera
## anatômica dele não enxerga o inimigo aos pés.
##
## Por isso a altura dos olhos é **limitada nas duas pontas**. O piso existe pra
## o pequeno conseguir jogar; o teto, pra o gigante conseguir mirar. A §19 diz
## com todas as letras que jogabilidade ganha de anatomia — isto é essa frase
## virando número.
class_name CameraProfile
extends RefCounted

## Fração da altura em que os olhos ficam, antes dos limites.
const FRACAO_DOS_OLHOS : float = 0.85

## Os limites que tornam qualquer espécie jogável.
const ALTURA_MINIMA : float = 0.9   ## abaixo disto não se enxerga o mundo
const ALTURA_MAXIMA : float = 3.2   ## acima disto não se enxerga o chão

## FOV maior em bicho pequeno: perto do chão, campo estreito é claustrofóbico.
const FOV_PEQUENO : float = 82.0
const FOV_GRANDE  : float = 68.0

static func altura_dos_olhos(altura_jogavel: float) -> float:
	return clampf(altura_jogavel * FRACAO_DOS_OLHOS, ALTURA_MINIMA, ALTURA_MAXIMA)

static func fov(altura_jogavel: float) -> float:
	var t : float = clampf(altura_jogavel / 3.0, 0.0, 1.0)
	return lerpf(FOV_PEQUENO, FOV_GRANDE, t)

## O perfil completo, pro `PokemonCombatController` da Fase 8 e pra o Codex
## ajustar depois sem mexer em entidade nenhuma.
static func perfil(altura_jogavel: float) -> Dictionary:
	return {
		"altura_dos_olhos": altura_dos_olhos(altura_jogavel),
		"fov": fov(altura_jogavel),
		"pitch_min": deg_to_rad(-80.0),
		"pitch_max": deg_to_rad(80.0),
		"sensibilidade": 0.0035,
		# A câmera adianta um pouco em bicho grande, senão o próprio corpo
		# ocupa a tela inteira em primeira pessoa.
		"offset_frente": clampf(altura_jogavel * 0.18, 0.0, 0.8),
		"near": 0.08,
	}

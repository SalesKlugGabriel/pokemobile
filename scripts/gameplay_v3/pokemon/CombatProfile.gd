## CombatProfile.gd — O corpo de combate de um Pokémon (§14, §22).
##
## Alcance, hitbox e hurtbox saem DAQUI, nunca do modelo 3D.
##
## ── Por que separar do modelo ───────────────────────────────────────────────
##
## Um modelo bonito com colisor errado é pior que um primitivo com colisor
## certo: o primeiro parece funcionar. Se a hurtbox viesse da malha, trocar o
## modelo de um Pokémon mudaria em silêncio o quanto ele é fácil de acertar —
## balanceamento mudando por causa de arte.
##
## §22 exige **hitbox de ataque e hurtbox separadas**. Elas já eram separadas na
## V2 (`HitBox`/`HurtBox`); aqui viram 3D e passam a sair do perfil.
class_name CombatProfile
extends RefCounted

## Proporções derivadas da altura jogável. Um número por espécie seria uma
## tabela de 151 linhas pra manter em sincronia — e a altura já descreve o bicho.
const RAIO_POR_ALTURA : float = 0.28
const ALCANCE_CORPO_A_CORPO : float = 1.6   ## metros ALÉM do próprio raio

## O corpo: raio e altura do colisor, em metros.
static func corpo(altura_jogavel: float) -> Dictionary:
	return {
		"raio": maxf(0.18, altura_jogavel * RAIO_POR_ALTURA),
		"altura": maxf(0.4, altura_jogavel),
	}

## A hurtbox — o que PODE ser acertado. Um pouco maior que o colisor físico, de
## propósito: acertar precisa ser mais generoso que esbarrar, senão o jogador
## erra golpes que visualmente acertaram, e isso lê como jogo quebrado.
const FOLGA_DA_HURTBOX : float = 1.12

static func hurtbox(altura_jogavel: float) -> Dictionary:
	var c := corpo(altura_jogavel)
	return {
		"raio": float(c["raio"]) * FOLGA_DA_HURTBOX,
		"altura": float(c["altura"]) * FOLGA_DA_HURTBOX,
	}

## Alcance do ataque básico: o raio do próprio corpo mais o braço. Um Onix
## alcança mais longe que um Rattata sem ninguém cadastrar isso.
static func alcance_basico(altura_jogavel: float) -> float:
	return float(corpo(altura_jogavel)["raio"]) + ALCANCE_CORPO_A_CORPO

## Altura de onde o golpe SAI. Meio corpo: golpe saindo do pé atravessa o chão,
## saindo do topo passa por cima de quem é baixo.
static func origem_do_golpe(altura_jogavel: float) -> float:
	return altura_jogavel * 0.55

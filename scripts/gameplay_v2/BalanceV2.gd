## BalanceV2.gd — A régua da Gameplay V2.
##
## Lê `CombatBalance` (que é da V1 e **não pode ser tocada** — decisão D-001) e
## sobrescreve só o que a V2 muda. Nada aqui vaza pro jogo atual.
##
## ── 🔴 A mudança grande, e por que ela existe ────────────────────────────────
##
## A simulação do passo 7 ia recalibrar o Alpha. Ela encontrou outra coisa.
##
## Com a régua atual, **uma luta equilibrada entre dois Pokémon de nível 40 dura
## 4,6 segundos.** Medido, não estimado:
##
##     dano×   duração   leitura
##     1,00      4,6 s   rápido demais    ← a régua de hoje
##     0,50      9,1 s   rápido demais
##     0,25     18,1 s   ← faixa de Action RPG
##     0,15     28,9 s   ← faixa de Action RPG
##
## Em 4,6 segundos **não dá pra posicionar, ler ataque nem esquivar** — que é a
## §9 inteira do pedido do Gabriel. Quem tiver qualquer margem ganha antes de o
## outro ter chance de jogar. Foi isso que fez a tabela do Alpha não ter
## nenhuma linha boa: o Alpha nunca foi o problema.
##
## ── Por que mexer na VIDA e não no dano ──────────────────────────────────────
##
## Matematicamente dá no mesmo: 4× mais vida = 4× menos dano, mesma duração.
## Na tela, não:
##
##   - dano ÷ 4 → os golpes passam a tirar 3 de 237. Números pequenos demais
##     pra o jogador sentir diferença entre um golpe bom e um ruim.
##   - vida × 4 → os golpes continuam tirando 13, e a barra é que fica grande.
##     Combina com as referências que o Gabriel deu (Tibia, PXG, Eterspire —
##     MMOs de barra longa), e mantém a granularidade do dano.
##
## ⚠️ **Isto é decisão de design, e é dele.** Está aqui porque o protótipo
## existe pra responder "lutar é divertido?" e uma luta de 4,6 s não consegue
## responder. Reverter é trocar um número deste arquivo.
class_name BalanceV2
extends RefCounted

## Multiplicador de vida da V2 sobre o que `StatsDePokemon` calcula.
## 4,0 leva a luta de 4,6 s pra ~18 s. Medido em `simular_equilibrio_v2.gd`.
const VIDA_MULT : float = 4.0

## §30, nas palavras do Gabriel: *"Alpha: +35% em todos os seis stats
## clássicos"*. A régua da V1 tem `ALPHA_HP_MULT = 3.0`, medida na Fase 2 —
## antes desta especificação existir. **A especificação ganha.**
const ALPHA_MULT : float = 1.35

## §30: "aproximadamente 1.35× tamanho".
const ALPHA_ESCALA_VISUAL : float = 1.35

static func vida(base: int) -> int:
	return maxi(1, int(round(float(base) * VIDA_MULT)))

## O multiplicador de um stat de Alpha. Um só pros seis, como a §30 pede —
## e não uma tabela por stat, que é como um "+35% em tudo" vira, sem ninguém
## perceber, seis números diferentes.
static func alpha(valor: int) -> int:
	return maxi(1, int(round(float(valor) * ALPHA_MULT)))

## CombatBalance.gd — TODOS os números de balanceamento do combate, num lugar só.
##
## Existe por causa do item 37 do pedido do Gabriel: "não espalhar números pelo
## código". Antes desta reengenharia (11/09/2026) a régua do combate estava
## partida em 6 arquivos — a chance de crítico morava no DamageCalculator, a
## redução de recarga por velocidade estava COPIADA em dois arquivos
## (`speed_stat / 500.0` no FollowerPokemon e no WildPokemon), os
## multiplicadores de Alpha no WildPokemon, os do chefe no ChefeLendario. Mudar
## o jogo exigia caçar número em arquivo.
##
## Regra deste arquivo: se um número decide o EQUILÍBRIO da briga, ele mora
## aqui. Se decide a APARÊNCIA (cor, tamanho de barra, duração de piscada), não.
##
## É `class_name` + `RefCounted` de propósito, não autoload: assim os testes
## headless conseguem ler a régua sem subir o jogo inteiro.
class_name CombatBalance
extends RefCounted

# ──────────────────────────────────────────────────────────────────────────────
# Dano
# ──────────────────────────────────────────────────────────────────────────────

## Ajuste fino global do dano. 1.0 = a fórmula pura da série. Mexer AQUI é o
## jeito certo de deixar o jogo todo mais duro ou mais mole sem tocar em nada.
##
## 0.55 é calibrado, não chutado: a fórmula pura da série é feita pra combate
## POR TURNO, onde 4 golpes por luta é bom ritmo. Aqui a luta é em tempo real e
## o Gabriel pediu 6-12 golpes num ataque básico (item 13). Medido com este
## valor e o HP_SCALE abaixo, contra alvo de mesmo nível:
##   power  35 (fraco)        13 golpes
##   power  50 (básico)       11 golpes
##   power  65 (médio)         8 golpes
##   power  85 (forte)         6 golpes
##   power 150 (ultimate)      4 golpes
const BASE_DAMAGE_MULTIPLIER : float = 0.55

## O "50" da fórmula clássica. Quanto MAIOR, menos dano sai.
const DAMAGE_DIVISOR : float = 50.0

## Os "+2" da fórmula clássica (o de dentro e o de fora do parêntese).
const LEVEL_TERM_BONUS : float = 2.0
const DAMAGE_FLAT_BONUS : float = 2.0

## Nível entra como `2 × nível / LEVEL_SCALE`. É ele que faz um Lv.50 bater
## MUITO mais forte que um Lv.10 com o mesmo golpe — o que não acontecia antes
## (medido na auditoria: 40 níveis davam só +58% de dano).
const LEVEL_SCALE : float = 5.0

## Piso de dano: um golpe que acerta nunca dá 0 (a não ser por imunidade de
## tipo, que é tratada separado e devolve 0 de verdade).
const MIN_DAMAGE : int = 1

## 🔴 Piso proporcional (11/09, achado pela própria simulação de
## balanceamento). O item 10 do pedido diz: "nunca permitir defesa infinita =
## dano zero". Com a razão ataque/defesa pura isso acontecia na prática — um
## golpe fraco, resistido, contra um tanque dava **1,2 de dano e 96 golpes pra
## matar** (Quick Attack num Onix: quase 3 minutos batendo). Não é dano zero
## no papel, mas é dano zero na mão do jogador.
##
## Então todo golpe que ACERTA tira pelo menos esta fração da vida máxima do
## alvo. 2% = no pior caso possível são ~50 golpes: continua gritando "você
## está usando o golpe errado" (com o golpe certo o mesmo Onix cai em ~8), mas
## deixa de ser uma parede intransponível.
##
## Imunidade de tipo NÃO passa por aqui: x0 continua sendo 0 de verdade.
const DANO_MINIMO_FRACAO_HP : float = 0.02

## Teto de segurança: nenhum golpe pode tirar mais que esta fração da vida
## MÁXIMA do alvo de uma vez. É a rede contra o hit-kill — mesmo com crítico,
## super-efetividade e 20 níveis de vantagem empilhados, sobra vida pra reagir.
## 0.9 = no pior caso possível o alvo fica com 10% e ainda pode fugir ou curar.
## Não substitui o balanceamento: é o para-quedas pra quando a conta escapar.
const TETO_DE_DANO_POR_GOLPE : float = 0.9

## Abaixo desta fração de vida, o teto acima deixa de valer — senão um alvo
## quase morto ficaria imortal (0.9 de 5 de vida = 4, sempre sobrando 1).
const VIDA_MINIMA_PRO_TETO : float = 0.15

# ──────────────────────────────────────────────────────────────────────────────
# Multiplicadores
# ──────────────────────────────────────────────────────────────────────────────

const STAB_MULTIPLIER : float = 1.25   ## golpe do mesmo tipo do Pokémon

const CRIT_CHANCE     : float = 0.05   ## 5% (item 16 do pedido)
const CRIT_MULTIPLIER : float = 1.5

const DAMAGE_VARIANCE_MIN : float = 0.90
const DAMAGE_VARIANCE_MAX : float = 1.10

## Efetividade de tipo. A TABELA de quem bate em quem continua no
## DamageCalculator (é dado de Pokémon, não régua de balanceamento) — aqui
## ficam só os VALORES que ela produz, porque são eles que se ajustam.
const TYPE_SUPER_EFFECTIVE : float = 2.0
const TYPE_RESISTANCE      : float = 0.5
const TYPE_IMMUNE          : float = 0.0

## Queimadura corta o golpe FÍSICO pela metade (regra clássica).
const BURN_PHYSICAL_MULTIPLIER : float = 0.5

# ──────────────────────────────────────────────────────────────────────────────
# Stats e HP
# ──────────────────────────────────────────────────────────────────────────────

## Quanto o HP cresce além da fórmula Gen 3 pura. É o outro lado do
## BASE_DAMAGE_MULTIPLIER: num jogo de tempo real a barra de vida precisa dar
## tempo de reagir, posicionar e fugir — coisas que não existem no turno.
## O pedido do Gabriel sugeria `HP = BASE_HP × (1 + nível × 0.10)` como ponto
## de partida (item 7); 2.5 sobre a Gen 3 chega quase no mesmo lugar E mantém
## IV/EV valendo, que a fórmula dele descartaria.
const HP_SCALE : float = 2.5

## IV: o "talento natural", 0-31, sorteado uma vez e nunca muda.
const IV_MIN : int = 0
const IV_MAX : int = 31

## Nature: +10% numa stat, -10% em outra (item 8 do pedido).
const NATURE_BOOST : float = 1.10
const NATURE_CUT   : float = 0.90

## Nível máximo do jogo.
const NIVEL_MAXIMO : int = 100

# ──────────────────────────────────────────────────────────────────────────────
# Recarga (cooldown)
# ──────────────────────────────────────────────────────────────────────────────

## Quanto a velocidade encurta a recarga. `speed / SPEED_COOLDOWN_DIVISOR`,
## limitado pelo teto abaixo — sem o teto, um Pokémon muito rápido atacaria
## quase sem intervalo e o combate viraria botão travado.
const SPEED_COOLDOWN_DIVISOR : float = 500.0
const MAX_COOLDOWN_REDUCTION : float = 0.40   ## no máximo -40% pela velocidade
const MIN_COOLDOWN_SEC       : float = 0.35   ## piso absoluto de recarga

# ──────────────────────────────────────────────────────────────────────────────
# Alcance e área
# ──────────────────────────────────────────────────────────────────────────────

const TILE_PX : float = 128.0   ## um tile em pixels (migração tile128, 03/09)

## Alcance padrão de um golpe que não declara `range` nos dados: corpo a corpo.
const ALCANCE_PADRAO_TILES : float = 1.5

## Teto de alvos de um golpe de área que não declara `max_targets`.
## Protege o balanceamento (item 39) e a performance (item 40) ao mesmo tempo.
const MAX_ALVOS_PADRAO : int = 6

# ──────────────────────────────────────────────────────────────────────────────
# Alpha (o selvagem raro e forte)
# ──────────────────────────────────────────────────────────────────────────────

## 🔴 Recalibrados em 11/09. Eram HP ×5 / ATK ×3 / DEF ×2.5 em cima de uma
## fórmula que já causava hit-kill: medido na auditoria, um Rhyhorn Alpha Lv30
## dava 929 de dano num alvo de 98 de vida. Um Alpha tem que ser uma PAREDE que
## dura, não um golpe que apaga a tela — então o HP subiu e o ataque desceu.
const ALPHA_HP_MULT   : float = 6.0
const ALPHA_ATK_MULT  : float = 1.35
const ALPHA_DEF_MULT  : float = 1.40
const ALPHA_SPD_MULT  : float = 1.20

# ──────────────────────────────────────────────────────────────────────────────
# IA, aggro, bando e coleira (itens 24-27 do pedido)
# ──────────────────────────────────────────────────────────────────────────────

const AGGRO_RADIUS_TILES : float = 5.0    ## a que distância um agressivo percebe
const PACK_RADIUS_TILES  : float = 4.0    ## até onde o grito de um chama os outros
const LEASH_RADIUS_TILES : float = 12.0   ## até onde persegue antes de desistir
const PATROL_LEASH_TILES : float = 6.0    ## até onde passeia quando está em paz
const MAX_PACK_SIZE      : int   = 5      ## quantos no máximo respondem ao chamado

## Quantos "saltos" o aggro pode dar de um bicho pro outro. 1 = quem ouviu o
## grito NÃO grita de novo. É o que impede a corrente que acorda o mapa inteiro
## (item 27 do pedido).
const AGGRO_CHAIN_MAX_HOPS : int = 1

## Abaixo desta fração de vida, quem tem personalidade FLEEING foge.
const FRACAO_HP_PRA_FUGIR : float = 0.25

## Ao voltar pra casa pela coleira, o selvagem recupera esta fração da vida
## máxima por segundo (item 26: "pode recuperar HP").
const REGEN_NA_COLEIRA_POR_SEG : float = 0.08

# ──────────────────────────────────────────────────────────────────────────────
# Ritmo da lógica de combate (item 41)
# ──────────────────────────────────────────────────────────────────────────────

## A IA não precisa pensar 60 vezes por segundo. Ela pensa a cada tantos
## segundos; a ANIMAÇÃO e o movimento continuam a 60 FPS.
const COMBAT_TICK_SEC : float = 0.2

## Status (queimadura/veneno) causa dano a cada tantos segundos.
const STATUS_TICK_SEC : float = 3.0

# ──────────────────────────────────────────────────────────────────────────────
# Alvo de TTK — a régua que a simulação da Fase 12 cobra (item 13)
# ──────────────────────────────────────────────────────────────────────────────

## Contra alvo de nível parecido, quantos golpes deveriam ser necessários.
const TTK_BASICO_MIN : int = 6
const TTK_BASICO_MAX : int = 12
const TTK_FORTE_MIN  : int = 3
const TTK_FORTE_MAX  : int = 7

## Nenhum golpe sozinho pode matar um alvo de mesmo nível com vida cheia —
## nem a ultimate. É o critério de sucesso nº 1 do pedido.
const ULTIMATE_FRACAO_MAXIMA : float = 0.85

# ──────────────────────────────────────────────────────────────────────────────
# Contas curtas que a régua faz por quem a usa
# ──────────────────────────────────────────────────────────────────────────────

## A recarga real de um golpe, já com velocidade e item aplicados.
##
## Existe como função (e não como fórmula copiada) porque a conta
## `speed_stat / 500.0` estava ESCRITA DUAS VEZES — uma no FollowerPokemon,
## outra no WildPokemon — e mudar uma sem a outra deixaria jogador e selvagem
## com réguas diferentes sem ninguém perceber.
static func recarga(base_seg: float, velocidade: int, alivio_de_item: float = 0.0) -> float:
	var por_velocidade : float = clampf(
		float(velocidade) / SPEED_COOLDOWN_DIVISOR, 0.0, MAX_COOLDOWN_REDUCTION)
	var por_item : float = clampf(alivio_de_item, 0.0, 0.6)
	return maxf(MIN_COOLDOWN_SEC, base_seg * (1.0 - por_velocidade) * (1.0 - por_item))

## Quantos pixels são N tiles.
static func tiles(n: float) -> float:
	return n * TILE_PX

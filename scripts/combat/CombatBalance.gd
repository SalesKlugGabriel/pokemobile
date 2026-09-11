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

## 🔴 REMOVIDO em 11/09 (Fase 2). Eu tinha criado um piso proporcional
## (`DANO_MINIMO_FRACAO_HP = 0.02`) pra resolver "golpe fraco num tanque dá 1,2
## de dano". Medido com calma, ele não resolvia nada e distorcia outra coisa:
##
##   Onix, Quick Attack:  com piso 58 golpes · sem piso 93 golpes
##   Rhyhorn, idem:       com piso 61 golpes · sem piso 89 golpes
##
## 58 golpes continua injogável — o piso só mascarava. E como ele era 2% da
## vida MÁXIMA, um golpe fraco passava a bater proporcionalmente mais forte
## justamente em quem tem muita vida, que é o contrário do que faz sentido.
##
## A regra agora é a que o Gabriel pediu: imunidade = 0 de verdade, qualquer
## outro golpe = no mínimo 1. Golpe errado contra tanque DEVE doer de usar —
## o jogador tem 4 slots pra escolher, e com o golpe certo o mesmo Onix cai em
## 3 golpes.

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

## 🔴 Recalibrados DUAS vezes, e a segunda foi medida contra três modelos.
##
## Fase 1: eram HP ×5 / ATK ×3 / DEF ×2.5 sobre a fórmula velha (um Rhyhorn
## Alpha dava 929 de dano num alvo de 98 de vida). Virou HP ×6 / ATK ×1.35.
##
## Fase 2: o Gabriel pediu pra conferir se HP ×6 não estava criando luta longa
## demais. Estava. Medido contra um Charizard Lv30, com o kit real de cada
## Alpha:
##
##   modelo            vida    luta do jogador   dano devolvido
##   A  HP×6 ATK×1.35  1098    69 golpes 265s    8% da vida por golpe
##   B  HP×3 ATK×1.20   549    30 golpes 115s    8% da vida por golpe
##   C  HP×3 ATK×1.60   549    31 golpes 119s   10% da vida por golpe
##
## O modelo A é exatamente o "saco de HP" que ele não queria: quatro minutos e
## meio batendo em algo que mal machuca. O B corrige a duração e não melhora a
## ameaça. O **C** é o adotado — metade da luta do A, com 20-30% mais dano.
## Um Alpha tem que ser um SUSTO, não uma maratona.
const ALPHA_HP_MULT   : float = 3.0
const ALPHA_ATK_MULT  : float = 1.60
const ALPHA_DEF_MULT  : float = 1.25
const ALPHA_SPD_MULT  : float = 1.20

# ──────────────────────────────────────────────────────────────────────────────
# IA, aggro, bando e coleira (itens 24-27 do pedido)
# ──────────────────────────────────────────────────────────────────────────────

const AGGRO_RADIUS_TILES : float = 5.0    ## a que distância um agressivo percebe
const PACK_RADIUS_TILES  : float = 4.0    ## até onde o grito de um chama os outros
const LEASH_RADIUS_TILES : float = 12.0   ## até onde persegue antes de desistir
const PATROL_LEASH_TILES : float = 6.0    ## até onde passeia quando está em paz
const MAX_PACK_SIZE      : int   = 5      ## quantos no máximo respondem ao chamado

## 🔴 Fase 2, medido: cinco Beedrill Lv.25 derrubam um Wartortle Lv.25 em
## 5,1 segundos se atacarem todos no mesmo instante. Cinco atacantes dão cinco
## vezes o dano — isso é aritmética, não desequilíbrio —, mas chegar todos
## juntos no mesmo quadro tira a janela de reação e faz parecer injusto.
##
## Quem responde ao grito entra com um atraso sorteado nesta faixa. O bando
## passa a chegar em ONDA, não em bloco: dá pra ver o primeiro, recuar, usar
## área. Custa zero (é só o relógio de ataque que já existe começando cheio).
const ATRASO_DO_BANDO_MIN : float = 0.4
const ATRASO_DO_BANDO_MAX : float = 1.8

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

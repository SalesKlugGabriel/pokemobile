## RegrasDeCorpo.gd — Derrotar, então capturar (§28, §29, §30, §31).
##
## Pedido do Gabriel (§28):
##
##   *"Pokémon selvagem precisa ser derrotado para 0 HP antes de tentar captura.
##   Corpo permanece aproximadamente 10–15 segundos. Durante esse período pode
##   coletar loot e pode tentar captura. **Apenas uma tentativa de captura por
##   corpo.** Falhou: Pokémon perdido. Capture chance considera espécie, nível
##   derrotado, Ball, Luck, categoria/raridade. **Chance fica escondida do
##   jogador.**"*
##
## ── O que muda em relação ao jogo atual ──────────────────────────────────────
##
## Hoje se joga a ball no selvagem vivo e o HP baixo só dá bônus. Aqui a captura
## vira **consequência de ganhar a luta**, e uma tentativa só. É uma mudança de
## gênero, não de número: no atual você insiste; aqui você aposta.
##
## ── Por que a chance fica escondida ──────────────────────────────────────────
##
## Mostrar "23%" transforma a decisão em planilha — o jogador espera a Ball
## certa e a tensão some. Escondida, a Ball melhor *parece* melhor sem virar
## cálculo. Por isso `chance()` existe pra o servidor e **não** entra em nenhum
## contrato de UI.
class_name RegrasDeCorpo
extends RefCounted

## §28: "aproximadamente 10–15 segundos". O sorteio é por corpo, e é de
## propósito: janela fixa vira contagem decorada, e o jogador passa a jogar
## contra o cronômetro em vez de contra a luta.
const DURACAO_MIN : float = 10.0
const DURACAO_MAX : float = 15.0

## Quando resta menos que isto, a tela avisa. O aviso é o que impede a perda
## por distração pura — perder o corpo tem que doer por escolha, não por susto.
const AVISO_EM : float = 4.0

## Multiplicadores de Ball. Números de partida, marcados PROXY: não há gabarito
## pra bater, então saem do balanceamento e não de fonte externa.
const BALLS : Dictionary = {
	"pokeball":   1.0,
	"greatball":  1.5,
	"ultraball":  2.0,
	"masterball": 255.0,   ## a única que ignora tudo (§ não declarado, mas é o pacto do gênero)
}

## §31: shiny é mais raro E mais difícil de capturar.
const PENALIDADE_SHINY : float = 0.55

## Teto. Nem a sorte máxima com Ultra Ball dá certeza — exceto Master Ball.
const CHANCE_MAXIMA : float = 0.95
const CHANCE_MINIMA : float = 0.01

# ──────────────────────────────────────────────────────────────────────────────
# Quanto tempo o corpo fica
# ──────────────────────────────────────────────────────────────────────────────

static func duracao(rng_valor: float) -> float:
	return DURACAO_MIN + clampf(rng_valor, 0.0, 1.0) * (DURACAO_MAX - DURACAO_MIN)

# ──────────────────────────────────────────────────────────────────────────────
# Pode tentar?
# ──────────────────────────────────────────────────────────────────────────────

## Devolve {"pode", "motivo"}. Motivo em português porque é ele que aparece na
## tela — "não deu" sem dizer por quê é o pior retorno possível.
static func pode_tentar(corpo: Dictionary) -> Dictionary:
	if bool(corpo.get("capturavel", true)) == false:
		# §30: Alpha é miniboss e NÃO pode ser capturado, por mais que o jogador
		# queira. É o que mantém o Alpha sendo um obstáculo e não um troféu.
		return {"pode": false, "motivo": "Alphas não podem ser capturados."}
	if bool(corpo.get("tentativa_usada", false)):
		return {"pode": false, "motivo": "Você já tentou capturar este Pokémon."}
	if float(corpo.get("restante", 0.0)) <= 0.0:
		return {"pode": false, "motivo": "O Pokémon já desapareceu."}
	return {"pode": true, "motivo": ""}

# ──────────────────────────────────────────────────────────────────────────────
# A chance (escondida do jogador)
# ──────────────────────────────────────────────────────────────────────────────

## `catch_rate` é o da espécie (3 a 255 — quanto maior, mais fácil).
## `nivel` é o nível em que ele foi derrotado: nível alto é mais difícil.
## `sorte` é o atributo Luck do treinador, 0 em diante.
##
## ⚠️ Nunca exponha este número na tela (§28). Ele existe pro servidor decidir
## e pro teste conferir.
static func chance(catch_rate: int, nivel: int, ball: String,
		sorte: int = 0, shiny: bool = false, lendario: bool = false) -> float:
	if ball == "masterball":
		return 1.0

	# Base: a taxa da espécie, normalizada. 255 (Caterpie) → 1,0; 3 (lendário) → 0,012.
	var base : float = clampf(float(maxi(1, catch_rate)) / 255.0, 0.0, 1.0)

	# Nível derrotado. Cai devagar e nunca zera: um Lv.100 continua capturável,
	# só custa caro. Zerar aqui mataria a caça a Pokémon de área perigosa, que é
	# justamente a recompensa de ir lá.
	var peso_do_nivel : float = 1.0 - (float(clampi(nivel, 1, 100)) / 100.0) * 0.55

	var mult_ball : float = float(BALLS.get(ball, 1.0))

	# §31 e §29: shiny e lendário são mais difíceis, cada um pelo seu motivo.
	var raridade : float = 1.0
	if shiny:
		raridade *= PENALIDADE_SHINY
	if lendario:
		# §29: "a menor chance de captura do jogo todo". Aplicado por cima do
		# catch_rate já baixíssimo (3), então o produto é pequeno de verdade.
		raridade *= 0.25

	# Sorte ajuda pouco e com retorno decrescente — se ajudasse muito, viraria a
	# única especialização que importa pra quem gosta de capturar.
	var mult_sorte : float = 1.0 + (float(maxi(0, sorte)) / 100.0) * 0.3

	var c : float = base * peso_do_nivel * mult_ball * raridade * mult_sorte
	return clampf(c, CHANCE_MINIMA, CHANCE_MAXIMA)

## A tentativa. `sorteio` é um número 0→1 de quem chamou (o RNG do jogo) —
## injetado, e não sorteado aqui dentro, pra o teste poder forçar os dois
## resultados sem depender de sorte.
##
## Devolve {"pegou", "chance", "motivo"}.
static func tentar(corpo: Dictionary, ball: String, sorteio: float,
		sorte: int = 0) -> Dictionary:
	var pode := pode_tentar(corpo)
	if not bool(pode["pode"]):
		return {"pegou": false, "chance": 0.0, "motivo": str(pode["motivo"])}

	var c := chance(
		int(corpo.get("catch_rate", 45)), int(corpo.get("nivel", 5)), ball,
		sorte, bool(corpo.get("shiny", false)), bool(corpo.get("lendario", false)))

	var pegou : bool = sorteio < c
	return {
		"pegou": pegou, "chance": c,
		# §28: falhou, perdeu. O texto conta o que aconteceu sem revelar a conta.
		"motivo": "" if pegou else "A Pokébola falhou e %s se foi." % str(corpo.get("nome", "o Pokémon")),
	}

# ──────────────────────────────────────────────────────────────────────────────
# O que o corpo larga
# ──────────────────────────────────────────────────────────────────────────────

## §35: loot fica no chão pelo mesmo tempo do corpo, e não existe "pegar tudo" —
## cada item é arrastado pra Bag. Aqui só decido **o que** cai; a tela de
## arrastar é do Codex.
##
## §30: o drop exclusivo de Alpha não é modificado por Luck. Se fosse, a
## especialização em sorte viraria obrigatória pra quem quer Held — e o Gabriel
## disse o contrário com todas as letras.
static func loot(nivel: int, alpha: bool, sorte: int, sorteios: Array) -> Array:
	var out : Array = []
	var i : int = 0

	# 🔴 O teto vai DEPOIS da sorte, não antes. Escrito ao contrário na primeira
	# versão, `sorte = 999` levava a chance a 2,9 — ou seja, drop garantido, o
	# que apaga a diferença entre um item comum e um raro.
	var chance_comum : float = clampf(
		(0.35 + float(nivel) / 300.0) * (1.0 + float(maxi(0, sorte)) / 100.0 * 0.5),
		0.0, 0.9)
	if i < sorteios.size() and float(sorteios[i]) < chance_comum:
		out.append({"item": "pocao", "qtd": 1})
	i += 1

	if alpha:
		# Sem `sorte` na conta, de propósito (§30).
		if i < sorteios.size() and float(sorteios[i]) < 0.08:
			out.append({"item": "held_bronze", "qtd": 1})
		i += 1
		if i < sorteios.size() and float(sorteios[i]) < 0.03:
			# §51: o item que remove um Held. Mais raro que o próprio Held.
			out.append({"item": "solvente_de_held", "qtd": 1})
	return out

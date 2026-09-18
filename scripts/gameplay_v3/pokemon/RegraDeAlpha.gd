## RegraDeAlpha.gd — O selvagem raro que é um obstáculo, não um troféu.
##
## ── O que esta fase encontrou, e é pior que o da Fase 17 ────────────────────
##
## 🔴 **O Alpha nunca existiu no jogo.** Não "estava incompleto": nunca nasceu
## nenhum. `WildPokemon.is_alpha` é um `@export` e **nada no repositório inteiro
## o liga** — nem código, nem cena, nem teste. A régua de stats, a trava de
## captura, o drop exclusivo, a escala visual: tudo escrito, testado em unidade,
## e inalcançável a partir do jogo.
##
## 🔴 **E `is_alpha_eligible` não é lido por ninguém.** As 151 espécies têm a
## chave preenchida à mão — 92 elegíveis, 59 não — e nenhuma linha de código
## jamais a consultou. É curadoria que nunca curou: sem ela, o primeiro Alpha a
## nascer poderia ser um Caterpie, que é exatamente o que a lista existe pra
## impedir.
##
## Mesma família do kit vazio da Fase 17, e pela mesma razão: os testes de
## unidade sempre construíram o Alpha à mão, então a suíte nunca perguntou
## **quem** constrói um no jogo.
##
## ── O que esta fase NÃO decide ─────────────────────────────────────────────
## Nada de balanceamento. A régua é a §30 nas palavras do Gabriel — *"+35% em
## todos os seis stats clássicos"* — e ela já mora em `BalanceV2`, que também já
## resolveu o conflito com a tabela medida da V1 (`CombatBalance`, HP×3/ATK×1,6)
## declarando que **a especificação ganha**. Esta classe delega e não repete
## nenhum número: dois lugares com o mesmo multiplicador é como eles passam a
## discordar.
##
## Classe pura: nenhum autoload citado, nem indiretamente — a regra da Fase 11.
class_name RegraDeAlpha
extends RefCounted

## A categoria de encontro de um Alpha, na língua do `KitDeCombate` — que já
## tem a faixa dele (5 a 6 golpes) desde a Fase 3.
const CATEGORIA := "alpha"

## ── A régua, fixada pelo Gabriel em 18/09 ──────────────────────────────────
##
## *"taxa de aparecimento de um elite: 2%; a taxa de aparecimento de um alpha é
## de 0,5% e aumenta 0,1% a cada elite derrotado nas últimas 3 hrs"*
##
## Isso **desfez** o desenho que eu tinha entregue horas antes, e o desfez pra
## melhor. Eu tinha feito Alpha um subconjunto do elite porque a chance de elite
## era 35% e um miniboss em 35% dos encontros seria rotina. Com o elite em 2%, a
## premissa cai: os dois passam a ser **sorteios independentes**, e é bom que
## sejam — o bônus por elites derrotados faz a chance de Alpha **crescer**, e
## uma chance filha nunca poderia passar da mãe.
const CHANCE_BASE : float = 0.005

## Quanto a chance sobe por elite derrotado dentro da janela.
const BONUS_POR_ELITE : float = 0.001

## O tamanho da janela: 3 horas de relógio.
const JANELA_SEGUNDOS : float = 3.0 * 60.0 * 60.0

## O teto da chance. **CONFIRMADO pelo Gabriel em 18/09** — nasceu como proposta
## minha e ele respondeu *"mantenha como você propôs"*.
##
## Por que um teto tem de existir: sem ele, "sobe 0,1% por elite" é ilimitado.
## 200 elites em 3 horas levariam o Alpha a 20,5%, e a raridade que ele fixou em
## 0,5% deixaria de existir justamente pra quem mais joga — a regra se desfaria
## sozinha no uso.
##
## 5% é 10× a base, e exige 45 elites derrotados em 3 horas pra ser atingido —
## o que, a 2% de chance de elite por encontro, é bastante jogo.
const CHANCE_MAXIMA : float = 0.05

# ──────────────────────────────────────────────────────────────────────────────
# Quem pode ser
# ──────────────────────────────────────────────────────────────────────────────

## §30: nem toda espécie vira Alpha. A lista é curadoria à mão em
## `species.json`, e **falha fechada**: espécie sem a chave não é elegível.
##
## Fechar por omissão importa aqui. Se o padrão fosse `true`, uma espécie nova
## entraria no jogo podendo virar miniboss sem ninguém ter decidido isso — e o
## sintoma seria um Caterpie de 1,35× dando susto numa rota inicial.
static func elegivel(especie: Dictionary) -> bool:
	return bool(especie.get("is_alpha_eligible", false))

# ──────────────────────────────────────────────────────────────────────────────
# Quão provável é
# ──────────────────────────────────────────────────────────────────────────────

## Quantos elites foram derrotados dentro da janela de 3 horas.
##
## `derrotas` são instantes em segundos (o mesmo relógio de `agora`). Filtrar
## aqui, e não em quem guarda a lista, é o que garante que a janela signifique a
## mesma coisa em todo lugar que perguntar.
static func elites_na_janela(derrotas: Array, agora: float) -> int:
	var n : int = 0
	for quando in derrotas:
		var t := float(quando)
		# O futuro não conta: relógio que anda pra trás (fuso, save antigo) não
		# pode virar bônus eterno.
		if t <= agora and (agora - t) < JANELA_SEGUNDOS:
			n += 1
	return n

## A chance de Alpha agora, já com o bônus, o teto e o perigo da zona.
##
## `perigo` é o 0→1 de `PerigoDaZona.perigo(zona)`, o **mesmo** fator que escala
## o elite. Os dois têm de escalar pela mesma régua, senão um Alpha nasceria em
## Pallet Town — onde a chance de elite é exatamente zero.
##
## O teto é aplicado ANTES do perigo: 5% é o teto da raridade, não do produto.
static func chance(derrotas: Array = [], agora: float = 0.0,
		perigo: float = 1.0) -> float:
	var bonus : float = BONUS_POR_ELITE * float(elites_na_janela(derrotas, agora))
	return minf(CHANCE_BASE + bonus, CHANCE_MAXIMA) * clampf(perigo, 0.0, 1.0)

## Este encontro é Alpha?
##
## Duas perguntas, e as duas têm de passar:
##   1. a **espécie** é elegível (curadoria, e ela ganha do sorteio);
##   2. o sorteio passa na chance de agora.
##
## ⚠️ Repare no que NÃO está aqui: `elite`. Até 18/09 estava, e a régua nova do
## Gabriel tirou — ver o cabeçalho. Elite e Alpha são dois sorteios
## independentes; podem coincidir, e coincidir não tem significado próprio.
static func sortear(especie: Dictionary, sorteio: float,
		derrotas: Array = [], agora: float = 0.0, perigo: float = 1.0) -> bool:
	if not elegivel(especie):
		return false
	return sorteio < chance(derrotas, agora, perigo)

# ──────────────────────────────────────────────────────────────────────────────
# O que muda quando é
# ──────────────────────────────────────────────────────────────────────────────

## Os seis stats com o multiplicador da §30.
##
## **Um multiplicador só pros seis**, como a especificação pede — e não uma
## tabela por stat, que é como um "+35% em tudo" vira seis números diferentes
## sem ninguém perceber. Quem faz a conta é `BalanceV2.alpha`.
static func stats(conjunto: Dictionary) -> Dictionary:
	var fora : Dictionary = {}
	for chave in conjunto:
		fora[chave] = BalanceV2.alpha(int(conjunto[chave]))
	return fora

## §30: "aproximadamente 1.35× tamanho". O número é do `BalanceV2`; aqui só
## passa adiante, pra apresentação ter uma porta e não um literal.
static func escala_visual() -> float:
	return BalanceV2.ALPHA_ESCALA_VISUAL

## §30: Alpha **não pode ser capturado**, por mais que o jogador queira — é o
## que o mantém sendo um obstáculo e não um troféu. A frase vem de
## `RegrasDeCorpo`, que já é a dona dela.
static func pode_capturar(alpha: bool) -> Dictionary:
	return RegrasDeCorpo.pode_tentar({"capturavel": not alpha, "restante": 1.0})

## O que o corpo larga. Delega — inclusive a regra de que o drop exclusivo de
## Alpha **não** é modificado por Luck (§30).
static func loot(nivel: int, alpha: bool, sorte: int, sorteios: Array) -> Array:
	return RegrasDeCorpo.loot(nivel, alpha, sorte, sorteios)

## Tudo que muda, num dicionário só — pra entidade e apresentação pedirem uma
## vez em vez de montarem o Alpha cada uma do seu jeito.
static func perfil(alpha: bool) -> Dictionary:
	return {
		"alpha": alpha,
		"categoria": CATEGORIA if alpha else RegraDeMovePool.CATEGORIA_PADRAO,
		"escala": escala_visual() if alpha else 1.0,
		"capturavel": not alpha,
	}

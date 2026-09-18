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

## ⚠️ **PROXY — palpite declarado, não medido.** (regra 7 do `CLAUDE.md`)
##
## Quantos dos encontros ELITE viram Alpha. A Fase 11 já sorteia "elite" com
## `PerigoDaZona.chance_de_elite()`, que vai até **35%** numa zona perigosa — e
## 35% de encontros com um miniboss incapturável não é raridade, é rotina.
##
## Não existe fonte pra este número: nem `zones.json`, nem a V2 (onde o Alpha
## nunca nasceu), nem medição. Então ele está declarado aqui como palpite, num
## lugar só, e **a pergunta vai pro Gabriel**. Com 0,20 e a curadoria de
## espécie, uma zona no perigo máximo entrega um Alpha a cada ~14 encontros.
const CHANCE_ENTRE_ELITES : float = 0.20

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

## Este encontro é Alpha?
##
## Três perguntas, e todas têm de passar:
##   1. o encontro já é **elite** (quem sorteia isso é a Fase 11, não esta);
##   2. a **espécie** é elegível;
##   3. o sorteio raro passa.
##
## Alpha é subconjunto de elite de propósito: são dois conceitos que se
## pareciam e não são o mesmo. Elite é "mais forte e mais alto de nível" e pode
## acontecer com qualquer bicho da tabela; Alpha é um miniboss com regra própria
## de captura e de drop.
static func sortear(especie: Dictionary, elite: bool, sorteio: float) -> bool:
	if not elite:
		return false
	if not elegivel(especie):
		return false
	return sorteio < CHANCE_ENTRE_ELITES

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

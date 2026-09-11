## Sinergia.gd — Golpe que fica melhor por causa do que já aconteceu.
##
## Item P7 da Fase 3. O pedido foi explícito sobre o escopo: **preparar a
## arquitetura, não implementar dezenas de sinergias agora**. Então isto é o
## mecanismo, com pouquíssimo conteúdo em cima dele — e o conteúdo que existe
## está em DADO (`moves.json`), nunca em `if nome_do_golpe == ...`.
##
## A ideia: um golpe pode declarar que ganha bônus quando o alvo (ou o próprio
## atacante, ou o campo) está numa certa condição.
##
##     "sinergia": { "alvo_com": "burn", "bonus": 1.3 }
##
## lê-se: *se o alvo estiver queimando, este golpe causa 30% a mais*.
##
## Isso cria a decisão que o combate em tempo real precisa ter: a ordem em que
## você aperta os botões passa a importar. Golpe A aplica a condição, golpe B
## colhe. Sem isso, quatro botões de dano são quatro botões iguais.
##
## ── Por que não hardcode ───────────────────────────────────────────────────
## Amarrar "Fire Punch fica forte em quem está molhado" dentro do código
## significa que toda sinergia nova é código novo, e que ninguém consegue ler a
## lista de sinergias sem abrir um arquivo .gd. Em dado, a lista é auditável e
## um golpe novo já nasce podendo participar.
##
## Classe pura: a conta precisa ser testável headless.
class_name Sinergia
extends RefCounted

## As condições que uma sinergia pode exigir. São só CHAVES — quem preenche o
## contexto é o atacante, no momento do golpe.
##
##   alvo_com        condição no alvo ("burn", "poison", "paralysis", "sleep",
##                   "freeze", "confuse", "molhado", "lento")
##   eu_com          a mesma coisa, mas em mim (ex: golpe que fica melhor
##                   quando estou envenenado)
##   campo           condição do ambiente ("chuva", "noite") — reaproveita os
##                   dois sistemas que já existem (ClimaDinamico, CicloDoDia)
##   alvo_abaixo_de  fração de vida do alvo (0.3 = "abaixo de 30%")
##   eu_abaixo_de    idem, pra mim
const CHAVES : Array[String] = ["alvo_com", "eu_com", "campo",
	"alvo_abaixo_de", "eu_abaixo_de"]

## Bônus máximo que uma sinergia pode dar, por segurança. Um dado mal escrito
## (`"bonus": 30` em vez de `3.0`) viraria um golpe de 3000% sem isso.
const BONUS_MAXIMO : float = 2.5

## O multiplicador que este golpe ganha AGORA.
##
## `contexto` é montado por quem ataca:
##
##     {
##       "alvo_status": "burn",
##       "meu_status": "none",
##       "campo": ["chuva"],
##       "alvo_fracao_vida": 0.4,
##       "minha_fracao_vida": 1.0,
##     }
##
## Golpe sem `sinergia` devolve 1.0 sem tocar em nada — é o caso de 192 dos
## 192 golpes hoje, e precisa custar quase zero.
static func multiplicador(golpe: Dictionary, contexto: Dictionary) -> float:
	var regra = golpe.get("sinergia")
	if regra == null or not (regra is Dictionary) or (regra as Dictionary).is_empty():
		return 1.0
	if not _condicao_bate(regra, contexto):
		return 1.0
	return clampf(float(regra.get("bonus", 1.0)), 0.0, BONUS_MAXIMO)

## Todas as condições declaradas precisam bater (é E, não OU). Uma regra que
## exige duas coisas é mais rara e mais interessante que uma que aceita
## qualquer uma das duas.
static func _condicao_bate(regra: Dictionary, contexto: Dictionary) -> bool:
	if regra.has("alvo_com"):
		if not _tem_condicao(str(regra["alvo_com"]), str(contexto.get("alvo_status", "none")),
				contexto.get("alvo_marcas", [])):
			return false
	if regra.has("eu_com"):
		if not _tem_condicao(str(regra["eu_com"]), str(contexto.get("meu_status", "none")),
				contexto.get("minhas_marcas", [])):
			return false
	if regra.has("campo"):
		if not (str(regra["campo"]) in contexto.get("campo", [])):
			return false
	if regra.has("alvo_abaixo_de"):
		if float(contexto.get("alvo_fracao_vida", 1.0)) > float(regra["alvo_abaixo_de"]):
			return false
	if regra.has("eu_abaixo_de"):
		if float(contexto.get("minha_fracao_vida", 1.0)) > float(regra["eu_abaixo_de"]):
			return false
	return true

## Uma condição pode vir do status persistente ("burn") ou de uma MARCA
## temporária ("molhado", "lento") que um golpe deixou. As duas valem, e
## procurar nas duas é o que permite sinergia sem inventar um sistema de
## status paralelo.
static func _tem_condicao(exigida: String, status: String, marcas: Array) -> bool:
	return exigida == status or (exigida in marcas)

# ──────────────────────────────────────────────────────────────────────────────
# Diagnóstico
# ──────────────────────────────────────────────────────────────────────────────

## Todas as sinergias declaradas nos dados, pra relatório e teste. Devolve
## [{id, sinergia}] — vazio significa "o mecanismo existe e ninguém usou
## ainda", que é um estado legítimo e não um erro.
static func declaradas(dados_dos_golpes: Dictionary) -> Array:
	var saida : Array = []
	for mid in dados_dos_golpes:
		var g : Dictionary = dados_dos_golpes[mid]
		var regra = g.get("sinergia")
		if regra != null and regra is Dictionary and not (regra as Dictionary).is_empty():
			saida.append({"id": mid, "sinergia": regra})
	return saida

## Uma regra de sinergia está bem escrita? Usado pelo teste que impede dado
## quebrado de entrar em silêncio.
static func regra_valida(regra: Dictionary) -> bool:
	if regra.is_empty():
		return false
	var tem_condicao := false
	for chave in regra:
		if str(chave) == "bonus":
			continue
		if not (str(chave) in CHAVES):
			return false
		tem_condicao = true
	if not tem_condicao:
		return false
	var b : float = float(regra.get("bonus", 0.0))
	return b > 0.0 and b <= BONUS_MAXIMO

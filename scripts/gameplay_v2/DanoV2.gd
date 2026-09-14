## DanoV2.gd — O dano da gameplay V2: sempre o mesmo número.
##
## §13 do pedido do Gabriel (13/09): *"Não existe crit. Não existe variance de
## dano. Mesmas condições devem gerar exatamente o mesmo dano."*
## §14: STAB de **1,25 no tipo primário e 1,15 no secundário**.
##
## ── Por que isto EMBRULHA o DamageCalculator em vez de editá-lo ──────────────
##
## O Codex pegou uma contradição no meu plano (revisão de 13/09): eu prometia
## "desfazer a V2 é apagar duas pastas" **e** "vou editar `DamageCalculator`".
## As duas não cabem juntas — editar a fórmula compartilhada muda o jogo que
## está no ar, e aí o rollback deixa de ser grátis.
##
## Resolvido invertendo a direção: `DamageCalculator` fica **intocado**, com
## crítico e variação, servindo a V1. A V2 chama `detalhar()`, pega os
## componentes da conta e **remonta o total sem os dois fatores aleatórios**.
##
## A conta da V1 é:
##     base × tipo × STAB × crítico × variação × habilidade × status × item ×
##     externo × sinergia
##
## A da V2 é a mesma linha sem `crítico` e sem `variação`, e com o STAB da §14.
## Nenhum número é recopiado: todos saem do relatório que a V1 já devolve.
##
## ── O que esta classe copia de propósito, e como isso é vigiado ──────────────
##
## Uma coisa é duplicada: o **teto anti-hit-kill** (nenhum golpe tira mais que
## 90% da vida máxima, salvo alvo abaixo de 15%). Ele é aplicado depois dos
## multiplicadores, então não dá pra reaproveitar sem pedir à V1 um número que
## ela não expõe.
##
## Cópia é risco de divergir. Por isso existe `teste_dano_v2.gd`, que compara
## este teto com o da V1 no mesmo caso — se um dia alguém mudar o teto lá e não
## aqui, o teste reprova. **A duplicação é consciente e vigiada, não esquecida.**
class_name DanoV2
extends RefCounted

## §14: o tipo que vem primeiro na lista da espécie é o primário.
const STAB_PRIMARIO   : float = 1.25
const STAB_SECUNDARIO : float = 1.15

# ──────────────────────────────────────────────────────────────────────────────
# STAB da §14
# ──────────────────────────────────────────────────────────────────────────────

## A V1 dá 1,25 pra qualquer tipo que bata, primário ou não. A V2 separa.
##
## `tipos_do_atacante` é a lista da espécie, e a ORDEM importa: `["Fire",
## "Flying"]` num Charizard significa Fire primário, Flying secundário. É assim
## que `species.json` já guarda — não é convenção nova.
static func stab(tipo_do_golpe: String, tipos_do_atacante: Array) -> float:
	if tipos_do_atacante.is_empty():
		return 1.0
	if str(tipos_do_atacante[0]) == tipo_do_golpe:
		return STAB_PRIMARIO
	for i in range(1, tipos_do_atacante.size()):
		if str(tipos_do_atacante[i]) == tipo_do_golpe:
			return STAB_SECUNDARIO
	return 1.0

# ──────────────────────────────────────────────────────────────────────────────
# A conta
# ──────────────────────────────────────────────────────────────────────────────

## O relatório completo, no mesmo formato do `DamageCalculator.detalhar()` —
## mais os campos da V2. Manter o formato importa: `CombateDebug` e os testes
## já sabem ler esse dicionário.
##
## ⚠️ `detalhar()` sorteia crítico e variação internamente e nós descartamos os
## dois. O resultado é determinístico, mas **consome 2 sorteios do RNG por
## golpe**. Não afeta o dano; afeta a sequência de outros sorteios do jogo se
## algum dia alguém depender da ordem exata. Registrado aqui pra não virar
## mistério: se incomodar, a saída é a V1 ganhar um `detalhar_sem_sorte()`.
static func detalhar(move_data: Dictionary, atacante: Dictionary,
		defensor: Dictionary) -> Dictionary:
	var r : Dictionary = DamageCalculator.detalhar(move_data, atacante, defensor)

	# Imunidade continua sendo zero absoluto (§15): não há item nem bônus que
	# transforme 0× em dano.
	if float(r.get("mult_tipo", 1.0)) <= 0.0:
		r["final"] = 0
		r["mult_stab"] = 1.0
		r["mult_critico"] = 1.0
		r["critico"] = false
		r["variacao"] = 1.0
		r["determinista"] = true
		return r

	var stab_v2 : float = stab(str(move_data.get("type", "Normal")),
		atacante.get("types", []))

	# Remontagem: a mesma linha da V1, sem crítico e sem variação, com o STAB
	# da §14 no lugar do de lá.
	var bruto : float = float(r["base"]) \
		* float(r["mult_tipo"]) \
		* stab_v2 \
		* float(r["mult_habilidade"]) \
		* float(r["mult_status"]) \
		* float(r["mult_item"]) \
		* float(r["mult_externo"]) \
		* float(r["mult_sinergia"])

	var final : int = maxi(CombatBalance.MIN_DAMAGE, int(floor(bruto)))
	var sem_piso : int = final

	var segurado : int = 0
	var teto := teto_de_dano(defensor)
	if teto > 0 and final > teto:
		segurado = final
		final = teto

	r["final"] = final
	r["sem_piso"] = sem_piso
	r["segurado_pelo_teto"] = segurado
	r["mult_stab"] = stab_v2
	r["mult_critico"] = 1.0
	r["critico"] = false
	r["variacao"] = 1.0
	r["determinista"] = true
	return r

## Só o número, pra quem não precisa do relatório.
static func calcular(move_data: Dictionary, atacante: Dictionary,
		defensor: Dictionary) -> int:
	return int(detalhar(move_data, atacante, defensor)["final"])

## O teto do golpe contra este alvo, ou 0 se não há teto agora.
##
## Mesma regra da V1, e por isso vigiada por teste: abaixo de 15% da vida o teto
## some, senão um alvo com 5 de vida ficaria imortal (90% de 5 é 4, sempre
## sobrando 1).
static func teto_de_dano(defensor: Dictionary) -> int:
	var max_hp : int = int(defensor.get("max_hp", 0))
	if max_hp <= 0:
		return 0
	var hp_agora : int = int(defensor.get("hp", max_hp))
	if float(hp_agora) <= float(max_hp) * CombatBalance.VIDA_MINIMA_PRO_TETO:
		return 0
	return maxi(1, int(floor(float(max_hp) * CombatBalance.TETO_DE_DANO_POR_GOLPE)))

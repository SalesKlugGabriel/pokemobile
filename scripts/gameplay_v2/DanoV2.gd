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
## ── O teto anti-hit-kill NÃO existe aqui (§15) ───────────────────────────────
##
## A V1 segura todo golpe em 90% da vida máxima. A V2 não. Dois motivos, e os
## dois vieram de fora da minha cabeça:
##
##  - **§15**: *"4x permanece literalmente 4x. Não aplicar cap especial em boss
##    ou Alpha."* Um teto sobre o dano final corta exatamente o 4× que a regra
##    manda preservar.
##  - **O teto era remendo do ritmo antigo.** Ele existia porque a luta durava
##    4,6 s e um golpe podia matar sozinho. Com a vida 4× maior da V2 (ver
##    `BalanceV2`), isso não acontece mais — e o remendo virou tesoura.
##
## Some junto a cópia do teto que eu tinha feito aqui, que era risco de divergir
## da V1 em silêncio. Achado do Codex na revisão de 14/09.
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
## `detalhar()` da V1 sorteia crítico e variação por dentro e nós descartamos os
## dois — mas o estado do RNG é **preservado e restaurado**, então nenhum golpe
## da V2 empurra de lado os sorteios de status, captura e loot.
static func detalhar(move_data: Dictionary, atacante: Dictionary,
		defensor: Dictionary) -> Dictionary:
	# Preserva o estado do RNG: `detalhar()` sorteia crítico e variação por
	# dentro, e a V2 descarta os dois. Sem isto, cada golpe da V2 empurrava de
	# lado os sorteios de status, captura e loot (achado do Codex, 14/09).
	var _estado_do_rng : int = Sorteio.get_state()
	var r : Dictionary = DamageCalculator.detalhar(move_data, atacante, defensor)
	Sorteio.set_state(_estado_do_rng)

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

	# 🔴 SEM TETO na V2 (§15), e isto é mudança deliberada — achado do Codex.
	#
	# A V1 segura todo golpe em 90% da vida máxima. Era um para-quedas contra
	# hit-kill, e fazia sentido quando a luta inteira durava 4,6 segundos.
	# Agora que a vida da V2 é 4× maior (ver `BalanceV2`), um golpe não mata
	# ninguém de uma vez sozinho — o para-quedas virou uma tesoura que corta
	# justamente o 4× que a §15 manda preservar **literalmente**, inclusive
	# contra Alpha e boss.
	#
	# Some com isso a cópia do teto que eu tinha feito aqui, que era risco de
	# divergir da V1 em silêncio. Menos código e menos contradição.
	var segurado : int = 0

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

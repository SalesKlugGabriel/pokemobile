## DamageCalculator.gd — A ÚNICA conta de dano do jogo.
##
## 🔴 Reescrito em 11/09/2026 (reengenharia do combate). A fórmula anterior era
##
##     dano = power × (atk/50) × (100/(100+def)) × tipo × crítico
##
## e tinha dois defeitos de raiz, os dois MEDIDOS na auditoria
## (`docs/auditoria-combate.md`):
##
##   1. o NÍVEL não entrava na conta. O dano vivia na escala do `power`
##      (40-120) e a vida na escala do `base_hp` (40-100), e nada fazia as duas
##      se encontrarem: Pikachu matava Spearow do MESMO nível com um golpe, em
##      100% dos níveis de 10 a 100.
##   2. subir de nível quase não mudava nada: 40 níveis davam +58% de dano,
##      enquanto a vida crescia 2,5x. Ou seja, quanto mais alto o nível, mais
##      LONGA a briga — o oposto de progressão.
##
## A fórmula nova é a clássica da série, que resolve os dois de uma vez:
##
##     dano = ( (2×nível/5 + 2) × power × (ataque/defesa) / 50 + 2 )
##            × STAB × tipo × crítico × variação × status × item × habilidade
##
## `ataque`/`defesa` são ATK/DEF num golpe físico e SP_ATK/SP_DEF num especial
## — antes a categoria do golpe era lida só pra queimadura, e todo Pokémon
## especial do jogo (Alakazam com sp_atk 135) atacava com o ataque físico.
##
## Todo número que decide equilíbrio mora em `CombatBalance`, nunca aqui.
class_name DamageCalculator
extends Node

# ──────────────────────────────────────────────────────────────────────────────
# Tabela de efetividade de tipos — Gen 1
# Estrutura: { atacante: { defensor: multiplicador } }
# Apenas entradas != 1.0 são listadas (omissão = 1.0 normal)
# ──────────────────────────────────────────────────────────────────────────────

const TYPE_CHART : Dictionary = {
	"Fire": {
		"Grass": 2.0, "Ice": 2.0, "Bug": 2.0,
		"Fire": 0.5, "Water": 0.5, "Rock": 0.5, "Dragon": 0.5,
	},
	"Water": {
		"Fire": 2.0, "Ground": 2.0, "Rock": 2.0,
		"Water": 0.5, "Grass": 0.5, "Dragon": 0.5,
	},
	"Grass": {
		"Water": 2.0, "Ground": 2.0, "Rock": 2.0,
		"Fire": 0.5, "Grass": 0.5, "Poison": 0.5,
		"Flying": 0.5, "Bug": 0.5, "Dragon": 0.5,
	},
	"Electric": {
		"Water": 2.0, "Flying": 2.0,
		"Electric": 0.5, "Grass": 0.5, "Dragon": 0.5,
		"Ground": 0.0,
	},
	"Ice": {
		"Grass": 2.0, "Ground": 2.0, "Flying": 2.0, "Dragon": 2.0,
		"Water": 0.5, "Ice": 0.5,
	},
	"Fighting": {
		"Normal": 2.0, "Ice": 2.0, "Rock": 2.0,
		"Poison": 0.5, "Bug": 0.5, "Flying": 0.5,
		"Psychic": 0.5, "Ghost": 0.0,
	},
	"Poison": {
		"Grass": 2.0, "Bug": 2.0,
		"Poison": 0.5, "Ground": 0.5, "Rock": 0.5, "Ghost": 0.5,
	},
	"Ground": {
		"Fire": 2.0, "Electric": 2.0, "Poison": 2.0, "Rock": 2.0,
		"Grass": 0.5, "Bug": 0.5,
		"Flying": 0.0,
	},
	"Flying": {
		"Grass": 2.0, "Fighting": 2.0, "Bug": 2.0,
		"Electric": 0.5, "Rock": 0.5,
	},
	"Psychic": {
		"Fighting": 2.0, "Poison": 2.0,
		"Psychic": 0.5,
		"Ghost": 0.0,
	},
	"Bug": {
		"Grass": 2.0, "Poison": 2.0, "Psychic": 2.0,
		"Fire": 0.5, "Fighting": 0.5, "Flying": 0.5, "Ghost": 0.5,
	},
	"Rock": {
		"Fire": 2.0, "Ice": 2.0, "Flying": 2.0, "Bug": 2.0,
		"Fighting": 0.5, "Ground": 0.5,
	},
	"Ghost": {
		"Ghost": 2.0,
		"Normal": 0.0, "Psychic": 0.0,
	},
	"Dragon": {
		"Dragon": 2.0,
	},
	"Normal": {
		"Rock": 0.5,
		"Ghost": 0.0,
	},
}

## Mantida por compatibilidade com quem já lia esta constante; o valor de
## verdade mora em CombatBalance (item 37 do pedido: um lugar só pra régua).
const CRIT_CHANCE : float = CombatBalance.CRIT_CHANCE

# ──────────────────────────────────────────────────────────────────────────────
# Fórmulas de stat
# ──────────────────────────────────────────────────────────────────────────────

## 🔴 As duas funções abaixo eram A TERCEIRA fórmula de stat do projeto e
## discordavam das outras duas (o HP do menu não era o HP da luta). Agora são
## só uma porta de entrada pra `StatsDePokemon`, que é a única fórmula do jogo.
## Continuam existindo porque meia dúzia de arquivos já chamava por aqui.
##
## `chave`/`nature` são opcionais: sem eles a nature não entra, que é o
## comportamento de quem chamava antes (nenhum chamador conhecia nature).
static func calculate_stat(base_stat: int, level: int, chave: String = "", nature: String = "") -> int:
	return StatsDePokemon.stat(base_stat, level, chave, nature)

## Calcula HP máximo a partir da base e do nível.
static func calculate_hp(base_hp: int, level: int, iv: int = 31, ev: int = 0) -> int:
	return StatsDePokemon.hp_maximo(base_hp, level, iv, ev)

# ──────────────────────────────────────────────────────────────────────────────
# Fórmula de dano
# ──────────────────────────────────────────────────────────────────────────────

## Calcula o dano final aplicado a um defensor.
##
## É um atalho pra `detalhar()` — a conta de verdade acontece lá, e a
## ferramenta de depuração (`CombateDebug`) lê O MESMO resultado. Assim é
## impossível o relatório de dano discordar do dano que saiu, que é o defeito
## clássico de se ter duas contas.
static func calculate_damage(
	move_data      : Dictionary,
	attacker_stats : Dictionary,
	defender_stats : Dictionary
) -> int:
	return int(detalhar(move_data, attacker_stats, defender_stats).get("final", 1))

## A conta inteira, passo a passo, devolvida como dicionário (item 44 do
## pedido: "descobrir rapidamente por que um ataque está causando dano
## excessivo").
##
## move_data:      { power, type, category, damage_bonus? }
## attacker_stats: { atk, spa?, level, types?, ability?, hp_ratio?, status?, held_item? }
## defender_stats: { def, spd?, types, max_hp?, level? }
##
## Chaves ausentes caem em valores neutros de propósito: muita coisa no jogo
## (projétil, passiva, dano de status) chama com meia dúzia de campos só.
static func detalhar(
	move_data      : Dictionary,
	attacker_stats : Dictionary,
	defender_stats : Dictionary
) -> Dictionary:
	var power     : int    = int(move_data.get("power", 40))
	var mv_type   : String = str(move_data.get("type", "Normal"))
	var categoria : String = str(move_data.get("category", "physical"))
	var especial  : bool   = categoria == "special"
	var nivel     : int    = maxi(1, int(attacker_stats.get("level", 5)))
	var def_types : Array  = defender_stats.get("types", ["Normal"])

	# ── Qual stat ataca e qual defende (item 10 do pedido) ────────────────────
	# Golpe físico usa ATK contra DEF; especial usa SP_ATK contra SP_DEF. Quem
	# não informar a stat especial cai na física — é o que mantém funcionando
	# quem chama com o dicionário antigo (passiva, projétil, dano de status).
	var ataque  : int = int(attacker_stats.get("spa", attacker_stats.get("atk", 50))) if especial \
		else int(attacker_stats.get("atk", 50))
	var defesa  : int = int(defender_stats.get("spd", defender_stats.get("def", 50))) if especial \
		else int(defender_stats.get("def", 50))
	ataque = maxi(1, ataque)
	defesa = maxi(1, defesa)

	# ── O corpo da fórmula ────────────────────────────────────────────────────
	var termo_nivel : float = 2.0 * float(nivel) / CombatBalance.LEVEL_SCALE + CombatBalance.LEVEL_TERM_BONUS
	var base : float = termo_nivel * float(power) * (float(ataque) / float(defesa)) \
		/ CombatBalance.DAMAGE_DIVISOR + CombatBalance.DAMAGE_FLAT_BONUS
	base *= CombatBalance.BASE_DAMAGE_MULTIPLIER

	# ── Os multiplicadores, cada um medido em separado ────────────────────────
	var tipo_mult : float = get_type_multiplier(mv_type, def_types)
	var stab      : float = stab_multiplier(mv_type, attacker_stats.get("types", []))
	var critico   : bool  = is_critical()
	var crit_mult : float = CombatBalance.CRIT_MULTIPLIER if critico else 1.0
	var variacao  : float = RNGManager.randf_range(
		CombatBalance.DAMAGE_VARIANCE_MIN, CombatBalance.DAMAGE_VARIANCE_MAX)

	var habilidade : String = str(attacker_stats.get("ability", ""))
	var hab_mult : float = 1.0
	if habilidade != "":
		hab_mult = ability_damage_multiplier(habilidade, mv_type, especial,
			float(attacker_stats.get("hp_ratio", 1.0)), str(attacker_stats.get("status", "none")))

	# Queimadura corta o golpe FÍSICO pela metade. Fica fora de
	# `ability_damage_multiplier` de propósito: vale pra qualquer Pokémon, com
	# ou sem habilidade cadastrada.
	var status_mult : float = 1.0
	if str(attacker_stats.get("status", "none")) == "burn" and not especial:
		status_mult = CombatBalance.BURN_PHYSICAL_MULTIPLIER

	# Item equipado (+20% no dano do tipo dele) e bônus externo (afinidade do
	# Treinador) — os dois já existiam, só mudaram de lugar na conta.
	var item_mult : float = multiplicador_de_item_equipado(
		str(attacker_stats.get("held_item", "")), mv_type)
	var bonus_ext : float = 1.0 + float(move_data.get("damage_bonus", 0.0))

	var bruto : float = base * tipo_mult * stab * crit_mult * variacao \
		* hab_mult * status_mult * item_mult * bonus_ext

	# ── Imunidade é zero de verdade, não "1 de dano" ──────────────────────────
	if tipo_mult <= 0.0:
		return _relatorio(move_data, attacker_stats, defender_stats, ataque, defesa,
			base, tipo_mult, stab, crit_mult, variacao, hab_mult, status_mult,
			item_mult, bonus_ext, 0, 0, critico, especial)

	var final : int = maxi(CombatBalance.MIN_DAMAGE, int(floor(bruto)))

	# Piso proporcional: defesa alta REDUZ muito, mas nunca transforma o golpe
	# em cócegas de 1 de dano (item 10). Ver a explicação em CombatBalance.
	var vida_maxima : int = int(defender_stats.get("max_hp", 0))
	if vida_maxima > 0:
		final = maxi(final, int(floor(float(vida_maxima) * CombatBalance.DANO_MINIMO_FRACAO_HP)))

	# ── O para-quedas contra hit-kill (a rede, não o balanceamento) ───────────
	# Nenhum golpe tira mais que 90% da vida MÁXIMA do alvo de uma vez. Vale
	# mesmo com crítico, super-efetividade e 70 níveis de vantagem empilhados:
	# medido, um Dragonite Lv100 com ultimate crítica faria 989 de dano num
	# alvo Lv30 de 121 de vida — com o teto, faz 108 e o alvo continua vivo pra
	# fugir, curar ou ser trocado.
	#
	# O teto NÃO vale se o alvo já está abaixo de 15% da vida — senão ele
	# ficaria imortal (90% de 5 de vida é 4, sempre sobrando 1).
	var teto_aplicado : int = 0
	var max_hp : int = int(defender_stats.get("max_hp", 0))
	var hp_agora : int = int(defender_stats.get("hp", max_hp))
	if max_hp > 0 and float(hp_agora) > float(max_hp) * CombatBalance.VIDA_MINIMA_PRO_TETO:
		var teto : int = maxi(1, int(floor(float(max_hp) * CombatBalance.TETO_DE_DANO_POR_GOLPE)))
		if final > teto:
			teto_aplicado = final
			final = teto

	return _relatorio(move_data, attacker_stats, defender_stats, ataque, defesa,
		base, tipo_mult, stab, crit_mult, variacao, hab_mult, status_mult,
		item_mult, bonus_ext, final, teto_aplicado, critico, especial)

## Monta o dicionário de saída. Separado só pra `detalhar()` não ter duas
## saídas copiadas (a de imunidade e a normal) que podem divergir.
static func _relatorio(move_data: Dictionary, atacante: Dictionary, defensor: Dictionary,
		ataque: int, defesa: int, base: float, tipo: float, stab: float, crit: float,
		variacao: float, habilidade: float, status: float, item: float, externo: float,
		final: int, teto_cru: int, foi_critico: bool, especial: bool) -> Dictionary:
	return {
		"final": final,
		"golpe": str(move_data.get("name", move_data.get("id", "?"))),
		"tipo_do_golpe": str(move_data.get("type", "Normal")),
		"categoria": "especial" if especial else "físico",
		"power": int(move_data.get("power", 0)),
		"nivel_atacante": int(atacante.get("level", 0)),
		"nivel_defensor": int(defensor.get("level", 0)),
		"stat_ofensiva": ataque,
		"stat_defensiva": defesa,
		"base": base,
		"mult_tipo": tipo,
		"mult_stab": stab,
		"mult_critico": crit,
		"critico": foi_critico,
		"variacao": variacao,
		"mult_habilidade": habilidade,
		"mult_status": status,
		"mult_item": item,
		"mult_externo": externo,
		# > 0 significa que o para-quedas segurou: este seria o dano sem teto.
		"segurado_pelo_teto": teto_cru,
	}

## STAB: +25% quando o golpe é do mesmo tipo do Pokémon que o usa (item 15).
## Lista de tipos vazia = quem chamou não informou, então sem bônus.
static func stab_multiplier(move_type: String, attacker_types: Array) -> float:
	if attacker_types.is_empty():
		return 1.0
	return CombatBalance.STAB_MULTIPLIER if move_type in attacker_types else 1.0

## +20% (ou o que o item disser) quando o tipo do golpe bate com o do item.
## Item vazio, desconhecido ou de outro tipo = 1.0, sem efeito.
## Avalia O ITEM QUE RECEBE — não o que está equipado no líder. Chegou a ser o
## contrário por um momento e quebrou dois testes: ignorar o próprio argumento
## faz a função mentir pra quem a chama, e quem chama é que sabe qual item quer
## medir (o combate passa o item do encaixe de COMBATE, que é o único que pode
## carregar efeito de dano).
static func multiplicador_de_item_equipado(held_item: String, move_type: String) -> float:
	if held_item.is_empty():
		return 1.0
	return 1.0 + ItensEquipados.valor({"held_combate": held_item}, "dano_tipo", move_type)

## Mesma regra de BattleManager._ability_damage_multiplier(), só que recebendo
## primitivos em vez de um BattlePokemon — pra funcionar tanto no combate por
## turno quanto no combate em tempo real sem os dois dependerem um do outro.
## status: "none"/"burn"/"paralysis"/etc — Guts só ativa com algum status
## diferente de "none". Combate em tempo real ainda não tem status
## persistente (WildPokemon/FollowerPokemon não guardam isso), então Guts
## nunca ativa por ali até essa peça existir — não é bug, é lacuna conhecida.
static func ability_damage_multiplier(ability: String, move_type: String, is_special: bool, hp_ratio: float, status: String = "none") -> float:
	var low_hp := hp_ratio <= (1.0 / 3.0)
	match ability:
		"Overgrow":
			if move_type == "Grass" and low_hp:
				return 1.5
		"Blaze":
			if move_type == "Fire" and low_hp:
				return 1.5
		"Torrent":
			if move_type == "Water" and low_hp:
				return 1.5
		"Guts":
			if status != "none" and not is_special:
				return 1.5
	return 1.0

# ──────────────────────────────────────────────────────────────────────────────
# Efetividade de tipos
# ──────────────────────────────────────────────────────────────────────────────

## Retorna o multiplicador de tipo para move_type contra uma lista de tipos defensores.
## Para dual-type, multiplica os dois multiplicadores.
static func get_type_multiplier(move_type: String, defender_types: Array) -> float:
	if not TYPE_CHART.has(move_type):
		return 1.0

	var chart_row : Dictionary = TYPE_CHART[move_type]
	var mult      : float      = 1.0

	for def_type in defender_types:
		if chart_row.has(def_type):
			mult *= chart_row[def_type]

	return mult

# ──────────────────────────────────────────────────────────────────────────────
# Crítico
# ──────────────────────────────────────────────────────────────────────────────

## Retorna true se o ataque é crítico (chance base 6.25%).
static func is_critical() -> bool:
	return RNGManager.chance(CRIT_CHANCE)

# ──────────────────────────────────────────────────────────────────────────────
# Velocidade
# ──────────────────────────────────────────────────────────────────────────────

## Velocidade de movimento em px/s baseada no speed_stat.
static func move_speed_from_stat(speed_stat: int) -> float:
	return 160.0 + (speed_stat * 1.6)

## Redução de cooldown baseada no speed_stat (0.0 a 1.0).
static func cooldown_reduction_from_stat(speed_stat: int) -> float:
	return speed_stat / 500.0

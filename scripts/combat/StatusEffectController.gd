## StatusEffectController.gd — Status persistente (queimadura, veneno, veneno
## grave, paralisia, sono, congelamento) + confusão pro combate em tempo real
## (Onda 1, item 5 do roteiro geral, 03/09).
##
## Reaproveita EXATAMENTE as frações/chances já validadas no combate por turno
## (BattlePokemon.gd/BattleManager.gd) — só a FORMA de aplicar muda (segundos
## em vez de turnos), a matemática é a mesma, pra não reinventar um número que
## já foi decidido. Funções estáticas puras (como DamageCalculator.gd), sem
## estado próprio — cada Pokémon (WildPokemon/FollowerPokemon) guarda seu
## próprio status/timers e só CHAMA estas funções pra saber o que fazer.
class_name StatusEffectController
extends RefCounted

## Nome do efeito em moves.json → nome interno do status.
const STATUS_EFFECT_MAP : Dictionary = {
	"burn": "burn", "poison": "poison", "bad_poison": "bad_poison",
	"paralysis": "paralysis", "sleep": "sleep", "freeze": "freeze",
}

## Segundos que valem por "turno" — usado só pra sono/confusão (a duração
## sorteada em turnos, 1-3 e 2-5, vira segundos multiplicando por isto) e pro
## intervalo entre dano de queima/veneno e a checagem de degelo. Não precisa
## bater com o cooldown de nenhum golpe específico — é só a cadência do
## "relógio" de status, independente de quantos golpes o jogador der no meio.
const TURN_SECONDS : float = 3.0

static func _extract_trailing_number(s: String) -> int:
	var digits := ""
	for c in s:
		if c.is_valid_int():
			digits += c
	return int(digits) if digits != "" else 0

## Lê o campo "effect" de um golpe (moves.json) e devolve {status, chance} se
## ele inflige uma das 5 condições — {} se não. `default_chance` replica
## BattleManager._resolve_chance(): 100 pra golpe de status puro (ex: Thunder
## Wave, sem número no nome = sempre acerta), -1 pra efeito secundário de
## golpe de dano (ex: "burn_10" já traz os 10% embutidos; sem número embutido
## E default -1, não aplica nada — evita golpe de dano virar status garantido).
static func resolve_status_effect(effect: String, default_chance: int = -1) -> Dictionary:
	for key in STATUS_EFFECT_MAP.keys():
		if effect == key or effect.begins_with(key + "_"):
			var raw : int = -1 if effect == key else _extract_trailing_number(effect)
			var chance : int = raw if raw >= 0 else default_chance
			if chance <= 0:
				return {}
			return { "status": STATUS_EFFECT_MAP[key], "chance": chance }
	return {}

## Mesma regra pra confusão — efeito à parte (não é um dos 6 valores do
## enum Status do combate por turno), pode coexistir com queima/veneno/etc.
static func resolve_confuse_effect(effect: String, default_chance: int = -1) -> int:
	if effect != "confuse" and not effect.begins_with("confuse_"):
		return -1
	var raw : int = -1 if effect == "confuse" else _extract_trailing_number(effect)
	var chance : int = raw if raw >= 0 else default_chance
	return chance if chance > 0 else -1

## Chamado pelo ATACANTE (Wild ou Follower) depois de decidir usar um golpe —
## aplica status/confusão no alvo, se o golpe tiver algum efeito desses.
## default_chance: 100 se o golpe é puro de status (category=="status", ex:
## Thunder Wave — garantido, igual ao combate por turno), -1 se é um golpe de
## dano com efeito secundário (só a chance embutida no nome conta).
## `mult_tipo` é o multiplicador de efetividade que o golpe teve contra ESTE
## alvo. Serve pra uma trava que faltava (achado na auditoria da Fase 2): um
## golpe IMUNE — Thunderbolt num Pokémon de Terra — causava 0 de dano e mesmo
## assim tentava paralisar. Agora imunidade barra o status junto com o dano,
## que é a ordem que o item 8 do pedido descreve: tipo → acerto → imunidade →
## só então o sorteio do status.
static func try_apply(target: Node, move_data: Dictionary, mult_tipo: float = 1.0) -> void:
	if not is_instance_valid(target) or not target.has_method("apply_move_effect"):
		return
	if mult_tipo <= 0.0:
		return
	var effect : String = move_data.get("effect", "none")
	if effect == "none" or effect == "":
		return
	target.apply_move_effect(effect, chance_do_golpe(move_data))

## A chance de status deste golpe, em PORCENTAGEM (0-100).
##
## Três fontes, nesta ordem de precedência:
##   1. `status_chance` nos dados (0.20 = 20%) — o campo que o item 8 pediu.
##      Existia em moves.json desde a Fase 1 e não era lido por ninguém.
##   2. o número embutido no nome do efeito ("burn_10" = 10%) — o jeito antigo,
##      que continua valendo pra quem não declarou `status_chance`.
##   3. golpe puro de status (category == "status") = 100%, garantido.
##
## Um golpe de DANO sem nenhuma das três não aplica status nenhum (-1) — é o
## que impede um golpe comum de virar status garantido por descuido de dado.
static func chance_do_golpe(move_data: Dictionary) -> int:
	var declarada : float = float(move_data.get("status_chance", 0.0))
	if declarada > 0.0:
		# Aceita tanto 0.20 quanto 20 — quem escrever o dado de um jeito ou do
		# outro obtém o mesmo resultado, em vez de um bug silencioso de 100x.
		return int(round(declarada * 100.0)) if declarada <= 1.0 else int(round(declarada))
	return 100 if move_data.get("category", "physical") == "status" else -1

# ──────────────────────────────────────────────────────────────────────────────
# Acerto (item 8: "a aplicação deve ocorrer depois de validar ... hit")
# ──────────────────────────────────────────────────────────────────────────────

## O golpe acertou?
##
## 🔴 Achado na auditoria da Fase 2: os 192 golpes têm `accuracy` nos dados e
## NINGUÉM lia. Blizzard, com 70 de precisão, nunca errava — o que tirava dela
## exatamente o que a torna uma aposta em vez de uma escolha óbvia.
##
## `accuracy <= 0` significa "não se erra" (é como os golpes de efeito puro,
## tipo Whirlwind, estão cadastrados) — não é 0% de chance.
static func acertou(move_data: Dictionary) -> bool:
	var precisao : int = int(move_data.get("accuracy", 100))
	if precisao <= 0 or precisao >= 100:
		return true
	return RNGManager.chance(float(precisao) / 100.0)

# ──────────────────────────────────────────────────────────────────────────────
# Dano de fim-de-turno — mesmas frações de BattlePokemon.tick_status()
# ──────────────────────────────────────────────────────────────────────────────

static func tick_damage(status: String, max_hp: int, bad_poison_stacks: int) -> int:
	match status:
		"burn":       return maxi(1, max_hp / 16)
		"poison":     return maxi(1, max_hp / 8)
		"bad_poison": return maxi(1, max_hp * bad_poison_stacks / 16)
	return 0

## true = degelou este "turno" — mesma chance de BattlePokemon.tick_status().
static func should_thaw() -> bool:
	return RNGManager.chance(0.2)

## true = a paralisia impediu a ação desta tentativa — mesma chance de
## BattlePokemon.can_move().
static func should_paralysis_fail() -> bool:
	return RNGManager.chance(0.25)

## true = a confusão fez o Pokémon se acertar em vez de agir — mesma chance
## (1/3) de BattleManager._on_attacker_turn().
static func should_confuse_self_hit() -> bool:
	return RNGManager.chance(1.0 / 3.0)

static func roll_sleep_duration() -> float:
	return float(RNGManager.randi_range(1, 3)) * TURN_SECONDS

static func roll_confuse_duration() -> float:
	return float(RNGManager.randi_range(2, 5)) * TURN_SECONDS

## true = totalmente incapaz de agir (sono/congelado). Paralisia NÃO entra
## aqui — ela é uma chance por TENTATIVA de ataque (should_paralysis_fail),
## não um travamento contínuo; o Pokémon paralisado continua patrulhando/
## perseguindo, só mais devagar (ver speed_multiplier) e às vezes falha o golpe.
static func is_incapacitated(status: String) -> bool:
	return status == "sleep" or status == "freeze"

static func speed_multiplier(status: String) -> float:
	return 0.5 if status == "paralysis" else 1.0

## Queimadura reduz ataque FÍSICO a 50% — mesma regra de
## BattlePokemon.effective_attack(), independente de qualquer ability (Guts
## tem seu PRÓPRIO bônus por estar statusado, calculado à parte em
## DamageCalculator.ability_damage_multiplier — os dois multiplicam juntos).
static func attack_multiplier(status: String, is_special: bool) -> float:
	return 0.5 if (status == "burn" and not is_special) else 1.0

static func status_label(status: String) -> String:
	match status:
		"burn":                    return "BRN"
		"poison", "bad_poison":    return "PSN"
		"paralysis":               return "PAR"
		"sleep":                   return "SLP"
		"freeze":                  return "FRZ"
	return ""

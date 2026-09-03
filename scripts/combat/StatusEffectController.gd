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
static func try_apply(target: Node, move_data: Dictionary) -> void:
	if not is_instance_valid(target) or not target.has_method("apply_move_effect"):
		return
	var effect : String = move_data.get("effect", "none")
	if effect == "none" or effect == "":
		return
	var default_chance : int = 100 if move_data.get("category", "physical") == "status" else -1
	target.apply_move_effect(effect, default_chance)

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

## DamageCalculator.gd — Cálculo de dano, stats e efetividade de tipos (Gen 1).
## Usar como Autoload (singleton) ou class_name para acesso global.
## Todas as fórmulas seguem a especificação do PokéMobile.
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

# Probabilidade base de crítico
const CRIT_CHANCE : float = 0.0625   # 6.25%

# ──────────────────────────────────────────────────────────────────────────────
# Fórmulas de stat
# ──────────────────────────────────────────────────────────────────────────────

## Calcula stat atual (atk, def, spd etc.) a partir da base e do nível.
## stat_atual = base_stat + floor(base_stat * (level / 60))
static func calculate_stat(base_stat: int, level: int) -> int:
	return base_stat + int(floor(base_stat * (level / 60.0)))

## Calcula HP máximo a partir da base e do nível.
## hp_atual = base_hp + floor(base_hp * (level / 40)) + level
static func calculate_hp(base_hp: int, level: int) -> int:
	return base_hp + int(floor(base_hp * (level / 40.0))) + level

# ──────────────────────────────────────────────────────────────────────────────
# Fórmula de dano
# ──────────────────────────────────────────────────────────────────────────────

## Calcula o dano final aplicado a um defensor.
## attacker_stats: { "atk": int, "level": int }
## defender_stats: { "def": int, "types": Array[String] }
## move_data:      { "power": int, "type": String, "damage_bonus": float (opcional) }
static func calculate_damage(
	move_data      : Dictionary,
	attacker_stats : Dictionary,
	defender_stats : Dictionary
) -> int:
	var power    : int   = move_data.get("power", 40)
	var atk      : int   = attacker_stats.get("atk", 50)
	var def      : int   = defender_stats.get("def", 50)
	var mv_type  : String = move_data.get("type", "Normal")
	var def_types : Array = defender_stats.get("types", ["Normal"])

	# Bônus de dano externo (ex: afinidade do Treinador)
	var ext_bonus : float = move_data.get("damage_bonus", 0.0)

	var reducao      : float = 100.0 / (100.0 + float(def))
	var tipo_mult    : float = get_type_multiplier(mv_type, def_types)
	var crit_mult    : float = 1.5 if is_critical() else 1.0
	var dano_efet    : float = float(power) * (float(atk) / 50.0) * reducao * tipo_mult * crit_mult
	dano_efet *= (1.0 + ext_bonus)

	return max(1, int(floor(dano_efet)))

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
	return 80.0 + (speed_stat * 0.8)

## Redução de cooldown baseada no speed_stat (0.0 a 1.0).
static func cooldown_reduction_from_stat(speed_stat: int) -> float:
	return speed_stat / 500.0

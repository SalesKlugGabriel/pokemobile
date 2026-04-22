## TrainerStats.gd — Sistema de Skill Tree do Treinador.
## Gerencia os 5 atributos, pontos disponíveis e cálculos de bônus.
## Serializa/deserializa para o SaveManager.
class_name TrainerStats
extends Resource

# ──────────────────────────────────────────────────────────────────────────────
# Constantes
# ──────────────────────────────────────────────────────────────────────────────

const BASE_SPEED        : float = 180.0
const BASE_MAX_HP       : int   = 100
const SPEED_PER_PT      : float = 8.0    # px/s por ponto de agilidade
const HP_PER_PT         : int   = 15     # HP máximo por ponto de sobrevivencia
const DMG_BONUS_PER_PT  : float = 0.02   # +2% dano do Pokémon por ponto de afinidade
const CD_REDUC_PER_PT   : float = 0.01   # -1% cooldown por ponto de afinidade
const CAPTURE_PER_PT    : float = 0.03   # +3% captura por ponto de mestre_captura
const LUCK_DROP_PER_PT  : float = 0.05   # +5% tier superior por ponto de sorte
const LUCK_EXTRA_PER_PT : float = 0.02   # +2% item extra por ponto de sorte

# Máximos por atributo
const MAX_POINTS : Dictionary = {
	"agilidade":      10,
	"sobrevivencia":  10,
	"afinidade":       8,
	"mestre_captura":  8,
	"sorte":           6,
}

# ──────────────────────────────────────────────────────────────────────────────
# Estado
# ──────────────────────────────────────────────────────────────────────────────

## Nível atual do Treinador (para calcular pontos totais acumulados)
var trainer_level      : int = 1

## Pontos já gastos por atributo
var _points : Dictionary = {
	"agilidade":      0,
	"sobrevivencia":  0,
	"afinidade":      0,
	"mestre_captura": 0,
	"sorte":          0,
}

## Pontos manualmente gastos (para rastrear quanto sobra)
var _spent_total : int = 0

# ──────────────────────────────────────────────────────────────────────────────
# API pública
# ──────────────────────────────────────────────────────────────────────────────

## Retorna o número de pontos disponíveis para distribuir.
## 1 ponto por nível (level 1 = 0 pontos acumulados, level 2 = 1, etc.)
func get_available_points() -> int:
	return max(0, (trainer_level - 1) - _spent_total)

## Adiciona 1 ponto no atributo indicado.
## Retorna true em caso de sucesso, false se não há ponto ou já atingiu o máximo.
func add_point(attribute: String) -> bool:
	if not MAX_POINTS.has(attribute):
		push_warning("[TrainerStats] Atributo desconhecido: %s" % attribute)
		return false
	if get_available_points() <= 0:
		return false
	if _points[attribute] >= MAX_POINTS[attribute]:
		return false
	_points[attribute] += 1
	_spent_total += 1
	EventBus.trainer_skill_tree_updated.emit()
	return true

## Retorna o valor atual de um atributo.
func get_attribute(attribute: String) -> int:
	return _points.get(attribute, 0)

# ──────────────────────────────────────────────────────────────────────────────
# Cálculos de bônus
# ──────────────────────────────────────────────────────────────────────────────

## Velocidade de movimento do Treinador em px/s.
func get_speed() -> float:
	return BASE_SPEED + (_points["agilidade"] * SPEED_PER_PT)

## HP máximo do Treinador.
func get_max_hp() -> int:
	return BASE_MAX_HP + (_points["sobrevivencia"] * HP_PER_PT)

## Bônus multiplicativo de dano do Pokémon Follower (ex: 0.06 = +6%).
func get_pokemon_damage_bonus() -> float:
	return _points["afinidade"] * DMG_BONUS_PER_PT

## Redução de cooldown (ex: 0.03 = -3%).
func get_cooldown_reduction() -> float:
	return _points["afinidade"] * CD_REDUC_PER_PT

## Bônus de chance de captura (ex: 0.09 = +9%).
func get_capture_bonus() -> float:
	return _points["mestre_captura"] * CAPTURE_PER_PT

## Retorna Dictionary com bônus de sorte: { "tier": float, "extra": float }
func get_luck_bonus() -> Dictionary:
	return {
		"tier":  _points["sorte"] * LUCK_DROP_PER_PT,
		"extra": _points["sorte"] * LUCK_EXTRA_PER_PT,
	}

## Retorna os pontos do mestre_captura (usado pela fórmula de captura).
func get_master_capture_points() -> int:
	return _points["mestre_captura"]

# ──────────────────────────────────────────────────────────────────────────────
# Serialização
# ──────────────────────────────────────────────────────────────────────────────

func serialize() -> Dictionary:
	return {
		"trainer_level": trainer_level,
		"points":        _points.duplicate(),
		"spent_total":   _spent_total,
	}

func deserialize(data: Dictionary) -> void:
	trainer_level = data.get("trainer_level", 1)
	_spent_total  = data.get("spent_total", 0)
	var saved : Dictionary = data.get("points", {})
	for key in _points.keys():
		if saved.has(key):
			_points[key] = saved[key]

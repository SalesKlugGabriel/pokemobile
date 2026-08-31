## BattlePokemon.gd — Representa um Pokémon dentro de uma batalha.
## Calcula stats a partir de base_stats + level + IVs/EVs.
## Gerencia HP atual, PP de cada move, status e modificadores de stage.
class_name BattlePokemon
extends RefCounted

# ──────────────────────────────────────────────────────────────────────────────
# Dados de identidade
# ──────────────────────────────────────────────────────────────────────────────
var species_id  : int    = 1
var species_name: String = "???"
var level       : int    = 5
var is_shiny    : bool   = false
var is_player   : bool   = false   # true = time do jogador, false = inimigo

# Moves carregados (Array de Dicts com dados completos + pp_current)
var moves       : Array[Dictionary] = []

# ──────────────────────────────────────────────────────────────────────────────
# Stats calculados
# ──────────────────────────────────────────────────────────────────────────────
var max_hp  : int = 1
var hp      : int = 1
var attack  : int = 1
var defense : int = 1
var sp_atk  : int = 1
var sp_def  : int = 1
var speed   : int = 1

# IVs (0–31) e EVs (0–252) — wild usa IVs aleatórios, EVs=0
var ivs     : Dictionary = { "hp":15,"atk":15,"def":15,"spa":15,"spd":15,"spe":15 }
var evs     : Dictionary = { "hp":0, "atk":0, "def":0, "spa":0, "spd":0, "spe":0 }

# ──────────────────────────────────────────────────────────────────────────────
# Estado de batalha
# ──────────────────────────────────────────────────────────────────────────────
enum Status { NONE, BURN, POISON, BAD_POISON, PARALYSIS, SLEEP, FREEZE }
var status        : Status = Status.NONE
var sleep_turns   : int    = 0      # turnos restantes de sono
var bad_poison_ctr: int    = 0      # contador de dano crescente de bad poison

# Modificadores de stage: -6 a +6 para cada stat
var stages : Dictionary = { "atk":0,"def":0,"spa":0,"spd":0,"spe":0,"acc":0,"eva":0 }

# ──────────────────────────────────────────────────────────────────────────────
# Construtor estático
# ──────────────────────────────────────────────────────────────────────────────

## Cria um BattlePokemon a partir de um species_id e level.
## ivs_override: dicionário opcional para forçar IVs (ex: Pokémon salvo).
static func create(p_species_id: int, p_level: int, p_is_player: bool,
		p_ivs: Dictionary = {}, p_move_ids: Array = []) -> BattlePokemon:
	var bp        := BattlePokemon.new()
	bp.species_id  = p_species_id
	bp.level       = p_level
	bp.is_player   = p_is_player

	var species    := GameData.get_species(p_species_id)
	bp.species_name = species.get("name", "???")

	# IVs: usa override ou gera aleatórios para Pokémon selvagem
	if p_ivs.is_empty():
		bp.ivs = {
			"hp":  RNGManager.randi_range(0, 31),
			"atk": RNGManager.randi_range(0, 31),
			"def": RNGManager.randi_range(0, 31),
			"spa": RNGManager.randi_range(0, 31),
			"spd": RNGManager.randi_range(0, 31),
			"spe": RNGManager.randi_range(0, 31),
		}
	else:
		bp.ivs = p_ivs.duplicate()

	var base_stats : Dictionary = species.get("base_stats", {})
	bp._calculate_stats(base_stats)

	# Moves: usa lista fornecida ou pega os últimos 4 aprendíveis até o level
	var move_ids := p_move_ids
	if move_ids.is_empty():
		var learnable := GameData.get_learnable_moves(p_species_id, p_level)
		learnable.sort_custom(func(a, b): return a.get("level", 0) > b.get("level", 0))
		for entry in learnable.slice(0, 4):
			move_ids.append(entry.get("move", ""))

	for mid in move_ids:
		var mdata := GameData.get_move(mid).duplicate()
		if mdata.is_empty():
			continue
		mdata["pp_current"] = mdata.get("pp", 10)
		bp.moves.append(mdata)

	return bp

## Reconstrói um BattlePokemon a partir dos dados salvos (SaveManager),
## preservando HP atual e PP restante de cada move em vez de recalcular do zero.
static func from_save(poke_save: Dictionary) -> BattlePokemon:
	var bp := BattlePokemon.new()
	bp.species_id = int(poke_save.get("species_id", 1))
	bp.level      = int(poke_save.get("level", 5))
	bp.is_player  = true
	bp.is_shiny   = bool(poke_save.get("is_shiny", false))

	var species : Dictionary = GameData.get_species(bp.species_id)
	bp.species_name = species.get("name", "???")
	bp.ivs = poke_save.get("ivs", bp.ivs).duplicate()
	bp.evs = poke_save.get("evs", bp.evs).duplicate()

	var base_stats : Dictionary = species.get("base_stats", {})
	bp._calculate_stats(base_stats)
	bp.hp = clampi(int(poke_save.get("hp_current", bp.max_hp)), 0, bp.max_hp)

	for move_save in poke_save.get("moves", []):
		var move_id : String = move_save.get("id", "")
		var mdata : Dictionary = GameData.get_move(move_id).duplicate()
		if mdata.is_empty():
			continue
		mdata["pp_current"] = int(move_save.get("pp_current", mdata.get("pp", 10)))
		mdata["pp_max"]     = int(move_save.get("pp_max", mdata.get("pp", 10)))
		bp.moves.append(mdata)

	return bp

# ──────────────────────────────────────────────────────────────────────────────
# Cálculo de stats (fórmula moderna Gen 3+)
# ──────────────────────────────────────────────────────────────────────────────
func _calculate_stats(base: Dictionary) -> void:
	max_hp  = _calc_hp (base.get("hp",  45))
	hp      = max_hp
	attack  = _calc_stat(base.get("atk", 45), ivs["atk"], evs["atk"])
	defense = _calc_stat(base.get("def", 45), ivs["def"], evs["def"])
	sp_atk  = _calc_stat(base.get("spa", 45), ivs["spa"], evs["spa"])
	sp_def  = _calc_stat(base.get("spd", 45), ivs["spd"], evs["spd"])
	speed   = _calc_stat(base.get("spe", 45), ivs["spe"], evs["spe"])

func _calc_hp(base_val: int) -> int:
	return floori((2.0 * base_val + ivs["hp"] + floori(evs["hp"] / 4.0)) * level / 100.0) + level + 10

func _calc_stat(base_val: int, iv: int, ev: int) -> int:
	return floori((2.0 * base_val + iv + floori(ev / 4.0)) * level / 100.0) + 5

# ──────────────────────────────────────────────────────────────────────────────
# Stat efetivo com stage modifier
# ──────────────────────────────────────────────────────────────────────────────
const STAGE_MULT : Array[float] = [0.25, 0.286, 0.333, 0.4, 0.5, 0.667, 1.0,
		1.5, 2.0, 2.5, 3.0, 3.5, 4.0]

func effective_attack(is_special: bool) -> int:
	var base := sp_atk if is_special else attack
	var mult := STAGE_MULT[stages["spa" if is_special else "atk"] + 6]
	# Burn reduz ataque físico a 50%
	if status == Status.BURN and not is_special:
		mult *= 0.5
	return maxi(1, roundi(base * mult))

func effective_defense(is_special: bool) -> int:
	var base := sp_def if is_special else defense
	var mult := STAGE_MULT[stages["spd" if is_special else "def"] + 6]
	return maxi(1, roundi(base * mult))

func effective_speed() -> int:
	var mult := STAGE_MULT[stages["spe"] + 6]
	if status == Status.PARALYSIS:
		mult *= 0.5
	return maxi(1, roundi(speed * mult))

func accuracy_modifier() -> float:
	return STAGE_MULT[stages["acc"] + 6]

func evasion_modifier() -> float:
	return STAGE_MULT[stages["eva"] + 6]

# ──────────────────────────────────────────────────────────────────────────────
# Estado de saúde
# ──────────────────────────────────────────────────────────────────────────────
func is_fainted() -> bool:
	return hp <= 0

func take_damage(amount: int) -> int:
	var actual := mini(amount, hp)
	hp = maxi(0, hp - amount)
	return actual

func heal(amount: int) -> int:
	var actual := mini(amount, max_hp - hp)
	hp = mini(max_hp, hp + amount)
	return actual

func hp_ratio() -> float:
	return float(hp) / float(max_hp)

# ──────────────────────────────────────────────────────────────────────────────
# Moves
# ──────────────────────────────────────────────────────────────────────────────
func get_usable_moves() -> Array[Dictionary]:
	var usable : Array[Dictionary] = []
	for m in moves:
		if m.get("pp_current", 0) > 0:
			usable.append(m)
	return usable

func use_move(move_index: int) -> Dictionary:
	if move_index < 0 or move_index >= moves.size():
		return {}
	var m := moves[move_index]
	if m.get("pp_current", 0) <= 0:
		return {}
	m["pp_current"] -= 1
	return m

# ──────────────────────────────────────────────────────────────────────────────
# Status
# ──────────────────────────────────────────────────────────────────────────────
func apply_status(new_status: Status) -> bool:
	if status != Status.NONE:
		return false  # já tem status
	status = new_status
	if new_status == Status.SLEEP:
		sleep_turns = RNGManager.randi_range(1, 3)
	return true

func tick_status() -> int:
	## Processa dano de fim de turno. Retorna dano causado (0 se nenhum).
	match status:
		Status.BURN:
			return take_damage(maxi(1, max_hp / 16))
		Status.POISON:
			return take_damage(maxi(1, max_hp / 8))
		Status.BAD_POISON:
			bad_poison_ctr += 1
			return take_damage(maxi(1, max_hp * bad_poison_ctr / 16))
		Status.SLEEP:
			sleep_turns = maxi(0, sleep_turns - 1)
			if sleep_turns == 0:
				status = Status.NONE
		Status.FREEZE:
			if RNGManager.chance(0.2):
				status = Status.NONE
	return 0

func can_move() -> bool:
	match status:
		Status.SLEEP:
			return sleep_turns == 0
		Status.FREEZE:
			return false
		Status.PARALYSIS:
			return not RNGManager.chance(0.25)
	return true

func status_name() -> String:
	match status:
		Status.BURN:      return "BRN"
		Status.POISON:    return "PSN"
		Status.BAD_POISON:return "TOX"
		Status.PARALYSIS: return "PAR"
		Status.SLEEP:     return "SLP"
		Status.FREEZE:    return "FRZ"
	return ""

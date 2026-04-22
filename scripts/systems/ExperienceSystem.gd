class_name ExperienceSystem
extends RefCounted

## Experience formula constants
const ALPHA_MULTIPLIER := 2.5
const TRAINER_EXP_RATIO := 0.30


## Returns EXP gained from defeating a wild pokemon.
## Alpha pokemon grant 2.5× EXP.
func calculate_exp_gain(pokemon_level: int, is_alpha: bool) -> int:
	var base_exp := int(floor(0.8 * pow(pokemon_level, 3))) / 5
	base_exp = maxi(base_exp, 5)
	if is_alpha:
		base_exp = int(base_exp * ALPHA_MULTIPLIER)
	return base_exp


## Returns trainer EXP (30% of pokemon EXP gain).
func trainer_exp_from_battle(pokemon_level: int) -> int:
	return int(ceil(calculate_exp_gain(pokemon_level, false) * TRAINER_EXP_RATIO))


## Returns the total EXP required to reach a given level.
## Formula: floor(0.8 * level^3)
func exp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	return int(floor(0.8 * pow(level, 3)))


## Returns true if current_exp is enough to trigger a level-up.
func check_level_up(current_exp: int, current_level: int) -> bool:
	if current_level >= 99:
		return false
	return current_exp >= exp_for_level(current_level + 1)


## Returns how much EXP is needed to reach the next level from current_level.
func exp_to_next_level(current_exp: int, current_level: int) -> int:
	if current_level >= 99:
		return 0
	return maxi(exp_for_level(current_level + 1) - current_exp, 0)
